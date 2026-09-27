import '../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/language.dart';
import '../../widgets/op_button.dart';
import '../../widgets/op_mark.dart';
import '../../widgets/role_art.dart';

/// "Who are you?" — patient or doctor, as two big drawn cards side by side. Emergency help is reachable here
/// without logging in.
class WhoScreen extends StatelessWidget {
  const WhoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 18, OpSpace.gutter, 24),
          children: [
            Row(
              children: [
                const OpMark(size: 38),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('OPflow'.tr,
                      maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: OpText.title.copyWith(color: OpColors.forest, fontSize: 22)),
                ),
                const SizedBox(width: 8),
                const LanguageToggle(),
              ],
            ),
            const SizedBox(height: 34),
            Row(
              children: [
                Container(width: 22, height: 2, color: OpColors.fern),
                const SizedBox(width: 8),
                Flexible(child: Text('NAMASTE'.tr, style: OpText.label.copyWith(color: OpColors.fern, letterSpacing: 2))),
              ],
            ).staggerIn(0),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                // Telugu says the name first: "OPflow కి స్వాగతం".
                children: Lang.instance.isTelugu
                    ? [
                        TextSpan(text: 'OPflow'.tr, style: const TextStyle(color: OpColors.forest, fontStyle: FontStyle.italic)),
                        const TextSpan(text: '\n'),
                        const TextSpan(text: 'కి స్వాగతం'),
                      ]
                    : [
                        TextSpan(text: 'Welcome to'.tr),
                        const TextSpan(text: '\n'),
                        TextSpan(text: 'OPflow'.tr, style: const TextStyle(color: OpColors.forest, fontStyle: FontStyle.italic)),
                      ],
              ),
              style: OpText.display.copyWith(fontSize: 42, height: 1.05),
            ).staggerIn(1),
            const SizedBox(height: 12),
            Text('Who are you? Pick one to begin.'.tr, style: OpText.lead.copyWith(color: OpColors.inkSoft)).staggerIn(2),
            const SizedBox(height: 26),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _RoleCard(
                      art: (t) => RoleArt.patient(t: t),
                      tag: 'PATIENT'.tr,
                      title: 'I am a patient'.tr,
                      text: 'Book a doctor near me'.tr,
                      onTap: () => context.push('/login'),
                    ).animate().fadeIn(delay: 180.ms, duration: 380.ms).slideY(begin: 0.08, curve: OpMotion.curve),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RoleCard(
                      art: (t) => RoleArt.doctor(t: t),
                      tag: 'DOCTOR'.tr,
                      title: 'I am a doctor'.tr,
                      text: 'Run my OPD and see my bookings'.tr,
                      onTap: () => context.push('/doctor-login'),
                    ).animate().fadeIn(delay: 280.ms, duration: 380.ms).slideY(begin: 0.08, curve: OpMotion.curve),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Right patient, right doctor, at the right time.'.tr,
              textAlign: TextAlign.center,
              style: OpText.body.copyWith(fontFamily: 'Newsreader', fontStyle: FontStyle.italic, color: OpColors.inkSoft, fontSize: 16.5),
            ).staggerIn(5),
            const SizedBox(height: 22),
            TapScale(
              onTap: () => context.push('/emergency'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: OpColors.alarmWash,
                  borderRadius: OpRadius.cardAll,
                  border: Border.all(color: OpColors.alarm.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: OpColors.alarm, borderRadius: OpRadius.controlAll),
                      child: const Icon(Icons.emergency_outlined, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Need emergency help?'.tr, style: OpText.bodyStrong.copyWith(color: OpColors.alarm)),
                          Text('Tap here. No login needed.'.tr, style: OpText.small),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: OpColors.alarm),
                  ],
                ),
              ),
            ).staggerIn(6),
          ],
        ),
      ),
    );
  }
}

/// One side: the drawn portrait in its arched window, then who it is for, then "Continue".
class _RoleCard extends StatefulWidget {
  const _RoleCard({required this.art, required this.tag, required this.title, required this.text, required this.onTap});

  final Widget Function(double t) art;
  final String tag;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  bool _down = false;

  @override
  void initState() {
    super.initState();
    if (!OpMotion.reduced) _life.repeat();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.text}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: OpMotion.quick,
          child: AnimatedContainer(
            duration: OpMotion.quick,
            decoration: BoxDecoration(
              color: OpColors.card,
              borderRadius: OpRadius.cardAll,
              border: Border.all(color: _down ? OpColors.forest : OpColors.lineSoft, width: _down ? 1.6 : 1),
              boxShadow: OpShadow.card,
            ),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 0.8, // the pictures are portrait (4 : 5)
                  child: ClipRRect(
                    borderRadius: OpRadius.controlAll,
                    child: AnimatedBuilder(
                      animation: _life,
                      builder: (context, _) => widget.art(_life.value),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.tag, style: OpText.label.copyWith(fontSize: 10.5, color: OpColors.fern, letterSpacing: 1.6)),
                      const SizedBox(height: 4),
                      Text(widget.title, style: OpText.heading.copyWith(fontSize: 19, height: 1.15)),
                      const SizedBox(height: 4),
                      Text(widget.text, style: OpText.small.copyWith(fontSize: 13.5, height: 1.3)),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 12),
                Container(
                  height: 42,
                  decoration: BoxDecoration(color: OpColors.forest, borderRadius: OpRadius.controlAll),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Continue'.tr,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: OpText.smallStrong.copyWith(color: OpColors.paper, fontSize: 14.5)),
                      ),
                      const Icon(Icons.arrow_forward_rounded, color: OpColors.leaf, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
