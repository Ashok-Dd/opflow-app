import '../../l10n/lang.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../mock/format.dart';
import '../../state/doctor_store.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../data/remote.dart';
import '../../widgets/bits.dart';
import '../../widgets/clock_time.dart';
import '../../widgets/op_button.dart';
import '../../widgets/op_loader.dart';

enum _F { all, online, emergency, changed, cancelled, didNotCome }

class DoctorBookingsTab extends ConsumerStatefulWidget {
  const DoctorBookingsTab({super.key});

  @override
  ConsumerState<DoctorBookingsTab> createState() => _DoctorBookingsTabState();
}

class _DoctorBookingsTabState extends ConsumerState<DoctorBookingsTab> {
  DateTime _day = today();
  _F _f = _F.all;

  /// The hours opened to show their patients (closed by default: the day reads as a list of hours).
  final _open = <String>{};
  String _slotKey(String hid, int h) => '${Remote.ymd(_day)}|$hid|$h';

  static const _labels = {
    _F.all: 'All',
    _F.online: 'Online',
    _F.emergency: 'Emergency',
    _F.changed: 'Changed',
    _F.cancelled: 'Cancelled',
    _F.didNotCome: 'Did not come',
  };

  bool _match(LinePatient p) => switch (_f) {
        _F.all => true,
        _F.online => p.source == Source.online,
        _F.emergency => p.source == Source.emergency,
        _F.changed => p.changed,
        _F.cancelled => p.state == PatientState.cancelled,
        _F.didNotCome => p.state == PatientState.didNotCome,
      };

  Future<void> _cancelDay(DoctorStore s) async {
    final all = s.bookingsOn(_day).where((p) => p.state == PatientState.notCome || p.state == PatientState.waiting).toList();
    final total = all.fold<int>(0, (a, p) => a + p.fee);
    final ok = await confirmSheet(
      context,
      title: "Can't come on {0}?".trf([dayLabel(_day)]),
      text: all.isEmpty
          ? 'There are no bookings on this day. It will be marked as leave.'
          : '${people(all.length)} will get their full money back. Total ${rupees(total)}. Everyone will get a message.',
      yes: all.isEmpty ? 'Mark as leave' : 'Yes, cancel the day',
      danger: true,
      icon: Icons.event_busy_outlined,
    );
    if (!ok || !mounted) return;
    final result = await runWithLoader(context, 'Cancelling the day…'.tr, () => s.cancelDay(_day));
    if (!mounted || result == null) return;
    final (n, sum) = result;
    showToast(context, n == 0 ? 'Marked as leave' : 'Cancelled. ${people(n)} get ${rupees(sum)} back.');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(doctorProvider);
    final all = s.bookingsOn(_day);
    final list = all.where(_match).toList()..sort((a, b) => a.order.compareTo(b.order));
    // Grouped by hospital (a doctor may sit at two on the same day), then by hour.
    final byPlace = <String, Map<int, List<LinePatient>>>{};
    for (final p in list) {
      byPlace.putIfAbsent(p.hospitalId ?? s.hospitalId, () => {}).putIfAbsent(p.hour, () => []).add(p);
    }
    final places = byPlace.keys.toList()..sort((a, b) => byPlace[a]!.keys.reduce(math.min).compareTo(byPlace[b]!.keys.reduce(math.min)));
    final slots = [
      for (final hid in places)
        for (final h in byPlace[hid]!.keys.toList()..sort()) (hid, h),
    ];
    final showPlace = places.length > 1 || (places.isNotEmpty && places.first != s.hospitalId);
    final isLeave = s.leaveDays.contains(dateOnly(_day));
    final works = s.worksOnWeekday(_day.weekday);

    return Column(
      children: [
        const SizedBox(height: 14),
        SizedBox(
          height: 24 + MediaQuery.textScalerOf(context).scale(56),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: OpSpace.gutter),
            itemCount: 14,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final d = today().add(Duration(days: i));
              final sel = sameDay(d, _day);
              final n = s.bookedCount(d);
              // Off only when no hospital has hours that day (or it is leave) and no one is booked.
              final off = n == 0 && (!s.worksOnWeekday(d.weekday) || s.leaveDays.contains(dateOnly(d)));
              return TapScale(
                onTap: () => setState(() => _day = d),
                child: AnimatedContainer(
                  duration: OpMotion.quick,
                  width: 64,
                  decoration: BoxDecoration(
                    color: sel ? OpColors.forest : (off ? OpColors.paperDeep : OpColors.card),
                    borderRadius: OpRadius.controlAll,
                    border: Border.all(color: sel ? OpColors.forest : OpColors.line, width: 1.3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(i == 0 ? 'Today' : shortDay(d), style: OpText.smallStrong.copyWith(fontSize: 12, color: sel ? OpColors.mint : OpColors.inkSoft)),
                      Text('${d.day}', style: OpText.mono(20, weight: FontWeight.w600, color: sel ? OpColors.paper : OpColors.ink)),
                      Text(off ? 'Off'.tr : '$n', style: OpText.mono(11, color: sel ? OpColors.leaf : OpColors.fern)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 10, OpSpace.gutter, 6),
            itemCount: _F.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final f = _F.values[i];
              return OpChip(label: _labels[f]!, selected: _f == f, onTap: () => setState(() => _f = f));
            },
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: OpMotion.page,
            child: KeyedSubtree(
              key: ValueKey('${_day.toIso8601String()}$_f${s.hospitalId}'),
              child: isLeave
                  ? EmptyState(icon: Icons.beach_access_outlined, title: 'You are on leave'.tr, text: 'No bookings are taken on this day.'.tr)
                  : list.isEmpty
                      ? EmptyState(
                          icon: Icons.event_available_outlined,
                          title: !works ? 'No OPD on this day'.tr : 'No bookings here'.tr,
                          text: !works ? 'You can add timings in My timings.' : 'Try a different filter or day.',
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 6, OpSpace.gutter, 24),
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text('${longDate(_day)} · ${people(list.length)}', style: OpText.small)),
                                // Open or close every hour at once.
                                TextButton(
                                  onPressed: () => setState(() {
                                    final allOpen = slots.every((x) => _open.contains(_slotKey(x.$1, x.$2)));
                                    for (final x in slots) {
                                      allOpen ? _open.remove(_slotKey(x.$1, x.$2)) : _open.add(_slotKey(x.$1, x.$2));
                                    }
                                  }),
                                  child: Text(slots.every((x) => _open.contains(_slotKey(x.$1, x.$2))) ? 'Close all'.tr : 'Open all'.tr),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            for (final (i, (hid, h)) in slots.indexed) ...[
                              if (showPlace && (i == 0 || slots[i - 1].$1 != hid))
                                _PlaceHeader(name: s.hospitalName(hid), count: byPlace[hid]!.values.fold(0, (a, l) => a + l.length), first: i == 0),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _Slot(
                                  hour: h,
                                  patients: byPlace[hid]![h]!,
                                  booked: all
                                      .where((p) => (p.hospitalId ?? s.hospitalId) == hid && p.hour == h && p.source == Source.online && p.state != PatientState.cancelled)
                                      .length,
                                  perHour: s.perHourAt(hid, _day.weekday),
                                  open: _open.contains(_slotKey(hid, h)),
                                  onToggle: () => setState(() => _open.contains(_slotKey(hid, h)) ? _open.remove(_slotKey(hid, h)) : _open.add(_slotKey(hid, h))),
                                  onPatient: (p) => context.push('/d/booking/${p.id}'),
                                ).staggerIn(i),
                              ),
                            ],
                          ],
                        ),
            ),
          ),
        ),
        if (!isLeave && (works || all.isNotEmpty) && !(sameDay(_day, DateTime.now()) && s.opd != OpdState.notStarted))
          BottomBar(
            child: OpButton(label: "I can't come on this day".tr, icon: Icons.event_busy_outlined, kind: OpButtonKind.dangerOutline, onPressed: () => _cancelDay(s)),
          ),
      ],
    );
  }
}

/// The hospital a group of hours is at (shown when the day has bookings at more than one, or not at the one on screen).
class _PlaceHeader extends StatelessWidget {
  const _PlaceHeader({required this.name, required this.count, required this.first});

  final String name;
  final int count;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 2 : 12, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: OpColors.mint, borderRadius: BorderRadius.circular(OpRadius.small)),
            child: const Icon(Icons.local_hospital_outlined, size: 18, color: OpColors.forest),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: OpText.bodyStrong.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(people(count), style: OpText.small.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

/// One hour of the day. Closed: the time, how full it is, and who is in it at a glance. Tap to see the
/// patients; tap again to close.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.hour,
    required this.patients,
    required this.booked,
    required this.perHour,
    required this.open,
    required this.onToggle,
    required this.onPatient,
  });

  final int hour;
  final List<LinePatient> patients;
  final int booked;
  final int perHour;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<LinePatient> onPatient;

  @override
  Widget build(BuildContext context) {
    final full = booked >= perHour;
    final done = patients.where((p) => p.state == PatientState.done).length;
    final waiting = patients.where((p) => p.state == PatientState.waiting || p.state == PatientState.withDoctor).length;
    final emergency = patients.where((p) => p.source == Source.emergency).length;
    final names = patients.map((p) => p.name).take(3).join(', ');
    final more = patients.length - 3;
    final nowHour = sameDay(patients.first.date, DateTime.now()) && DateTime.now().hour == hour;
    return AnimatedContainer(
      duration: OpMotion.quick,
      decoration: BoxDecoration(
        color: OpColors.card,
        borderRadius: OpRadius.cardAll,
        border: Border.all(color: open ? OpColors.fern : (nowHour ? OpColors.leaf : OpColors.lineSoft), width: open || nowHour ? 1.4 : 1),
        boxShadow: OpShadow.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: open ? OpColors.mint.withValues(alpha: 0.5) : Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: ClockRange(hour, hour + 1, size: 18))),
                              if (nowHour) ...[
                                const SizedBox(width: 8),
                                StatusTag('Now'.tr, tone: Tone.good),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Flexible(child: SeatMeter(total: perHour, taken: booked.clamp(0, perHour), box: 9, animate: false)),
                              const SizedBox(width: 8),
                              Text('{0} of {1}'.trf([booked, perHour]),
                                  style: OpText.smallStrong.copyWith(fontSize: 12.5, color: full ? OpColors.forest : OpColors.inkSoft)),
                            ],
                          ),
                          if (!open) ...[
                            const SizedBox(height: 6),
                            Text(more > 0 ? '$names +$more' : names,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: OpText.small.copyWith(fontSize: 13)),
                          ],
                          if (done + waiting + emergency > 0) ...[
                            const SizedBox(height: 6),
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              if (emergency > 0) StatusTag('{0} emergency'.trf([emergency]), tone: Tone.bad),
                              if (waiting > 0) StatusTag('{0} waiting'.trf([waiting]), tone: Tone.warn),
                              if (done > 0) StatusTag('{0} done'.trf([done]), tone: Tone.good),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // How many people, and the open/close arrow.
                    Container(
                      width: 46,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(color: open ? OpColors.forest : OpColors.mint, borderRadius: OpRadius.controlAll),
                      child: Column(
                        children: [
                          Text('${patients.length}',
                              style: TextStyle(
                                  fontFamily: 'IBMPlexSans', fontSize: 18, fontWeight: FontWeight.w700, height: 1.1, color: open ? OpColors.paper : OpColors.forest)),
                          AnimatedRotation(
                            turns: open ? 0.5 : 0,
                            duration: OpMotion.page,
                            child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: open ? OpColors.leaf : OpColors.forest),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: OpMotion.page,
            curve: OpMotion.curve,
            alignment: Alignment.topCenter,
            child: !open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                    child: Column(
                      children: [
                        for (final (i, p) in patients.indexed)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _BookingRow(p: p, onTap: () => onPatient(p)).staggerIn(i),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.p, required this.onTap});

  final LinePatient p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = switch (p.state) {
      PatientState.cancelled || PatientState.didNotCome => Tone.bad,
      PatientState.done => Tone.good,
      PatientState.waiting || PatientState.withDoctor => Tone.warn,
      _ => Tone.calm,
    };
    return OpCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: p.source == Source.emergency ? OpColors.alarmWash : OpColors.mint,
              borderRadius: OpRadius.controlAll,
            ),
            child: Text(p.tokenLabel,
                style: TextStyle(
                    fontFamily: 'IBMPlexSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: p.source == Source.emergency ? OpColors.alarm : OpColors.forest,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: OpText.bodyStrong.copyWith(fontSize: 15)),
                if (p.phone.isNotEmpty) Text(p.phone, style: OpText.mono(12.5)),
                Text('${p.age} yrs · ${p.gender} · ${p.source.label}${p.changed ? ' · Changed' : ''}', style: OpText.small.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          StatusTag(p.state == PatientState.notCome ? 'Booked' : p.state.label, tone: tone),
        ],
      ),
    );
  }
}
