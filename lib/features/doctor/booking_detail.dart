import '../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/config.dart';
import '../../mock/data.dart';
import '../../mock/format.dart';
import '../../mock/models.dart';
import '../../state/doctor_store.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/op_button.dart';
import '../../widgets/op_loader.dart';
import '../patient/widgets.dart';

class DoctorBookingDetail extends ConsumerWidget {
  const DoctorBookingDetail({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(doctorProvider);
    final p = s.findBooking(bookingId);
    if (p == null) {
      // Opened from a message about another day: ask the server for it.
      return OpPage(
        title: 'Booking'.tr,
        body: FutureBuilder<LinePatient?>(
          future: s.fetchBooking(bookingId),
          builder: (context, snap) => snap.connectionState != ConnectionState.done
              ? const Center(child: OpLoadingPanel(text: 'Loading the booking…', height: 260))
              : Center(
                  child: EmptyState(emoji: '🔍', icon: Icons.search_off, title: 'Booking not found'.tr, text: 'It may have been moved.'.tr),
                ),
        ),
      );
    }
    final open = p.state == PatientState.notCome || p.state == PatientState.waiting;
    // "Did not come" only makes sense for today's line once the OPD has started.
    final inTodaysLine = s.line.contains(p) && s.opd != OpdState.notStarted && s.opd != OpdState.ended;

    return OpPage(
      title: 'Token {0}'.trf([p.tokenLabel]),
      subtitle: '${dayLabel(p.date)} · ${windowLabel(p.hour)}',
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          OpCard(
            child: Row(
              children: [
                InitialsTile(text: p.name[0], size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: OpText.title.copyWith(fontSize: 22)),
                      Text('{0} years · {1}'.trf([p.age, p.gender]), style: OpText.small),
                      const SizedBox(height: 6),
                      StatusTag(p.state == PatientState.notCome ? 'Booked' : p.state.label,
                          tone: p.state == PatientState.cancelled || p.state == PatientState.didNotCome ? Tone.bad : Tone.good),
                    ],
                  ),
                ),
              ],
            ),
          ).staggerIn(0),
          const SizedBox(height: 14),
          if (p.phone.isNotEmpty)
            OpCard(
              child: Row(
                children: [
                  const Icon(Icons.call_outlined, color: OpColors.fern),
                  const SizedBox(width: 10),
                  Expanded(child: Text(maskPhone(p.phone), style: OpText.mono(18, weight: FontWeight.w600))),
                  OpButton(
                    label: 'Call'.tr,
                    expand: false,
                    height: 44,
                    onPressed: () => showCallSheet(context, name: p.name, phone: maskPhone(p.phone)),
                  ),
                ],
              ),
            ).staggerIn(1),
          const SizedBox(height: 14),
          OpCard(
            child: Column(
              children: [
                KeyValueRow('Day', longDate(p.date)),
                KeyValueRow('Hospital', p.hospitalName ?? s.hospitalName(p.hospitalId)),
                KeyValueRow('Time', windowLabel(p.hour), mono: true),
                KeyValueRow('How booked', p.source.label),
                KeyValueRow('Paid', '${rupees(p.fee)} online', mono: true),
                if (p.state == PatientState.cancelled) KeyValueRow('Money back', '${rupees(p.fee)} sent', mono: true),
              ],
            ),
          ).staggerIn(2),
          if (p.note.isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionLabel('Problem the patient wrote'),
            Text(p.note, style: OpText.body),
          ],
          const SizedBox(height: 18),
          const SectionLabel('History'),
          _History(p: p),
          if (open) ...[
            const SizedBox(height: 22),
            OpButton.secondary(
              label: AppConfig.isApi ? 'Ask to pick a new time'.tr : 'Change date or time'.tr,
              icon: Icons.event_repeat,
              onPressed: () => AppConfig.isApi ? _askNewTime(context, s, p) : _change(context, s, p),
            ),
            if (inTodaysLine) ...[
              const SizedBox(height: 10),
              OpButton(label: 'Mark did not come'.tr, kind: OpButtonKind.quiet, icon: Icons.person_off_outlined, onPressed: () async {
                final ok = await confirmSheet(context,
                    title: 'Mark {0} as did not come?'.trf([p.name]),
                    text: 'Use this only when the patient did not come. You can put them back in the line later.'.tr,
                    yes: 'Yes, did not come'.tr,
                    icon: Icons.person_off_outlined);
                if (!ok || !context.mounted) return;
                s.markNoShow(p);
                showToast(context, 'Marked as did not come'.tr);
              }),
            ],
            const SizedBox(height: 10),
            OpButton(label: 'Cancel booking'.tr, kind: OpButtonKind.dangerOutline, icon: Icons.block, onPressed: () => _cancel(context, s, p)),
          ],
        ],
      ),
    );
  }

  /// Real server: the doctor can't choose the patient's new time (the patient knows when they can come).
  /// The patient gets a message to pick a new time; if they don't within 48 hours, all their money comes back.
  Future<void> _askNewTime(BuildContext context, DoctorStore s, LinePatient p) async {
    final ok = await confirmSheet(
      context,
      title: 'Ask {0} to pick a new time?'.trf([p.name]),
      text: 'They get a message to choose another time with you. If they do not choose within 48 hours, they get all their money back.'.tr,
      yes: 'Yes, ask them'.tr,
      icon: Icons.event_repeat,
    );
    if (!ok || !context.mounted) return;
    final done = await runStep(context, 'Sending…'.tr, () => s.changeBooking(p, p.date, p.hour));
    if (done && context.mounted) showToast(context, '{0} will pick a new time.'.trf([p.name]));
  }

  Future<void> _change(BuildContext context, DoctorStore s, LinePatient p) async {
    final result = await showModalBottomSheet<(DateTime, int)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChangeSheet(s: s, p: p),
    );
    if (result == null || !context.mounted) return;
    final done = await runStep(context, 'Changing booking…'.tr, () => s.changeBooking(p, result.$1, result.$2));
    if (!done || !context.mounted) return;
    showToast(context, 'Changed. {0} will get a message.'.trf([p.name]));
  }

  Future<void> _cancel(BuildContext context, DoctorStore s, LinePatient p) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Why cancel?'.tr, style: OpText.title),
              const SizedBox(height: 4),
              Text('The patient will see this reason.'.tr, style: OpText.small),
              const SizedBox(height: 12),
              MenuGroup(children: [
                for (final r in const ['I have an emergency', 'I am not well', 'Hospital is closed', 'Patient asked to cancel', 'Other reason'])
                  MenuRow(icon: Icons.circle_outlined, title: r, onTap: () => Navigator.pop(context, r)),
              ]),
            ],
          ),
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    final ok = await confirmSheet(
      context,
      title: 'Cancel {0}\'s booking?'.trf([p.name]),
      text: 'Patient gets full money back: {0}.\nReason: {1}'.trf([rupees(p.fee), reason]),
      yes: 'Yes, cancel'.tr,
      danger: true,
      icon: Icons.currency_rupee,
    );
    if (!ok || !context.mounted) return;
    final done = await runStep(context, 'Cancelling and sending money back…'.tr, () => s.cancelBooking(p, reason));
    if (!done || !context.mounted) return;
    showToast(context, 'Cancelled. {0} sent back.'.trf([rupees(p.fee)]));
  }
}

class _History extends StatelessWidget {
  const _History({required this.p});

  final LinePatient p;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String)>[
      (Icons.event_available_outlined, p.source == Source.online ? 'Booked online and paid' : 'Emergency consultation booked and paid'),
      if (p.changed) (Icons.event_repeat, 'Date or time changed'),
      if (p.reachedAt != null) (Icons.how_to_reg_outlined, 'Reached at ${clockLabel(p.reachedAt!)}'),
      if (p.calledAt != null) (Icons.campaign_outlined, 'Called in at ${clockLabel(p.calledAt!)}'),
      if (p.doneAt != null) (Icons.check, 'Done at ${clockLabel(p.doneAt!)}'),
      if (p.state == PatientState.cancelled) (Icons.currency_rupee, 'Cancelled, money back sent'),
      if (p.state == PatientState.didNotCome) (Icons.person_off_outlined, 'Did not come'),
    ];
    return Column(
      children: [
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(icon, size: 18, color: OpColors.fern),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: OpText.body.copyWith(fontSize: 15))),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChangeSheet extends StatefulWidget {
  const _ChangeSheet({required this.s, required this.p});

  final DoctorStore s;
  final LinePatient p;

  @override
  State<_ChangeSheet> createState() => _ChangeSheetState();
}

class _ChangeSheetState extends State<_ChangeSheet> {
  DateTime? _day;
  TimeWindow? _w;

  @override
  Widget build(BuildContext context) {
    final d = widget.s.doctor;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 12),
              child: Text('Move {0} to'.trf([widget.p.name]), style: OpText.title),
            ),
            DayStrip(doctor: d, selected: _day, onSelect: (x) => setState(() {
              _day = x;
              _w = null;
            })),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: OpSpace.gutter),
                children: [
                  if (_day == null)
                    Text('Pick a day first.'.tr, style: OpText.small.copyWith(fontSize: 15))
                  else
                    WindowList(windows: MockData.windows(d, _day!), selected: _w?.start, onSelect: (w) => setState(() => _w = w)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 8, OpSpace.gutter, 12),
              child: OpButton(
                label: 'Move booking'.tr,
                onPressed: _w == null ? null : () => Navigator.pop(context, (_day!, _w!.start)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
