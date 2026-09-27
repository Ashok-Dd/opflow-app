import 'package:flutter/material.dart';

import '../data/config.dart';
import '../data/remote.dart';
import '../l10n/lang.dart';
import '../theme/text.dart';
import 'op_button.dart';
import 'op_loader.dart';

/// Shows [child] once the doctors and hospitals have come from the server. Until then: the OP loader (the
/// server may be waking up, which can take up to a minute). If it failed: a short note and "Try again".
/// In the mock build there is nothing to wait for.
class DirectoryGate extends StatelessWidget {
  const DirectoryGate({super.key, required this.builder, this.height = 200, this.text = 'Finding doctors near you…'});

  final WidgetBuilder builder;
  final double height;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isApi) return builder(context);
    return ListenableBuilder(
      listenable: Remote.instance,
      builder: (context, _) {
        final r = Remote.instance;
        if (r.loaded) return builder(context);
        r.ensureLoaded();
        if (r.error != null && !r.busy) {
          return SizedBox(
            height: height,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load doctors. Please check your internet.'.tr, style: OpText.small, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OpButton.secondary(label: 'Try again'.tr, expand: false, height: 44, onPressed: () => r.loadDirectory()),
                ],
              ),
            ),
          );
        }
        return OpLoadingPanel(text: text, height: height, hint: 'The first load can take up to a minute.');
      },
    );
  }
}
