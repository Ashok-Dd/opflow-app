import 'package:flutter/widgets.dart';

/// Medical icons for the types of doctor, in OPflow's own small icon font (assets/fonts/OpflowMedIcons.ttf):
/// Google's Material Symbols (Apache 2.0), fixed to one style and cut down to these icons only. A fixed font
/// is used because trimming the big variable font at build time blanked some of these glyphs on phones.
abstract final class MedIcons {
  static const _f = 'OpflowMedIcons';
  static const stethoscope = IconData(0xf805, fontFamily: _f);
  static const pediatrics = IconData(0xe11d, fontFamily: _f);
  static const gynecology = IconData(0xe0f4, fontFamily: _f);
  static const dermatology = IconData(0xe0a7, fontFamily: _f);
  static const orthopedics = IconData(0xf897, fontFamily: _f);
  static const ophthalmology = IconData(0xe115, fontFamily: _f);
  static const ent = IconData(0xe0aa, fontFamily: _f);
  static const dentistry = IconData(0xe0a6, fontFamily: _f);
  static const cardiology = IconData(0xe09c, fontFamily: _f);
  static const neurology = IconData(0xe10e, fontFamily: _f);
  static const psychiatry = IconData(0xe123, fontFamily: _f);
  static const gastroenterology = IconData(0xe0f1, fontFamily: _f);
  static const pulmonology = IconData(0xe124, fontFamily: _f);
  static const urology = IconData(0xe137, fontFamily: _f);
  static const surgical = IconData(0xe131, fontFamily: _f);
}
