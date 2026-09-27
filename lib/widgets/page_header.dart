import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';

/// The top of every tab: a small context line, a large serif title, an optional subtitle.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.eyebrow, this.subtitle, this.trailing, this.rule = true});

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;
  final bool rule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null) ...[
                    Text(eyebrow!.toUpperCase(), style: OpText.label.copyWith(letterSpacing: 1.6)),
                    const SizedBox(height: 6),
                  ],
                  Text(title, style: OpText.display),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle!, style: OpText.body.copyWith(color: OpColors.inkSoft)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
        if (rule) const SizedBox(height: 8),
      ],
    );
  }
}

/// A soft divider: a short green accent over a hairline.
class DoubleRule extends StatelessWidget {
  const DoubleRule({super.key, this.color = OpColors.ink});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1, color: OpColors.lineSoft),
      ],
    );
  }
}
