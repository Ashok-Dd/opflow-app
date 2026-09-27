import '../../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';

import '../../../core/errors.dart';
import '../../../data/places.dart';
import '../../../mock/data.dart';
import '../../../mock/format.dart';
import '../../../mock/models.dart';
import '../../../state/patient_store.dart';
import '../../../state/session.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/op_button.dart';
import '../../../widgets/op_loader.dart';
import '../../auth/about_you.dart';
import '../widgets.dart';

// ---------------------------------------------------------------------------
// My details

class MyDetailsScreen extends ConsumerStatefulWidget {
  const MyDetailsScreen({super.key});

  @override
  ConsumerState<MyDetailsScreen> createState() => _MyDetailsScreenState();
}

class _MyDetailsScreenState extends ConsumerState<MyDetailsScreen> {
  late final me = ref.read(patientProvider).me;
  late final _name = TextEditingController(text: me.name);
  late final _age = TextEditingController(text: '${me.age}');
  late String _gender = me.gender;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final age = int.tryParse(_age.text) ?? me.age;
    final done = await runStep(context, 'Saving…'.tr, () => SessionStore.instance.saveProfile(name: _name.text, age: age, gender: _gender));
    if (!done || !mounted) return;
    ref.read(patientProvider).updateMe(name: _name.text.trim(), age: age, gender: _gender);
    showToast(context, 'Saved'.tr);
    context.popOr('/me');
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(sessionProvider).phone;
    return OpPage(
      title: 'My details'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          GenderAgeNameForm(name: _name, age: _age, gender: _gender, onGender: (g) => setState(() => _gender = g), onChanged: () => setState(() {})),
          const SizedBox(height: 20),
          Text('Mobile number'.tr, style: OpText.smallStrong),
          const SizedBox(height: 6),
          OpCard(
            color: OpColors.paperDeep,
            child: Row(
              children: [
                Text(phone.isEmpty ? 'Not added' : '+91 ${prettyPhone(phone)}', style: OpText.monoBody),
                const Spacer(),
                const Icon(Icons.lock_outline, size: 18, color: OpColors.inkSoft),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('To change your number, please log out and log in with the new number.'.tr, style: OpText.small.copyWith(fontSize: 13)),
        ],
      ),
      bottom: OpButton(label: 'Save'.tr, onPressed: _name.text.trim().length >= 2 && _gender.isNotEmpty ? _save : null),
    );
  }
}

// ---------------------------------------------------------------------------
// Payments

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(patientProvider);
    final list = [...store.bookings]..sort((a, b) => (b.bookedAt ?? b.windowStart).compareTo(a.bookedAt ?? a.windowStart));
    final paid = list.where((b) => b.status != BookingStatus.cancelledByDoctor).fold<int>(0, (a, b) => a + b.total);
    return OpPage(
      title: 'Payments and money back'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          OpCard(
            color: OpColors.forest,
            borderColor: OpColors.forest,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL PAID'.tr, style: OpText.label.copyWith(color: OpColors.mint)),
                      Text(rupees(paid), style: OpText.mono(28, weight: FontWeight.w600, color: OpColors.paper)),
                    ],
                  ),
                ),
                Text('{0} payments'.trf([list.length]), style: OpText.small.copyWith(color: OpColors.mint)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final (i, b) in list.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OpCard(
                onTap: () => showReceipt(context, b, store.me.name),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(MockData.doctor(b.doctorId).name, style: OpText.bodyStrong),
                          Text('${dayLabel(b.date)} · Token ${b.tokenLabel}${b.emergency ? ' · Emergency' : ''}', style: OpText.small.copyWith(fontSize: 13)),
                          const SizedBox(height: 6),
                          b.status == BookingStatus.cancelledByDoctor
                              ? const StatusTag('Money back sent', tone: Tone.good, icon: Icons.currency_rupee)
                              : const StatusTag('Paid', tone: Tone.calm, icon: Icons.check),
                        ],
                      ),
                    ),
                    Text(
                      b.status == BookingStatus.cancelledByDoctor ? '+${rupees(b.total)}' : rupees(b.total),
                      style: OpText.mono(17, weight: FontWeight.w600, color: b.status == BookingStatus.cancelledByDoctor ? OpColors.fern : OpColors.ink),
                    ),
                  ],
                ),
              ).staggerIn(i),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Messages settings

class AlertSettingsScreen extends ConsumerWidget {
  const AlertSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(patientProvider);
    Widget row(IconData icon, String title, String text, bool value, ValueChanged<bool> on) => MenuRow(
          icon: icon,
          title: title,
          detail: text,
          trailing: Switch(value: value, onChanged: on),
          onTap: () => on(!value),
        );
    return OpPage(
      title: 'Messages settings'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          Text('Choose what we tell you about.'.tr, style: OpText.body.copyWith(color: OpColors.inkSoft)),
          const SizedBox(height: 16),
          MenuGroup(children: [
            row(Icons.alarm, 'Reminders', 'Before your time starts', s.remindMe, (v) => s.setAlerts(remind: v)),
            row(Icons.schedule, 'Late alerts', 'When the doctor is running late', s.lateAlerts, (v) => s.setAlerts(late: v)),
            row(Icons.directions_walk, 'Turn alerts', 'When your turn is coming', s.turnAlerts, (v) => s.setAlerts(turn: v)),
          ]),
          const SizedBox(height: 16),
          InfoBox(icon: Icons.info_outline, child: Text('Booking done, date changed and money back messages are always sent.'.tr)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Help

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const _faq = [
    ('What is "Your time"?', 'It is one hour, like 10 – 11 AM. Please come at the start of this hour. The doctor will see you within this hour, or a little later if the doctor is late.'),
    ('What is a token?', 'It is your number in the line. The screen shows which token the doctor is seeing now.'),
    ('Can I cancel my booking?', 'No. After paying, you cannot cancel. But you can change the date or time once, up to 2 hours before your time.'),
    ('What if the doctor cancels?', 'You get your full money back. It reaches your account in 5–7 days.'),
    ('What if I miss my time?', 'If you do not come and did not change the time, there is no money back.'),
    ('Does OPflow tell me my disease?', 'No. OPflow only helps you find the right doctor. Only the doctor can tell you what is wrong.'),
  ];


  @override
  Widget build(BuildContext context) {
    return OpPage(
      title: 'Help'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          const SectionLabel('Common questions'),
          Container(
            decoration: BoxDecoration(color: OpColors.card, borderRadius: OpRadius.cardAll, border: Border.all(color: OpColors.line, width: 1.2)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, (q, a)) in _faq.indexed) ...[
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(q.tr, style: OpText.bodyStrong),
                      iconColor: OpColors.fern,
                      collapsedIconColor: OpColors.inkSoft,
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedAlignment: Alignment.centerLeft,
                      children: [Text(a.tr, style: OpText.body.copyWith(color: OpColors.inkSoft))],
                    ),
                  ),
                  if (i < _faq.length - 1) const Divider(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Call us'),
          OpCard(
            onTap: () => showCallSheet(context, name: 'OPflow help', phone: MockData.opflowHelpPhone),
            child: Row(
              children: [
                const Icon(Icons.call_outlined, color: OpColors.fern),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(MockData.opflowHelpPhone, style: OpText.mono(18, weight: FontWeight.w600)),
                      Text('Mon – Sat, 9 AM – 7 PM'.tr, style: OpText.small.copyWith(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rules and privacy

const _rulePages = {
  'privacy': (
    'Privacy',
    Icons.lock_outline,
    [
      'We keep your name, age, mobile number and bookings only to run your bookings.',
      'Only the doctor you booked can see your booking and the problem you wrote.',
      'We never sell your details to anyone.',
      'You can ask us to delete your account any time from Help.',
    ]
  ),
  'terms': (
    'Terms of use',
    Icons.description_outlined,
    [
      'OPflow helps you book a time with a doctor. The doctor gives the treatment, not OPflow.',
      'Please give correct details for the patient.',
      '"Your time" is an hour. The exact minute depends on the doctor and other patients.',
      'The doctor may be late because of emergencies. We will tell you when this happens.',
    ]
  ),
  'money': (
    'Money back rules',
    Icons.currency_rupee,
    [
      'You cannot cancel a booking after paying.',
      'You can change the date or time once, free, up to 2 hours before your time.',
      'If the doctor or hospital cancels, you get your full money back, on its own. It reaches in 5–7 days.',
      'If you miss your time and did not change it, there is no money back.',
    ]
  ),
  'medical': (
    'Medical note',
    Icons.health_and_safety_outlined,
    [
      'OPflow does not tell you what disease you have.',
      'The health problem list only helps you find the right type of doctor.',
      'In an emergency, call 108 or go to the nearest hospital. Do not wait for a booking.',
    ]
  ),
};

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OpPage(
      title: 'Rules and privacy'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          MenuGroup(children: [
            for (final e in _rulePages.entries) MenuRow(icon: e.value.$2, title: e.value.$1.tr, onTap: () => context.push('/me/rules/${e.key}')),
          ]),
        ],
      ),
    );
  }
}

class RulePage extends StatelessWidget {
  const RulePage({super.key, required this.pageId});

  final String pageId;

  @override
  Widget build(BuildContext context) {
    final page = _rulePages[pageId] ?? _rulePages['terms']!;
    return OpPage(
      title: page.$1.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          Icon(page.$2, color: OpColors.fern, size: 40),
          const SizedBox(height: 12),
          Text(page.$1.tr, style: OpText.display),
          const SizedBox(height: 18),
          for (final (i, line) in page.$3.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 28, child: Text('${i + 1}.', style: OpText.mono(16, weight: FontWeight.w600, color: OpColors.fern))),
                  Expanded(child: Text(line.tr, style: OpText.body.copyWith(fontSize: 17))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My area

class PlaceScreen extends ConsumerStatefulWidget {
  const PlaceScreen({super.key});

  @override
  ConsumerState<PlaceScreen> createState() => _PlaceScreenState();
}

enum _Find { idle, finding, found, trouble }

/// The patient's area, from the phone's location only (no list of places). Also opened from sign-up.
class _PlaceScreenState extends ConsumerState<PlaceScreen> {
  _Find _state = _Find.idle;
  Place? _found;
  LocationProblem? _problem;

  Future<void> _locate() async {
    setState(() {
      _state = _Find.finding;
      _problem = null;
    });
    try {
      final p = await placeFromPhone();
      if (!mounted) return;
      ref.read(sessionProvider).setPlace(p); // saved at once; doctors near here load again
      setState(() {
        _found = p;
        _state = _Find.found;
      });
    } on LocationProblem catch (e) {
      if (!mounted) return;
      setState(() {
        _problem = e;
        _state = _Find.trouble;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _problem = const LocationProblem(LocationTrouble.failed, 'Could not find your location. Please try again in an open place.');
        _state = _Find.trouble;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final saved = session.place;
    final found = _found;
    return OpPage(
      title: 'Your area'.tr,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 8, OpSpace.gutter, 28),
        children: [
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: Lottie.asset('assets/lottie/locate.json', animate: !OpMotion.reduced, repeat: true, frameRate: FrameRate.max),
            ),
          ),
          Text(
            _state == _Find.found ? 'You are here'.tr : 'Find doctors near you'.tr,
            textAlign: TextAlign.center,
            style: OpText.display.copyWith(fontSize: 30),
          ),
          const SizedBox(height: 8),
          Text(
            _state == _Find.finding
                ? 'Finding your location…'.tr
                : 'OPflow uses your location only to show the doctors and hospitals closest to you.'.tr,
            textAlign: TextAlign.center,
            style: OpText.body.copyWith(color: OpColors.inkSoft),
          ),
          const SizedBox(height: 22),
          if (_state == _Find.found && found != null) ...[
            OpCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: OpColors.mint, borderRadius: OpRadius.controlAll),
                    child: const Icon(Icons.place, color: OpColors.forest),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(found.label, style: OpText.heading.copyWith(fontSize: 19)),
                        const SizedBox(height: 2),
                        Text(
                          MockData.hospitals.any((h) => h.lat != null)
                              ? '{0} near you (within 10 km)'.trf([doctorsCount(doctorsNear(found.lat, found.lng))])
                              : 'Doctors near here are shown first.'.tr,
                          style: OpText.small.copyWith(color: OpColors.fern, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OpButton(label: 'Done'.tr, icon: Icons.check, onPressed: () => context.popOr('/me')),
            const SizedBox(height: 10),
            OpButton(label: 'Find my location again'.tr, kind: OpButtonKind.quiet, onPressed: _locate),
          ] else if (_state == _Find.trouble && _problem != null) ...[
            InfoBox(icon: Icons.location_off_outlined, tone: Tone.bad, child: Text(_problem!.message.tr)),
            const SizedBox(height: 14),
            if (_problem!.trouble == LocationTrouble.off)
              OpButton(label: 'Turn on location'.tr, icon: Icons.settings, onPressed: () => Geolocator.openLocationSettings())
            else if (_problem!.trouble == LocationTrouble.blocked)
              OpButton(label: 'Open settings'.tr, icon: Icons.settings, onPressed: () => Geolocator.openAppSettings()),
            const SizedBox(height: 10),
            OpButton(
              label: 'Try again'.tr,
              icon: Icons.my_location,
              kind: _problem!.trouble == LocationTrouble.off || _problem!.trouble == LocationTrouble.blocked ? OpButtonKind.secondary : OpButtonKind.primary,
              onPressed: _locate,
            ),
          ] else ...[
            OpButton(
              label: _state == _Find.finding ? 'Finding…'.tr : 'Use my current location'.tr,
              icon: Icons.my_location,
              loading: _state == _Find.finding,
              onPressed: _state == _Find.finding ? null : _locate,
            ),
            if (saved.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Your area now: {0}'.trf([saved]), textAlign: TextAlign.center, style: OpText.small),
            ],
          ],
        ],
      ),
    );
  }
}
