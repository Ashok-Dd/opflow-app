import '../l10n/lang.dart';
import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';

/// The dark LED board from the hospital wall: "Now seeing" and "Your token".
class TokenBoard extends StatelessWidget {
  const TokenBoard({super.key, required this.nowSeeing, this.yourToken, this.compact = false, this.nowLabel = 'NOW SEEING'});

  final int? nowSeeing;
  final int? yourToken;
  final bool compact;
  final String nowLabel;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 40.0 : 56.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: compact ? 14 : 20),
      decoration: BoxDecoration(
        color: OpColors.forest,
        borderRadius: OpRadius.cardAll,
        border: Border.all(color: const Color(0xFF062A21), width: 2),
      ),
      child: Row(
        children: [
          Expanded(child: _Cell(label: nowLabel, value: nowSeeing, size: size, lit: true)),
          if (yourToken != null) ...[
            Container(width: 1, height: size + 24, color: OpColors.pine),
            Expanded(child: _Cell(label: 'YOUR TOKEN'.tr, value: yourToken, size: size, lit: false)),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, required this.size, required this.lit});

  final String label;
  final int? value;
  final double size;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final color = lit ? OpColors.led : OpColors.paper;
    return Column(
      children: [
        Text(label, style: OpText.label.copyWith(color: OpColors.mint.withValues(alpha: 0.75))),
        const SizedBox(height: 6),
        FlipNumber(
          value: value,
          style: OpText.mono(size, weight: FontWeight.w600, color: color).copyWith(
            shadows: lit ? [Shadow(color: OpColors.led.withValues(alpha: 0.45), blurRadius: 14)] : null,
          ),
        ),
      ],
    );
  }
}

/// A number that flips (slides down and fades) when it changes, like a token display.
class FlipNumber extends StatelessWidget {
  const FlipNumber({super.key, required this.value, required this.style, this.pad = 2});

  final int? value;
  final TextStyle style;
  final int pad;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '--' : value.toString().padLeft(pad, '0');
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) {
          final incoming = child.key == ValueKey(text);
          final offset = Tween(begin: Offset(0, incoming ? -0.6 : 0.6), end: Offset.zero).animate(anim);
          return FadeTransition(opacity: anim, child: SlideTransition(position: offset, child: child));
        },
        child: Text(text, key: ValueKey(text), style: style),
      ),
    );
  }
}
