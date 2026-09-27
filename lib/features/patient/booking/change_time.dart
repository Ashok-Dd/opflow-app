import '../../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../mock/data.dart';
import '../../../mock/format.dart';
import '../../../mock/models.dart';
import '../../../state/patient_store.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/op_button.dart';
import '../../../widgets/op_loader.dart';
import '../widgets.dart';

/// Change date or time (once, up to 2 hours before). Same doctor, any open time.
class ChangeTimeScreen extends ConsumerStatefulWidget {
  const ChangeTimeScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ChangeTimeScreen> createState() => _ChangeTimeScreenState();
}

class _ChangeTimeScreenState extends ConsumerState<ChangeTimeScreen> {
  DateTime? _day;
  TimeWindow? _w;

  Future<void> _confirm(Booking b) async {
    final ok = await confirmSheet(
      context,
      title: 'Change to {0}, {1}?'.trf([dayLabel(_day!), windowLabel(_w!.start)]),
      text: 'You can change only once. After this, the booking cannot be changed again.'.tr,
      yes: 'Yes, change it'.tr,
      icon: Icons.event_repeat,
    );
    if (!ok || !mounted) return;
    final done = await runStep(context, 'Changing your booking…'.tr, () => ref.read(patientProvider).changeTime(b, _day!, _w!));
    if (!done || !mounted) return;
    // The booking as it is now (new hour, new token), not the one from before the change.
    final now = ref.read(patientProvider).booking(b.id) ?? b;
    showToast(context, 'Booking changed. New token {0}.'.trf([now.tokenLabel]));
    context.popOr('/bookings');
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(patientProvider);
    final b = store.booking(widget.bookingId);
    if (b == null) return OpPage(title: 'Change date or time'.tr, body: SizedBox());
    final d = MockData.doctor(b.doctorId);
    final why = store.whyNoChange(b);
    _day ??= b.date;

    return OpPage(
      title: 'Change date or time'.tr,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OpSpace.gutter),
            child: OpCard(
              color: OpColors.paperDeep,
              child: Row(
                children: [
                  const Icon(Icons.event_note_outlined, color: OpColors.inkSoft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NOW'.tr, style: OpText.label),
                        Text('{0}, {1} · Token {2}'.trf([dayLabel(b.date), windowLabel(b.start), b.token]), style: OpText.bodyStrong),
                        Text(d.name, style: OpText.small.copyWith(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (why != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OpSpace.gutter),
              child: InfoBox(tone: Tone.warn, icon: Icons.lock_clock, child: Text(why)),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OpSpace.gutter),
              child: Text('Pick a new day'.tr, style: OpText.title),
            ),
            const SizedBox(height: 12),
            DayStrip(
              doctor: d,
              selected: _day,
              windowsFor: (day) => store.windows(d, day),
              onSelect: (day) => setState(() {
                _day = day;
                _w = null;
              }),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OpSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pick a new time'.tr, style: OpText.title),
                  const SizedBox(height: 12),
                  WindowList(
                    windows: store.windows(d, _day!).where((w) => !(sameDay(_day!, b.date) && w.start == b.start)).toList(),
                    selected: _w?.start,
                    onSelect: (w) => setState(() => _w = w),
                  ),
                  InfoBox(icon: Icons.info_outline, child: Text('You can change only once. There is no extra charge.'.tr)),
                ],
              ),
            ),
          ],
        ],
      ),
      bottom: OpButton(
        label: 'Confirm change'.tr,
        onPressed: why == null && _w != null ? () => _confirm(b) : null,
      ),
    );
  }
}
