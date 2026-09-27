import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../theme/tokens.dart';

/// A time like a good clock face: big even numbers, small AM / PM tucked beside them ("9 AM", not the wide
/// typewriter "9  AM"). [ClockRange] joins two with a short rule: 9 AM — 1 PM.
class ClockTime extends StatelessWidget {
  const ClockTime(this.hour, {super.key, this.size = 28, this.color = OpColors.ink, this.suffixColor, this.showSuffix = true});

  final int hour;
  final double size;
  final Color color;
  final Color? suffixColor;
  final bool showSuffix;

  static String number(int h) => '${h % 12 == 0 ? 12 : h % 12}';
  static String suffix(int h) => (h % 24) >= 12 ? 'PM'.tr : 'AM'.tr;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: number(hour),
          style: TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: size,
            fontWeight: FontWeight.w600,
            height: 1,
            letterSpacing: -0.5,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (showSuffix)
          TextSpan(
            text: ' ${suffix(hour)}',
            style: TextStyle(
              fontFamily: 'IBMPlexSans',
              fontSize: (size * 0.42).clamp(10, 18),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: suffixColor ?? color.withValues(alpha: 0.7),
            ),
          ),
      ]),
      maxLines: 1,
      softWrap: false,
    );
  }
}

/// "9 AM — 1 PM". The first AM/PM is left out when both are the same (10 — 11 AM), like people write it.
class ClockRange extends StatelessWidget {
  const ClockRange(this.start, this.end, {super.key, this.size = 17, this.color = OpColors.ink, this.suffixColor, this.shortSame = true});

  final int start;
  final int end;
  final double size;
  final Color color;
  final Color? suffixColor;
  final bool shortSame;

  @override
  Widget build(BuildContext context) {
    final same = shortSame && ((start % 24) >= 12) == ((end % 24) >= 12);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClockTime(start, size: size, color: color, suffixColor: suffixColor, showSuffix: !same),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.32),
          child: Container(width: size * 0.55, height: size < 20 ? 1.6 : 2.2, color: (suffixColor ?? color).withValues(alpha: 0.55)),
        ),
        ClockTime(end, size: size, color: color, suffixColor: suffixColor),
      ],
    );
  }
}
