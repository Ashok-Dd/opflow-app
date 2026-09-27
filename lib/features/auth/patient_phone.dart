import '../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../state/session.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/op_button.dart';

class PatientPhoneScreen extends StatefulWidget {
  const PatientPhoneScreen({super.key});

  @override
  State<PatientPhoneScreen> createState() => _PatientPhoneScreenState();
}

class _PatientPhoneScreenState extends State<PatientPhoneScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _valid => RegExp(r'^[6-9]\d{9}$').hasMatch(_ctrl.text);

  Future<void> _send() async {
    if (!_valid) {
      setState(() => _error = 'Please enter a correct 10-digit mobile number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionStore.instance.sendOtp(_ctrl.text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, friendlyMessage(e));
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    context.push('/login/otp');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OpPage(
      title: 'Log in'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          Text('Your mobile number'.tr, style: OpText.title).staggerIn(0),
          const SizedBox(height: 8),
          Text('We will send a 6-digit code by SMS to check it is you.'.tr, style: OpText.body.copyWith(color: OpColors.inkSoft))
              .staggerIn(1),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: OpColors.paperDeep,
                  borderRadius: OpRadius.controlAll,
                  border: Border.all(color: OpColors.line, width: 1.2),
                ),
                child: Text('+91', style: OpText.mono(18, weight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: OpText.mono(20, weight: FontWeight.w500),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: '98765 43210',
                    counterText: '',
                    errorText: _error,
                    errorMaxLines: 2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                ),
              ),
            ],
          ).staggerIn(2),
          const SizedBox(height: 20),
          InfoBox(
            icon: Icons.lock_outline,
            child: Text('Your number is safe. We use it only for your bookings and messages.'.tr),
          ).staggerIn(3),
        ],
      ),
      bottom: OpButton(label: 'Send OTP'.tr, loading: _busy, onPressed: _ctrl.text.length == 10 ? _send : null),
    );
  }
}
