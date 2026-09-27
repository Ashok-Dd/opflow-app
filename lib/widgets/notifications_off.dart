import 'package:flutter/material.dart';

import '../data/push.dart';
import '../l10n/lang.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'op_button.dart';

/// Shown only when the phone blocks OPflow's notifications: then "your turn is near" or "new booking" would never
/// pop up. One tap asks again or opens OPflow's notification settings; it checks again when the person comes back.
class NotificationsOffCard extends StatefulWidget {
  const NotificationsOffCard({super.key, required this.forDoctor, this.padding = const EdgeInsets.only(bottom: 16)});

  final bool forDoctor;
  final EdgeInsets padding;

  @override
  State<NotificationsOffCard> createState() => _NotificationsOffCardState();
}

class _NotificationsOffCardState extends State<NotificationsOffCard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Push.instance.checkAllowed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Push.instance.checkAllowed(); // back from Settings
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: Push.instance.allowed,
      builder: (context, ok, _) => AnimatedSize(
        duration: OpMotion.page,
        child: ok != false
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: widget.padding,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    color: OpColors.amberWash,
                    borderRadius: OpRadius.cardAll,
                    border: Border.all(color: OpColors.amber.withValues(alpha: 0.55)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notifications_off_outlined, color: OpColors.amber),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Notifications are off'.tr, style: OpText.bodyStrong),
                                const SizedBox(height: 2),
                                Text(
                                  widget.forDoctor
                                      ? 'You will not hear about new bookings, changes or emergency patients. Please turn them on.'.tr
                                      : 'You will not hear when your turn is near or if the doctor is late. Please turn them on.'.tr,
                                  style: OpText.small.copyWith(fontSize: 13.5, color: OpColors.ink),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OpButton(label: 'Turn on notifications'.tr, icon: Icons.notifications_active_outlined, height: 46, onPressed: Push.instance.turnOn),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
