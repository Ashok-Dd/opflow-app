import '../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../mock/data.dart';
import '../../mock/format.dart';
import '../../mock/models.dart';
import '../../state/directory_store.dart';
import '../../state/doctor_store.dart';
import '../../state/session.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/language.dart';
import '../../widgets/doctor_card.dart';
import '../../widgets/doctor_portrait.dart';
import '../../widgets/op_button.dart';
import '../../widgets/op_loader.dart';
import '../auth/doctor_new_password.dart';
import '../patient/widgets.dart';
import '../../core/errors.dart';
import '../../data/api.dart';
import '../../data/config.dart';

/// How complete the doctor's public profile is, with what is still missing.
(double, List<String>) profileStrength(Doctor d, DoctorStore s) {
  final missing = <String>[];
  if (d.photoPath == null) missing.add('Add your photo');
  if (d.about.trim().length < 40) missing.add('Write a few lines about you');
  if (d.languages.length < 2) missing.add('Add the languages you speak');
  if (s.blocksFor(1).isEmpty && s.blocksFor(2).isEmpty) missing.add('Set your timings');
  // Fee is always set, so it counts as one of the five parts.
  return ((5 - missing.length) / 5, missing);
}

class DoctorMeTab extends ConsumerWidget {
  const DoctorMeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(doctorProvider);
    ref.watch(directoryProvider);
    final d = s.doctor;
    final todayEarn = s.earnings(1).fold<int>(0, (a, r) => a + r.doctorShare);
    final (strength, missing) = profileStrength(d, s);

    Future<void> logout() async {
      final ok = await confirmSheet(context, title: 'Log out?'.tr, text: 'You will need your Doctor ID and password to log in again.'.tr, yes: 'Yes, log out'.tr, icon: Icons.logout);
      if (!ok || !context.mounted) return;
      SessionStore.instance.logout();
      context.go('/who');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 22, OpSpace.gutter, 36),
      children: [
        // Profile header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TapScale(onTap: () => context.push('/d/me/profile'), child: DoctorPortrait(doctor: d, width: 96)),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID {0}'.trf([SessionStore.demoDoctorId]), style: OpText.mono(12, color: OpColors.inkSoft)),
                  const SizedBox(height: 4),
                  Text(d.name, style: OpText.title),
                  Text('${MockData.type(d.typeId).simple} · ${d.degrees}', style: OpText.small.copyWith(fontSize: 13)),
                  const SizedBox(height: 10),
                  OpButton(
                    label: 'Edit profile'.tr,
                    icon: Icons.edit_outlined,
                    expand: false,
                    height: 42,
                    kind: OpButtonKind.secondary,
                    onPressed: () => context.push('/d/me/profile'),
                  ),
                ],
              ),
            ),
          ],
        ).staggerIn(0),
        const SizedBox(height: 20),
        // Profile strength
        OpCard(
          onTap: missing.isEmpty ? null : () => context.push('/d/me/profile'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('PROFILE STRENGTH'.tr, style: OpText.label.copyWith(color: OpColors.ink, letterSpacing: 1.4))),
                  Text('${(strength * 100).round()}%', style: OpText.mono(18, weight: FontWeight.w600, color: strength == 1 ? OpColors.fern : OpColors.amber)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < 5; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: OpMotion.page,
                        height: 6,
                        color: i < (strength * 5).round() ? OpColors.fern : OpColors.paperDeep,
                      ),
                    ),
                    if (i < 4) const SizedBox(width: 4),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                missing.isEmpty ? 'Your profile is complete. Patients trust full profiles more.' : 'Next: ${missing.first}.',
                style: OpText.small.copyWith(fontSize: 14),
              ),
            ],
          ),
        ).staggerIn(1),
        const SizedBox(height: 12),
        OpCard(
          color: OpColors.forest,
          borderColor: OpColors.forest,
          onTap: () => context.push('/d/me/earnings'),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOU GET TODAY'.tr, style: OpText.label.copyWith(color: OpColors.mint)),
                    Text(rupees(todayEarn), style: OpText.mono(28, weight: FontWeight.w600, color: OpColors.paper)),
                  ],
                ),
              ),
              Text('See earnings'.tr, style: OpText.smallStrong.copyWith(color: OpColors.leaf)),
              const Icon(Icons.chevron_right, color: OpColors.leaf),
            ],
          ),
        ).staggerIn(2),
        const SizedBox(height: 26),
        const SectionLabel('My work'),
        MenuGroup(children: [
          MenuRow(icon: Icons.visibility_outlined, title: 'See my page as patients see it'.tr, onTap: () => context.push('/doctor/${d.id}?preview=1')),
          MenuRow(icon: Icons.local_hospital_outlined, title: 'Hospitals I work at'.tr, detail: '{0} hospitals'.trf([s.hospitals.length]), onTap: () => context.push('/d/me/hospitals')),
          MenuRow(icon: Icons.account_balance_wallet_outlined, title: 'My earnings'.tr, detail: 'Money paid to your bank'.tr, onTap: () => context.push('/d/me/earnings')),
          MenuRow(icon: Icons.bar_chart, title: 'Reports'.tr, detail: 'Patients, waiting time, did not come'.tr, onTap: () => context.push('/d/me/reports')),
        ]).staggerIn(3),
        const SizedBox(height: 26),
        const SectionLabel('Settings'),
        MenuGroup(children: [
          MenuRow(icon: Icons.inbox_outlined, title: 'Messages'.tr, detail: 'Bookings, changes, money sent'.tr, onTap: () => context.push('/d/messages')),
          MenuRow(icon: Icons.notifications_none, title: 'Messages settings'.tr, onTap: () => context.push('/d/me/alerts')),
          MenuRow(icon: Icons.lock_outline, title: 'Change password'.tr, onTap: () => context.push('/d/me/password')),
          MenuRow(icon: Icons.devices_outlined, title: 'Signed in on'.tr, detail: 'Phones and computers using your account'.tr, onTap: () => context.push('/d/me/devices')),
          const LanguageRow(),
          MenuRow(
            icon: Icons.support_agent,
            title: 'Help'.tr,
            detail: 'Call OPflow: {0}'.trf([MockData.opflowHelpPhone]),
            onTap: () => showCallSheet(context, name: 'OPflow help', phone: MockData.opflowHelpPhone),
          ),
          MenuRow(icon: Icons.gavel_outlined, title: 'Rules'.tr, onTap: () => context.push('/me/rules')),
        ]).staggerIn(4),
        const SizedBox(height: 26),
        MenuGroup(children: [MenuRow(icon: Icons.logout, title: 'Log out'.tr, color: OpColors.alarm, onTap: logout)]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Edit profile: photo upload and the details patients see.

class DoctorProfileScreen extends ConsumerStatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  ConsumerState<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends ConsumerState<DoctorProfileScreen> {
  late Doctor _d = ref.read(doctorProvider).doctor;
  late final _about = TextEditingController(text: _d.about);
  bool _dirty = false;

  static const _allLangs = ['Telugu', 'English', 'Hindi', 'Urdu', 'Tamil', 'Kannada'];

  @override
  void dispose() {
    _about.dispose();
    super.dispose();
  }

  void _set(Doctor d) => setState(() {
        _d = d;
        _dirty = true;
      });

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your photo'.tr, style: OpText.title),
              const SizedBox(height: 4),
              Text('A clear face photo, in good light. Patients see it on your card.'.tr, style: OpText.small),
              const SizedBox(height: 14),
              MenuGroup(children: [
                MenuRow(icon: Icons.photo_camera_outlined, title: 'Take a photo'.tr, onTap: () => Navigator.pop(context, 'camera')),
                MenuRow(icon: Icons.photo_library_outlined, title: 'Choose from gallery'.tr, onTap: () => Navigator.pop(context, 'gallery')),
                if (_d.photoPath != null)
                  MenuRow(icon: Icons.delete_outline, title: 'Remove photo'.tr, color: OpColors.alarm, onTap: () => Navigator.pop(context, 'remove')),
              ]),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'remove') {
      _set(_d.copyWith(clearPhoto: true));
      return;
    }
    try {
      final picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;
      final path = await ref.read(directoryProvider).keepPhoto(picked, _d.id);
      _set(_d.copyWith(photoPath: path));
    } catch (_) {
      if (mounted) {
        showError(context, choice == 'camera' ? 'Could not open the camera. Please allow camera access.' : 'Could not open your photos.');
      }
    }
  }

  Future<void> _save() async {
    final d = _d.copyWith(about: _about.text.trim());
    final oldFee = ref.read(doctorProvider).doctor.fee;
    if (d.fee != oldFee) {
      final ok = await confirmSheet(context,
          title: 'Change your fee to {0}?'.trf([rupees(d.fee)]),
          text: 'New bookings pay {0}. Bookings already made stay at {1}.'.trf([rupees(d.fee), rupees(oldFee)]),
          yes: 'Yes, change fee'.tr);
      if (!ok || !mounted) return;
    }
    final done = await runStep(context, 'Saving your profile…'.tr, () => ref.read(directoryProvider).update(d), detail: 'Patients will see it right away'.tr);
    if (!done || !mounted) return;
    setState(() => _dirty = false);
    showToast(context, 'Profile saved'.tr);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    return confirmSheet(context, title: 'Leave without saving?'.tr, text: 'Your changes will be lost.'.tr, yes: 'Yes, leave'.tr, no: 'Stay and save'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final portraitW = (MediaQuery.sizeOf(context).width * 0.46).clamp(140.0, 200.0);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          setState(() => _dirty = false);
          context.popOr('/d/me');
        }
      },
      child: OpPage(
        title: 'Edit profile'.tr,
        actions: [
          TextButton(onPressed: () => _preview(context), child: Text('Preview'.tr)),
          const SizedBox(width: 8),
        ],
        body: ListView(
          padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 24, OpSpace.gutter, 32),
          children: [
            // Photo
            Center(
              child: TapScale(
                onTap: _pickPhoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedSwitcher(
                      duration: OpMotion.page,
                      child: DoctorPortrait(key: ValueKey(d.photoPath), doctor: d, width: portraitW),
                    ),
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: OpColors.forest, borderRadius: OpRadius.controlAll, border: Border.all(color: OpColors.paper, width: 3)),
                        child: const Icon(Icons.photo_camera_outlined, color: OpColors.paper),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: OpButton(
                label: (d.photoPath == null ? 'Add your photo' : 'Change photo').tr,
                icon: Icons.upload_outlined,
                expand: false,
                height: 46,
                kind: OpButtonKind.secondary,
                onPressed: _pickPhoto,
              ),
            ),
            const SizedBox(height: 8),
            Text('Doctors with a photo get more bookings.'.tr, textAlign: TextAlign.center, style: OpText.small.copyWith(fontSize: 13)),
            const SizedBox(height: 28),

            // Locked details
            const SectionLabel('Checked by OPflow'),
            OpCard(
              color: OpColors.paperDeep,
              child: Column(
                children: [
                  KeyValueRow('Name', d.name, strong: true),
                  KeyValueRow('Type of doctor', MockData.type(d.typeId).simple),
                  KeyValueRow('Degrees', d.degrees),
                  KeyValueRow('Reg. number', d.regNo, mono: true),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: OpColors.inkSoft),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Only the OPflow team can change these. Call us if something is wrong.'.tr, style: OpText.small.copyWith(fontSize: 12.5))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Editable details
            const SectionLabel('About you'),
            Text('Gender'.tr, style: OpText.smallStrong),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final g in const ['Male', 'Female', 'Other']) ...[
                  Expanded(
                    child: TapScale(
                      onTap: () => _set(d.copyWith(gender: g)),
                      child: AnimatedContainer(
                        duration: OpMotion.quick,
                        height: 56,
                        decoration: BoxDecoration(
                          color: d.gender == g ? OpColors.forest : OpColors.card,
                          borderRadius: OpRadius.controlAll,
                          border: Border.all(color: d.gender == g ? OpColors.forest : OpColors.line, width: 1.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(genderIcon(g), size: 18, color: d.gender == g ? OpColors.paper : OpColors.fern),
                            const SizedBox(width: 6),
                            Text(g.tr, style: OpText.smallStrong.copyWith(color: d.gender == g ? OpColors.paper : OpColors.ink)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (g != 'Other') const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 18),
            OpCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text('Years of experience'.tr, style: OpText.bodyStrong), Text('Since your first degree'.tr, style: OpText.small.copyWith(fontSize: 12.5))],
                    ),
                  ),
                  NumberStepper(value: d.years, min: 0, max: 60, unit: 'years', onChanged: (v) => _set(d.copyWith(years: v))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OpCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Doctor fee'.tr, style: OpText.bodyStrong)),
                      NumberStepper(value: d.fee, min: 50, max: 3000, step: 50, unit: 'rupees', onChanged: (v) => _set(d.copyWith(fee: v))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('You get {0} per patient. OPflow keeps 10% ({1}).'.trf([rupees(d.fee * 0.9), rupees(d.fee * 0.1)]), style: OpText.small.copyWith(fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Languages I speak'.tr, style: OpText.smallStrong),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final l in _allLangs)
                OpChip(
                  label: l,
                  selected: d.languages.contains(l),
                  onTap: () {
                    final langs = [...d.languages];
                    langs.contains(l) ? langs.remove(l) : langs.add(l);
                    if (langs.isNotEmpty) _set(d.copyWith(languages: langs));
                  },
                ),
            ]),
            const SizedBox(height: 18),
            Text('About me'.tr, style: OpText.smallStrong),
            const SizedBox(height: 4),
            Text('What you treat, in simple words. Patients read this before booking.'.tr, style: OpText.small.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _about,
              maxLines: 5,
              minLines: 3,
              maxLength: 240,
              onChanged: (_) => setState(() => _dirty = true),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: 'Example: Child doctor for new-born babies to 16 years. Fever, cough, vaccines…'.tr),
            ),
          ],
        ),
        bottom: OpButton(label: _dirty ? 'Save profile' : 'Saved', icon: _dirty ? Icons.check : null, onPressed: _dirty ? _save : null),
      ),
    );
  }

  void _preview(BuildContext context) {
    final d = _d.copyWith(about: _about.text.trim());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OpColors.paper,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 20),
            children: [
              Text('This is your card'.tr, style: OpText.title),
              const SizedBox(height: 4),
              Text('Patients see it when they search. Save to publish your changes.'.tr, style: OpText.small),
              const SizedBox(height: 16),
              IgnorePointer(child: DoctorCard(doctor: d, onTap: () {})),
              const SizedBox(height: 16),
              OpButton.secondary(
                label: 'See my full page'.tr,
                icon: Icons.open_in_new,
                onPressed: () {
                  Navigator.pop(context);
                  this.context.push('/doctor/${d.id}?preview=1');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DoctorHospitalsScreen extends ConsumerWidget {
  const DoctorHospitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(doctorProvider);
    return OpPage(
      title: 'Hospitals I work at'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          for (final h in s.hospitals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OpCard(
                child: Row(
                  children: [
                    InitialsTile(text: h.initials, icon: Icons.local_hospital_outlined, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.name, style: OpText.bodyStrong),
                          Text(h.address, style: OpText.small.copyWith(fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(s.blocksFor(1, h.id).map((b) => '${hourLabel(b.start)} – ${hourLabel(b.end)}').join(', '), style: OpText.monoSmall),
                        ],
                      ),
                    ),
                    if (h.id == s.hospitalId) const StatusTag('Showing', tone: Tone.good),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          OpButton.secondary(
            label: 'Add another hospital'.tr,
            icon: Icons.add,
            onPressed: () => showCallSheet(context, name: 'OPflow team to add a hospital', phone: MockData.opflowHelpPhone),
          ),
          const SizedBox(height: 8),
          Text('The OPflow team checks and adds new hospitals for you.'.tr, style: OpText.small.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  int _tab = 0;
  late final Future<DoctorPayouts> _payouts = ref.read(doctorProvider).loadPayouts();

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(doctorProvider);
    final rows = s.earnings(const [1, 7, 30][_tab]);
    final fee = rows.where((r) => !r.refunded).fold<int>(0, (a, r) => a + r.fee);
    final cut = rows.fold<int>(0, (a, r) => a + r.opflowShare);
    final get = rows.fold<int>(0, (a, r) => a + r.doctorShare);
    final paid = rows.where((r) => r.paid).fold<int>(0, (a, r) => a + r.doctorShare);

    return OpPage(
      title: 'My earnings'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          OpSegments(labels: const ['Today', 'This week', 'This month'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 16),
          OpCard(
            color: OpColors.forest,
            borderColor: OpColors.forest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOU GET'.tr, style: OpText.label.copyWith(color: OpColors.mint)),
                Text(rupees(get), style: OpText.mono(34, weight: FontWeight.w600, color: OpColors.paper)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _Mini('Patients paid', rupees(fee))),
                    Expanded(child: _Mini('OPflow 10%', rupees(cut))),
                    Expanded(child: _Mini('Sent to bank', rupees(paid))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('Money is sent to your bank 2 days after the visit. Money back for cancelled visits is taken out.'.tr,
              style: OpText.small.copyWith(fontSize: 13)),
          const SizedBox(height: 18),
          SectionLabel('{0} bookings'.trf([rows.length])),
          Container(
            decoration: BoxDecoration(color: OpColors.card, borderRadius: OpRadius.cardAll, border: Border.all(color: OpColors.line, width: 1.2)),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(children: [
                    Expanded(flex: 4, child: Text('PATIENT'.tr, style: OpText.label.copyWith(fontSize: 10.5))),
                    Expanded(flex: 2, child: Text('FEE'.tr, textAlign: TextAlign.right, style: OpText.label.copyWith(fontSize: 10.5))),
                    Expanded(flex: 2, child: Text('10%', textAlign: TextAlign.right, style: OpText.label.copyWith(fontSize: 10.5))),
                    Expanded(flex: 3, child: Text('YOU GET'.tr, textAlign: TextAlign.right, style: OpText.label.copyWith(fontSize: 10.5))),
                  ]),
                ),
                const Divider(),
                for (final r in rows.take(60))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.patient, style: OpText.smallStrong),
                              Text(
                                r.refunded ? 'Money back given'.tr : (r.paid ? '{0} · In bank'.trf([dayLabel(r.date)]) : '{0} · Coming'.trf([dayLabel(r.date)])),
                                style: OpText.small.copyWith(fontSize: 11.5, color: r.refunded ? OpColors.alarm : (r.paid ? OpColors.fern : OpColors.amber)),
                              ),
                            ],
                          ),
                        ),
                        Expanded(flex: 2, child: Text(rupees(r.fee), textAlign: TextAlign.right, style: OpText.monoSmall)),
                        Expanded(flex: 2, child: Text(rupees(r.opflowShare), textAlign: TextAlign.right, style: OpText.monoSmall.copyWith(color: OpColors.inkSoft))),
                        Expanded(
                          flex: 3,
                          child: Text(rupees(r.doctorShare), textAlign: TextAlign.right, style: OpText.mono(14, weight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Bank payouts'),
          FutureBuilder<DoctorPayouts>(
            future: _payouts,
            builder: (context, snap) {
              if (snap.hasError) return Text(friendlyMessage(snap.error!), style: OpText.small.copyWith(color: OpColors.alarm));
              final p = snap.data;
              if (p == null) return const Padding(padding: EdgeInsets.all(20), child: Center(child: OpLoader()));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !p.hasBank
                        ? 'Your bank account is not added yet. Please call the OPflow team.'.tr
                        : p.bankActive
                            ? 'To your account ending {0}. One payout covers many visits.'.trf([p.bankLast4 ?? '····'])
                            : 'Your bank account is being checked. Payouts start once it is verified.'.tr,
                    style: OpText.small.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  if (p.items.isEmpty)
                    Text('Your money is sent to your bank 24 hours after your visits are over.'.tr, style: OpText.small.copyWith(fontSize: 13))
                  else
                    MenuGroup(children: [
                      for (final x in p.items)
                        MenuRow(
                          icon: Icons.account_balance_outlined,
                          title: '{0} · {1} visits'.trf([x.amount, x.visits]),
                          detail: [
                            dayLabel(x.sentAt),
                            if (x.bankReference != null) 'Ref {0}'.trf([x.bankReference!]),
                            if (x.deducted != null) '{0} taken back for a cancelled visit'.trf([x.deducted!]),
                          ].join(' · '),
                          trailing: StatusTag(
                            x.status == 'success' ? 'Reached your bank' : (x.status == 'pending' ? 'On the way' : 'Will be sent again'),
                            tone: x.status == 'success' ? Tone.good : (x.status == 'pending' ? Tone.warn : Tone.bad),
                          ),
                        ),
                    ]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: OpText.mono(15, weight: FontWeight.w600, color: OpColors.paper)),
        Text(label.tr, style: OpText.small.copyWith(fontSize: 11.5, color: OpColors.mint)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  static const _ranges = [7, 30, 90];
  int _tab = 1; // 30 days, like the doctor website
  DoctorReport? _report;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final days = _ranges[_tab];
    setState(() {
      _report = null;
      _error = null;
    });
    try {
      final r = await ref.read(doctorProvider).loadReport(days);
      if (mounted && _ranges[_tab] == days) setState(() => _report = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    final tiles = r == null
        ? const <(String, String, Color)>[]
        : [
            ('OPDs held', '${r.sessions}', OpColors.ink),
            ('Patients booked', '${r.booked}', OpColors.ink),
            ('Patients seen', '${r.seen}', OpColors.fern),
            ('Did not come', '${r.missed}', OpColors.alarm),
            ('Cancelled with money back', '${r.cancelled}', OpColors.ink),
            ('Emergency patients', '${r.emergency}', OpColors.alarm),
            ('Average time per patient', r.avgConsultMinutes == null ? '—' : '{0} min'.trf([r.avgConsultMinutes!]), OpColors.ink),
            ('Came when booked', r.showRate == null ? '—' : '${r.showRate}%', OpColors.fern),
          ];
    return OpPage(
      title: 'Reports'.tr,
      subtitle: 'Patients, waiting time, did not come'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          OpSegments(
            labels: [for (final d in _ranges) '{0} days'.trf([d])],
            index: _tab,
            onChanged: (i) {
              setState(() => _tab = i);
              _load();
            },
          ),
          const SizedBox(height: 16),
          if (_error != null)
            EmptyState(icon: Icons.wifi_off, title: 'Could not load'.tr, text: friendlyMessage(_error!), action: 'Try again'.tr, onAction: _load)
          else if (r == null)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: OpLoader()))
          else
            for (var i = 0; i < tiles.length; i += 2) ...[
              Row(
                children: [
                  Expanded(child: _Tile(label: tiles[i].$1.tr, value: tiles[i].$2, color: tiles[i].$3)),
                  const SizedBox(width: 8),
                  Expanded(child: _Tile(label: tiles[i + 1].$1.tr, value: tiles[i + 1].$2, color: tiles[i + 1].$3)),
                ],
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.color = OpColors.ink});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return OpCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: OpText.mono(24, weight: FontWeight.w600, color: color)),
          Text(label, style: OpText.small.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _old = TextEditingController();
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _old.dispose();
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!SessionStore.instance.checkDoctorPassword(_old.text)) {
      setState(() => _wrong = true);
      return;
    }
    final sure = await confirmSheet(context,
        title: 'Change your password?'.tr,
        text: 'Your other phones and browsers will be logged out. Use the new password there.'.tr,
        yes: 'Yes, change it'.tr);
    if (!sure || !mounted) return;
    // runWithLoader shows any error itself (e.g. "Your current password is not right") and returns null.
    final ok = await runWithLoader(context, 'Saving…'.tr, () async {
      await SessionStore.instance.setDoctorPassword(_a.text, oldPassword: _old.text);
      return true;
    });
    if (ok != true || !mounted) return;
    showToast(context, 'Password changed'.tr);
    context.popOr('/d/me');
  }

  @override
  Widget build(BuildContext context) {
    return OpPage(
      title: 'Change password'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          Text('Old password'.tr, style: OpText.smallStrong),
          const SizedBox(height: 6),
          TextField(
            controller: _old,
            obscureText: true,
            onChanged: (_) => setState(() => _wrong = false),
            decoration: InputDecoration(
              hintText: 'Your password now'.tr,
              prefixIcon: const Icon(Icons.lock_clock_outlined),
              errorText: _wrong ? 'This is not your password now.' : null,
            ),
          ),
          const SizedBox(height: 20),
          PasswordFields(a: _a, b: _b, onChanged: () => setState(() {})),
        ],
      ),
      bottom: OpButton(label: 'Save new password'.tr, onPressed: _old.text.isNotEmpty && passwordOk(_a.text, _b.text) ? _save : null),
    );
  }
}

class DoctorAlertsScreen extends StatefulWidget {
  const DoctorAlertsScreen({super.key});

  @override
  State<DoctorAlertsScreen> createState() => _DoctorAlertsScreenState();
}

/// Which messages reach the phone as a notification. They always stay in Messages in the app.
/// Emergency patients and notes from the OPflow team always come.
class _DoctorAlertsScreenState extends State<DoctorAlertsScreen> {
  // The server's names for the switches.
  final _on = <String, bool>{'newBookings': true, 'bookingChanges': true, 'reminders': true, 'eveningSummary': true};
  bool _loading = AppConfig.isApi;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isApi) _load();
  }

  Future<void> _load() async {
    try {
      final r = Map<String, dynamic>.from(await Api.instance.get('/v1/me/notification-prefs') as Map);
      for (final k in _on.keys) {
        if (r[k] is bool) _on[k] = r[k] as bool;
      }
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _set(String key, bool v) async {
    setState(() => _on[key] = v);
    if (!AppConfig.isApi) return;
    try {
      await Api.instance.patch('/v1/me/notification-prefs', {key: v});
    } catch (e) {
      if (!mounted) return;
      setState(() => _on[key] = !v); // not saved: show the real setting again
      showError(context, friendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String title, String text, String key) => MenuRow(
          icon: icon,
          title: title.tr,
          detail: text.tr,
          trailing: Switch(value: _on[key]!, onChanged: (v) => _set(key, v)),
          onTap: () => _set(key, !_on[key]!),
        );
    return OpPage(
      title: 'Messages settings'.tr,
      body: _loading
          ? const Center(child: OpLoadingPanel(text: 'Loading…', height: 220))
          : ListView(
              padding: const EdgeInsets.all(OpSpace.gutter),
              children: [
                Text('Choose what comes to your phone as a notification.'.tr, style: OpText.body.copyWith(color: OpColors.inkSoft)),
                const SizedBox(height: 14),
                MenuGroup(children: [
                  row(Icons.event_available_outlined, 'New booking', 'When a patient books you', 'newBookings'),
                  row(Icons.event_repeat, 'Booking changed', 'When a patient changes date or time', 'bookingChanges'),
                  row(Icons.alarm, 'OPD starts soon', '30 minutes before each OPD', 'reminders'),
                  row(Icons.summarize_outlined, 'Evening summary', "Tomorrow's bookings at 8 PM", 'eveningSummary'),
                ]),
                const SizedBox(height: 14),
                InfoBox(
                  icon: Icons.emergency_outlined,
                  tone: Tone.calm,
                  child: Text('Emergency patients, money sent to your bank and notes from the OPflow team always come.'.tr),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Where the account is signed in (the same list as the doctor website's Settings)

class DoctorDevicesScreen extends ConsumerStatefulWidget {
  const DoctorDevicesScreen({super.key});

  @override
  ConsumerState<DoctorDevicesScreen> createState() => _DoctorDevicesScreenState();
}

class _DoctorDevicesScreenState extends ConsumerState<DoctorDevicesScreen> {
  List<SignedInDevice>? _list;
  int _max = 2;
  int _maxWeb = 1;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final (list, max, maxWeb) = await ref.read(doctorProvider).devices();
      if (!mounted) return;
      setState(() {
        _list = list;
        _max = max;
        _maxWeb = maxWeb;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _signOut(SignedInDevice d) async {
    final ok = await confirmSheet(
      context,
      title: 'Sign out this device?'.tr,
      text: 'It will need the OPD ID and password to come back.'.tr,
      yes: 'Sign out'.tr,
      icon: Icons.logout,
    );
    if (!ok || !mounted) return;
    final done = await runStep(context, 'Signing out…'.tr, () => ref.read(doctorProvider).signOutDevice(d.id));
    if (!done || !mounted) return;
    setState(() => _list = _list?.where((x) => x.id != d.id).toList());
    showToast(context, 'Signed out'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return OpPage(
      title: 'Signed in on'.tr,
      body: _error != null
          ? EmptyState(icon: Icons.wifi_off, title: 'Could not load'.tr, text: friendlyMessage(_error!), action: 'Try again'.tr, onAction: _load)
          : list == null
              ? const Center(child: OpLoader())
              : ListView(
                  padding: const EdgeInsets.all(OpSpace.gutter),
                  children: [
                    Text('Up to {0} phones and {1} computer at a time.'.trf([_max, _maxWeb]), style: OpText.body.copyWith(color: OpColors.inkSoft)),
                    const SizedBox(height: 4),
                    Text(
                      'In use now: {0} of {1} phones, {2} of {3} computer.'.trf([list.where((x) => !x.web).length, _max, list.where((x) => x.web).length, _maxWeb]),
                      style: OpText.body.copyWith(color: OpColors.inkSoft),
                    ),
                    const SizedBox(height: 14),
                    MenuGroup(children: [
                      for (final d in list)
                        MenuRow(
                          icon: d.web ? Icons.computer_outlined : Icons.smartphone_outlined,
                          title: d.device,
                          detail: d.thisDevice ? 'This one'.tr : 'Last used {0}'.trf([agoLabel(d.lastUsed).toLowerCase()]),
                          trailing: d.thisDevice
                              ? const StatusTag('This one', tone: Tone.good)
                              : TextButton(onPressed: () => _signOut(d), child: Text('Sign out'.tr, style: const TextStyle(color: OpColors.alarm))),
                        ),
                    ]),
                    const SizedBox(height: 14),
                    InfoBox(
                      icon: Icons.info_outline,
                      tone: Tone.calm,
                      child: Text('New phone refused? Sign out an old phone here, then log in on the new one.'.tr),
                    ),
                  ],
                ),
    );
  }
}
