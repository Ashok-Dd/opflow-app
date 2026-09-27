import '../../l10n/lang.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../mock/format.dart';
import '../../data/config.dart';
import '../../state/session.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/op_button.dart';

class PatientOtpScreen extends StatefulWidget {
  const PatientOtpScreen({super.key});

  @override
  State<PatientOtpScreen> createState() => _PatientOtpScreenState();
}

class _PatientOtpScreenState extends State<PatientOtpScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  bool _wrong = false;
  int _wait = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // The boxes show where the cursor is, so they redraw when the field gains or loses focus.
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  /// Tapping the boxes always brings the keyboard back, even when the field kept its focus but the keyboard
  /// was closed (back button, tap outside).
  void _openKeyboard() {
    if (_focus.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _focus.requestFocus();
    }
  }

  /// Tapping one box: the cursor goes there and the keyboard opens. A filled box is retyped from that digit on
  /// (the digits after it are cleared), so a single wrong digit is easy to fix.
  void _tapBox(int i) {
    final text = _ctrl.text;
    if (i < text.length) {
      _ctrl.text = text.substring(0, i);
      _ctrl.selection = TextSelection.collapsed(offset: i);
      setState(() => _wrong = false);
    }
    _openKeyboard();
  }

  /// A fresh start after a wrong or expired code: empty boxes, cursor in the first one, keyboard open.
  void _clearForRetry() {
    _ctrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openKeyboard();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _wait = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _check() async {
    if (_ctrl.text.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _wrong = false;
    });
    final ok = await SessionStore.instance.checkOtp(_ctrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      final why = SessionStore.instance.loginMessage;
      if (why != null) showError(context, why);
      setState(() => _wrong = why == null);
      // Never keep old digits: the next typing would be ignored (6 digits at most) and "Check code" would send
      // the same wrong code again.
      _clearForRetry();
      return;
    }
    context.go(SessionStore.instance.profileDone ? '/home' : '/login/about');
  }

  Future<void> _resend() async {
    try {
      await SessionStore.instance.sendOtp(SessionStore.instance.phone);
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
      return;
    }
    if (!mounted) return;
    showToast(context, 'New code sent'.tr);
    setState(() => _wrong = false);
    _clearForRetry();
    _startTimer();
  }

  /// Test server only: tap the shown code to fill the boxes and check it.
  void _fillTestCode(String code) {
    _ctrl.text = code;
    _ctrl.selection = TextSelection.collapsed(offset: code.length);
    setState(() => _wrong = false);
    _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _ctrl.text;
    return OpPage(
      title: 'Enter code'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          Text('Enter the 6-digit code'.tr, style: OpText.title),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'We sent it by SMS to '.tr),
              TextSpan(text: '+91 ${prettyPhone(SessionStore.instance.phone)}', style: OpText.monoBody.copyWith(fontWeight: FontWeight.w600)),
            ]),
            style: OpText.body.copyWith(color: OpColors.inkSoft),
          ),
          const SizedBox(height: 28),
          // Six boxes drawn over one hidden field, so paste and auto-fill work.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openKeyboard,
            child: Stack(
              children: [
                Opacity(
                  opacity: 0,
                  child: SizedBox(
                    height: 64,
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      showCursor: false,
                      onChanged: (v) {
                        setState(() => _wrong = false);
                        if (v.length == 6) _check();
                      },
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _tapBox(i),
                          child: _Box(char: i < code.length ? code[i] : '', active: i == code.length.clamp(0, 5) && _focus.hasFocus, wrong: _wrong),
                        ),
                      ),
                      if (i < 5) SizedBox(width: i == 2 ? 14 : 8),
                    ],
                  ],
                ),
              ],
            ),
          )
              .animate(target: _wrong ? 1 : 0)
              .shakeX(hz: 5, amount: 6, duration: 400.ms),
          const SizedBox(height: 12),
          if (_wrong)
            Text('This code is not right. Please check the SMS and try again.'.tr, style: OpText.small.copyWith(color: OpColors.alarm)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _wait > 0
                    ? Text('Resend code in 0:${_wait.toString().padLeft(2, '0')}', style: OpText.small.copyWith(fontSize: 15))
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(onPressed: _resend, child: Text('Send code again'.tr)),
                      ),
              ),
              TextButton(onPressed: () => context.popOr('/login'), child: Text('Wrong number? Change'.tr)),
            ],
          ),
          const SizedBox(height: 16),
          if (SessionStore.instance.testCode != null)
            TapScale(
              onTap: _busy ? null : () => _fillTestCode(SessionStore.instance.testCode!),
              child: InfoBox(
                icon: Icons.sms_outlined,
                tone: Tone.calm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: 'SMS is not set up yet. Your code is '.tr),
                      TextSpan(text: SessionStore.instance.testCode, style: OpText.monoBody.copyWith(fontWeight: FontWeight.w700, letterSpacing: 2)),
                    ])),
                    const SizedBox(height: 4),
                    Text('Tap here to fill it in.'.tr, style: OpText.smallStrong.copyWith(color: OpColors.fern)),
                  ],
                ),
              ),
            )
          else if (!AppConfig.isApi)
            InfoBox(icon: Icons.science_outlined, tone: Tone.calm, child: Text('Test build: any 6 numbers will work.'.tr))
          else if (SessionStore.instance.otpMode == 'demo')
            InfoBox(icon: Icons.science_outlined, tone: Tone.calm, child: Text('Test server: no SMS is sent. Use the test code.'.tr)),
        ],
      ),
      bottom: OpButton(label: 'Check code'.tr, loading: _busy, onPressed: code.length == 6 ? _check : null),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.char, required this.active, required this.wrong});

  final String char;
  final bool active;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final color = wrong ? OpColors.alarm : (active ? OpColors.fern : (char.isEmpty ? OpColors.line : OpColors.ink));
    return AnimatedContainer(
      duration: OpMotion.quick,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: OpColors.card,
        borderRadius: OpRadius.controlAll,
        border: Border.all(color: color, width: active || wrong ? 2 : 1.3),
      ),
      child: char.isEmpty && active
          // The cursor: a blinking bar in the box where the next digit goes.
          ? Container(width: 2.5, height: 28, decoration: BoxDecoration(color: OpColors.fern, borderRadius: BorderRadius.circular(2)))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeOut(duration: 550.ms, curve: Curves.easeInOut)
          : AnimatedSwitcher(
              duration: OpMotion.quick,
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Text(char, key: ValueKey(char), style: OpText.mono(26, weight: FontWeight.w600)),
            ),
    );
  }
}
