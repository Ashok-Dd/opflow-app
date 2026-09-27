import '../../l10n/lang.dart';
import '../../widgets/notifications_off.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/config.dart';
import '../../mock/format.dart';
import '../../state/doctor_store.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/clock_time.dart';
import '../../widgets/op_button.dart';
import '../../widgets/op_loader.dart';
import '../../widgets/page_header.dart';
import '../../widgets/token_board.dart';
import '../patient/widgets.dart' show showCallSheet;

/// The OPD console. Built for one hand, between patients: big buttons, few words.
class TodayTab extends ConsumerWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(doctorProvider);
    return AnimatedSwitcher(
      duration: OpMotion.page,
      child: switch (s.opd) {
        OpdState.notStarted => _BeforeStart(key: const ValueKey('before'), s: s),
        OpdState.ended => _Ended(key: const ValueKey('ended'), s: s),
        _ => _Running(key: const ValueKey('running'), s: s),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Before the OPD starts

class _BeforeStart extends StatelessWidget {
  const _BeforeStart({super.key, required this.s});

  final DoctorStore s;

  @override
  Widget build(BuildContext context) {
    final groups = s.lineByHour;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 18, OpSpace.gutter, 24),
            children: [
              PageHeader(eyebrow: longDate(DateTime.now()), title: "Today's OPD".tr),
              const SizedBox(height: 18),
              const NotificationsOffCard(forDoctor: true),
              _HoursCard(s: s).staggerIn(0),
              _Elsewhere(s: s),
              const SizedBox(height: 14),
              InfoBox(
                icon: Icons.info_outline,
                child: Text('When you press Start OPD, patients will see "Doctor has started" and the live line.'.tr),
              ).staggerIn(1),
              const SizedBox(height: 18),
              BookingsPauseCard(s: s).staggerIn(2),
              const SizedBox(height: 22),
              const SectionLabel('Expected patients'),
              if (groups.isEmpty) _NoOneYet(paused: s.bookingsPaused),
              for (final e in groups.entries) ...[
                _HourHeader(hour: e.key, count: e.value.length, cap: 8),
                for (final p in e.value) _LineRow(p: p, s: s, compact: true),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        BottomBar(
          child: OpButton(
            label: 'START OPD'.tr,
            icon: Icons.play_arrow_rounded,
            onPressed: () async {
              final ok = await confirmSheet(context,
                  title: 'Start OPD now?'.tr,
                  text: 'Patients will see "Doctor has started" and the live line.'.tr,
                  yes: 'Yes, start OPD'.tr,
                  icon: Icons.play_circle_outline);
              if (!ok || !context.mounted) return;
              if (await runStep(context, 'Starting OPD…'.tr, s.startOpd, detail: 'Telling your patients'.tr)) HapticFeedback.mediumImpact();
            },
          ),
        ),
      ],
    );
  }
}

/// Today's OPD at a glance: the hours as a clock would say them, how full each hour is, and the counts.
/// "You also have patients today at (the other hospital)", with a switch. Nothing when there are none.
class _Elsewhere extends StatelessWidget {
  const _Elsewhere({required this.s});

  final DoctorStore s;

  @override
  Widget build(BuildContext context) {
    final others = s.elsewhereToday();
    if (others.isEmpty) return const SizedBox.shrink();
    final hid = others.first.hospitalId!;
    final n = others.where((p) => p.hospitalId == hid).length;
    final name = others.first.hospitalName ?? s.hospitalName(hid);
    final first = others.where((p) => p.hospitalId == hid).map((p) => p.hour).reduce((a, b) => a < b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(color: OpColors.amberWash, borderRadius: OpRadius.cardAll, border: Border.all(color: OpColors.amber.withValues(alpha: 0.5))),
        child: Row(
          children: [
            const Icon(Icons.local_hospital_outlined, color: OpColors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text('You also have {0} today at {1}, from {2}.'.trf([people(n), name, hourLabel(first)]),
                  style: OpText.small.copyWith(fontSize: 14, color: OpColors.ink)),
            ),
            if (s.hospitals.any((h) => h.id == hid))
              TextButton(
                onPressed: () {
                  s.switchHospital(hid);
                  showToast(context, 'Now showing {0}'.trf([name]));
                },
                child: Text('Switch'.tr),
              ),
          ],
        ),
      ),
    );
  }
}

/// Nobody booked this OPD (yet): said kindly, with what happens next.
class _NoOneYet extends StatelessWidget {
  const _NoOneYet({required this.paused, this.running = false});

  final bool paused;
  final bool running;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: OpColors.card,
        borderRadius: OpRadius.cardAll,
        border: Border.all(color: OpColors.lineSoft),
        boxShadow: OpShadow.card,
      ),
      child: Column(
        children: [
          // An empty waiting-room chair with a small calendar: no one booked or waiting yet.
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(color: OpColors.mint, shape: BoxShape.circle),
                  child: const Icon(Icons.event_seat_outlined, size: 38, color: OpColors.forest),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: OpColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: OpColors.lineSoft),
                      boxShadow: OpShadow.card,
                    ),
                    child: Icon(running ? Icons.hourglass_empty_rounded : Icons.event_available_outlined, size: 17, color: OpColors.fern),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            running ? 'No one is in the line right now'.tr : 'No one has booked this session yet'.tr,
            textAlign: TextAlign.center,
            style: OpText.heading.copyWith(fontSize: 19),
          ),
          const SizedBox(height: 6),
          Text(
            paused
                ? 'New bookings are paused, so patients cannot book you now. Resume bookings whenever you are ready.'.tr
                : 'Patients can still book your open times. We will send you a message as soon as someone books.'.tr,
            textAlign: TextAlign.center,
            style: OpText.small.copyWith(fontSize: 14.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.s});

  final DoctorStore s;

  @override
  Widget build(BuildContext context) {
    final cap = s.blocksFor(DateTime.now().weekday).firstOrNull?.perHour ?? 8;
    final hours = [for (var h = s.opdStart; h < s.opdEnd; h++) h];
    int bookedAt(int h) => s.line.where((p) => p.hour == h && p.source == Source.online && p.state != PatientState.cancelled).length;
    final seats = hours.length * cap;
    final left = (seats - s.onlineCount).clamp(0, seats);
    final nowHour = DateTime.now().hour;
    return Container(
      decoration: BoxDecoration(color: OpColors.card, borderRadius: OpRadius.cardAll, border: Border.all(color: OpColors.lineSoft), boxShadow: OpShadow.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Forest band: the hours, big and clear.
          Container(
            color: OpColors.forest,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 15, color: OpColors.leaf),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('OPD HOURS TODAY'.tr,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: OpText.label.copyWith(color: OpColors.mint, fontSize: 11, letterSpacing: 1.4)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: OpColors.pine, borderRadius: BorderRadius.circular(OpRadius.small), border: Border.all(color: OpColors.fern)),
                      child: Text('{0} hrs'.trf([hours.length]), style: OpText.smallStrong.copyWith(color: OpColors.mint, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: ClockRange(s.opdStart, s.opdEnd, size: 38, color: OpColors.paper, suffixColor: OpColors.leaf, shortSame: false),
                ),
              ],
            ),
          ),
          // How full each hour is.
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final h in hours)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: SizedBox(
                              height: 34,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(color: OpColors.mint.withValues(alpha: 0.55)),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: (bookedAt(h) / cap).clamp(0.0, 1.0),
                                      widthFactor: 1,
                                      child: Container(color: bookedAt(h) >= cap ? OpColors.forest : OpColors.fern),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClockTime(h, size: 13, color: h == nowHour ? OpColors.forest : OpColors.inkSoft, showSuffix: false),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _Stat(label: 'Booked'.tr, value: s.onlineCount)),
                  const VerticalDivider(width: 18, color: OpColors.lineSoft),
                  Expanded(child: _Stat(label: 'Emergency'.tr, value: s.emergencyCount, color: OpColors.alarm)),
                  const VerticalDivider(width: 18, color: OpColors.lineSoft),
                  Expanded(child: _Stat(label: 'Seats left'.tr, value: left, color: OpColors.fern)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: OpMotion.quick,
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Text('$value',
              key: ValueKey(value),
              style: TextStyle(
                  fontFamily: 'IBMPlexSans',
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: color ?? OpColors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        Text(label, style: OpText.small.copyWith(fontSize: 12, height: 1.2)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// While the OPD runs

class _Running extends StatelessWidget {
  const _Running({super.key, required this.s});

  final DoctorStore s;

  Future<void> _callNext(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final p = s.callNext();
    if (p == null) {
      showToast(context, 'No one is waiting right now'.tr, icon: Icons.hourglass_empty);
    } else {
      showToast(context, 'Calling token {0} — {1}'.trf([p.tokenLabel, p.name]), icon: Icons.campaign_outlined);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = s.current;
    final onBreak = s.opd == OpdState.onBreak;
    final nextUp = s.nextToCall;
    return ListView(
      padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 14, OpSpace.gutter, 28),
      children: [
        const NotificationsOffCard(forDoctor: true, padding: EdgeInsets.only(bottom: 12)),
        // Numbers strip
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(color: OpColors.card, borderRadius: OpRadius.cardAll, border: Border.all(color: OpColors.line, width: 1.2)),
          child: Row(
            children: [
              Expanded(child: _Stat(label: 'Booked'.tr, value: s.onlineCount)),
              Expanded(child: _Stat(label: 'Emergency'.tr, value: s.emergencyCount, color: OpColors.alarm)),
              Expanded(child: _Stat(label: 'Done'.tr, value: s.count(PatientState.done), color: OpColors.fern)),
              Expanded(child: _Stat(label: 'Waiting'.tr, value: s.count(PatientState.waiting), color: OpColors.amber)),
              Expanded(child: _Stat(label: 'Did not come'.tr, value: s.count(PatientState.didNotCome), color: OpColors.alarm)),
            ],
          ),
        ),
        _Elsewhere(s: s),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: onBreak
                  ? const StatusTag('You are on break', tone: Tone.calm, icon: Icons.pause_circle_outline, big: true)
                  : s.lateMinutes == 0
                      ? const StatusTag('On time', tone: Tone.good, icon: Icons.schedule, big: true)
                      : StatusTag('{0} min late'.trf([s.lateMinutes]), tone: s.lateMinutes >= 30 ? Tone.bad : Tone.warn, icon: Icons.schedule, big: true),
            ),
            const SizedBox(width: 8),
            Text('Patients see this'.tr, style: OpText.small.copyWith(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),

        // With doctor now
        Text('WITH DOCTOR NOW'.tr, style: OpText.label),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: OpMotion.page,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0.1, 0), end: Offset.zero).animate(a), child: c),
          ),
          child: cur == null
              ? OpCard(
                  key: const ValueKey('none'),
                  color: OpColors.paperDeep,
                  child: Row(
                    children: [
                      const Icon(Icons.chair_outlined, color: OpColors.inkSoft),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(nextUp == null ? 'No one inside. No one left in the line.'.tr : 'No one inside. Press CALL NEXT for token {0}.'.trf([nextUp.tokenLabel]),
                            style: OpText.body.copyWith(fontSize: 15)),
                      ),
                    ],
                  ),
                )
              : OpCard(
                  key: ValueKey(cur.id),
                  borderColor: OpColors.forest,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: OpColors.forest, borderRadius: OpRadius.controlAll),
                            child: cur.source == Source.emergency
                                ? Text(cur.tokenLabel, style: OpText.mono(34, weight: FontWeight.w600, color: OpColors.led))
                                : FlipNumber(value: cur.token, style: OpText.mono(34, weight: FontWeight.w600, color: OpColors.led)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cur.name, style: OpText.title.copyWith(fontSize: 22)),
                                Text('{0} years · {1} · {2}'.trf([cur.age, cur.gender, cur.source.label]), style: OpText.small),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (cur.note.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        InfoBox(tone: Tone.calm, icon: Icons.notes, child: Text(cur.note)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: OpButton(label: 'Done'.tr, height: 48, onPressed: s.markDone)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OpButton(
                                label: 'Did not come'.tr,
                                height: 48,
                                kind: OpButtonKind.dangerOutline,
                                onPressed: () async {
                                  final ok = await confirmSheet(context,
                                      title: 'Mark {0} as did not come?'.trf([cur.name]), text: 'Use this only when the patient did not come. You can put them back in the line later.'.tr, yes: 'Yes, did not come'.tr, danger: true);
                                  if (ok) s.markDidNotCome(cur);
                                }),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: OpButton(label: 'Skip for now'.tr, height: 48, kind: OpButtonKind.secondary, onPressed: () => s.skip(cur))),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 14),

        // CALL NEXT
        _CallNextButton(
          enabled: !onBreak && (nextUp != null || cur != null),
          nextToken: nextUp?.tokenLabel,
          onTap: () => _callNext(context),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OpIconAction(
                icon: onBreak ? Icons.play_arrow_rounded : Icons.coffee_outlined,
                label: onBreak ? 'Start again' : 'Take a break',
                onTap: () {
                  s.toggleBreak();
                  showToast(context, onBreak ? 'OPD started again' : 'Break started. Patients will see it.');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: OpIconAction(icon: Icons.schedule, label: 'I am late'.tr, onTap: () => _lateSheet(context, s))),
            const SizedBox(width: 8),
            Expanded(
              child: OpIconAction(
                icon: s.bookingsPaused ? Icons.play_circle_outline : Icons.pause_circle_outline,
                label: s.bookingsPaused ? 'Resume bookings'.tr : 'Pause bookings'.tr,
                color: s.bookingsPaused ? OpColors.fern : OpColors.amber,
                onTap: () => toggleBookingsPause(context, s),
              ),
            ),
          ],
        ),
        if (s.bookingsPaused) ...[
          const SizedBox(height: 10),
          const StatusTag('New bookings are paused. Patients already booked still come.', tone: Tone.warn, icon: Icons.pause_circle_outline, big: true),
        ],
        const SizedBox(height: 24),

        // Line
        const SectionLabel('The line'),
        if (s.lineByHour.isEmpty) _NoOneYet(paused: s.bookingsPaused, running: true),
        for (final e in s.lineByHour.entries) ...[
          _HourHeader(hour: e.key, count: e.value.where((p) => p.source == Source.online).length, cap: 8),
          for (final p in e.value) _LineRow(p: p, s: s),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        OpButton(
          label: 'END OPD'.tr,
          icon: Icons.stop_rounded,
          kind: OpButtonKind.dangerOutline,
          onPressed: () => _end(context, s),
        ),
      ],
    );
  }

  Future<void> _end(BuildContext context, DoctorStore s) async {
    final ok = await confirmSheet(context,
        title: 'End today\'s OPD?'.tr, text: 'Patients will see that the OPD is over.'.tr, yes: 'Yes, end OPD'.tr, danger: true, icon: Icons.stop_circle_outlined);
    if (!ok || !context.mounted) return;
    final left = s.summary().stillWaiting;
    var move = true;
    if (left > 0) {
      final choice = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('{0} still in the line'.trf([people(left)]), style: OpText.title),
                const SizedBox(height: 6),
                Text('What should we do for them?'.tr, style: OpText.body.copyWith(color: OpColors.inkSoft)),
                const SizedBox(height: 18),
                OpButton(label: 'Move them to another day'.tr, icon: Icons.event_repeat, onPressed: () => Navigator.pop(context, true)),
                const SizedBox(height: 10),
                OpButton(label: 'Cancel and give money back'.tr, kind: OpButtonKind.dangerOutline, onPressed: () => Navigator.pop(context, false)),
              ],
            ),
          ),
        ),
      );
      if (choice == null) return;
      move = choice;
      if (!move) {
        if (!context.mounted) return;
        final sure = await confirmSheet(context,
            title: 'Cancel {0}?'.trf([people(left)]),
            text: 'Their bookings are cancelled and everyone gets all their money back. This cannot be undone.'.tr,
            yes: 'Yes, cancel and refund'.tr,
            danger: true);
        if (!sure) return;
      }
    }
    if (!context.mounted) return;
    await runWithLoader(context, 'Ending OPD…'.tr, () => s.endOpd(moveLeftovers: move));
  }

  Future<void> _lateSheet(BuildContext context, DoctorStore s) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How late are you?'.tr, style: OpText.title),
              const SizedBox(height: 4),
              Text('Patients get a message, so they can come a little later.'.tr, style: OpText.small),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final m in const [10, 20, 30, 45]) ...[
                    Expanded(
                      child: OpButton(
                        label: '+{0} min'.trf([m]),
                        height: 52,
                        kind: s.lateMinutes == m ? OpButtonKind.primary : OpButtonKind.secondary,
                        onPressed: () {
                          s.setLate(m);
                          Navigator.pop(context);
                          showToast(context, 'Patients told: {0} min late'.trf([m]));
                        },
                      ),
                    ),
                    if (m != 45) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              OpButton(
                label: 'Back on time'.tr,
                icon: Icons.check,
                kind: OpButtonKind.quiet,
                onPressed: () {
                  s.setLate(0);
                  Navigator.pop(context);
                  showToast(context, 'Patients told: on time'.tr);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallNextButton extends StatelessWidget {
  const _CallNextButton({required this.enabled, required this.nextToken, required this.onTap});

  final bool enabled;
  final String? nextToken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: enabled ? onTap : null,
      scale: 0.96,
      child: AnimatedContainer(
        duration: OpMotion.quick,
        height: 84,
        decoration: BoxDecoration(
          color: enabled ? OpColors.forest : OpColors.paperDeep,
          borderRadius: OpRadius.cardAll,
          border: Border.all(color: enabled ? OpColors.forest : OpColors.line, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, color: enabled ? OpColors.led : OpColors.inkFaint, size: 32),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CALL NEXT'.tr, style: OpText.button.copyWith(fontSize: 22, color: enabled ? OpColors.paper : OpColors.inkFaint, letterSpacing: 1)),
                if (nextToken != null)
                  Text('Token {0}'.trf([nextToken]), style: OpText.mono(14, color: enabled ? OpColors.mint : OpColors.inkFaint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HourHeader extends StatelessWidget {
  const _HourHeader({required this.hour, required this.count, required this.cap});

  final int hour;
  final int count;
  final int cap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          ClockRange(hour, hour + 1, size: 16),
          const SizedBox(width: 10),
          Expanded(child: SeatMeter(total: cap, taken: count.clamp(0, cap), box: 9, animate: false)),
          const SizedBox(width: 8),
          Text('{0} booked'.trf([count]), style: OpText.small.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.p, required this.s, this.compact = false});

  final LinePatient p;
  final DoctorStore s;
  final bool compact;

  (Tone, IconData) get _look => switch (p.state) {
        PatientState.notCome => (Tone.calm, Icons.schedule),
        PatientState.waiting => (Tone.warn, Icons.event_seat_outlined),
        PatientState.withDoctor => (Tone.info, Icons.meeting_room_outlined),
        PatientState.done => (Tone.good, Icons.check),
        PatientState.didNotCome => (Tone.bad, Icons.close),
        PatientState.cancelled => (Tone.bad, Icons.block),
        PatientState.moved => (Tone.calm, Icons.event_repeat),
      };

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = _look;
    final faded = p.state == PatientState.done || p.state == PatientState.cancelled || p.state == PatientState.moved;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: p.state == PatientState.withDoctor ? OpColors.mint : OpColors.card,
        borderRadius: OpRadius.controlAll,
        child: InkWell(
          borderRadius: OpRadius.controlAll,
          onTap: () => _actions(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: OpRadius.controlAll,
              border: Border.all(color: p.state == PatientState.withDoctor ? OpColors.fern : OpColors.line),
            ),
            child: Opacity(
              opacity: faded ? 0.6 : 1,
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Text(p.tokenLabel, style: OpText.mono(18, weight: FontWeight.w600, color: p.source == Source.emergency ? OpColors.alarm : OpColors.forest)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(p.name, style: OpText.bodyStrong.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
                            if (p.source != Source.online) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: p.source == Source.emergency ? OpColors.alarm : OpColors.paperDeep,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(p.source.label.toUpperCase(),
                                    style: OpText.label.copyWith(fontSize: 9.5, color: p.source == Source.emergency ? Colors.white : OpColors.inkSoft)),
                              ),
                            ],
                          ],
                        ),
                        Text('${p.age} yrs · ${p.gender}${p.note.isEmpty ? '' : ' · ${p.note}'}',
                            style: OpText.small.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (!compact) StatusTag(p.state.label, tone: tone, icon: icon),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate(key: ValueKey('${p.id}${p.state}')).fadeIn(duration: 220.ms);
  }

  void _actions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheet) {
        void act(VoidCallback f, String msg) {
          f();
          Navigator.pop(sheet);
          showToast(context, msg);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Token {0} · {1}'.trf([p.tokenLabel, p.name]), style: OpText.title),
                Text('{0} years · {1} · {2}'.trf([p.age, p.gender, p.state.label]), style: OpText.small),
                const SizedBox(height: 14),
                MenuGroup(children: [
                  if (p.state == PatientState.notCome)
                    MenuRow(icon: Icons.how_to_reg_outlined, title: 'Mark reached'.tr, onTap: () => act(() => s.markReached(p), '${p.name} marked as reached')),
                  if ((p.state == PatientState.waiting || p.state == PatientState.notCome) && s.opd != OpdState.notStarted)
                    MenuRow(icon: Icons.campaign_outlined, title: 'Call in now'.tr, onTap: () => act(() => s.callNow(p), 'Calling token ${p.tokenLabel}')),
                  if (p.state == PatientState.didNotCome || p.state == PatientState.done)
                    MenuRow(icon: Icons.undo, title: 'Put back in line'.tr, onTap: () => act(() => s.putBack(p), '${p.name} is back in the line')),
                  if (p.state == PatientState.waiting || p.state == PatientState.notCome)
                    MenuRow(
                      icon: Icons.person_off_outlined,
                      title: 'Did not come'.tr,
                      color: OpColors.alarm,
                      onTap: () async {
                        Navigator.pop(sheet);
                        final ok = await confirmSheet(context,
                            title: 'Mark {0} as did not come?'.trf([p.name]), text: 'Use this only when the patient did not come. You can put them back in the line later.'.tr, yes: 'Yes, did not come'.tr, danger: true);
                        if (!ok || !context.mounted) return;
                        s.markDidNotCome(p);
                        showToast(context, '{0} marked as did not come'.trf([p.name]));
                      },
                    ),
                  if (p.phone.isNotEmpty)
                    MenuRow(
                      icon: Icons.call_outlined,
                      title: 'Call patient'.tr,
                      detail: maskPhone(p.phone),
                      onTap: () {
                        Navigator.pop(sheet);
                        showCallSheet(context, name: p.name, phone: maskPhone(p.phone));
                      },
                    ),
                  if (p.source == Source.online)
                    MenuRow(
                      icon: Icons.open_in_new,
                      title: 'See booking'.tr,
                      onTap: () {
                        Navigator.pop(sheet);
                        context.push('/d/booking/${p.id}');
                      },
                    ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// After the OPD ends

class _Ended extends StatelessWidget {
  const _Ended({super.key, required this.s});

  final DoctorStore s;

  @override
  Widget build(BuildContext context) {
    final sum = s.summary();
    return ListView(
      padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 24, OpSpace.gutter, 28),
      children: [
        const Icon(Icons.task_alt, color: OpColors.fern, size: 48).animate().scale(curve: Curves.easeOutBack, duration: 400.ms),
        const SizedBox(height: 10),
        Text('OPD is over'.tr, style: OpText.display),
        Text('Good work today.'.tr, style: OpText.body.copyWith(color: OpColors.inkSoft)),
        const SizedBox(height: 20),
        OpCard(
          child: Column(
            children: [
              KeyValueRow('Patients seen', '${sum.seen}', mono: true, strong: true),
              KeyValueRow('Did not come', '${sum.didNotCome}', mono: true),
              KeyValueRow('Average time per patient', '${sum.avgMinutes} min', mono: true),
              KeyValueRow('Ran late by', sum.lateBy == 0 ? 'On time' : '${sum.lateBy} min', mono: true),
              KeyValueRow('Moved to another day', '${s.count(PatientState.moved)}', mono: true),
              KeyValueRow('Cancelled with money back', '${s.count(PatientState.cancelled)}', mono: true),
            ],
          ),
        ).staggerIn(0),
        const SizedBox(height: 20),
        OpButton.secondary(label: 'See reports'.tr, icon: Icons.bar_chart, onPressed: () => context.push('/d/me/reports')),
        const SizedBox(height: 10),
        if (s.nextOpdToday != null)
          OpButton(label: 'Open the next OPD ({0})'.trf([hourLabel(s.nextOpdToday!)]), icon: Icons.arrow_forward, onPressed: s.resetDay)
        else if (!AppConfig.isApi)
          OpButton(label: 'Start a new day (test)'.tr, kind: OpButtonKind.quiet, onPressed: s.resetDay),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pause bookings: patients can't book until the doctor resumes. Bookings already made stay.

Future<void> toggleBookingsPause(BuildContext context, DoctorStore s) async {
  final pausing = !s.bookingsPaused;
  final ok = await confirmSheet(
    context,
    title: pausing ? 'Pause new bookings?'.tr : 'Take bookings again?'.tr,
    text: pausing
        ? 'Patients will not be able to book you until you resume. Patients who already booked will still come.'
        : 'Patients will be able to book your open times again.',
    yes: pausing ? 'Yes, pause bookings' : 'Yes, take bookings',
    icon: pausing ? Icons.pause_circle_outline : Icons.play_circle_outline,
  );
  if (!ok || !context.mounted) return;
  final done = await runStep(context, pausing ? 'Pausing bookings…'.tr : 'Opening bookings…'.tr, () => s.setBookingsPaused(pausing));
  if (done && context.mounted) showToast(context, pausing ? 'Bookings paused. Patients cannot book you now.' : 'Bookings open again');
}

/// The "taking bookings / paused" switch, shown at the top of Today and My timings.
class BookingsPauseCard extends StatelessWidget {
  const BookingsPauseCard({super.key, required this.s});

  final DoctorStore s;

  @override
  Widget build(BuildContext context) {
    final paused = s.bookingsPaused;
    return AnimatedContainer(
      duration: OpMotion.quick,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: paused ? OpColors.amberWash : OpColors.mint,
        borderRadius: OpRadius.cardAll,
        border: Border.all(color: paused ? OpColors.amber : OpColors.fern, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(paused ? Icons.pause_circle_outline : Icons.event_available, color: paused ? OpColors.amber : OpColors.fern, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(paused ? 'Bookings paused'.tr : 'Taking new bookings'.tr, style: OpText.bodyStrong),
                Text(paused ? 'Patients cannot book you until you resume.'.tr : 'Patients can book your open times.'.tr,
                    style: OpText.small.copyWith(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OpButton(
            label: paused ? 'Resume'.tr : 'Pause'.tr,
            expand: false,
            height: 44,
            kind: paused ? OpButtonKind.primary : OpButtonKind.secondary,
            onPressed: () => toggleBookingsPause(context, s),
          ),
        ],
      ),
    );
  }
}
