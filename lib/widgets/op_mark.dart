import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Paints the OPflow "OP" mark. Each part takes a 0–1 progress value so the mark can draw itself.
///
/// Same mark as the website logo: a thick O ring with a heartbeat line across it, then the P.
class OpMarkPainter extends CustomPainter {
  OpMarkPainter({
    this.ring = 1,
    this.stem = 1,
    this.bowl = 1,
    this.beat = 1,
    this.opacity = 1,
    this.color = OpColors.forest,
    this.beatColor = OpColors.fern,
  });

  final double ring;
  final double stem;
  final double bowl;
  /// Progress of the heartbeat line inside the O.
  final double beat;
  final double opacity;
  final Color color;
  final Color beatColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final dx = (size.width - s) / 2;
    final dy = (size.height - s) / 2;
    canvas.translate(dx, dy);

    final stroke = s * 0.11;
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // O ring.
    final oCenter = Offset(s * 0.3, s * 0.5);
    final oRadius = s * 0.215;
    if (ring > 0) {
      canvas.drawArc(Rect.fromCircle(center: oCenter, radius: oRadius), -math.pi / 2, math.pi * 2 * ring, false,
          paint);
    }

    // P stem.
    final stemX = s * 0.64;
    final top = s * 0.285;
    final bottom = s * 0.8;
    if (stem > 0) {
      canvas.drawLine(Offset(stemX, top), Offset(stemX, top + (bottom - top) * stem), paint);
    }

    // P bowl.
    if (bowl > 0) {
      final bowlPath = Path()
        ..moveTo(stemX, top)
        ..lineTo(s * 0.74, top)
        ..arcToPoint(Offset(s * 0.74, s * 0.555), radius: Radius.circular(s * 0.135))
        ..lineTo(stemX, s * 0.555);
      _drawPartial(canvas, bowlPath, bowl, paint);
    }

    // Heartbeat across the O.
    if (beat > 0) {
      final r = oRadius;
      final c = oCenter;
      // Stays inside the ring (the inner edge is at about 0.74 × r).
      final line = Path()
        ..moveTo(c.dx - r * 0.7, c.dy)
        ..lineTo(c.dx - r * 0.3, c.dy)
        ..lineTo(c.dx - r * 0.17, c.dy + r * 0.22)
        ..lineTo(c.dx - r * 0.01, c.dy - r * 0.5)
        ..lineTo(c.dx + r * 0.16, c.dy + r * 0.44)
        ..lineTo(c.dx + r * 0.3, c.dy)
        ..lineTo(c.dx + r * 0.7, c.dy);
      final beatPaint = Paint()
        ..color = beatColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.042
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      _drawPartial(canvas, line, beat.clamp(0, 1), beatPaint);
    }
  }

  void _drawPartial(Canvas canvas, Path path, double t, Paint paint) {
    for (final PathMetric metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(OpMarkPainter old) =>
      old.ring != ring ||
      old.stem != stem ||
      old.bowl != bowl ||
      old.beat != beat ||
      old.opacity != opacity ||
      old.color != color ||
      old.beatColor != beatColor;
}

/// A still OP mark, used in headers and the about screen.
class OpMark extends StatelessWidget {
  const OpMark({super.key, this.size = 40, this.color = OpColors.forest});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: size, child: CustomPaint(painter: OpMarkPainter(color: color)));
  }
}

/// Maps [t] in [start, end] to 0–1 with an ease-out curve.
double opPhase(double t, double start, double end) {
  if (t <= start) return 0;
  if (t >= end) return 1;
  return Curves.easeOutCubic.transform((t - start) / (end - start));
}
