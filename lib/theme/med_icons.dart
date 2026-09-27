import 'package:flutter/widgets.dart';

/// OPflow's own small medical icon font (assets/fonts/OpflowIcons.ttf): real organs and symptoms from Healthicons
/// (healthicons.org, CC0 / MIT) and the rib cage from Google's Material Symbols (Apache 2.0), made into one static
/// font by the build script noted in assets/fonts/OpflowIcons-LICENSE.txt. Everything else uses Material icons.
abstract final class MedIcons {
  static const _f = 'OpflowIcons';
  static const heart = IconData(0xe900, fontFamily: _f);
  static const lungs = IconData(0xe901, fontFamily: _f);
  static const stomach = IconData(0xe902, fontFamily: _f);
  static const stomachPain = IconData(0xe903, fontFamily: _f);
  static const looseMotions = IconData(0xe904, fontFamily: _f);
  static const breathing = IconData(0xe905, fontFamily: _f);
  static const redEyes = IconData(0xe906, fontFamily: _f);
  static const eyePain = IconData(0xe907, fontFamily: _f);
  static const hairFall = IconData(0xe908, fontFamily: _f);
  static const cancer = IconData(0xe909, fontFamily: _f);
  static const chestPain = IconData(0xf898, fontFamily: _f); // rib cage (not a heart)
}
