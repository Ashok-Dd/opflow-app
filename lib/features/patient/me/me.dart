import '../../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../mock/format.dart';
import '../../../state/patient_store.dart';
import '../../../state/session.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/language.dart';
import '../../../widgets/page_header.dart';

class MeTab extends ConsumerWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(patientProvider);
    final session = ref.watch(sessionProvider);
    final me = store.me;

    Future<void> logout() async {
      final ok = await confirmSheet(
        context,
        title: 'Log out?'.tr,
        text: 'You will need your mobile number and OTP to log in again.'.tr,
        yes: 'Yes, log out'.tr,
        icon: Icons.logout,
      );
      if (!ok || !context.mounted) return;
      session.logout();
      context.go('/who');
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 16, OpSpace.gutter, 32),
        children: [
          PageHeader(eyebrow: 'Your account'.tr, title: 'Me'.tr),
          const SizedBox(height: 18),
          OpCard(
            onTap: () => context.push('/me/details'),
            child: Row(
              children: [
                InitialsTile(text: me.name.isEmpty ? '?' : me.name[0], size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me.name, style: OpText.heading),
                      Text('{0} years · {1}'.trf([me.age, me.gender]), style: OpText.small),
                      if (session.phone.isNotEmpty) Text('+91 ${prettyPhone(session.phone)}', style: OpText.monoSmall),
                    ],
                  ),
                ),
                Text('Edit'.tr, style: OpText.smallStrong.copyWith(color: OpColors.fern)),
              ],
            ),
          ).staggerIn(0),
          const SizedBox(height: 22),
          const SectionLabel('Payments'),
          MenuGroup(children: [
            MenuRow(
              icon: Icons.receipt_long_outlined,
              title: 'Payments and money back'.tr,
              detail: 'All your payments'.tr,
              onTap: () => context.push('/me/payments'),
            ),
            MenuRow(
              icon: Icons.medical_services_outlined,
              title: 'My doctor suggestions'.tr,
              detail: 'Doctors OPflow suggested for you'.tr,
              onTap: () => context.push('/me/suggestions'),
            ),
          ]).staggerIn(1),
          const SizedBox(height: 22),
          const SectionLabel('App settings'),
          MenuGroup(children: [
            MenuRow(icon: Icons.notifications_none, title: 'Messages settings'.tr, detail: 'Reminders, late alerts, turn alerts'.tr, onTap: () => context.push('/me/alerts')),
            MenuRow(icon: Icons.place_outlined, title: 'My area'.tr, detail: session.place.isEmpty ? 'Not set'.tr : session.place, onTap: () => context.push('/me/place')),
            const LanguageRow(),
          ]).staggerIn(2),
          const SizedBox(height: 22),
          const SectionLabel('Help'),
          MenuGroup(children: [
            MenuRow(icon: Icons.help_outline, title: 'Help'.tr, detail: 'Common questions and call us'.tr, onTap: () => context.push('/me/help')),
            MenuRow(icon: Icons.gavel_outlined, title: 'Rules and privacy'.tr, onTap: () => context.push('/me/rules')),
          ]).staggerIn(3),
          const SizedBox(height: 22),
          MenuGroup(children: [
            MenuRow(icon: Icons.logout, title: 'Log out'.tr, color: OpColors.alarm, onTap: logout),
          ]).staggerIn(4),
          const SizedBox(height: 20),
          Center(child: Text('OPflow · version 1.0 (test build)'.tr, style: OpText.small.copyWith(fontSize: 12))),
        ],
      ),
    );
  }
}
