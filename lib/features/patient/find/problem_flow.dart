import '../../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../mock/data.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/op_button.dart';

/// "Who is this for?" after picking a health problem.
class ProblemWhoScreen extends StatelessWidget {
  const ProblemWhoScreen({super.key, required this.problemId});

  final String problemId;

  @override
  Widget build(BuildContext context) {
    final p = MockData.problem(problemId);
    void go(String who) => context.pushReplacement('/doctors?problem=${p.id}&who=$who');
    return OpPage(
      title: p.name,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          Icon(p.icon, size: 44, color: OpColors.fern).staggerIn(0),
          const SizedBox(height: 12),
          Text('Who is this for?'.tr, style: OpText.display).staggerIn(1),
          const SizedBox(height: 6),
          Text('Children and adults see different doctors.'.tr, style: OpText.body.copyWith(color: OpColors.inkSoft)).staggerIn(1),
          const SizedBox(height: 24),
          _BigChoice(icon: Icons.person_outline, title: 'Adult'.tr, text: '16 years and above'.tr, onTap: () => go('adult')).staggerIn(2),
          const SizedBox(height: 12),
          _BigChoice(icon: Icons.child_care, title: 'Child'.tr, text: 'Below 16 years'.tr, onTap: () => go('child')).staggerIn(3),
          const SizedBox(height: 24),
          InfoBox(
            icon: Icons.info_outline,
            child: Text('OPflow does not tell you the disease. It helps you find the right doctor.'.tr),
          ),
        ],
      ),
    );
  }
}

class _BigChoice extends StatelessWidget {
  const _BigChoice({required this.icon, required this.title, required this.text, required this.onTap});

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OpCard(
      onTap: onTap,
      borderColor: OpColors.ink,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: OpColors.mint, borderRadius: OpRadius.controlAll),
            child: Icon(icon, size: 34, color: OpColors.forest),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: OpText.heading),
                Text(text, style: OpText.small.copyWith(fontSize: 15)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, color: OpColors.forest),
        ],
      ),
    );
  }
}

/// Red warning for problems that may be an emergency.
class DangerScreen extends StatelessWidget {
  const DangerScreen({super.key, this.problemId});

  final String? problemId;

  String get _kind => switch (problemId) {
        'chest' => 'heart',
        'breathing' => 'breathing',
        'fits' => 'fits',
        'pregbleed' => 'pregnancy',
        _ => 'other',
      };

  @override
  Widget build(BuildContext context) {
    final p = problemId == null ? null : MockData.problem(problemId!);
    return Scaffold(
      backgroundColor: OpColors.alarmWash,
      appBar: AppBar(
        backgroundColor: OpColors.alarm,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Please read'.tr, style: OpText.heading.copyWith(color: Colors.white)),
        shape: const Border(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          const Icon(Icons.warning_amber_rounded, color: OpColors.alarm, size: 64)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.08, duration: 800.ms),
          const SizedBox(height: 12),
          Text('This may be an emergency.\nDo not wait.'.tr, style: OpText.display.copyWith(color: OpColors.alarm)),
          const SizedBox(height: 12),
          Text(
            p == null
                ? 'Some problems need a doctor right now, not a booking for later.'
                : '${p.name} can sometimes be serious. It may need a doctor right now, not a booking for later.',
            style: OpText.body.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 18),
          for (final line in const [
            'Very hard to breathe',
            'Strong chest pain that does not stop',
            'Fits, or the person does not wake up',
            'A lot of bleeding',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: OpColors.alarm),
                  const SizedBox(width: 10),
                  Expanded(child: Text(line, style: OpText.bodyStrong)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text('If you see any of these, call 108 now.'.tr, style: OpText.body),
          const SizedBox(height: 24),
          OpButton(
            label: 'Call 108 — Ambulance'.tr,
            icon: Icons.call,
            kind: OpButtonKind.danger,
            onPressed: () => showToast(context, 'Calling 108…'.tr, icon: Icons.call),
          ),
          const SizedBox(height: 10),
          OpButton(
            label: 'Nearest emergency hospitals'.tr,
            icon: Icons.local_hospital_outlined,
            kind: OpButtonKind.dangerOutline,
            onPressed: () => context.pushReplacement('/emergency/$_kind'),
          ),
          const SizedBox(height: 28),
          if (p != null)
            Center(
              child: TextButton(
                onPressed: () => context.pushReplacement('/problem/${p.id}'),
                child: Text('It is not serious. Show me doctors to book.'.tr),
              ),
            ),
        ],
      ),
    );
  }
}
