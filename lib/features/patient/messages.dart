import '../../l10n/lang.dart';
import '../../widgets/op_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../mock/format.dart';
import '../../mock/models.dart';
import '../../state/patient_store.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  (IconData, Color) _look(MessageKind k) => switch (k) {
        MessageKind.booked => (Icons.check_circle_outline, OpColors.fern),
        MessageKind.reminder => (Icons.alarm, OpColors.forest),
        MessageKind.late => (Icons.schedule, OpColors.amber),
        MessageKind.turn => (Icons.directions_walk, OpColors.fern),
        MessageKind.cancelled => (Icons.event_busy_outlined, OpColors.alarm),
        MessageKind.changed => (Icons.event_repeat, OpColors.forest),
        MessageKind.refund => (Icons.currency_rupee, OpColors.fern),
        MessageKind.system => (Icons.info_outline, OpColors.forest),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(patientProvider);
    final list = store.messages;
    return OpPage(
      title: 'Messages'.tr,
      actions: [
        if (store.unread > 0) TextButton(onPressed: store.markAllRead, child: Text('Mark all read'.tr)),
        const SizedBox(width: 8),
      ],
      body: list.isEmpty && store.isLoading
          ? const Center(child: OpLoadingPanel(text: 'Loading your messages…', height: 260))
          : list.isEmpty
          ? Center(child: SingleChildScrollView(child: EmptyState(emoji: '📭', icon: Icons.notifications_none, title: 'No messages', text: 'Booking updates will show here.')))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length + (store.hasMoreMessages ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(indent: 72),
              itemBuilder: (context, i) {
                if (i >= list.length) {
                  // Older messages: fetched when the list reaches its end.
                  store.loadMoreMessages();
                  return const OpLoadingPanel(height: 90, text: 'Loading more…');
                }
                final m = list[i];
                final (icon, color) = _look(m.kind);
                return InkWell(
                  onTap: () {
                    store.markRead(m);
                    if (m.bookingId != null) context.push('/booking/${m.bookingId}');
                  },
                  child: Container(
                    color: m.unread ? OpColors.mint.withValues(alpha: 0.45) : null,
                    padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 14, OpSpace.gutter, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: OpColors.card, borderRadius: OpRadius.controlAll, border: Border.all(color: OpColors.line)),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(m.title.tr, style: OpText.bodyStrong)),
                                  Text(agoLabel(m.time), style: OpText.small.copyWith(fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(m.body, style: OpText.small.copyWith(fontSize: 14.5, color: OpColors.inkSoft)),
                            ],
                          ),
                        ),
                        if (m.unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(color: OpColors.alarm, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                  ),
                ).staggerIn(i);
              },
            ),
    );
  }
}
