import '../l10n/lang.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';

import '../data/api.dart';

/// Everything that goes wrong in the app ends up here: logged, and sent to Sentry when the build has a key
/// (`--dart-define=SENTRY_DSN=…`). Nothing here ever throws.
abstract final class ErrorReporter {
  static const _dsn = String.fromEnvironment('SENTRY_DSN');
  static bool _sentry = false;

  /// Turns on Sentry when this build has a key. No personal details (phone, name) are ever attached.
  static Future<void> start() async {
    if (_dsn.isEmpty || _sentry) return;
    try {
      await SentryFlutter.init((o) {
        o.dsn = _dsn;
        o.sendDefaultPii = false;
        o.environment = kReleaseMode ? 'production' : 'test';
        o.tracesSampleRate = 0;
      });
      _sentry = true;
    } catch (_) {
      // Without error reports the app works the same.
    }
  }

  /// Recent errors, newest first. Useful for a future "Report a problem" screen and for tests.
  static final recent = <String>[];

  static void report(Object error, StackTrace? stack, {String? where}) {
    try {
      final line = '${DateTime.now().toIso8601String()} ${where ?? 'app'}: $error';
      recent.insert(0, line);
      if (recent.length > 50) recent.removeLast();
      debugPrint('[OPflow error] $line');
      if (stack != null && kDebugMode) debugPrint(stack.toString());
      if (_sentry) {
        unawaited(Sentry.captureException(error, stackTrace: stack, withScope: (s) => s.setTag('where', where ?? 'app')));
      }
    } catch (_) {
      // Reporting must never be the thing that crashes the app.
    }
  }
}

/// Turns any error into one short, calm sentence for people.
String friendlyMessage(Object error) => _friendly(error).tr; // in the app's language when there is Telugu for it

String _friendly(Object error) {
  if (error is AppFailure) return error.message;
  if (error is ApiException) return error.message; // the server writes it in simple English
  if (error is TimeoutException) return 'This is taking too long. Please check your internet and try again.';
  final text = error.toString().toLowerCase();
  if (text.contains('socket') || text.contains('network') || text.contains('connection')) {
    return 'No internet. Please check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}

/// An error we expect and can explain (from the server or our own checks).
class AppFailure implements Exception {
  const AppFailure(this.message, {this.code = 'unknown', this.retryable = true});

  final String message;
  final String code;
  final bool retryable;

  @override
  String toString() => 'AppFailure($code): $message';
}

/// Shown in place of a single broken part of a screen, instead of a red or grey error box.
/// The rest of the screen keeps working.
class ErrorFallback extends StatelessWidget {
  const ErrorFallback({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: EdgeInsets.all(compact ? 10 : 16),
        decoration: BoxDecoration(
          color: OpColors.paperDeep,
          borderRadius: OpRadius.controlAll,
          border: Border.all(color: OpColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 18, color: OpColors.inkSoft),
            const SizedBox(width: 8),
            Flexible(
              child: Text('This part could not be shown. Please go back and try again.'.tr,
                  style: OpText.small.copyWith(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full screen for links to things that do not exist (a removed doctor, a wrong link…).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, this.what = 'page', this.home = '/home'});

  final String what;
  final String home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Back'.tr, icon: const Icon(Icons.arrow_back), onPressed: () => context.popOr(home)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 48, color: OpColors.fern),
              const SizedBox(height: 16),
              Text('We could not find this $what', textAlign: TextAlign.center, style: OpText.title),
              const SizedBox(height: 8),
              Text('It may have been moved or removed.'.tr, textAlign: TextAlign.center, style: OpText.body.copyWith(color: OpColors.inkSoft)),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => context.go(home), child: Text('Go to home'.tr)),
            ],
          ),
        ),
      ),
    );
  }
}

extension SafeNavigation on BuildContext {
  /// Goes back if there is somewhere to go back to; otherwise goes to [fallback].
  /// (`context.pop()` throws when a screen was opened directly from a link.)
  void popOr(String fallback) {
    try {
      if (canPop()) {
        pop();
      } else {
        go(fallback);
      }
    } catch (e, s) {
      ErrorReporter.report(e, s, where: 'popOr');
    }
  }
}

/// Runs [action] and never lets an error escape. Returns null on failure.
Future<T?> guard<T>(Future<T> Function() action, {String? where, void Function(Object error)? onError}) async {
  try {
    return await action();
  } catch (e, s) {
    ErrorReporter.report(e, s, where: where);
    try {
      onError?.call(e);
    } catch (_) {}
    return null;
  }
}
