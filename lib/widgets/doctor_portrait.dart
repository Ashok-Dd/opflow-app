import '../l10n/lang.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../mock/data.dart';
import '../mock/models.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';

/// The doctor's picture in a 4:5 portrait frame.
///
/// Shows the uploaded photo when there is one; otherwise an engraved-style monogram: mint field,
/// fine diagonal lines, serif initials, and a forest band with the type-of-doctor icon.
class DoctorPortrait extends StatelessWidget {
  const DoctorPortrait({super.key, required this.doctor, this.width = 104, this.seal = true, this.band = true});

  /// Small square-ish thumbnail for lists and headers.
  const DoctorPortrait.small({super.key, required this.doctor, this.width = 48}) : seal = false, band = false;

  final Doctor doctor;
  final double width;
  final bool seal;
  final bool band;

  double get height => width * 1.25;

  @override
  Widget build(BuildContext context) {
    final photo = doctor.photoPath;
    final r = BorderRadius.circular(width < 64 ? width * 0.22 : OpRadius.card);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: r,
                border: Border.all(color: OpColors.forest.withValues(alpha: 0.10)),
                color: OpColors.mint,
              ),
              child: doctor.photoUrl != null && photo == null
                  ? Image.network(doctor.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _Monogram(doctor: doctor, band: band))
                  : photo != null
                  ? (kIsWeb
                      ? Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, _, _) => _Monogram(doctor: doctor, band: band))
                      : Image.file(File(photo), fit: BoxFit.cover, errorBuilder: (_, _, _) => _Monogram(doctor: doctor, band: band)))
                  : _Monogram(doctor: doctor, band: band),
            ),
          ),
          if (seal)
            Positioned(
              right: -6,
              top: -6,
              child: VerifiedSeal(size: width < 90 ? 22 : 28),
            ),
        ],
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.doctor, required this.band});

  final Doctor doctor;
  final bool band;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final type = MockData.type(doctor.typeId);
      return Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HatchPainter())),
          // Thin inner frame, like an engraved plate.
          Positioned.fill(
            child: Container(
              margin: EdgeInsets.all(w * 0.06),
              decoration: BoxDecoration(
                border: Border.all(color: OpColors.forest.withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(w * 0.12),
              ),
            ),
          ),
          Align(
            alignment: band ? const Alignment(0, -0.2) : Alignment.center,
            child: Text(
              doctor.initials,
              style: OpText.display.copyWith(fontSize: w * 0.36, color: OpColors.forest, letterSpacing: w * 0.01, height: 1),
            ),
          ),
          if (band)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: w * 0.24,
                color: OpColors.forest,
                alignment: Alignment.center,
                child: Icon(type.icon, color: OpColors.mint, size: w * 0.14),
              ),
            ),
        ],
      );
    });
  }
}

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = OpColors.forest.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const gap = 7.0;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Amber rosette: "Checked by OPflow".
class VerifiedSeal extends StatelessWidget {
  const VerifiedSeal({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Checked by OPflow'.tr,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: OpColors.paper,
          shape: BoxShape.circle,
          border: Border.all(color: OpColors.amber, width: 1.5),
        ),
        child: Icon(Icons.verified, size: size * 0.66, color: OpColors.amber),
      ),
    );
  }
}
