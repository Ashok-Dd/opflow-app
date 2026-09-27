import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Friendly drawn portraits for the "Who are you?" screen: a doctor in a white coat with a stethoscope, and a
/// patient holding their OPflow token slip. Drawn in code (sharp at any size, in the app's own colours).
///
/// [t] (0–1, repeating) gives a little life: the doctor's stethoscope beats, the patient's token glows.
class RoleArt extends StatelessWidget {
  const RoleArt.doctor({super.key, this.t = 0}) : doctor = true;
  const RoleArt.patient({super.key, this.t = 0}) : doctor = false;

  final bool doctor;
  final double t;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: doctor ? _DoctorPainter(t) : _PatientPainter(t), size: Size.infinite);
  }
}

const _skin = Color(0xFFD69E74);
const _skinShade = Color(0xFFC0865D);
const _hair = Color(0xFF1E2622);

/// The shared parts: arched window behind, neck, head, face.
abstract class _Figure extends CustomPainter {
  _Figure(this.t);

  final double t;
  late double u;

  Offset p(double x, double y) => Offset(x * u, y * u);

  Paint fill(Color c) => Paint()..color = c;
  Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * u
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void backdrop(Canvas c, Color color, Color rule) {
    // An arched hospital window, with a hairline inner frame.
    final arch = Path()
      ..moveTo(12 * u, 100 * u)
      ..lineTo(12 * u, 44 * u)
      ..arcToPoint(p(88, 44), radius: Radius.circular(38 * u))
      ..lineTo(88 * u, 100 * u)
      ..close();
    c.drawPath(arch, fill(color));
    final inner = Path()
      ..moveTo(17 * u, 100 * u)
      ..lineTo(17 * u, 44 * u)
      ..arcToPoint(p(83, 44), radius: Radius.circular(33 * u))
      ..lineTo(83 * u, 100 * u);
    c.drawPath(inner, stroke(rule, 0.7));
  }

  void head(Canvas c, {required Path hair, bool smile = true}) {
    // Neck with a soft shadow under the chin.
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(44.5 * u, 54 * u, 55.5 * u, 68 * u), Radius.circular(3 * u)), fill(_skin));
    c.drawRect(Rect.fromLTRB(44.5 * u, 58 * u, 55.5 * u, 61 * u), fill(_skinShade.withValues(alpha: 0.55)));
    // Ears, face.
    c.drawCircle(p(36.2, 46), 2.8 * u, fill(_skinShade));
    c.drawCircle(p(63.8, 46), 2.8 * u, fill(_skinShade));
    c.drawOval(Rect.fromCenter(center: p(50, 45), width: 27 * u, height: 29 * u), fill(_skin));
    c.drawPath(hair, fill(_hair));
    // Eyes, a calm smile, a touch of cheek.
    c.drawCircle(p(44.6, 46.5), 1.35 * u, fill(_hair));
    c.drawCircle(p(55.4, 46.5), 1.35 * u, fill(_hair));
    if (smile) c.drawArc(Rect.fromCenter(center: p(50, 51.2), width: 8 * u, height: 5 * u), 0.15, math.pi - 0.3, false, stroke(_hair, 1.1));
    c.drawCircle(p(41.5, 51), 2.2 * u, fill(const Color(0xFFE08A7A).withValues(alpha: 0.35)));
    c.drawCircle(p(58.5, 51), 2.2 * u, fill(const Color(0xFFE08A7A).withValues(alpha: 0.35)));
  }

  @override
  bool shouldRepaint(_Figure old) => old.t != t;
}

class _DoctorPainter extends _Figure {
  _DoctorPainter(super.t);

  @override
  void paint(Canvas c, Size size) {
    u = size.shortestSide / 100;
    c.translate((size.width - 100 * u) / 2, (size.height - 100 * u) / 2);
    c.clipRect(Rect.fromLTWH(0, 0, 100 * u, 100 * u));
    backdrop(c, OpColors.mint, OpColors.fern.withValues(alpha: 0.25));

    // Shirt and tie under the coat.
    c.drawPath(Path()..addPolygon([p(40, 66), p(60, 66), p(56, 100), p(44, 100)], true), fill(const Color(0xFFBFD9EA)));
    c.drawPath(Path()..addPolygon([p(48.4, 68), p(51.6, 68), p(52.6, 86), p(50, 90), p(47.4, 86)], true), fill(OpColors.pine));
    // White coat: shoulders and two lapels open over the shirt.
    final coatL = Path()
      ..moveTo(16 * u, 100 * u)
      ..lineTo(16 * u, 84 * u)
      ..quadraticBezierTo(16 * u, 69 * u, 32 * u, 66 * u)
      ..lineTo(42 * u, 64.5 * u)
      ..lineTo(47 * u, 100 * u)
      ..close();
    final coatR = Path()
      ..moveTo(84 * u, 100 * u)
      ..lineTo(84 * u, 84 * u)
      ..quadraticBezierTo(84 * u, 69 * u, 68 * u, 66 * u)
      ..lineTo(58 * u, 64.5 * u)
      ..lineTo(53 * u, 100 * u)
      ..close();
    for (final coat in [coatL, coatR]) {
      c.drawPath(coat, fill(OpColors.card));
      c.drawPath(coat, stroke(OpColors.forest.withValues(alpha: 0.55), 0.9));
    }
    // Lapel folds.
    c.drawLine(p(42, 64.5), p(38, 76), stroke(OpColors.forest.withValues(alpha: 0.35), 0.8));
    c.drawLine(p(58, 64.5), p(62, 76), stroke(OpColors.forest.withValues(alpha: 0.35), 0.8));
    // Pocket with the red cross, and a pen.
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(64 * u, 82 * u, 75 * u, 92 * u), Radius.circular(1.2 * u)), stroke(OpColors.forest.withValues(alpha: 0.4), 0.8));
    c.drawLine(p(67, 79), p(67, 84), stroke(OpColors.fern, 1.6));
    c.drawLine(p(26.5, 84), p(32.5, 84), stroke(OpColors.alarm, 2));
    c.drawLine(p(29.5, 81), p(29.5, 87), stroke(OpColors.alarm, 2));

    final hair = Path()
      ..moveTo(36.4 * u, 45 * u)
      ..quadraticBezierTo(35.5 * u, 30 * u, 50 * u, 29.5 * u)
      ..quadraticBezierTo(64.5 * u, 30 * u, 63.6 * u, 44 * u)
      ..quadraticBezierTo(60 * u, 36.5 * u, 51 * u, 37.5 * u)
      ..quadraticBezierTo(42 * u, 36 * u, 36.4 * u, 45 * u)
      ..close();
    head(c, hair: hair);

    // Stethoscope round the neck, down to the chest piece, which beats.
    final tube = stroke(const Color(0xFF2B3A33), 1.9);
    c.drawPath(
      Path()
        ..moveTo(43 * u, 63 * u)
        ..cubicTo(37 * u, 70 * u, 37 * u, 80 * u, 43 * u, 84 * u),
      tube,
    );
    c.drawPath(
      Path()
        ..moveTo(57 * u, 63 * u)
        ..cubicTo(63 * u, 70 * u, 60 * u, 80 * u, 55 * u, 84 * u),
      tube,
    );
    c.drawPath(
      Path()
        ..moveTo(43 * u, 84 * u)
        ..quadraticBezierTo(49 * u, 88 * u, 55 * u, 84 * u),
      tube,
    );
    final beat = 1 + 0.12 * math.sin(t * math.pi * 2).abs();
    c.drawLine(p(49, 87), p(49, 91), tube);
    c.drawCircle(p(49, 93.5), 3.6 * u * beat, fill(OpColors.fern));
    c.drawCircle(p(49, 93.5), 3.6 * u * beat, stroke(const Color(0xFF2B3A33), 1.2));
    c.drawCircle(p(49, 93.5), 1.3 * u, fill(OpColors.leaf));
  }
}

class _PatientPainter extends _Figure {
  _PatientPainter(super.t);

  @override
  void paint(Canvas c, Size size) {
    u = size.shortestSide / 100;
    c.translate((size.width - 100 * u) / 2, (size.height - 100 * u) / 2);
    c.clipRect(Rect.fromLTWH(0, 0, 100 * u, 100 * u));
    backdrop(c, OpColors.amberWash, OpColors.amber.withValues(alpha: 0.25));

    // A soft kurta with a round collar.
    final body = Path()
      ..moveTo(16 * u, 100 * u)
      ..lineTo(16 * u, 84 * u)
      ..quadraticBezierTo(16 * u, 68 * u, 34 * u, 65.5 * u)
      ..lineTo(66 * u, 65.5 * u)
      ..quadraticBezierTo(84 * u, 68 * u, 84 * u, 84 * u)
      ..lineTo(84 * u, 100 * u)
      ..close();
    c.drawPath(body, fill(OpColors.fern));
    c.drawArc(Rect.fromCenter(center: p(50, 65), width: 16 * u, height: 9 * u), 0, math.pi, false, stroke(OpColors.pine, 1.6));
    c.drawLine(p(50, 69.5), p(50, 78), stroke(OpColors.pine, 1.2));

    // Hair with a side parting and a bun.
    c.drawCircle(p(62.5, 33.5), 5.2 * u, fill(_hair));
    final hair = Path()
      ..moveTo(36.4 * u, 47 * u)
      ..quadraticBezierTo(34.5 * u, 29.5 * u, 50 * u, 29.5 * u)
      ..quadraticBezierTo(65.5 * u, 29.5 * u, 63.6 * u, 47 * u)
      ..quadraticBezierTo(62 * u, 38 * u, 55 * u, 36 * u)
      ..quadraticBezierTo(47 * u, 40 * u, 38.5 * u, 39 * u)
      ..quadraticBezierTo(37 * u, 42 * u, 36.4 * u, 47 * u)
      ..close();
    head(c, hair: hair);

    // The OPflow token slip, held up: forest card, glowing LED number.
    final glow = 0.75 + 0.25 * math.sin(t * math.pi * 2);
    final slip = RRect.fromRectAndRadius(Rect.fromLTRB(53 * u, 72 * u, 81 * u, 96 * u), Radius.circular(2.6 * u));
    c.drawRRect(slip.shift(Offset(0, 1.2 * u)), fill(Colors.black.withValues(alpha: 0.12)));
    c.drawRRect(slip, fill(OpColors.forest));
    c.drawLine(p(56, 77.5), p(78, 77.5), stroke(OpColors.mint.withValues(alpha: 0.45), 0.7));
    final tp = TextPainter(
      text: TextSpan(
        text: '07',
        style: TextStyle(fontFamily: 'IBMPlexMono', fontWeight: FontWeight.w600, fontSize: 12.5 * u, color: OpColors.led.withValues(alpha: glow), height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(67 * u - tp.width / 2, 80.5 * u));
    // Hands holding the slip.
    c.drawOval(Rect.fromCenter(center: p(53.5, 85), width: 6 * u, height: 7.5 * u), fill(_skin));
    c.drawOval(Rect.fromCenter(center: p(80.5, 88), width: 5.5 * u, height: 7 * u), fill(_skin));
  }
}
