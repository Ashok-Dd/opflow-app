import '../../l10n/lang.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../state/session.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/op_button.dart';
import '../../widgets/token_board.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _pages = [
    ('Book a doctor\nfrom home', 'Find the right doctor near you and book in a few taps.'),
    ('Know your time.\nNo long waiting.', 'We give you a time like 10 – 11 AM, so you come at the right time.'),
    ('See your turn live', 'Watch the token number move and know when to walk in.'),
  ];

  void _finish() {
    SessionStore.instance.finishOnboarding();
    context.go('/who');
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
    } else {
      _pc.nextPage(duration: const Duration(milliseconds: 380), curve: OpMotion.curve);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: OpSpace.gutter),
                  Text('OPflow'.tr, style: OpText.heading.copyWith(color: OpColors.forest)),
                  const Spacer(),
                  AnimatedOpacity(
                    duration: OpMotion.quick,
                    opacity: last ? 0 : 1,
                    child: TextButton(onPressed: last ? null : _finish, child: Text('Skip'.tr)),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final (title, text) = _pages[i];
                  return LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: OpSpace.gutter),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: (box.maxHeight * 0.55).clamp(240, 360),
                              child: Center(
                                // The drawings shrink to fit small phones and large text.
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: MediaQuery.withNoTextScaling(
                                    child: switch (i) {
                                      0 => const _PhonePicture(),
                                      1 => const _TimePicture(),
                                      _ => const _TurnPicture(),
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(title, style: OpText.display.copyWith(fontSize: 32)),
                            const SizedBox(height: 12),
                            Text(text, style: OpText.body.copyWith(fontSize: 18, color: OpColors.inkSoft)),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 8, OpSpace.gutter, 16),
              child: Row(
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: OpMotion.page,
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 28 : 10,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? OpColors.forest : OpColors.line,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: 150,
                    child: OpButton(label: last ? 'Start' : 'Next', onPressed: _next, icon: last ? null : Icons.arrow_forward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drawings for each page, built from real objects: a phone, the hour list, the token board.

class _PhonePicture extends StatelessWidget {
  const _PhonePicture();

  @override
  Widget build(BuildContext context) {
    Widget row(String initials, String name, String type, bool picked, int i) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: picked ? OpColors.mint : OpColors.card,
          borderRadius: OpRadius.controlAll,
          border: Border.all(color: picked ? OpColors.fern : OpColors.line),
        ),
        child: Row(
          children: [
            InitialsTile(text: initials, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: OpText.smallStrong.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(type, style: OpText.small.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            () {
              final btn = Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(color: OpColors.forest, borderRadius: BorderRadius.circular(2)),
                child: Text('Book'.tr, style: OpText.smallStrong.copyWith(fontSize: 10, color: OpColors.paper)),
              );
              if (!picked) return btn;
              return btn
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1, end: 1.12, duration: 700.ms, curve: Curves.easeInOut);
            }(),
          ],
        ),
      ).animate().fadeIn(delay: (250 + i * 180).ms, duration: 300.ms).slideX(begin: 0.15, end: 0, curve: OpMotion.curve);
    }

    return Container(
      width: 200,
      height: 320,
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
      decoration: BoxDecoration(
        color: OpColors.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OpColors.ink, width: 5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: OpColors.ink, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text('Child doctor'.tr, style: OpText.heading.copyWith(fontSize: 15)),
          Text('3 doctors near you'.tr, style: OpText.small.copyWith(fontSize: 10)),
          const SizedBox(height: 10),
          row('SR', 'Dr. Srinivas Rao', 'Today 11 – 12', true, 0),
          row('RT', 'Dr. Y. Ravi Teja', 'Today 6 – 7 PM', false, 1),
          row('AK', 'Dr. A. Kiran', 'Tomorrow 9 – 10', false, 2),
        ],
      ),
    );
  }
}

class _TimePicture extends StatelessWidget {
  const _TimePicture();

  @override
  Widget build(BuildContext context) {
    Widget row(String label, int taken, bool yours, int i) {
      final full = taken >= 8;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: yours ? OpColors.mint : OpColors.card,
          borderRadius: OpRadius.controlAll,
          border: Border.all(color: yours ? OpColors.fern : OpColors.line, width: yours ? 2 : 1),
        ),
        child: Row(
          children: [
            SizedBox(width: 92, child: Text(label, style: OpText.mono(14, weight: FontWeight.w600))),
            Expanded(child: SeatMeter(total: 8, taken: taken, box: 10)),
            if (yours)
              Text('Your time'.tr, style: OpText.smallStrong.copyWith(fontSize: 11, color: OpColors.fern))
            else if (full)
              Text('Full'.tr, style: OpText.small.copyWith(fontSize: 11)),
          ],
        ),
      ).animate().fadeIn(delay: (200 + i * 150).ms, duration: 300.ms).slideY(begin: 0.2, end: 0, curve: OpMotion.curve);
    }

    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("DR. SRINIVAS RAO · TODAY'S OPD".tr, style: OpText.label),
          const SizedBox(height: 10),
          row('9 – 10 AM', 8, false, 0),
          row('10 – 11 AM', 6, true, 1),
          row('11 – 12', 3, false, 2),
          row('12 – 1 PM', 1, false, 3),
        ],
      ),
    );
  }
}

class _TurnPicture extends StatefulWidget {
  const _TurnPicture();

  @override
  State<_TurnPicture> createState() => _TurnPictureState();
}

class _TurnPictureState extends State<_TurnPicture> {
  int _now = 14;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (!mounted) return;
      setState(() => _now = _now >= 17 ? 14 : _now + 1);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ahead = 18 - _now - 1;
    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TokenBoard(nowSeeing: _now, yourToken: 18),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: OpMotion.quick,
            child: StatusTag(
              key: ValueKey(ahead),
              ahead == 0 ? 'You are next. Please be near the room.' : '${people(ahead)} before you',
              tone: ahead == 0 ? Tone.good : Tone.info,
              icon: Icons.people_outline,
              big: true,
            ),
          ),
          const SizedBox(height: 8),
          const StatusTag('Doctor is on time', tone: Tone.good, icon: Icons.schedule),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).scaleXY(begin: 0.96, end: 1, curve: OpMotion.curve);
  }

  String people(int n) => n == 1 ? '1 person' : '$n people';
}
