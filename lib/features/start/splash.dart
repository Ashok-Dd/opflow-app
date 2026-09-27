import 'dart:async';

import '../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../data/config.dart';
import '../../data/push.dart';
import '../../data/remote.dart';
import '../../state/session.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/op_loader.dart';
import '../../widgets/op_mark.dart';

/// The start: the OP mark draws itself with the name and line (the same mark the phone showed while the app
/// opened, in the same spot), then the OP loader while the app gets ready, then the right screen.
///
/// Getting ready (API build): push notifications, and for patients the doctors and hospitals near them, so the
/// first screen opens full. Never longer than [_maxWait]; screens that still need data show their own loader.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _maxWait = Duration(seconds: 8);
  static const _minLoader = Duration(milliseconds: 900);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final Future<void> _ready = _prepare();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ready; // start at once, while the mark draws
    _c.forward().whenComplete(_afterMark);
  }

  static Future<void> _prepare() async {
    if (!AppConfig.isApi) return;
    await guard(() async {
      Remote.instance.prepare();
      // Push notifications (Android + iPhone). Never blocks or breaks the start.
      await Push.instance.start();
      // Patients open on the doctor list: get it now. (Doctors load their own OPD on the next screen.)
      if (SessionStore.instance.side != Side.doctor) {
        await Remote.instance.loadDirectory().timeout(_maxWait);
      }
    }, where: 'splash.prepare');
  }

  Future<void> _afterMark() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await Future.wait([
      _ready.timeout(_maxWait, onTimeout: () {}),
      Future<void>.delayed(_minLoader),
    ]);
    _next();
  }

  void _next() {
    if (!mounted) return;
    final s = SessionStore.instance;
    final String to;
    if (!s.onboardingSeen) {
      to = '/welcome';
    } else if (s.side == Side.patient) {
      to = s.profileDone ? '/home' : '/login/about';
    } else if (s.side == Side.doctor) {
      to = '/d/today';
    } else {
      to = '/who';
    }
    context.go(to);
    Push.instance.openPending();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OpColors.paper,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final textIn = opPhase(t, 0.45, 0.75);
          final lineIn = opPhase(t, 0.6, 0.9);
          // Starts exactly where the phone's own start screen drew it, then rises to the optical centre.
          final lift =
              78 * Curves.easeOutCubic.transform(opPhase(t, 0.35, 0.62));
          final middle = MediaQuery.sizeOf(context).height / 2 - lift;
          return Stack(
            children: [
              Transform.translate(
                offset: Offset(0, -lift),
                child: Center(
                  child: SizedBox.square(
                    dimension: 112,
                    child: CustomPaint(
                      painter: OpMarkPainter(
                        ring: opPhase(t, 0.0, 0.35),
                        stem: opPhase(t, 0.2, 0.42),
                        bowl: opPhase(t, 0.32, 0.55),
                        beat: opPhase(t, 0.45, 0.7),
                      ),
                    ),
                  ),
                ),
              ),
              // Name and line just under the mark.
              Positioned(
                left: 24,
                right: 24,
                top: middle + 56 + 18,
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: textIn,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - textIn)),
                          child: Text(
                            'OPflow'.tr,
                            style: OpText.display.copyWith(
                              fontSize: 40,
                              color: OpColors.forest,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: lineIn,
                        child: Text(
                          'Right patient, right doctor,\nat the right time.'.tr,
                          textAlign: TextAlign.center,
                          style: OpText.body.copyWith(
                            color: OpColors.inkSoft,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Newsreader',
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Then the OP loader, while the app gets ready.
              Align(
                alignment: const Alignment(0, 0.78),
                child: AnimatedOpacity(
                  opacity: _loading ? 1 : 0,
                  duration: OpMotion.page,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loading) const OpLoader(size: 44),
                      const SizedBox(height: 10),
                      Text(
                        'Getting things ready…'.tr,
                        style: OpText.small.copyWith(color: OpColors.inkFaint),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
