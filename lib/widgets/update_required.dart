import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/lang.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'op_button.dart';
import 'op_mark.dart';

/// Shown over the whole app when the server says this version is too old (for example, it still has an
/// old way of paying). Nothing else can be used until OPflow is updated.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  static const webApp = 'https://opflow-alpha.vercel.app';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OpColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(OpSpace.gutter),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OpMark(size: 56),
              const SizedBox(height: 22),
              Text('Please update OPflow'.tr, style: OpText.display),
              const SizedBox(height: 10),
              Text(
                'This version of the app is too old and cannot book or pay any more. Please install the latest OPflow. Your bookings are safe.'.tr,
                style: OpText.body.copyWith(color: OpColors.inkSoft),
              ),
              const SizedBox(height: 26),
              OpButton(
                label: 'Open OPflow on the web'.tr,
                icon: Icons.open_in_new,
                onPressed: () => launchUrl(Uri.parse(webApp), mode: LaunchMode.externalApplication),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
