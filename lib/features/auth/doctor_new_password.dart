import '../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../state/session.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/op_button.dart';
import '../../core/errors.dart';

/// First login only: the doctor replaces the password the OPflow team gave them.
class DoctorNewPasswordScreen extends StatefulWidget {
  const DoctorNewPasswordScreen({super.key});

  @override
  State<DoctorNewPasswordScreen> createState() => _DoctorNewPasswordScreenState();
}

class _DoctorNewPasswordScreenState extends State<DoctorNewPasswordScreen> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await SessionStore.instance.setDoctorPassword(_a.text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, friendlyMessage(e));
      return;
    }
    if (!mounted) return;
    context.go('/d/today');
  }

  @override
  Widget build(BuildContext context) {
    return OpPage(
      title: 'New password'.tr,
      body: ListView(
        padding: const EdgeInsets.all(OpSpace.gutter),
        children: [
          Text('Set your own password'.tr, style: OpText.title),
          const SizedBox(height: 8),
          Text('This is your first time here. Please make a new password that only you know.'.tr,
              style: OpText.body.copyWith(color: OpColors.inkSoft)),
          const SizedBox(height: 24),
          PasswordFields(a: _a, b: _b, onChanged: () => setState(() {})),
        ],
      ),
      bottom: OpButton(label: 'Save password'.tr, loading: _busy, onPressed: passwordOk(_a.text, _b.text) ? _save : null),
    );
  }
}

bool passwordOk(String a, String b) => a.length >= 8 && RegExp(r'\d').hasMatch(a) && a == b;

/// New password + confirm, with plain-word checks that tick as you type.
class PasswordFields extends StatefulWidget {
  const PasswordFields({super.key, required this.a, required this.b, required this.onChanged});

  final TextEditingController a;
  final TextEditingController b;
  final VoidCallback onChanged;

  @override
  State<PasswordFields> createState() => _PasswordFieldsState();
}

class _PasswordFieldsState extends State<PasswordFields> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.a.text;
    final checks = [
      ('At least 8 letters or numbers', a.length >= 8),
      ('Has at least one number', RegExp(r'\d').hasMatch(a)),
      ('Both boxes are the same', a.isNotEmpty && a == widget.b.text),
    ];
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            tooltip: _show ? 'Hide password' : 'Show password',
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _show = !_show),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('New password'.tr, style: OpText.smallStrong),
        const SizedBox(height: 6),
        TextField(controller: widget.a, obscureText: !_show, onChanged: (_) => widget.onChanged(), decoration: deco('New password')),
        const SizedBox(height: 16),
        Text('Type it again'.tr, style: OpText.smallStrong),
        const SizedBox(height: 6),
        TextField(controller: widget.b, obscureText: !_show, onChanged: (_) => widget.onChanged(), decoration: deco('Same password again')),
        const SizedBox(height: 16),
        for (final (text, ok) in checks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: OpMotion.quick,
                  transitionBuilder: (c, an) => ScaleTransition(scale: an, child: c),
                  child: Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
                      key: ValueKey(ok), size: 20, color: ok ? OpColors.fern : OpColors.inkFaint),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: OpText.body.copyWith(fontSize: 15, color: ok ? OpColors.ink : OpColors.inkSoft))),
              ],
            ),
          ),
      ],
    );
  }
}
