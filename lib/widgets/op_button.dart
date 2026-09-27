import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'op_loader.dart';

/// Wraps any tappable thing: it shrinks a little when pressed and gives a light haptic tap.
class TapScale extends StatefulWidget {
  const TapScale({super.key, required this.child, required this.onTap, this.scale = 0.97, this.haptic = true, this.debounce = true});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  /// Ignore a second tap within 500 ms, so a quick double tap cannot open a screen twice or pay twice.
  /// Turn off for controls meant to be tapped fast (the − / + steppers).
  final bool debounce;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _down = false;
  Duration? _lastTap;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              // Frame time: real time on a phone, fake time in tests.
              final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
              final last = _lastTap;
              if (widget.debounce && last != null && now - last < const Duration(milliseconds: 500)) return;
              _lastTap = now;
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

enum OpButtonKind { primary, secondary, danger, dangerOutline, quiet, light }

/// The app's button. Rectangular, 56 high by default, always with words.
class OpButton extends StatelessWidget {
  const OpButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = OpButtonKind.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = OpSpace.buttonHeight,
  });

  const OpButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
  }) : kind = OpButtonKind.secondary;

  final String label;
  final VoidCallback? onPressed;
  final OpButtonKind kind;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (bg, fg, border) = switch (kind) {
      OpButtonKind.primary => (OpColors.forest, OpColors.paper, OpColors.forest),
      OpButtonKind.secondary => (OpColors.card, OpColors.forest, OpColors.line),
      OpButtonKind.danger => (OpColors.alarm, OpColors.paper, OpColors.alarm),
      OpButtonKind.dangerOutline => (OpColors.card, OpColors.alarm, OpColors.alarm),
      OpButtonKind.quiet => (OpColors.mint, OpColors.forest, OpColors.mint),
      OpButtonKind.light => (OpColors.paper, OpColors.forest, OpColors.paper),
    };
    final disabled = !enabled && !loading;

    final content = loading
        ? OpLoader.small(color: fg)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 20, color: disabled ? OpColors.inkFaint : fg), const SizedBox(width: 10)],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: OpText.button.copyWith(
                      color: disabled ? OpColors.inkFaint : fg, fontSize: height < 52 ? 15 : 17),
                ),
              ),
            ],
          );

    final box = AnimatedContainer(
      duration: OpMotion.quick,
      constraints: BoxConstraints(minHeight: height),
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: disabled ? OpColors.paperDeep : bg,
        borderRadius: OpRadius.controlAll,
        border: Border.all(color: disabled ? OpColors.paperDeep : border, width: 1.3),
        boxShadow: !disabled && (kind == OpButtonKind.primary || kind == OpButtonKind.danger) ? OpShadow.button : null,
      ),
      // Center with factors of 1 keeps the button as tall as its content (min 56), so it never
      // stretches to fill a bottom bar.
      child: Center(heightFactor: 1, widthFactor: expand ? null : 1, child: content),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: TapScale(onTap: enabled ? onPressed : null, child: box),
    );
  }
}

/// A small action with an icon on top of its word. Used for rows like "Directions · Call · Receipt".
class OpIconAction extends StatelessWidget {
  const OpIconAction({super.key, required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = onTap == null ? OpColors.inkFaint : (color ?? OpColors.forest);
    return TapScale(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: OpColors.card,
          borderRadius: OpRadius.controlAll,
          border: Border.all(color: OpColors.lineSoft),
          boxShadow: OpShadow.card,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: OpText.smallStrong.copyWith(fontSize: 13, color: onTap == null ? OpColors.inkFaint : OpColors.ink)),
          ],
        ),
      ),
    );
  }
}
