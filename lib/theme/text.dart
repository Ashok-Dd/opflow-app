import 'package:flutter/material.dart';

import 'tokens.dart';

/// Text styles. Newsreader and IBM Plex Sans are variable fonts, so every style sets the
/// `wght` axis as well as [FontWeight].
abstract final class OpText {
  static const _serif = 'Newsreader';
  static const _sans = 'IBMPlexSans';
  static const _mono = 'IBMPlexMono';

  static TextStyle _style(String family, double size, FontWeight weight,
      {double height = 1.4, double spacing = 0, Color color = OpColors.ink}) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: const ['NotoSansTelugu'], // Telugu letters
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      height: height,
      letterSpacing: spacing,
      color: color,
    );
  }

  // Serif headings.
  static final display = _style(_serif, 34, FontWeight.w500, height: 1.1, spacing: -0.5);
  static final displayItalic = display.copyWith(fontStyle: FontStyle.italic);
  static final title = _style(_serif, 24, FontWeight.w500, height: 1.2, spacing: -0.2);
  static final heading = _style(_serif, 20, FontWeight.w600, height: 1.25);

  // Sans for everything else.
  static final lead = _style(_sans, 18, FontWeight.w500, height: 1.35);
  static final body = _style(_sans, 16, FontWeight.w400, height: 1.5);
  static final bodyStrong = _style(_sans, 16, FontWeight.w600, height: 1.4);
  static final small = _style(_sans, 14, FontWeight.w400, height: 1.45, color: OpColors.inkSoft);
  static final smallStrong = _style(_sans, 14, FontWeight.w600, height: 1.4);
  static final label = _style(_sans, 12, FontWeight.w600, height: 1.3, spacing: 0.9, color: OpColors.inkSoft);
  static final button = _style(_sans, 17, FontWeight.w600, height: 1.2, spacing: 0.2);

  // Mono for tokens, times, money and IDs.
  static TextStyle mono(double size, {FontWeight weight = FontWeight.w500, Color color = OpColors.ink}) =>
      TextStyle(fontFamily: _mono, fontSize: size, fontWeight: weight, color: color, height: 1.2,
          fontFeatures: const [FontFeature.tabularFigures()]);

  static final monoSmall = mono(14);
  static final monoBody = mono(16);
  static final monoBig = mono(22, weight: FontWeight.w600);
}
