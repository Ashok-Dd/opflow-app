import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A paper OPD slip: two parts split by a dashed tear line with half-round notches.
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.top, required this.bottom, this.color = OpColors.card, this.notchColor});

  final Widget top;
  final Widget bottom;
  final Color color;

  /// Colour of the notches; should match what the ticket sits on.
  final Color? notchColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: OpRadius.cardAll,
        border: Border.all(color: OpColors.lineSoft),
        boxShadow: OpShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 14), child: top),
          TearLine(notchColor: notchColor ?? OpColors.paper),
          Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 18), child: bottom),
        ],
      ),
    );
  }
}

class TearLine extends StatelessWidget {
  const TearLine({super.key, this.notchColor = OpColors.paper});

  final Color notchColor;

  @override
  Widget build(BuildContext context) {
    Widget notch() => Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: notchColor,
            shape: BoxShape.circle,
            border: Border.all(color: OpColors.lineSoft),
          ),
        );
    return SizedBox(
      height: 20,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: CustomPaint(painter: DashedLinePainter()),
            ),
          ),
          Positioned(left: -10, top: 0, child: notch()),
          Positioned(right: -10, top: 0, child: notch()),
        ],
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  DashedLinePainter({this.color = OpColors.line, this.dash = 6, this.gap = 5});

  final Color color;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter old) => old.color != color;
}
