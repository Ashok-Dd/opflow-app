import 'package:flutter/material.dart';

/// OPflow colours. Same values as the landing site (`web/src/app/globals.css`).
abstract final class OpColors {
  static const paper = Color(0xFFF4F1E8);
  static const paperDeep = Color(0xFFE8E3D4);
  static const card = Color(0xFFFFFDF7);
  static const ink = Color(0xFF17221D);
  static const inkSoft = Color(0xFF4B574F);
  static const inkFaint = Color(0xFF7D867F);
  static const line = Color(0xFFD5CFBD);

  /// Card edges: the same crisp hairline as everything else (the first version's printed-form look).
  static const lineSoft = line;

  static const forest = Color(0xFF0B3A2E);
  static const pine = Color(0xFF0F5140);
  static const fern = Color(0xFF1A7550);
  static const leaf = Color(0xFF5CC27F);
  static const mint = Color(0xFFDCECE1);

  static const amber = Color(0xFF946300);
  static const amberWash = Color(0xFFF7EACB);
  static const led = Color(0xFFFFB21E);
  static const alarm = Color(0xFFC4291D);
  static const alarmWash = Color(0xFFFBE9E7);
}

/// Corners: small and exact, like a printed OPD form (the first version). Never big rounded corners.
abstract final class OpRadius {
  static const small = 3.0; // tags, badges, small tiles
  static const chip = 4.0;
  static const control = 4.0; // buttons, fields
  static const card = 6.0;
  static const sheet = 6.0; // bottom sheets, the tab bar
  static final smallAll = BorderRadius.circular(small);
  static final chipAll = BorderRadius.circular(chip);
  static final controlAll = BorderRadius.circular(control);
  static final cardAll = BorderRadius.circular(card);
  static final sheetTop = const BorderRadius.vertical(top: Radius.circular(sheet));
}

/// No soft shadows (the first version): cards and bars are drawn with hairline rules instead.
abstract final class OpShadow {
  static const card = <BoxShadow>[];
  static const raised = <BoxShadow>[];
  static const button = <BoxShadow>[];
  static const bar = <BoxShadow>[];
}

abstract final class OpSpace {
  static const gutter = 20.0;
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
