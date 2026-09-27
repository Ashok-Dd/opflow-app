import '../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/patient_store.dart';
import '../../state/session.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/op_button.dart';
import '../../core/errors.dart';

/// First time only: name, age, gender and area. Four questions, nothing more.
class AboutYouScreen extends ConsumerStatefulWidget {
  const AboutYouScreen({super.key});

  @override
  ConsumerState<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends ConsumerState<AboutYouScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  String _gender = '';
  bool _busy = false;

  bool get _ok =>
      _name.text.trim().length >= 2 && (int.tryParse(_age.text) ?? 0) > 0 && _gender.isNotEmpty && SessionStore.instance.place.isNotEmpty;

  Future<void> _save() async {
    setState(() => _busy = true);
    final age = int.parse(_age.text);
    try {
      await SessionStore.instance.saveProfile(name: _name.text, age: age, gender: _gender);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, friendlyMessage(e));
      return;
    }
    ref.read(patientProvider).updateMe(name: _name.text.trim(), age: age, gender: _gender);
    if (!mounted) return;
    context.go('/home');
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final place = ref.watch(sessionProvider).place;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(OpSpace.gutter),
          children: [
            const SizedBox(height: 12),
            Text('Tell us about you'.tr, style: OpText.display).staggerIn(0),
            const SizedBox(height: 8),
            Text('This helps the doctor know who is coming.'.tr, style: OpText.body.copyWith(color: OpColors.inkSoft)).staggerIn(1),
            const SizedBox(height: 28),
            GenderAgeNameForm(
              name: _name,
              age: _age,
              gender: _gender,
              onGender: (g) => setState(() => _gender = g),
              onChanged: () => setState(() {}),
            ).staggerIn(2),
            const SizedBox(height: 18),
            Text('Your area'.tr, style: OpText.smallStrong).staggerIn(3),
            const SizedBox(height: 6),
            TapScale(
              onTap: () => context.push('/me/place'),
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: OpColors.card,
                  borderRadius: OpRadius.controlAll,
                  border: Border.all(color: OpColors.line, width: 1.3),
                ),
                child: Row(
                  children: [
                    Icon(place.isEmpty ? Icons.my_location : Icons.place, color: OpColors.fern),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        place.isEmpty ? 'Use my location'.tr : place,
                        style: place.isEmpty ? OpText.body.copyWith(color: OpColors.inkSoft) : OpText.bodyStrong,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(place.isEmpty ? 'Set'.tr : 'Change'.tr, style: OpText.smallStrong.copyWith(color: OpColors.fern)),
                  ],
                ),
              ),
            ).staggerIn(3),
            const SizedBox(height: 6),
            Text('We show doctors near you first.'.tr, style: OpText.small),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(child: OpButton(label: 'Save and continue'.tr, loading: _busy, onPressed: _ok ? _save : null)),
    );
  }
}

/// Name, age and gender fields. Also used for My details and for direct patients.
class GenderAgeNameForm extends StatelessWidget {
  const GenderAgeNameForm({
    super.key,
    required this.name,
    required this.age,
    required this.gender,
    required this.onGender,
    required this.onChanged,
    this.nameLabel = 'Your name',
  });

  final TextEditingController name;
  final TextEditingController age;
  final String gender;
  final ValueChanged<String> onGender;
  final VoidCallback onChanged;
  final String nameLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nameLabel, style: OpText.smallStrong),
        const SizedBox(height: 6),
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(hintText: 'Full name'.tr),
        ),
        const SizedBox(height: 18),
        Text('Age'.tr, style: OpText.smallStrong),
        const SizedBox(height: 6),
        SizedBox(
          width: 140,
          child: TextField(
            controller: age,
            keyboardType: TextInputType.number,
            maxLength: 3,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged(),
            style: OpText.monoBody.copyWith(fontSize: 18),
            decoration: InputDecoration(hintText: 'Years'.tr, counterText: '', suffixText: 'years'),
          ),
        ),
        const SizedBox(height: 18),
        Text('Gender'.tr, style: OpText.smallStrong),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (g, icon) in const [('Male', Icons.male), ('Female', Icons.female), ('Other', Icons.person_outline)]) ...[
              Expanded(
                child: TapScale(
                  onTap: () => onGender(g),
                  child: AnimatedContainer(
                    duration: OpMotion.quick,
                    height: 64,
                    decoration: BoxDecoration(
                      color: gender == g ? OpColors.forest : OpColors.card,
                      borderRadius: OpRadius.controlAll,
                      border: Border.all(color: gender == g ? OpColors.forest : OpColors.line, width: 1.3),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: gender == g ? OpColors.paper : OpColors.fern),
                        Text(g.tr, style: OpText.smallStrong.copyWith(color: gender == g ? OpColors.paper : OpColors.ink)),
                      ],
                    ),
                  ),
                ),
              ),
              if (g != 'Other') const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }
}
