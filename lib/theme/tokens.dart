import 'package:flutter/material.dart';

/// OPflow colours. Same values as the landing site (`web/src/app/globals.css`).
abstract final class OpColors {
  static const paper = Color(0xFFF4F1E8);
  static const paperDeep = Color(0xFFE8E3D4);
  static const card = Color(0xFFFFFEFB);
  static const ink = Color(0xFF17221D);
  static const inkSoft = Color(0xFF4B574F);
  static const inkFaint = Color(0xFF7D867F);
  static const line = Color(0xFFD5CFBD);

  /// Softer hairline for card edges (the shadow does most of the work).
  static const lineSoft = Color(0xFFE9E3D5);

  static const forest = Color(0xFF1F7A5C);
  static const pine = Color(0xFF17654B);
  static const fern = Color(0xFF1A6F52);
  static const leaf = Color(0xFF8ED6A6);
  static const mint = Color(0xFFDCECE1);

  static const amber = Color(0xFF946300);
  static const amberWash = Color(0xFFF7EACB);
  static const led = Color(0xFFFFB21E);
  static const alarm = Color(0xFFC4291D);
  static const alarmWash = Color(0xFFFBE9E7);
}

/// Corners: soft and friendly, the same few sizes everywhere.
abstract final class OpRadius {
  static const small = 10.0; // tags, badges, small tiles
  static const chip = 12.0;
  static const control = 14.0; // buttons, fields
  static const card = 18.0;
  static const sheet = 24.0; // bottom sheets, the tab bar
  static final smallAll = BorderRadius.circular(small);
  static final chipAll = BorderRadius.circular(chip);
  static final controlAll = BorderRadius.circular(control);
  static final cardAll = BorderRadius.circular(card);
  static final sheetTop = const BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Soft, layered shadows (a tight contact shadow + a wide ambient one), tinted with the forest green.
abstract final class OpShadow {
  static const card = [
    BoxShadow(color: Color(0x0D1F7A5C), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x121F7A5C), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -4),
  ];
  static const raised = [
    BoxShadow(color: Color(0x141F7A5C), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x1F1F7A5C), blurRadius: 28, offset: Offset(0, 12), spreadRadius: -6),
  ];
  static const button = [
    BoxShadow(color: Color(0x331F7A5C), blurRadius: 14, offset: Offset(0, 6), spreadRadius: -4),
  ];
  static const bar = [
    BoxShadow(color: Color(0x141F7A5C), blurRadius: 24, offset: Offset(0, -4), spreadRadius: -6),
  ];
}

abstract final class OpSpace {
  static const gutter = 22.0;
  static const buttonHeight = 56.0;
}

abstract final class OpMotion {
  static const page = Duration(milliseconds: 250);
  static const quick = Duration(milliseconds: 180);
  static const curve = Cubic(0.2, 0.7, 0.2, 1);

  /// True when the phone's "remove animations" setting is on. Set once per frame in `main.dart`.
  static bool reduced = false;

  /// How long fake "network" calls take in the mock build.
  static const fakeShort = Duration(milliseconds: 800);
  static const fakeLong = Duration(milliseconds: 1400);
}
