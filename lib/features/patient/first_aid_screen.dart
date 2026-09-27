import '../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../mock/data.dart';
import '../../mock/first_aid.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/op_button.dart';
import 'emergency.dart' show Call108;

/// First aid for one emergency situation: when to call 108, Do's, Don'ts, and the WHO source.
/// Bundled in the app, so it works with no internet.
class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({super.key, required this.kindId});

  final String kindId;

  @override
  Widget build(BuildContext context) {
    final kind = MockData.emergencyKind(kindId);
    final g = FirstAid.forKind(kindId);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(kind.icon, color: OpColors.alarm),
            const SizedBox(width: 8),
            Flexible(child: Text(kind.name, style: OpText.heading.copyWith(color: OpColors.alarm), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 16, OpSpace.gutter, 32),
        children: [
          const Call108(),
          if (g == null) ...[
            const SizedBox(height: 20),
            Text('Call 108 or go to the nearest hospital now.'.tr, style: OpText.title),
          ] else ...[
            if (g.intro != null) ...[
              const SizedBox(height: 20),
              Text(g.intro!, style: OpText.body.copyWith(fontSize: 17, height: 1.5)),
            ],
            if (g.signs.isNotEmpty) ...[
              const SizedBox(height: 22),
              _Heading(text: 'Signs to look for'.tr, color: OpColors.ink, icon: Icons.visibility_outlined),
              for (final s in g.signs) _Line(text: s, mark: _Mark.dot),
            ],
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              decoration: const BoxDecoration(
                color: OpColors.alarmWash,
                border: Border(left: BorderSide(color: OpColors.alarm, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Heading(text: 'Call 108 now if'.tr, color: OpColors.alarm, icon: Icons.call),
                  for (final s in g.callNowIf) _Line(text: s, mark: _Mark.alert),
                ],
              ),
            ),
            const SizedBox(height: 26),
            _Heading(text: 'Do'.tr, color: OpColors.fern, icon: Icons.check_circle),
            for (final s in g.dos) _Line(text: s, mark: _Mark.yes),
            const SizedBox(height: 22),
            _Heading(text: 'Don\'t'.tr, color: OpColors.alarm, icon: Icons.cancel),
            for (final s in g.donts) _Line(text: s, mark: _Mark.no),
          ],
          const SizedBox(height: 26),
          OpButton(
            label: 'Emergency care open near you'.tr,
            icon: Icons.local_hospital_outlined,
            kind: OpButtonKind.dangerOutline,
            onPressed: () => context.push('/emergency/$kindId/near'),
          ),
          if (g != null) ...[
            const SizedBox(height: 26),
            _Sources(guide: g),
          ],
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Flexible(child: Text(text.toUpperCase(), style: OpText.label.copyWith(fontSize: 14, color: color, letterSpacing: 1.6))),
        ],
      ),
    );
  }
}

enum _Mark { yes, no, alert, dot }

class _Line extends StatelessWidget {
  const _Line({required this.text, required this.mark});

  final String text;
  final _Mark mark;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (mark) {
      _Mark.yes => (Icons.check, OpColors.fern),
      _Mark.no => (Icons.close, OpColors.alarm),
      _Mark.alert => (Icons.priority_high, OpColors.alarm),
      _Mark.dot => (Icons.circle, OpColors.inkSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: mark == _Mark.dot ? Colors.transparent : color.withValues(alpha: 0.12),
              borderRadius: OpRadius.smallAll,
            ),
            child: Icon(icon, size: mark == _Mark.dot ? 8 : 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: OpText.body.copyWith(fontSize: 17, height: 1.45))),
        ],
      ),
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({required this.guide});

  final FirstAidGuide guide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OpColors.card,
        borderRadius: OpRadius.cardAll,
        border: Border.all(color: OpColors.line, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 18, color: OpColors.forest),
              const SizedBox(width: 8),
              Text('BASED ON WHO GUIDANCE'.tr, style: OpText.label.copyWith(color: OpColors.forest, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 10),
          for (final s in guide.sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.title} (${s.year})', style: OpText.smallStrong),
                  if (s.url != null)
                    GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: s.url!));
                        showToast(context, 'Link copied'.tr);
                      },
                      child: SelectableText(s.url!, style: OpText.mono(11.5, color: OpColors.fern)),
                    ),
                ],
              ),
            ),
          if (guide.sourceToConfirm || guide.reviewedBy == null) ...[
            const Divider(height: 18),
            Text(
              guide.reviewedBy == null ? 'Medical review: pending (test build).' : 'Checked by ${guide.reviewedBy}.',
              style: OpText.small.copyWith(fontSize: 12.5, color: OpColors.amber),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'This is first aid only. It does not replace a doctor. WHO does not endorse apps; these steps follow the WHO documents named above.'.tr,
            style: OpText.small.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
