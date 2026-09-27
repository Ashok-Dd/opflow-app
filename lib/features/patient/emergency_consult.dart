import '../../l10n/lang.dart';
import 'booking/pay_runner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../mock/data.dart';
import '../../mock/format.dart';
import '../../mock/models.dart';
import '../../state/directory_store.dart';
import '../../state/patient_store.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/doctor_portrait.dart';
import '../../widgets/op_button.dart';
import 'booking/booking_flow.dart' show MockPaySheet;
import 'widgets.dart';

/// Emergency consultation with a doctor who is available now. The patient pays the doctor's fee plus an
/// emergency charge (the charge is all OPflow's; the fee is split as usual), goes to the hospital now and is
/// seen first with an E-token.
class EmergencyConsultScreen extends ConsumerStatefulWidget {
  const EmergencyConsultScreen({super.key, required this.doctorId, this.kindId});

  final String doctorId;
  final String? kindId;

  @override
  ConsumerState<EmergencyConsultScreen> createState() => _EmergencyConsultScreenState();
}

class _EmergencyConsultScreenState extends ConsumerState<EmergencyConsultScreen> {
  final _note = TextEditingController();
  bool _agree = false;
  Booking? _booking;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final kind = widget.kindId == null ? null : MockData.findEmergencyKind(widget.kindId!);
    if (kind != null && kind.id != 'other') _note.text = kind.name;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pay(Doctor d, int total) async {
    final method = await showModalBottomSheet<(String, bool)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MockPaySheet(amount: total),
    );
    if (method == null || !mounted) return;
    final (outcome, b) = await runPayment(
      context,
      () => ref.read(patientProvider).payEmergency(
            doctor: d,
            hospitalId: d.hospitalIds.first,
            note: _note.text.trim(),
            fail: method.$2,
          ),
    );
    if (!mounted || outcome == PayOutcome.problem) return; // the red note already says what happened
    HapticFeedback.mediumImpact();
    setState(() {
      _booking = b;
      _failed = outcome == PayOutcome.notPaid;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(directoryProvider).doctor(widget.doctorId);
    final h = MockData.hospital(d.hospitalIds.first);
    final charge = MockData.emergencyCharge(d.fee);
    final total = d.fee + charge;

    if (_booking != null) return _Success(booking: _booking!, doctor: d, hospital: h);

    if (!MockData.takesEmergencyNow(d)) {
      return OpPage(
        title: 'Emergency consultation'.tr,
        body: EmptyState(
          icon: Icons.event_busy_outlined,
          title: 'This doctor is not available now'.tr,
          text: 'Please choose another doctor or hospital, or call 108.'.tr,
          action: 'Go back'.tr,
          onAction: () => context.popOr('/emergency'),
        ),
      );
    }

    return OpPage(
      title: 'Emergency consultation'.tr,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 18, OpSpace.gutter, 32),
        children: [
          InfoBox(
            tone: Tone.bad,
            icon: Icons.warning_amber_rounded,
            child: Text('If someone is not breathing, not waking up or bleeding a lot, do not wait: call 108 now.'.tr),
          ),
          const SizedBox(height: 18),
          OpCard(
            raised: true,
            child: Row(
              children: [
                DoctorPortrait(doctor: d, width: 64, seal: false, band: false),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name, style: OpText.heading),
                      Text(MockData.type(d.typeId).simple, style: OpText.smallStrong.copyWith(color: OpColors.fern)),
                      Text('{0} · {1} km'.trf([h.name, h.distanceKm]), style: OpText.small.copyWith(fontSize: 13)),
                      const SizedBox(height: 6),
                      StatusTag(
                        d.emergency == EmergencyStatus.availableTill ? 'Available till ${d.emergencyTill}' : 'Available now',
                        tone: Tone.good,
                        icon: Icons.circle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('What happens'),
          for (final (i, t) in const [
            'You pay now and get an emergency token (E1, E2…).',
            'Go to the hospital straight away. Show your token at reception.',
            'The doctor sees you before the patients in the normal line.',
          ].indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: OpColors.forest, borderRadius: OpRadius.smallAll),
                    child: Text('${i + 1}', style: OpText.mono(13, weight: FontWeight.w600, color: OpColors.paper)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t, style: OpText.body.copyWith(fontSize: 16))),
                ],
              ),
            ),
          const SizedBox(height: 14),
          const SectionLabel('Price'),
          OpCard(
            child: Column(
              children: [
                KeyValueRow('Doctor fee', rupees(d.fee), mono: true),
                KeyValueRow('Emergency charge', rupees(charge), mono: true),
                const Divider(height: 18),
                KeyValueRow('You pay', rupees(total), mono: true, strong: true),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('The emergency charge keeps doctors available for emergencies at short notice.'.tr,
              style: OpText.small.copyWith(fontSize: 13)),
          const SizedBox(height: 20),
          Text('What happened? (short)'.tr, style: OpText.smallStrong),
          const SizedBox(height: 6),
          TextField(
            controller: _note,
            maxLength: 140,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'Example: high fever and fits since morning'.tr),
          ),
          const SizedBox(height: 6),
          OpCard(
            color: OpColors.paper,
            child: Column(
              children: const [
                _Rule(Icons.check_circle_outline, OpColors.fern, 'If the doctor cannot see you, you get your full money back.'),
                _Rule(Icons.cancel_outlined, OpColors.alarm, 'An emergency consultation cannot be changed or cancelled after paying.'),
                _Rule(Icons.info_outline, OpColors.amber, 'This is for urgent problems. For regular check-ups, book a normal time.'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TapScale(
            onTap: () => setState(() => _agree = !_agree),
            child: Row(
              children: [
                Checkbox(value: _agree, onChanged: (v) => setState(() => _agree = v ?? false)),
                Expanded(child: Text('I understand'.tr, style: OpText.bodyStrong)),
              ],
            ),
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            InfoBox(tone: Tone.bad, icon: Icons.error_outline, child: Text('Payment did not go through. No money was taken. Please try again.'.tr)),
          ],
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_agree)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Tick "I understand" above to pay'.tr, style: OpText.small.copyWith(fontSize: 13)),
            ),
          OpButton(
            label: 'Pay {0}'.trf([rupees(total)]),
            icon: Icons.lock_outline,
            kind: OpButtonKind.danger,
            onPressed: _agree ? () => _pay(d, total) : null,
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.icon, this.color, this.text);

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: OpText.body.copyWith(fontSize: 15))),
        ],
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.booking, required this.doctor, required this.hospital});

  final Booking booking;
  final Doctor doctor;
  final Hospital hospital;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/bookings');
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(OpSpace.gutter),
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(color: OpColors.forest, borderRadius: OpRadius.cardAll),
                child: Column(
                  children: [
                    Text('YOUR EMERGENCY TOKEN'.tr, style: OpText.label.copyWith(color: OpColors.mint, letterSpacing: 1.6)),
                    const SizedBox(height: 6),
                    Text(booking.tokenLabel,
                        style: OpText.mono(64, weight: FontWeight.w600, color: OpColors.led)
                            .copyWith(shadows: [Shadow(color: OpColors.led.withValues(alpha: 0.45), blurRadius: 14)])),
                  ],
                ),
              ).animate().scale(begin: const Offset(0.94, 0.94), curve: Curves.easeOutBack, duration: 450.ms),
              const SizedBox(height: 18),
              Text('Go to the hospital now'.tr, style: OpText.display.copyWith(fontSize: 30), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('Show this token at reception. {0} will see you first.'.trf([doctor.name]),
                  textAlign: TextAlign.center, style: OpText.body.copyWith(color: OpColors.inkSoft)),
              const SizedBox(height: 20),
              OpCard(
                child: Column(
                  children: [
                    KeyValueRow('Hospital', hospital.name, strong: true),
                    KeyValueRow('Address', hospital.address),
                    KeyValueRow('You paid', rupees(booking.total), mono: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OpButton(label: 'Get directions'.tr, icon: Icons.directions_outlined, onPressed: () => showDirectionsSheet(context, hospital)),
              const SizedBox(height: 10),
              OpButton.secondary(
                label: 'Call the hospital'.tr,
                icon: Icons.call_outlined,
                onPressed: () => showCallSheet(context, name: hospital.name, phone: hospital.phone),
              ),
              const SizedBox(height: 10),
              OpButton(label: 'Go to my bookings'.tr, kind: OpButtonKind.quiet, onPressed: () => context.go('/bookings')),
            ],
          ),
        ),
      ),
    );
  }
}
