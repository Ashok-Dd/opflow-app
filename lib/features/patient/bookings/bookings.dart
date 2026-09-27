import '../../../l10n/lang.dart';
import '../../../widgets/clock_time.dart';
import '../../../widgets/op_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../mock/data.dart';
import '../../../mock/format.dart';
import '../../../mock/models.dart';
import '../../../state/patient_store.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/doctor_portrait.dart';
import '../../../widgets/op_button.dart';
import '../../../widgets/page_header.dart';
import '../widgets.dart';

class BookingsTab extends ConsumerStatefulWidget {
  const BookingsTab({super.key});

  @override
  ConsumerState<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends ConsumerState<BookingsTab> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(patientProvider);
    final list = _tab == 0 ? store.upcoming : store.past;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 16, OpSpace.gutter, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(eyebrow: 'Your visits'.tr, title: 'My bookings'.tr),
                const SizedBox(height: 16),
                OpSegments(
                  labels: ['Coming up (${store.upcoming.length})', 'Old (${store.past.length})'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: OpMotion.page,
              child: list.isEmpty && store.isLoading
                  ? const Center(key: ValueKey('loading'), child: OpLoadingPanel(text: 'Loading your bookings…', height: 260))
                  : list.isEmpty
                  ? LayoutBuilder(
                      key: ValueKey('empty$_tab'),
                      builder: (context, box) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Center(
                            child: EmptyState(
                        emoji: _tab == 0 ? '🗓️' : '📂',
                        icon: Icons.confirmation_number_outlined,
                        title: _tab == 0 ? 'No bookings yet' : 'No old bookings',
                        text: _tab == 0 ? 'When you book a doctor, it will show here.' : 'Your past visits will show here.',
                        action: _tab == 0 ? 'Find a doctor' : null,
                        onAction: () => context.go('/find'),
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      key: ValueKey('list$_tab'),
                      padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 4, OpSpace.gutter, 28),
                      itemCount: list.length + (_tab == 1 && store.hasMorePast ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i >= list.length) {
                          // The end of the loaded page: fetch the next one, show the loader meanwhile.
                          store.loadMorePast();
                          return const OpLoadingPanel(height: 90, text: 'Loading more…');
                        }
                        return _BookingCard(b: list[i], store: store).staggerIn(i);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.b, required this.store});

  final Booking b;
  final PatientStore store;

  @override
  Widget build(BuildContext context) {
    final d = MockData.doctor(b.doctorId);
    final isToday = sameDay(b.date, DateTime.now()) && b.status == BookingStatus.upcoming;
    return OpCard(
      onTap: () => context.push('/booking/${b.id}'),
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date block on the left, like the stub of a ticket.
            Container(
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isToday ? OpColors.forest : (b.status == BookingStatus.upcoming ? OpColors.mint : OpColors.paperDeep),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(OpRadius.card)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isToday ? 'TODAY' : shortDay(b.date).toUpperCase(),
                      style: OpText.label.copyWith(color: isToday ? OpColors.mint : OpColors.inkSoft)),
                  Text('${b.date.day}', style: OpText.mono(28, weight: FontWeight.w600, color: isToday ? OpColors.paper : OpColors.ink)),
                  Text(monthShort(b.date), style: OpText.small.copyWith(fontSize: 12, color: isToday ? OpColors.mint : OpColors.inkSoft)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        DoctorPortrait.small(doctor: d, width: 34),
                        const SizedBox(width: 10),
                        Expanded(child: Text(d.name, style: OpText.bodyStrong.copyWith(fontSize: 17))),
                        Text('#${b.tokenLabel}', style: OpText.mono(16, weight: FontWeight.w600, color: b.emergency ? OpColors.alarm : OpColors.forest)),
                      ],
                    ),
                    Text(MockData.type(d.typeId).simple,
                        style: OpText.small.copyWith(fontSize: 13)),
                    const SizedBox(height: 6),
                    ClockRange(b.start, b.start + 1, size: 16),
                    const SizedBox(height: 8),
                    if (isToday) liveTag(store.live[b.id]) else bookingStatusTag(b),
                    if (b.status != BookingStatus.upcoming) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OpButton(
                          label: 'Book again'.tr,
                          expand: false,
                          height: 40,
                          kind: OpButtonKind.secondary,
                          onPressed: () => context.push('/book/${d.id}?hospital=${b.hospitalId}'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
