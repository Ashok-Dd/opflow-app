import '../../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../mock/data.dart';
import '../../../mock/format.dart';
import '../../../mock/models.dart';
import '../../../state/patient_store.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/op_button.dart';
import '../../../widgets/token_board.dart';
import '../widgets.dart';

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(patientProvider);
    final b = store.booking(bookingId);
    if (b == null) {
      return OpPage(
        title: 'Booking'.tr,
        body: EmptyState(icon: Icons.search_off, title: 'Booking not found'.tr, text: 'It may have been removed.'.tr),
      );
    }
    final d = MockData.doctor(b.doctorId);
    final h = MockData.hospital(b.hospitalId);
    final live = store.live[b.id];
    final isToday = sameDay(b.date, DateTime.now()) && b.status == BookingStatus.upcoming;
    final why = store.whyNoChange(b);

    return OpPage(
      title: 'Booking'.tr,
      subtitle: '${b.emergency ? 'Emergency · ' : ''}Token ${b.tokenLabel} · ${dayLabel(b.date)}',
      body: OpRefresh(
        onRefresh: () => store.refreshLive(b),
        child: ListView(
          physics: opRefreshPhysics,
          padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 16, OpSpace.gutter, 32),
          children: [
            if (b.needsNewTime && b.status == BookingStatus.upcoming) ...[
              PickNewTimeCard(booking: b).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 18),
            ],
            if (isToday && live != null && !b.needsNewTime) ...[
              _LivePanel(b: b, live: live).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 18),
            ],
            VisitTicket(
              booking: b,
              footer: b.status == BookingStatus.upcoming && !isToday && !b.needsNewTime
                  ? StatusTag('Please reach by {0}'.trf([clockLabel(b.windowStart.subtract(const Duration(minutes: 15)))]),
                      tone: Tone.info, icon: Icons.directions_walk)
                  : bookingStatusTag(b),
            ).staggerIn(1),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OpIconAction(icon: Icons.call_outlined, label: 'Call hospital'.tr, onTap: () => showCallSheet(context, name: h.name, phone: h.phone))),
                const SizedBox(width: 8),
                Expanded(child: OpIconAction(icon: Icons.directions_outlined, label: 'Get directions'.tr, onTap: () => showDirectionsSheet(context, h))),
                const SizedBox(width: 8),
                Expanded(child: OpIconAction(icon: Icons.receipt_long_outlined, label: 'See receipt'.tr, onTap: () => showReceipt(context, b, store.me.name))),
              ],
            ).staggerIn(2),
            if (b.status == BookingStatus.upcoming) ...[
              const SizedBox(height: 16),
              OpButton.secondary(
                label: 'Change date or time'.tr,
                icon: Icons.event_repeat,
                onPressed: why == null ? () => context.push('/booking/${b.id}/change') : null,
              ),
              const SizedBox(height: 8),
              if (why != null)
                Row(
                  children: [
                    const Icon(Icons.lock_clock, size: 16, color: OpColors.inkSoft),
                    const SizedBox(width: 6),
                    Expanded(child: Text(why, style: OpText.small.copyWith(fontSize: 13))),
                  ],
                )
              else
                Text('You can change once, up to 2 hours before your time.'.tr, style: OpText.small.copyWith(fontSize: 13)),
              const SizedBox(height: 10),
              Text('Want to cancel? Please call the hospital.'.tr, style: OpText.small.copyWith(fontSize: 13)),
            ],
            if (b.status == BookingStatus.cancelledByDoctor) ...[
              const SizedBox(height: 16),
              InfoBox(
                tone: Tone.good,
                icon: Icons.currency_rupee,
                child: Text('The doctor cancelled this visit. Your full {0} is sent back. It reaches your account in 5–7 days.'.trf([rupees(b.total)])),
              ),
            ],
            if (b.status == BookingStatus.missed) ...[
              const SizedBox(height: 16),
              InfoBox(
                tone: Tone.warn,
                icon: Icons.info_outline,
                child: Text('You did not come at your time, and the date was not changed. So there is no money back for this visit.'.tr),
              ),
            ],
            if (b.note.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionLabel('Problem you told the doctor'),
              Text(b.note, style: OpText.body),
            ],
            const SizedBox(height: 22),
            const SectionLabel('Progress'),
            _Timeline(b: b, live: live),
            if (b.status != BookingStatus.upcoming) ...[
              const SizedBox(height: 20),
              OpButton(label: 'Book {0} again'.trf([d.name]), onPressed: () => context.push('/book/${d.id}?hospital=${b.hospitalId}')),
            ],
          ],
        ),
      ),
    );
  }
}

class _LivePanel extends StatelessWidget {
  const _LivePanel({required this.b, required this.live});

  final Booking b;
  final LiveStatus live;

  @override
  Widget build(BuildContext context) {
    final ahead = live.aheadOf(b);
    final yourTurn = live.isMyTurn(b);
    const perPatient = 7;
    final low = live.lowMinutes ?? ahead * perPatient;
    final high = live.highMinutes ?? low + 10;
    final seen = live.myState == 'done';
    final missed = live.myState == 'did_not_come';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: OpColors.alarm, shape: BoxShape.circle))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 1, end: 0.2, duration: 700.ms),
            const SizedBox(width: 8),
            Text('LIVE TURN'.tr, style: OpText.label.copyWith(color: OpColors.alarm)),
            const Spacer(),
            Text('Updated {0}'.trf([agoLabel(live.updated).toLowerCase()]), style: OpText.small.copyWith(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        TokenBoard(nowSeeing: live.nowSeeing, yourToken: b.token),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: OpMotion.quick,
          child: seen
              ? const StatusTag('Your visit is done.', key: ValueKey('seen'), tone: Tone.good, icon: Icons.check_circle_outline, big: true)
              : missed
              ? const StatusTag('You were marked as not come. Please tell the hospital desk so you are put back in line.',
                  key: ValueKey('missed'), tone: Tone.warn, icon: Icons.info_outline, big: true)
              : yourTurn
              ? const StatusTag('It is your turn now. Please go in.', key: ValueKey('turn'), tone: Tone.good, icon: Icons.meeting_room_outlined, big: true)
              : ahead == 0
                  ? const StatusTag('You are next. Please be near the room.', key: ValueKey('next'), tone: Tone.good, icon: Icons.directions_walk, big: true)
                  : Column(
                      key: ValueKey(ahead),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('{0} before you'.trf([people(ahead)]), style: OpText.title),
                        Text('About {0} – {1} min'.trf([low, high]), style: OpText.mono(16, weight: FontWeight.w500, color: OpColors.inkSoft)),
                      ],
                    ),
        ),
        const SizedBox(height: 10),
        liveTag(live, big: true),
        const SizedBox(height: 8),
        Text('Pull down to refresh'.tr, style: OpText.small.copyWith(fontSize: 12)),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.b, required this.live});

  final Booking b;
  final LiveStatus? live;

  @override
  Widget build(BuildContext context) {
    final List<(String, bool)> steps;
    if (b.status == BookingStatus.cancelledByDoctor) {
      steps = [('Booked', true), ('Paid', true), ('Cancelled by doctor', true), ('Money back sent', true)];
    } else if (b.status == BookingStatus.missed) {
      steps = [('Booked', true), ('Paid', true), ('You did not come', true)];
    } else {
      final done = b.status == BookingStatus.done;
      final st = live?.myState;
      final reached = done || (st != null ? const {'waiting', 'with_doctor', 'done'}.contains(st) : live != null && live!.nowSeeing >= b.token - 3);
      final called = done || (st != null ? const {'with_doctor', 'done'}.contains(st) : live != null && live!.nowSeeing >= b.token);
      steps = [('Booked', true), ('Paid', true), ('Reached hospital', reached), ('Called in', called), ('Done', done)];
    }
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: OpMotion.quick,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: steps[i].$2 ? OpColors.fern : OpColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: steps[i].$2 ? OpColors.fern : OpColors.line, width: 2),
                    ),
                    child: steps[i].$2 ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                  if (i < steps.length - 1)
                    Container(width: 2, height: 28, color: steps[i + 1].$2 ? OpColors.fern : OpColors.line),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(steps[i].$1,
                    style: steps[i].$2 ? OpText.bodyStrong.copyWith(fontSize: 15) : OpText.body.copyWith(fontSize: 15, color: OpColors.inkFaint)),
              ),
            ],
          ),
      ],
    );
  }
}
