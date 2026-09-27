import '../../l10n/lang.dart';
import '../../widgets/op_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../mock/models.dart';
import '../../state/doctor_inbox.dart';
import '../../state/doctor_store.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/doctor_portrait.dart';
import '../../widgets/op_button.dart';
import '../patient/patient_shell.dart';

class DoctorShell extends ConsumerWidget {
  const DoctorShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const items = [
    NavItem('Today', Icons.today_outlined, Icons.today),
    NavItem('Bookings', Icons.event_note_outlined, Icons.event_note),
    NavItem('My timings', Icons.schedule_outlined, Icons.schedule),
    NavItem('Me', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(doctorProvider);
    // Problems from the server (no internet, the line changed…) show as a red note, once.
    ref.listen(doctorProvider, (_, s) {
      final n = s.takeNotice();
      if (n != null && context.mounted) showError(context, n);
    });
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: DoctorTopBar(store: store),
        ),
        body: store.isReady ? shell : const OpLoadingPanel(text: 'Loading your OPD…', height: 320),
        bottomNavigationBar: OpBottomNav(
          items: items,
          index: shell.currentIndex,
          onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      ),
    );
  }
}

/// Forest top bar: doctor name, hospital switcher, and the emergency switch.
class DoctorTopBar extends StatelessWidget {
  const DoctorTopBar({super.key, required this.store});

  final DoctorStore store;

  @override
  Widget build(BuildContext context) {
    final e = store.emergency;
    final eOn = e != EmergencyStatus.off;
    return Container(
      decoration: const BoxDecoration(
        color: OpColors.forest,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(OpRadius.sheet)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TapScale(
                  onTap: () => context.push('/d/me/profile'),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: OpColors.leaf.withValues(alpha: 0.6)), borderRadius: OpRadius.smallAll),
                    child: DoctorPortrait.small(doctor: store.doctor, width: 40),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TapScale(
                    onTap: store.hospitals.length > 1 ? () => _pickHospital(context) : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.doctor.name, style: OpText.heading.copyWith(color: OpColors.paper, fontSize: 19), overflow: TextOverflow.ellipsis),
                        Row(
                          children: [
                            const Icon(Icons.local_hospital_outlined, size: 15, color: OpColors.leaf),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(store.hospital.name,
                                  style: OpText.smallStrong.copyWith(color: OpColors.mint, fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                            if (store.hospitals.length > 1) const Icon(Icons.keyboard_arrow_down, size: 18, color: OpColors.mint),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const _Bell(),
                const SizedBox(width: 6),
                TapScale(
                  onTap: () => showEmergencySheet(context, store),
                  child: AnimatedContainer(
                    duration: OpMotion.quick,
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: eOn ? OpColors.alarm : OpColors.pine,
                      borderRadius: OpRadius.controlAll,
                      border: Border.all(color: eOn ? OpColors.alarm : OpColors.fern),
                    ),
                    // Compact: "EMERGENCY" small above the state, so the doctor's name keeps its room.
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emergency_outlined, size: 18, color: eOn ? Colors.white : OpColors.mint),
                        const SizedBox(width: 6),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EMERGENCY'.tr, style: OpText.label.copyWith(color: eOn ? Colors.white70 : OpColors.leaf, fontSize: 9, letterSpacing: 1)),
                            Text(store.emergencyShort, style: OpText.smallStrong.copyWith(color: Colors.white, fontSize: 13, height: 1.15)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickHospital(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Which hospital?'.tr, style: OpText.title),
              const SizedBox(height: 4),
              Text('Today, bookings and timings will change to this hospital.'.tr, style: OpText.small),
              const SizedBox(height: 14),
              MenuGroup(children: [
                for (final h in store.hospitals)
                  MenuRow(
                    icon: h.id == store.hospitalId ? Icons.radio_button_checked : Icons.radio_button_off,
                    title: h.name,
                    detail: h.area,
                    onTap: () => Navigator.pop(context, h.id),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != store.hospitalId) {
      store.switchHospital(picked);
      if (context.mounted) showToast(context, 'Now showing {0}'.trf([store.hospital.name]));
    }
  }
}

/// Messages, with the number not read yet.
class _Bell extends ConsumerWidget {
  const _Bell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(doctorInboxProvider).unread;
    return Semantics(
      button: true,
      label: n > 0 ? 'Messages, {0} new'.trf([n]) : 'Messages'.tr,
      child: TapScale(
        onTap: () => context.push('/d/messages'),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(n > 0 ? Icons.notifications_active_outlined : Icons.notifications_none, color: OpColors.mint, size: 26),
              if (n > 0)
                Positioned(
                  top: 3,
                  right: 1,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: OpColors.alarm,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: OpColors.forest, width: 1.5),
                    ),
                    child: Text(n > 9 ? '9+' : '$n', style: OpText.smallStrong.copyWith(color: Colors.white, fontSize: 10.5, height: 1)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showEmergencySheet(BuildContext context, DoctorStore store) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _EmergencySheet(store: store),
  );
}

class _EmergencySheet extends StatefulWidget {
  const _EmergencySheet({required this.store});

  final DoctorStore store;

  @override
  State<_EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<_EmergencySheet> {
  late EmergencyStatus _s = widget.store.emergency;
  late String _till = widget.store.emergencyTill;
  late String _place = widget.store.emergencyPlace;

  @override
  Widget build(BuildContext context) {
    final options = [
      (EmergencyStatus.off, 'Not available', 'Patients will not see you in emergency help'),
      (EmergencyStatus.availableNow, 'Available now', 'Patients can call and come now. Turns off by itself after 12 hours.'),
      (EmergencyStatus.availableTill, 'Available till a time', 'Goes off on its own after that time'),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emergency status'.tr, style: OpText.title),
            const SizedBox(height: 4),
            Text('This shows in the patient emergency screen. Please keep it true.'.tr, style: OpText.small),
            const SizedBox(height: 14),
            for (final (s, title, text) in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TapScale(
                  onTap: () => setState(() => _s = s),
                  child: AnimatedContainer(
                    duration: OpMotion.quick,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _s == s ? (s == EmergencyStatus.off ? OpColors.paperDeep : OpColors.alarmWash) : OpColors.card,
                      borderRadius: OpRadius.controlAll,
                      border: Border.all(color: _s == s ? (s == EmergencyStatus.off ? OpColors.ink : OpColors.alarm) : OpColors.line, width: _s == s ? 2 : 1.2),
                    ),
                    child: Row(
                      children: [
                        Icon(_s == s ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: s == EmergencyStatus.off ? OpColors.ink : OpColors.alarm),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [Text(title.tr, style: OpText.bodyStrong), Text(text.tr, style: OpText.small.copyWith(fontSize: 13))],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_s == EmergencyStatus.availableTill) ...[
              const SizedBox(height: 6),
              Text('Till what time?'.tr, style: OpText.smallStrong),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in const ['8 PM', '10 PM', '12 AM', '6 AM'])
                  OpChip(label: t, selected: _till == t, onTap: () => setState(() => _till = t)),
              ]),
            ],
            if (_s != EmergencyStatus.off) ...[
              const SizedBox(height: 14),
              Text('Where?'.tr, style: OpText.smallStrong),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in const ['At hospital', 'By phone first'])
                  OpChip(label: p, selected: _place == p, onTap: () => setState(() => _place = p)),
              ]),
            ],
            const SizedBox(height: 20),
            OpButton(
              label: 'Save'.tr,
              onPressed: () {
                widget.store.setEmergency(_s, till: _till, place: _place);
                Navigator.pop(context);
                showToast(context, _s == EmergencyStatus.off ? 'Emergency status is off'.tr : 'Emergency status saved'.tr);
              },
            ),
          ],
        ),
      ),
    );
  }
}
