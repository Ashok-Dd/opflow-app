import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'bits.dart';
import 'op_button.dart';

/// "Language · English" in Me (patients and doctors). Opens [showLanguageSheet].
class LanguageRow extends StatelessWidget {
  const LanguageRow({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Lang.instance,
      builder: (context, _) => MenuRow(
        icon: Icons.translate,
        title: 'Language'.tr,
        detail: Lang.instance.isTelugu ? 'తెలుగు' : 'English',
        onTap: () => showLanguageSheet(context),
      ),
    );
  }
}

/// English or Telugu. Each name is written in its own script, so anyone can find theirs.
Future<void> showLanguageSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Language / భాష', style: OpText.title),
            const SizedBox(height: 12),
            MenuGroup(children: [
              for (final (code, name) in const [(Lang.english, 'English'), (Lang.telugu, 'తెలుగు (Telugu)')])
                MenuRow(
                  icon: Lang.instance.code == code ? Icons.check_circle : Icons.circle_outlined,
                  title: name,
                  onTap: () {
                    Navigator.pop(sheet);
                    Lang.instance.set(code, context);
                  },
                ),
            ]),
          ],
        ),
      ),
    ),
  );
}

/// Two small buttons, "English | తెలుగు", for the first screen (before anyone logs in).
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Lang.instance,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (code, name) in const [(Lang.english, 'English'), (Lang.telugu, 'తెలుగు')])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: TapScale(
                onTap: () => Lang.instance.set(code, context),
                child: AnimatedContainer(
                  duration: OpMotion.quick,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Lang.instance.code == code ? OpColors.forest : OpColors.card,
                    borderRadius: OpRadius.controlAll,
                    border: Border.all(color: Lang.instance.code == code ? OpColors.forest : OpColors.line, width: 1.2),
                  ),
                  child: Text(
                    name,
                    style: OpText.smallStrong.copyWith(color: Lang.instance.code == code ? OpColors.paper : OpColors.ink),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
