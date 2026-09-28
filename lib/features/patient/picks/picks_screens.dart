import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors.dart';
import '../../../data/remote.dart';
import '../../../l10n/lang.dart';
import '../../../mock/data.dart';
import '../../../mock/format.dart';
import '../../../state/patient_store.dart';
import '../../../state/picks.dart';
import '../../../state/session.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/doctor_card.dart';
import '../../../widgets/op_button.dart';
import '../../../widgets/op_loader.dart';

/// "Find Your Right Doctor": OPflow suggests up to 3 doctors of one type near the patient, for a small fee.
/// Picked by OPflow from published criteria — doctors can never pay to be suggested. Always shown as a
/// recommendation, never as "the best doctor", and never a guarantee of treatment outcome.

const _disclaimer = 'This is a recommendation, not a guarantee of treatment outcome.';

// ---------------------------------------------------------------------------
// Home card

/// The card on Home (hidden when the admin switched the feature off).
class RightDoctorCard extends ConsumerStatefulWidget {
  const RightDoctorCard({super.key});

  @override
  ConsumerState<RightDoctorCard> createState() => _RightDoctorCardState();
}

class _RightDoctorCardState extends ConsumerState<RightDoctorCard> {
  PickInfo? _info;

  @override
  void initState() {
    super.initState();
    ref.read(patientProvider).pickInfo().then((i) {
      if (mounted) setState(() => _info = i);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null || !info.enabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: OpCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        borderColor: OpColors.forest,
        onTap: () => context.push('/right-doctor'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: OpColors.forest, borderRadius: OpRadius.controlAll),
                  child: const Icon(Icons.medical_services_outlined, color: OpColors.paper, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('FIND YOUR RIGHT DOCTOR'.tr, style: OpText.label.copyWith(color: OpColors.forest, letterSpacing: 1.6))),
              ],
            ),
            const SizedBox(height: 12),
            Text('Not sure whom to consult?'.tr, style: OpText.heading.copyWith(fontSize: 21)),
            const SizedBox(height: 6),
            Text(
              'Tell OPflow which type of doctor you want to consult. We will suggest the right doctor(s) near you, based on their qualifications, experience, training, areas of practice and patient feedback.'.tr,
              style: OpText.body.copyWith(color: OpColors.inkSoft),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text('{0} · Personalized recommendation'.trf([info.priceText]),
                      style: OpText.smallStrong.copyWith(color: OpColors.ink, fontSize: 13.5)),
                ),
                OpButton(label: 'Find My Doctor'.tr, icon: Icons.arrow_forward, expand: false, height: 42, onPressed: () => context.push('/right-doctor')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Which type of doctor

class RightDoctorScreen extends StatelessWidget {
  const RightDoctorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final types = [...MockData.types]..sort((a, b) => a.simple.tr.compareTo(b.simple.tr));
    return OpPage(
      title: 'Find Your Right Doctor'.tr,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 12, OpSpace.gutter, 32),
        children: [
          Text('Let OPflow find a doctor for you'.tr, style: OpText.display.copyWith(fontSize: 28)),
          const SizedBox(height: 8),
          Text('Choose the type of doctor you need. We will suggest up to 3 doctors near you.'.tr, style: OpText.body.copyWith(color: OpColors.inkSoft)),
          const SizedBox(height: 18),
          const SectionLabel('Choose a type of doctor'),
          MenuGroup(children: [
            for (final t in types)
              MenuRow(icon: t.icon, title: t.simple.tr, detail: t.proper.tr, onTap: () => context.push('/right-doctor/${t.id}')),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. The offer: how OPflow recommends, the price, "I understand", pay

class PickOfferScreen extends ConsumerStatefulWidget {
  const PickOfferScreen({super.key, required this.typeId});

  final String typeId;

  @override
  ConsumerState<PickOfferScreen> createState() => _PickOfferScreenState();
}

class _PickOfferScreenState extends ConsumerState<PickOfferScreen> {
  PickOffer? _offer;
  Object? _error;
  bool _agree = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final o = await ref.read(patientProvider).pickOffer(widget.typeId);
      if (mounted) setState(() => _offer = o);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pay() async {
    final store = ref.read(patientProvider);
    PickResult? result;
    var tried = false;
    await runWithLoader(context, 'Checking your payment…'.tr, detail: 'Please do not close the app.'.tr, () async {
      tried = true;
      result = await store.buyPick(widget.typeId);
    }, timeout: const Duration(minutes: 20));
    if (!mounted || !tried) return;
    if (result == null) {
      showError(context, 'The payment did not go through. No money was taken. Please try again.'.tr);
      return;
    }
    context.pushReplacement('/right-doctor/result/${result!.id}?fresh=1');
  }

  @override
  Widget build(BuildContext context) {
    final o = _offer;
    final type = MockData.type(widget.typeId);
    final place = ref.watch(sessionProvider).place;
    return OpPage(
      title: 'Find Your Right Doctor'.tr,
      body: _error != null
          ? EmptyState(icon: Icons.wifi_off, title: 'Could not load'.tr, text: friendlyMessage(_error!), action: 'Try again'.tr, onAction: _load)
          : o == null
              ? const Center(child: OpLoader())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 12, OpSpace.gutter, 32),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: OpColors.mint, borderRadius: OpRadius.controlAll),
                          child: Icon(type.icon, color: OpColors.forest, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text('Looking for a {0}?'.trf([o.typeName.tr]), style: OpText.display.copyWith(fontSize: 26))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'OPflow suggests up to {0} doctors near you who suit what you need, and explains why for each one.'.trf([o.max]),
                      style: OpText.body.copyWith(color: OpColors.inkSoft),
                    ),
                    const SizedBox(height: 18),
                    const SectionLabel('How we recommend'),
                    OpCard(child: Text(o.criteria.tr, style: OpText.body)),
                    const SizedBox(height: 18),
                    if (!o.enabled)
                      InfoBox(tone: Tone.warn, icon: Icons.pause_circle_outline, child: Text('Doctor suggestions are stopped for a short time. Please try again later.'.tr))
                    else if (o.available == 0) ...[
                      InfoBox(
                        tone: Tone.calm,
                        icon: Icons.info_outline,
                        child: Text('OPflow has no suggestions for this type of doctor near you yet. We will not charge you. You can still see every {0} near you.'
                            .trf([o.typeName.tr])),
                      ),
                      const SizedBox(height: 14),
                      OpButton(label: 'See all {0}s'.trf([o.typeName.tr]), kind: OpButtonKind.secondary, onPressed: () => context.push('/doctors?type=${widget.typeId}')),
                    ] else ...[
                      OpCard(
                        child: Row(
                          children: [
                            const Icon(Icons.place_outlined, color: OpColors.fern),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                place.isEmpty ? 'Suggestions near your area'.tr : 'Suggestions near {0}'.trf([place]),
                                style: OpText.bodyStrong,
                              ),
                            ),
                            TextButton(onPressed: () => context.push('/me/place'), child: Text('Change'.tr)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TapScale(
                        onTap: () => setState(() => _agree = !_agree),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(value: _agree, onChanged: (v) => setState(() => _agree = v ?? false)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'I understand this is a recommendation, not a guarantee of treatment outcome. OPflow uses my area only to find doctors near me.'.tr,
                                  style: OpText.small.copyWith(color: OpColors.ink),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
      bottom: o == null || !o.enabled || o.available == 0
          ? null
          : BottomBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('{0} · Personalized recommendation'.trf([o.priceText]), style: OpText.smallStrong),
                  const SizedBox(height: 8),
                  OpButton(
                    label: 'Pay {0} · See my doctors'.trf([o.priceText]),
                    icon: Icons.lock_outline,
                    onPressed: () => _agree ? _pay() : showError(context, 'Please tick the box above to agree first.'.tr),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. "Your OPflow Recommendation"

class PickResultScreen extends ConsumerStatefulWidget {
  const PickResultScreen({super.key, required this.id, this.initial, this.backHome = false});

  final String id;
  final PickResult? initial;

  /// Opened right after paying: the back arrow goes to Home (not back to the payment screen).
  final bool backHome;

  @override
  ConsumerState<PickResultScreen> createState() => _PickResultScreenState();
}

class _PickResultScreenState extends ConsumerState<PickResultScreen> {
  PickResult? _r;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _r = widget.initial;
    if (_r == null) _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      Remote.instance.prepare();
      // Opened from Me or a link: the hospitals near the patient (names, distances on the cards) may not be loaded yet.
      if (!Remote.instance.loaded) await Remote.instance.loadDirectory().timeout(const Duration(seconds: 20)).catchError((_) {});
      final r = await ref.read(patientProvider).pickResult(widget.id);
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return OpPage(
      title: 'Your OPflow Recommendation'.tr,
      onBack: widget.backHome ? () => context.go('/home') : null,
      body: _error != null
          ? EmptyState(icon: Icons.wifi_off, title: 'Could not load'.tr, text: friendlyMessage(_error!), action: 'Try again'.tr, onAction: _load)
          : r == null
              ? const Center(child: OpLoader())
              : PickResultView(result: r),
    );
  }
}

/// The saved list (also shown right after paying).
class PickResultView extends StatelessWidget {
  const PickResultView({super.key, required this.result});

  final PickResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 12, OpSpace.gutter, 32),
      children: [
        Text('{0} near you'.trf([r.typeName.tr]), style: OpText.display.copyWith(fontSize: 26)),
        if (r.place != null && r.place!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Near {0}{1}'.trf([r.place!, r.paidAt == null ? '' : ' · ${dayLabel(r.paidAt!)}']), style: OpText.small),
        ],
        const SizedBox(height: 14),
        InfoBox(icon: Icons.info_outline, child: Text('Based on the criteria OPflow publishes. {0}'.trf([_disclaimer.tr]))),
        if (r.refunded) ...[
          const SizedBox(height: 14),
          InfoBox(
            tone: Tone.good,
            icon: Icons.currency_rupee,
            child: Text('Your {0} is sent back. It reaches your account in 5–7 days.'.trf([r.amountText.isEmpty ? '₹99' : r.amountText])),
          ),
        ],
        if (r.doctors.isEmpty && !r.refunded) ...[
          const SizedBox(height: 18),
          EmptyState(icon: Icons.search_off, title: 'No doctors to show'.tr, text: 'Please contact OPflow help.'.tr),
        ],
        for (var i = 0; i < r.doctors.length; i++) ...[
          const SizedBox(height: 18),
          _PickDoctorBlock(n: i + 1, p: r.doctors[i]),
        ],
      ],
    );
  }
}

class _PickDoctorBlock extends StatelessWidget {
  const _PickDoctorBlock({required this.n, required this.p});

  final int n;
  final PickDoctor p;

  @override
  Widget build(BuildContext context) {
    final d = p.doctor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: OpColors.forest, borderRadius: OpRadius.smallAll),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified_outlined, size: 14, color: OpColors.paper),
                const SizedBox(width: 5),
                Text('OPflow recommended'.tr, style: OpText.smallStrong.copyWith(color: OpColors.paper, fontSize: 12)),
              ]),
            ),
            const SizedBox(width: 8),
            Text('SUGGESTION {0}'.trf([n]), style: OpText.label.copyWith(color: OpColors.forest, letterSpacing: 1.6)),
          ],
        ),
        const SizedBox(height: 8),
        DoctorCard(doctor: d, onTap: () => context.push('/doctor/${d.id}'), onBook: () => context.push('/book/${d.id}')),
        if (p.reasons.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(color: OpColors.mint.withValues(alpha: 0.55), borderRadius: OpRadius.cardAll, border: Border.all(color: OpColors.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Why OPflow suggests this doctor'.tr, style: OpText.smallStrong.copyWith(color: OpColors.forest)),
                const SizedBox(height: 6),
                for (final reason in p.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.check, size: 15, color: OpColors.fern)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(reason, style: OpText.small.copyWith(color: OpColors.ink))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Me → My doctor suggestions

class MyPicksScreen extends ConsumerStatefulWidget {
  const MyPicksScreen({super.key});

  @override
  ConsumerState<MyPicksScreen> createState() => _MyPicksScreenState();
}

class _MyPicksScreenState extends ConsumerState<MyPicksScreen> {
  List<PickSummary>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await ref.read(patientProvider).myPicks();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return OpPage(
      title: 'My doctor suggestions'.tr,
      body: _error != null
          ? EmptyState(icon: Icons.wifi_off, title: 'Could not load'.tr, text: friendlyMessage(_error!), action: 'Try again'.tr, onAction: _load)
          : items == null
              ? const Center(child: OpLoader())
              : items.isEmpty
                  ? EmptyState(
                      icon: Icons.medical_services_outlined,
                      title: 'No suggestions yet'.tr,
                      text: 'Not sure whom to consult? OPflow can suggest doctors near you.'.tr,
                      action: 'Find My Doctor'.tr,
                      onAction: () => context.push('/right-doctor'),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(OpSpace.gutter),
                      children: [
                        MenuGroup(children: [
                          for (final p in items)
                            MenuRow(
                              icon: MockData.type(p.typeId).icon,
                              title: p.typeName.tr,
                              detail: p.status == 'refunded'
                                  ? 'Money sent back'.tr
                                  : '{0} · {1}'.trf([doctorsCount(p.count), p.paidAt == null ? '' : dayLabel(p.paidAt!)]),
                              onTap: () => context.push('/right-doctor/result/${p.id}'),
                            ),
                        ]),
                      ],
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// The web version comes back here after Cashfree's payment page

class PickReturnScreen extends ConsumerStatefulWidget {
  const PickReturnScreen({super.key, required this.id, required this.checkoutSaidPaid});

  final String id;
  final bool checkoutSaidPaid;

  @override
  ConsumerState<PickReturnScreen> createState() => _PickReturnScreenState();
}

class _PickReturnScreenState extends ConsumerState<PickReturnScreen> {
  PickResult? _r;
  bool _done = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _done = false;
      _message = null;
    });
    try {
      Remote.instance.prepare();
      await Remote.instance.loadDirectory().timeout(const Duration(seconds: 20)).catchError((_) {});
      final r = await ref.read(patientProvider).settlePickReturn(widget.id, checkoutSaidPaid: widget.checkoutSaidPaid);
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (mounted) setState(() => _message = friendlyMessage(e));
    }
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    if (_done && r != null) return OpPage(title: 'Your OPflow Recommendation'.tr, onBack: () => context.go('/home'), body: PickResultView(result: r));
    return OpPage(
      title: 'Find Your Right Doctor'.tr,
      body: !_done
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const OpLoader(size: 72),
                const SizedBox(height: 16),
                Text('Checking your payment…'.tr, style: OpText.title),
              ]),
            )
          : EmptyState(
              icon: _message == null ? Icons.error_outline : Icons.hourglass_top_rounded,
              title: _message == null ? 'Payment did not go through'.tr : 'Still confirming your payment'.tr,
              text: _message ?? 'No money was taken. You can try again.'.tr,
              action: _message == null ? 'Go back'.tr : 'Check again'.tr,
              onAction: _message == null ? () => context.go('/home') : _check,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// "How was your visit?" (private: only OPflow sees it)

class VisitFeedbackCard extends ConsumerStatefulWidget {
  const VisitFeedbackCard({super.key, required this.bookingId, required this.doctorName});

  final String bookingId;
  final String doctorName;

  @override
  ConsumerState<VisitFeedbackCard> createState() => _VisitFeedbackCardState();
}

class _VisitFeedbackCardState extends ConsumerState<VisitFeedbackCard> {
  int _rating = 0;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await ref.read(patientProvider).sendFeedback(widget.bookingId, _rating, _note.text);
      if (mounted) showToast(context, 'Thank you. It helps us suggest the right doctors.'.tr);
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(patientProvider);
    if (store.ratedBookings.contains(widget.bookingId)) {
      return InfoBox(tone: Tone.good, icon: Icons.check_circle_outline, child: Text('Thank you for telling us about this visit.'.tr));
    }
    return OpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How was your visit?'.tr, style: OpText.heading.copyWith(fontSize: 19)),
          const SizedBox(height: 4),
          Text('Only OPflow sees this, never the doctor or other patients. It helps us suggest the right doctors.'.tr, style: OpText.small),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i',
                  onPressed: _busy ? null : () => setState(() => _rating = i),
                  icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 34, color: i <= _rating ? OpColors.amber : OpColors.inkFaint),
                ),
            ],
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              maxLength: 300,
              maxLines: 2,
              decoration: InputDecoration(hintText: 'Anything to tell us? (not needed)'.tr),
            ),
            const SizedBox(height: 6),
            OpButton(label: 'Send'.tr, loading: _busy, onPressed: _busy ? null : _send),
          ],
        ],
      ),
    );
  }
}

