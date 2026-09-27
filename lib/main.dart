import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/errors.dart';
import 'data/config.dart';
import 'widgets/update_required.dart';
import 'router/app_router.dart';
import 'state/directory_store.dart';
import 'state/session.dart';
import 'theme/theme.dart';
import 'theme/tokens.dart';
import 'l10n/lang.dart';

Future<void> main() async {
  // Every error, from anywhere, is caught and reported. None of them may close the app.
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await ErrorReporter.start(); // Sentry, only when this build has a key

    // Errors while building, laying out or painting widgets.
    FlutterError.onError = (details) {
      ErrorReporter.report(details.exception, details.stack, where: details.library);
      if (kDebugMode) FlutterError.dumpErrorToConsole(details);
    };
    // Errors from platform channels and async code outside Flutter's own handling.
    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorReporter.report(error, stack, where: 'platform');
      return true; // handled: do not crash
    };
    // A widget that fails to build shows a small, calm note instead of a red or grey box.
    ErrorWidget.builder = (details) {
      if (kDebugMode) return ErrorWidget(details.exception);
      return const ErrorFallback(compact: true);
    };

    // Saved data can be missing or broken on some phones; the app then starts fresh.
    await guard(SessionStore.instance.load, where: 'session.load');
    await guard(DirectoryStore.instance.load, where: 'directory.load');
    await guard(Lang.instance.load, where: 'lang.load');
    // Nothing slow here: the first screen must draw at once (no blank start). The server, push and the doctor
    // list are prepared by the splash, while it shows the OP mark and then the OP loader.

    // Portrait only, even with auto-rotate on (the screens are designed for a phone held upright).
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: OpColors.paper,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    runApp(ProviderScope(
      // A provider that fails is reported, not fatal.
      observers: [_ProviderErrors()],
      child: const OpflowApp(),
    ));
  }, (error, stack) => ErrorReporter.report(error, stack, where: 'zone'));
}

final class _ProviderErrors extends ProviderObserver {
  @override
  void providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace) {
    ErrorReporter.report(error, stackTrace, where: 'provider ${context.provider.name ?? context.provider.runtimeType}');
  }
}

class OpflowApp extends StatefulWidget {
  const OpflowApp({super.key});

  @override
  State<OpflowApp> createState() => _OpflowAppState();
}

class _OpflowAppState extends State<OpflowApp> {
  @override
  void initState() {
    super.initState();
    Lang.instance.addListener(_languageChanged);
  }

  @override
  void dispose() {
    Lang.instance.removeListener(_languageChanged);
    super.dispose();
  }

  /// English ↔ Telugu: every screen, including ones further back, is drawn again in the new language.
  void _languageChanged() {
    if (mounted) Lang.redrawAll(context);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OPflow',
      debugShowCheckedModeBanner: false,
      theme: buildOpTheme(),
      routerConfig: appRouter,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        OpMotion.reduced = mq.disableAnimations;
        // Allow large phone text, but stop at 1.5× so screens stay usable.
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1, maxScaleFactor: 1.5)),
          child: ValueListenableBuilder<bool>(
            valueListenable: AppConfig.updateRequired,
            builder: (context, old, _) => old ? const UpdateRequiredScreen() : (child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
