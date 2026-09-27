import '../../l10n/lang.dart';
import '../../widgets/clock_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../mock/format.dart';
import '../../mock/models.dart';
import '../../state/doctor_store.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/op_button.dart';
import '../../widgets/op_loader.dart';
import '../../widgets/page_header.dart';
import '../patient/widgets.dart';
import 'today.dart' show BookingsPauseCard;

/// The doctor decides the timings and how many patients: this is where OPflow is set up.
class TimingsTab extends ConsumerStatefulWidget {
  const TimingsTab({super.key});

  @override
  ConsumerState<TimingsTab> createState() => _TimingsTabState();
}

class _TimingsTabState extends ConsumerState<TimingsTab> {
  Map<int, List<TimeBlock>>? _week;
  String? _loadedFor;
  int _openBefore = 14;
  bool _dirty = false;

  void _load(DoctorStore s) {
    _week = {for (var d = 1; d <= 7; d++) d: s.blocksFor(d).map((b) => b.copy()).toList()};
    _openBefore = s.openDaysBefore;
    _loadedFor = s.hospitalId;
    _dirty = false;
  }

  void _changed(VoidCallback f) => setState(() {
        f();
        _dirty = true;
      });

  Future<void> _save(DoctorStore s) async {
    final ok = await confirmSheet(context,
        title: 'Save your new timings?'.tr,
        text: 'Patients will see the new times and can book them. Bookings already made stay the same.'.tr,
        yes: 'Yes, save'.tr);
    if (!ok || !mounted) return;
    final done = await runStep(context, 'Saving your timings…'.tr, () => s.saveTimings(_week!, _openBefore));
    if (!done || !mounted) return;
    setState(() => _dirty = false);
    showToast(context, 'Saved. Patients will see the new times.'.tr);
  }

  void _preview(DoctorStore s) {
    final d = s.doctor;
    // Find the next day with a block, and build what the patient would see.
    DateTime? day;
    for (var i = 0; i < 7; i++) {
      final x = today().add(Duration(days: i));
      if (_week![x.weekday]!.isNotEmpty) {
        day = x;
        break;
      }
    }
    final windows = <TimeWindow>[];
    if (day != null) {
      for (final b in _week![day.weekday]!) {
        for (var h = b.start; h < b.end; h++) {
          windows.add(TimeWindow(start: h, capacity: b.perHour, booked: (h * 3 + d.id.length) % (b.perHour + 1)));
        }
      }
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 16),
            children: [
              Text('This is how patients see your times'.tr, style: OpText.title),
              const SizedBox(height: 4),
              Text(day == null ? 'You have no OPD this week.' : longDate(day), style: OpText.small),
              const SizedBox(height: 14),
              IgnorePointer(child: WindowList(windows: windows, selected: null, onSelect: (_) {})),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(doctorProvider);
    if (_week == null || _loadedFor != s.hospitalId) _load(s);
    final week = _week!;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 18, OpSpace.gutter, 28),
            children: [
              PageHeader(eyebrow: s.hospital.name, title: 'My timings'.tr, subtitle: 'You decide the hours and how many patients.'.tr),
              const SizedBox(height: 18),
              BookingsPauseCard(s: s),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: OpButton.secondary(label: 'Leave and holidays'.tr, icon: Icons.beach_access_outlined, onPressed: () => context.push('/d/leave'))),
                  const SizedBox(width: 10),
                  Expanded(child: OpButton.secondary(label: 'Preview'.tr, icon: Icons.visibility_outlined, onPressed: () => _preview(s))),
                ],
              ),
              const SizedBox(height: 20),
              const SectionLabel('Every week'),
              for (var d = 1; d <= 7; d++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DayCard(
                    weekday: d,
                    blocks: week[d]!,
                    onToggle: (on) => _changed(() => week[d] = on ? [TimeBlock(start: 9, end: 13)] : []),
                    onAdd: () => _changed(() {
                      final last = week[d]!.isEmpty ? 9 : week[d]!.last.end + 3;
                      week[d]!.add(TimeBlock(start: last.clamp(6, 20), end: (last + 2).clamp(7, 22)));
                    }),
                    onRemove: (b) => _changed(() => week[d]!.remove(b)),
                    onChanged: () => _changed(() {}),
                    onCopyToAll: () => _changed(() {
                      for (var x = 1; x <= 6; x++) {
                        week[x] = week[d]!.map((b) => b.copy()).toList();
                      }
                    }),
                  ),
                ),
              const SizedBox(height: 14),
              const SectionLabel('Booking window'),
              OpCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Open booking before'.tr, style: OpText.bodyStrong),
                          Text('How many days ahead patients can book'.tr, style: OpText.small.copyWith(fontSize: 13)),
                        ],
                      ),
                    ),
                    NumberStepper(value: _openBefore, min: 1, max: 30, unit: 'days', onChanged: (v) => _changed(() => _openBefore = v)),
                  ],
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: OpMotion.quick,
          child: _dirty
              ? BottomBar(
                  child: Row(
                    children: [
                      Expanded(child: OpButton(label: 'Undo'.tr, kind: OpButtonKind.secondary, onPressed: () => setState(() => _load(s)))),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: OpButton(label: 'Save'.tr, icon: Icons.check, onPressed: () => _save(s))),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.weekday,
    required this.blocks,
    required this.onToggle,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
    required this.onCopyToAll,
  });

  final int weekday;
  final List<TimeBlock> blocks;
  final ValueChanged<bool> onToggle;
  final VoidCallback onAdd;
  final ValueChanged<TimeBlock> onRemove;
  final VoidCallback onChanged;
  final VoidCallback onCopyToAll;

  @override
  Widget build(BuildContext context) {
    final on = blocks.isNotEmpty;
    return AnimatedContainer(
      duration: OpMotion.quick,
      decoration: BoxDecoration(
        color: on ? OpColors.card : OpColors.paperDeep,
        borderRadius: OpRadius.cardAll,
        border: Border.all(color: OpColors.line, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                SizedBox(width: 108, child: Text(weekdayName(weekday), style: OpText.bodyStrong)),
                Expanded(
                  child: Text(
                    on ? blocks.map((b) => '${hourLabel(b.start)} – ${hourLabel(b.end)}').join(', ') : 'No OPD'.tr,
                    style: on ? OpText.mono(13, weight: FontWeight.w500) : OpText.small,
                  ),
                ),
                Switch(value: on, onChanged: onToggle),
              ],
            ),
          ),
          if (on) ...[
            const Divider(),
            for (final b in blocks) _BlockEditor(b: b, onChanged: onChanged, onRemove: () => onRemove(b)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text('Add time'.tr)),
                  if (weekday == 1) TextButton(onPressed: onCopyToAll, child: Text('Same for Mon – Sat'.tr)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BlockEditor extends StatelessWidget {
  const _BlockEditor({required this.b, required this.onChanged, required this.onRemove});

  final TimeBlock b;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    Widget line(String title, String help, Widget control) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: OpText.smallStrong.copyWith(fontSize: 15)),
                    Text(help, style: OpText.small.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              control,
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: OpColors.paper, borderRadius: OpRadius.controlAll, border: Border.all(color: OpColors.line)),
      child: Column(
        children: [
          Row(
            children: [
              ClockRange(b.start, b.end, size: 18, shortSame: false),
              const Spacer(),
              IconButton(tooltip: 'Remove this time'.tr, onPressed: onRemove, icon: const Icon(Icons.delete_outline, color: OpColors.alarm)),
            ],
          ),
          line('Starts at', 'OPD start time', NumberStepper(value: b.start, min: 6, max: b.end - 1, unit: hourLabel(b.start), onChanged: (v) {
            b.start = v;
            onChanged();
          })),
          line('Ends at', 'OPD end time', NumberStepper(value: b.end, min: b.start + 1, max: 23, unit: hourLabel(b.end), onChanged: (v) {
            b.end = v;
            onChanged();
          })),
          const Divider(height: 18),
          line('Patients per hour', 'Booked online', NumberStepper(value: b.perHour, min: 1, max: 20, onChanged: (v) {
            b.perHour = v;
            onChanged();
          })),
          line('Average time per patient', 'Used to guess waiting time', NumberStepper(value: b.avgMinutes, min: 2, max: 30, unit: 'min', onChanged: (v) {
            b.avgMinutes = v;
            onChanged();
          })),
          line('Take emergency patients', 'As needed', Switch(value: b.takeEmergency, onChanged: (v) {
            b.takeEmergency = v;
            onChanged();
          })),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Total online: {0} patients'.trf([(b.end - b.start) * b.perHour]), style: OpText.mono(13, color: OpColors.fern)),
          ),
        ],
      ),
    );
  }
}
