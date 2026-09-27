import '../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../mock/data.dart';
import '../../state/session.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/op_button.dart';

/// Doctors log in with the Doctor ID and password given by the OPflow team. No sign-up here.
class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _show = false;
  bool _busy = false;
  bool _wrong = false;

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _wrong = false;
    });
    final r = await SessionStore.instance.doctorLogin(_id.text, _pw.text);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case DoctorLoginResult.wrong:
        final why = SessionStore.instance.loginMessage;
        if (why != null) {
          showError(context, why);
        } else {
          setState(() => _wrong = true);
        }
      case DoctorLoginResult.needsNewPassword:
        context.push('/doctor-login/new-password');
      case DoctorLoginResult.ok:
        context.go('/d/today');
    }
  }

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _id.text.trim().isNotEmpty && _pw.text.isNotEmpty;
    return OpPage(
      title: 'Doctor log in'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          Text('Welcome, Doctor'.tr, style: OpText.title).staggerIn(0),
          const SizedBox(height: 8),
          Text('Your Doctor ID and password are given by the OPflow team.'.tr,
                  style: OpText.body.copyWith(color: OpColors.inkSoft))
              .staggerIn(1),
          const SizedBox(height: 24),
          Text('Doctor ID'.tr, style: OpText.smallStrong),
          const SizedBox(height: 6),
          TextField(
            controller: _id,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            style: OpText.mono(18),
            onChanged: (_) => setState(() => _wrong = false),
            decoration: InputDecoration(hintText: 'OPD-10234'.tr, prefixIcon: Icon(Icons.badge_outlined)),
          ),
          const SizedBox(height: 18),
          Text('Password'.tr, style: OpText.smallStrong),
          const SizedBox(height: 6),
          TextField(
            controller: _pw,
            obscureText: !_show,
            onChanged: (_) => setState(() => _wrong = false),
            onSubmitted: (_) => ready ? _login() : null,
            decoration: InputDecoration(
              hintText: 'Password'.tr,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _show ? 'Hide password' : 'Show password',
                icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
          ),
          if (_wrong) ...[
            const SizedBox(height: 14),
            InfoBox(tone: Tone.bad, icon: Icons.error_outline, child: Text('Doctor ID or password is wrong. Please check and try again.'.tr))
                .animate()
                .shakeX(hz: 5, amount: 5, duration: 400.ms),
          ],
          const SizedBox(height: 20),
          Text('Forgot password?'.tr, style: OpText.bodyStrong),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Call OPflow help: '.tr),
              TextSpan(text: MockData.opflowHelpPhone, style: OpText.monoBody.copyWith(color: OpColors.fern, fontWeight: FontWeight.w600)),
            ]),
            style: OpText.small.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 24),
          InfoBox(
            tone: Tone.calm,
            icon: Icons.science_outlined,
            child: Text('Test account\nDoctor ID: OPD-10234   Password: demo1234'.tr),
          ),
        ],
      ),
      bottom: OpButton(label: 'Log in'.tr, loading: _busy, onPressed: ready ? _login : null),
    );
  }
}
