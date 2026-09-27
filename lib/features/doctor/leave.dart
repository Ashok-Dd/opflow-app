import '../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../data/config.dart';
import '../../mock/format.dart';
import '../../state/doctor_store.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/op_button.dart';
import '../../widgets/op_loader.dart';

/// Tap days to mark leave. Days with bookings ask what to do with the patients.
class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen> {
  late final Set<DateTime> _days = {...ref.read(doctorProvider).leaveDays};

  Future<void> _save(DoctorStore s) async {
    final ok = await confirmSheet(context,
        title: 'Save your leave?'.tr,
        text: 'Patients cannot book you on your leave days. If someone already booked, we ask you what to do next.'.tr,
        yes: 'Yes, save'.tr);
    if (!ok || !mounted) return;
    final added = _days.where((d) => !s.leaveDays.contains(d)).toList();
    // Wait for each new day's real bookings: a day still loading must not look empty.
    final booked = <DateTime, List<LinePatient>>{};
    final loaded = await runStep(context, 'Checking your bookings…'.tr, () async {
      for (final d in added) {
        final open = (await s.loadBookingsOn(d)).where((p) => p.state == PatientState.notCome).toList();
        if (open.isNotEmpty) booked[d] = open;
      }
    });
    if (!loaded || !mounted) return;
    final withBookings = booked.keys.toList();
    var cancel = false;
    if (withBookings.isNotEmpty) {
      final n = booked.values.fold<int>(0, (a, l) => a + l.length);
      final choice = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('{0} booked on these days'.trf([people(n)]), style: OpText.title),
                const SizedBox(height: 6),
                Text('What should we do for them?'.tr, style: OpText.body.copyWith(color: OpColors.inkSoft)),
                const SizedBox(height: 18),
                OpButton(label: 'Move patients to another day'.tr, icon: Icons.event_repeat, onPressed: () => Navigator.pop(context, false)),
                const SizedBox(height: 10),
                OpButton(label: 'Cancel and give money back'.tr, kind: OpButtonKind.dangerOutline, onPressed: () => Navigator.pop(context, true)),
              ],
            ),
          ),
        ),
      );
      if (choice == null) return;
      cancel = choice;
    }
    if (!mounted) return;
    final done = await runStep(context, 'Saving leave…'.tr, () async {
      if (cancel) {
        for (final d in withBookings) {
          await s.cancelDay(d);
        }
      } else {
        // Each patient is asked to pick a new time (all money back if they don't within 48 hours).
        for (final p in booked.values.expand((l) => l)) {
          if (AppConfig.isApi) {
            await s.changeBooking(p, p.date, p.hour);
          } else {
            p.state = PatientState.moved;
          }
        }
      }
      await s.setLeave(_days);
    });
    if (!done || !mounted) return;
    showToast(context, 'Leave saved'.tr);
    context.popOr('/d/timings');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(doctorProvider);
    final now = today();
    return OpPage(
      title: 'Leave and holidays'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          Text('Tap the days you will not come.'.tr, style: OpText.body.copyWith(color: OpColors.inkSoft)),
          const SizedBox(height: 16),
          for (var m = 0; m < 2; m++) _Month(first: DateTime(now.year, now.month + m, 1), s: s, days: _days, onTap: (d) => setState(() {
                if (!_days.remove(d)) _days.add(d);
              })),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 8, children: [
            _Legend(color: OpColors.alarm, text: 'Leave'.tr),
            _Legend(color: OpColors.fern, text: 'Has bookings'.tr, dot: true),
            _Legend(color: OpColors.paperDeep, text: 'No OPD'.tr),
          ]),
        ],
      ),
      bottom: OpButton(label: 'Save leave ({0} days)'.trf([_days.where((d) => !d.isBefore(now)).length]), onPressed: () => _save(s)),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text, this.dot = false});

  final Color color;
  final String text;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: dot ? 7 : 14, height: dot ? 7 : 14, decoration: BoxDecoration(color: color, shape: dot ? BoxShape.circle : BoxShape.rectangle)),
        const SizedBox(width: 6),
        Text(text, style: OpText.small.copyWith(fontSize: 13)),
      ],
    );
  }
}

class _Month extends StatelessWidget {
  const _Month({required this.first, required this.s, required this.days, required this.onTap});

  final DateTime first;
  final DoctorStore s;
  final Set<DateTime> days;
  final ValueChanged<DateTime> onTap;

  static const _names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final lead = first.weekday - 1;
    final now = today();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_names[first.month - 1]} ${first.year}', style: OpText.heading),
          const SizedBox(height: 10),
          Row(children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(child: Center(child: Text(d, style: OpText.label))),
          ]),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox(),
              for (var d = 1; d <= daysInMonth; d++)
                () {
                  final day = DateTime(first.year, first.month, d);
                  final past = day.isBefore(now);
                  final off = s.blocksFor(day.weekday).isEmpty;
                  final leave = days.contains(day);
                  final booked = !past && !off && s.hasComing(day);
                  return InkWell(
                    onTap: past || off ? null : () => onTap(day),
                    borderRadius: OpRadius.smallAll,
                    child: AnimatedContainer(
                      duration: OpMotion.quick,
                      decoration: BoxDecoration(
                        color: leave ? OpColors.alarm : (off ? OpColors.paperDeep : OpColors.card),
                        borderRadius: OpRadius.smallAll,
                        border: Border.all(color: sameDay(day, now) ? OpColors.forest : OpColors.line, width: sameDay(day, now) ? 2 : 1),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text('$d',
                              style: OpText.mono(14,
                                  weight: FontWeight.w600,
                                  color: leave ? Colors.white : (past || off ? OpColors.inkFaint : OpColors.ink))),
                          if (booked && !leave)
                            Positioned(
                              bottom: 4,
                              child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: OpColors.fern, shape: BoxShape.circle)),
                            ),
                        ],
                      ),
                    ),
                  );
                }(),
            ],
          ),
        ],
      ),
    );
  }
}
