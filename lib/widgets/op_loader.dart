import '../l10n/lang.dart';
import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'op_mark.dart';

/// The OPflow loader. It replaces every spinner in the app.
///
/// A one-second loop: the O ring draws, the P follows, the heartbeat runs across the O, then it
/// fades and starts again. With "remove animations" turned on it shows a still mark instead.
class OpLoader extends StatefulWidget {
  const OpLoader({super.key, this.size = 56, this.color = OpColors.forest, this.beatColor = OpColors.fern});

  /// Small version for use inside buttons.
  const OpLoader.small({super.key, this.color = OpColors.paper, this.beatColor = OpColors.leaf}) : size = 26;

  final double size;
  final Color color;
  final Color beatColor;

  @override
  State<OpLoader> createState() => _OpLoaderState();
}

class _OpLoaderState extends State<OpLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 0.8;
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading'.tr,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final fade = 1 - opPhase(t, 0.86, 1.0);
            return CustomPaint(
              painter: OpMarkPainter(
                ring: opPhase(t, 0.0, 0.38),
                stem: opPhase(t, 0.2, 0.44),
                bowl: opPhase(t, 0.36, 0.62),
                beat: opPhase(t, 0.5, 0.84),
                opacity: fade,
                color: widget.color,
                beatColor: widget.beatColor,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Full-screen loading layer with a short message ("Checking your payment…").
class OpLoadingScreen extends StatelessWidget {
  const OpLoadingScreen({super.key, required this.message, this.detail});

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: OpColors.paper,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OpLoader(size: 88),
              const SizedBox(height: 24),
              Text(message, style: OpText.heading, textAlign: TextAlign.center),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(detail!, style: OpText.small, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows [OpLoadingScreen] over everything while [task] runs, then removes it.
///
/// Never throws: if [task] fails, the error is reported, a calm message is shown, and null is returned.
/// A task that takes longer than [timeout] is treated as failed.
/// [runWithLoader] for a step with no answer: true only when it really worked (a failure has already shown
/// the red note), so "Saved" / "Cancelled" is never shown for something that did not happen.
Future<bool> runStep(BuildContext context, String message, Future<void> Function() task, {String? detail}) async {
  final ok = await runWithLoader<bool>(context, message, () async {
    await task();
    return true;
  }, detail: detail);
  return ok == true;
}

Future<T?> runWithLoader<T>(
  BuildContext context,
  String message,
  Future<T> Function() task, {
  String? detail,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return guard(task, where: 'runWithLoader($message)');
  final entry = OverlayEntry(
    builder: (_) => Material(
      type: MaterialType.transparency,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: OpMotion.quick,
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: OpLoadingScreen(message: message, detail: detail),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    return await task().timeout(timeout);
  } catch (e, s) {
    ErrorReporter.report(e, s, where: 'runWithLoader($message)');
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(
      backgroundColor: OpColors.alarm,
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(friendlyMessage(e))),
        ],
      ),
    ));
    return null;
  } finally {
    entry.remove();
  }
}

/// The OP loader with a short line of text, for a part of a screen that is still loading.
class OpLoadingPanel extends StatelessWidget {
  const OpLoadingPanel({super.key, this.text = 'Loading…', this.height = 180, this.hint});

  final String text;
  final String? hint;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OpLoader(size: 44),
            const SizedBox(height: 12),
            Text(text.tr, style: OpText.smallStrong.copyWith(color: OpColors.inkSoft), textAlign: TextAlign.center),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(hint!.tr, style: OpText.small.copyWith(fontSize: 12.5), textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
