import '../../../l10n/lang.dart';
import 'pay_runner.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors.dart';
import '../../../mock/data.dart';
import '../../../mock/format.dart';
import '../../../mock/models.dart';
import '../../../state/patient_store.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/doctor_portrait.dart';
import '../../../widgets/op_button.dart';
import '../widgets.dart';

/// Booking in four steps: day → time → check → pay. Then success or failed. Always for the logged-in patient.
class BookingFlow extends ConsumerStatefulWidget {
  const BookingFlow({super.key, required this.doctorId, this.hospitalId});

  final String doctorId;
  final String? hospitalId;

  @override
  ConsumerState<BookingFlow> createState() => _BookingFlowState();
}

enum _Result { none, success, failed }

class _BookingFlowState extends ConsumerState<BookingFlow> {
  Doctor get d => MockData.doctor(widget.doctorId);
  late final String hid = widget.hospitalId ?? d.hospitalIds.first;

  int _step = 1;
  DateTime? _day;
  TimeWindow? _window;
  final _note = TextEditingController();
  bool _agree = false;
  _Result _result = _Result.none;
  Booking? _booking;
  bool _forward = true;

  static const _titles = ['Pick a day', 'Pick your time', 'Check and confirm', 'Pay'];

  @override
  void initState() {
    super.initState();
    // Start on the first day that has free places.
    final next = MockData.nextFree(d);
    _day = next?.$1;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _canNext => switch (_step) {
        1 => _day != null,
        2 => _window != null,
        3 => _agree,
        _ => false,
      };

  void _go(int step) {
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  Future<void> _back() async {
    if (_result == _Result.success) {
      context.go('/bookings');
      return;
    }
    if (_step > 1 && _result == _Result.none) {
      _go(_step - 1);
      return;
    }
    if (_step == 1 && _result == _Result.none) {
      context.popOr('/home');
      return;
    }
    final leave = await confirmSheet(
      context,
      title: 'Leave this booking?'.tr,
      text: 'Your choices will not be saved.'.tr,
      yes: 'Yes, leave'.tr,
      no: 'Stay here'.tr,
    );
    if (leave && mounted) context.popOr('/home');
  }

  Future<void> _pay() async {
    final method = await showModalBottomSheet<(String, bool)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MockPaySheet(amount: d.fee),
    );
    if (method == null || !mounted) return;
    final store = ref.read(patientProvider);
    final (outcome, b) = await runPayment(
      context,
      () => store.payAndBook(
        doctor: d,
        hospitalId: hid,
        day: _day!,
        window: _window!,
        note: _note.text.trim(),
        fail: method.$2,
      ),
    );
    if (!mounted || outcome == PayOutcome.problem) return; // the red note already says what happened
    HapticFeedback.mediumImpact();
    setState(() {
      _booking = b;
      _result = outcome == PayOutcome.booked ? _Result.success : _Result.failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(patientProvider);

    if (_result == _Result.success) return BookingSuccessView(booking: _booking!);
    if (d.bookingsPaused && _result == _Result.none) {
      return OpPage(
        title: 'Book {0}'.trf([d.name]),
        body: EmptyState(
          icon: Icons.pause_circle_outline,
          title: 'Bookings are paused'.tr,
          text: '{0} is not taking new bookings right now. Please try later, or see another doctor.'.trf([d.name]),
          action: 'Find another doctor'.tr,
          onAction: () => context.go('/find'),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: 'Back'.tr, icon: const Icon(Icons.arrow_back), onPressed: _back),
          titleSpacing: 4,
          title: Row(
            children: [
              DoctorPortrait.small(doctor: d, width: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Book {0}'.trf([d.name]), style: OpText.heading, overflow: TextOverflow.ellipsis),
                    Text('${MockData.type(d.typeId).simple} · ${MockData.hospital(hid).name}',
                        style: OpText.small.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          toolbarHeight: 68,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 12),
              child: StepBar(step: _result == _Result.failed ? 4 : _step, total: 4, title: _titles[(_result == _Result.failed ? 4 : _step) - 1].tr),
            ),
          ),
        ),
        body: _result == _Result.failed
            ? _FailedView(onRetry: () {
                setState(() => _result = _Result.none);
                _pay();
              })
            : AnimatedSwitcher(
                duration: OpMotion.page,
                switchInCurve: OpMotion.curve,
                transitionBuilder: (child, a) {
                  final incoming = child.key == ValueKey(_step);
                  final dx = (incoming == _forward) ? 0.12 : -0.12;
                  return FadeTransition(
                    opacity: a,
                    child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a), child: child),
                  );
                },
                child: KeyedSubtree(key: ValueKey(_step), child: _stepBody(store)),
              ),
        bottomNavigationBar: _result == _Result.failed
            ? null
            : BottomBar(
                child: _step < 3
                    ? OpButton(label: 'Next'.tr, icon: Icons.arrow_forward, onPressed: _canNext ? () => _go(_step + 1) : null)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_agree)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('Tick "I understand" above to pay'.tr, style: OpText.small.copyWith(fontSize: 13)),
                            ),
                          OpButton(label: 'Pay {0}'.trf([rupees(d.fee)]), icon: Icons.lock_outline, onPressed: _agree ? _pay : null),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _stepBody(PatientStore store) {
    switch (_step) {
      case 1:
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OpSpace.gutter),
              child: Text('Which day do you want to come?'.tr, style: OpText.title),
            ),
            const SizedBox(height: 16),
            DayStrip(
              doctor: d,
              selected: _day,
              windowsFor: (day) => store.windowsAt(d, day, hid),
              onSelect: (day) => setState(() {
                _day = day;
                _window = null;
              }),
            ),
            const SizedBox(height: 18),
            if (_day != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OpSpace.gutter),
                child: InfoBox(
                  tone: Tone.good,
                  icon: Icons.event_available_outlined,
                  child: Text('{0}\n{1} times free on this day'.trf([longDate(_day!), store.windowsAt(d, _day!, hid).where((w) => w.open).length])),
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OpSpace.gutter),
              child: Text('Grey days: the doctor does not sit, or all places are full.'.tr, style: OpText.small),
            ),
          ],
        );
      case 2:
        return ListView(
          padding: const EdgeInsets.all(OpSpace.gutter),
          children: [
            Text('Pick your time'.tr, style: OpText.title),
            const SizedBox(height: 4),
            Text(longDate(_day!), style: OpText.smallStrong.copyWith(color: OpColors.fern)),
            const SizedBox(height: 16),
            WindowList(
              windows: store.windowsAt(d, _day!, hid),
              selected: _window?.start,
              onSelect: (w) => setState(() => _window = w),
            ),
            const SizedBox(height: 6),
            InfoBox(
              icon: Icons.schedule,
              child: Text('Come at the start of your time. The doctor may see you any time within this hour.'.tr),
            ),
          ],
        );
      default:
        final h = MockData.hospital(hid);
        final reach = DateTime(_day!.year, _day!.month, _day!.day, _window!.start).subtract(const Duration(minutes: 15));
        return ListView(
          padding: const EdgeInsets.all(OpSpace.gutter),
          children: [
            Text('Please check once'.tr, style: OpText.title),
            const SizedBox(height: 16),
            OpCard(
              raised: true,
              child: Column(
                children: [
                  Row(
                    children: [
                      DoctorPortrait(doctor: d, width: 64, seal: false, band: false),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.name, style: OpText.heading),
                            Text(MockData.type(d.typeId).simple, style: OpText.smallStrong.copyWith(color: OpColors.fern)),
                            Text(d.degrees, style: OpText.small.copyWith(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  KeyValueRow('Hospital', h.name),
                  KeyValueRow('Day', longDate(_day!)),
                  KeyValueRow('Your time', windowLabel(_window!.start), mono: true, strong: true),
                  KeyValueRow('Reach by', clockLabel(reach), mono: true),
                  KeyValueRow('Patient', '${store.me.name} (you)'),
                  const Divider(height: 20),
                  KeyValueRow('Doctor fee', rupees(d.fee), mono: true, strong: true),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Tell the doctor your problem (short)'.tr, style: OpText.smallStrong),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              maxLength: 140,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: 'Example: Fever since 2 days (not needed)'.tr),
            ),
            const SizedBox(height: 10),
            Text('BEFORE YOU PAY'.tr, style: OpText.label),
            const SizedBox(height: 8),
            OpCard(
              color: OpColors.paper,
              child: Column(
                children: [
                  _Rule(icon: Icons.check_circle_outline, color: OpColors.fern, text: 'You can change the date or time once, up to 2 hours before.'.tr),
                  _Rule(icon: Icons.cancel_outlined, color: OpColors.alarm, text: 'You cannot cancel after paying.'.tr),
                  _Rule(icon: Icons.currency_rupee, color: OpColors.amber, text: 'If the doctor cancels, you get full money back.'.tr),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TapScale(
              onTap: () => setState(() => _agree = !_agree),
              child: Row(
                children: [
                  Checkbox(value: _agree, onChanged: (v) => setState(() => _agree = v ?? false)),
                  Expanded(child: Text('I understand'.tr, style: OpText.bodyStrong)),
                ],
              ),
            ),
          ],
        );
    }
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.color, required this.text});

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

// ---------------------------------------------------------------------------
// Mock payment sheet.

/// Mock payment sheet (UPI / card / net banking). Returns (method, makeItFail) or null if closed.
class MockPaySheet extends StatefulWidget {
  const MockPaySheet({super.key, required this.amount});

  final int amount;

  @override
  State<MockPaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<MockPaySheet> {
  String _method = 'UPI';
  bool _fail = false;

  @override
  Widget build(BuildContext context) {
    const methods = [
      ('UPI', 'PhonePe, Google Pay, Paytm', Icons.qr_code_2),
      ('Card', 'Debit or credit card', Icons.credit_card),
      ('Net banking', 'All Indian banks', Icons.account_balance_outlined),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('How do you want to pay?'.tr, style: OpText.title)),
                Text(rupees(widget.amount), style: OpText.mono(22, weight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),
            for (final (name, text, icon) in methods)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TapScale(
                  onTap: () => setState(() => _method = name),
                  child: AnimatedContainer(
                    duration: OpMotion.quick,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _method == name ? OpColors.mint : OpColors.card,
                      borderRadius: OpRadius.controlAll,
                      border: Border.all(color: _method == name ? OpColors.fern : OpColors.line, width: _method == name ? 2 : 1.2),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: OpColors.forest),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [Text(name, style: OpText.bodyStrong), Text(text, style: OpText.small.copyWith(fontSize: 13))],
                          ),
                        ),
                        Icon(_method == name ? Icons.radio_button_checked : Icons.radio_button_off, color: OpColors.fern),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 16, color: OpColors.inkSoft),
                const SizedBox(width: 6),
                Expanded(child: Text('Safe payment by Cashfree'.tr, style: OpText.small.copyWith(fontSize: 13))),
              ],
            ),
            const SizedBox(height: 8),
            // Test build only: lets the team see the failed screen.
            Row(
              children: [
                Switch(value: _fail, onChanged: (v) => setState(() => _fail = v)),
                const SizedBox(width: 6),
                Expanded(child: Text('Test: make this payment fail'.tr, style: OpText.small)),
              ],
            ),
            const SizedBox(height: 12),
            OpButton(label: 'Pay {0}'.trf([rupees(widget.amount)]), onPressed: () => Navigator.pop(context, (_method, _fail))),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result screens.

class _FailedView extends StatefulWidget {
  const _FailedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  State<_FailedView> createState() => _FailedViewState();
}

class _FailedViewState extends State<_FailedView> {
  int _left = 600;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _left = (_left - 1).clamp(0, 600));
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mm = (_left ~/ 60).toString();
    final ss = (_left % 60).toString().padLeft(2, '0');
    return ListView(
      padding: const EdgeInsets.all(OpSpace.gutter),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: OpColors.alarmWash, borderRadius: OpRadius.cardAll, border: Border.all(color: OpColors.alarm, width: 2)),
            child: const Icon(Icons.close, color: OpColors.alarm, size: 48),
          ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),
        ),
        const SizedBox(height: 20),
        Text('Payment did not go through'.tr, style: OpText.title, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('No money was taken from your account.'.tr, style: OpText.body.copyWith(color: OpColors.inkSoft), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        InfoBox(
          tone: Tone.warn,
          icon: Icons.timer_outlined,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: 'Your place is kept for '.tr),
            TextSpan(text: '$mm:$ss', style: OpText.monoBody.copyWith(fontWeight: FontWeight.w600)),
            TextSpan(text: ' minutes. Please try again.'.tr),
          ])),
        ),
        const SizedBox(height: 24),
        OpButton(label: 'Try again'.tr, icon: Icons.refresh, onPressed: _left > 0 ? widget.onRetry : null),
        const SizedBox(height: 10),
        OpButton.secondary(label: 'Go back to home'.tr, onPressed: () => context.go('/home')),
      ],
    );
  }
}

class BookingSuccessView extends StatelessWidget {
  const BookingSuccessView({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final h = MockData.hospital(booking.hospitalId);
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
              Center(child: const _DrawnTick()),
              const SizedBox(height: 16),
              Text('Booking done!'.tr, style: OpText.display, textAlign: TextAlign.center)
                  .animate()
                  .fadeIn(delay: 350.ms, duration: 300.ms),
              const SizedBox(height: 6),
              Text('We also sent this to your messages.'.tr, style: OpText.body.copyWith(color: OpColors.inkSoft), textAlign: TextAlign.center)
                  .animate()
                  .fadeIn(delay: 450.ms, duration: 300.ms),
              const SizedBox(height: 24),
              VisitTicket(
                booking: booking,
                footer: StatusTag('Please reach by {0}'.trf([clockLabel(booking.windowStart.subtract(const Duration(minutes: 15)))]),
                    tone: Tone.info, icon: Icons.directions_walk, big: true),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 350.ms)
                  .slideY(begin: -0.25, end: 0, delay: 500.ms, duration: 550.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 16),
              OpCard(
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, color: OpColors.fern),
                    const SizedBox(width: 10),
                    Expanded(child: Text(h.address, style: OpText.body.copyWith(fontSize: 15))),
                  ],
                ),
              ).animate().fadeIn(delay: 800.ms),
              const SizedBox(height: 20),
              OpButton(label: 'Get directions'.tr, icon: Icons.directions_outlined, onPressed: () => showDirectionsSheet(context, h)),
              const SizedBox(height: 10),
              OpButton.secondary(label: 'Go to my bookings'.tr, onPressed: () => context.go('/bookings')),
            ],
          ),
        ),
      ),
    );
  }
}

/// A green square with a tick that draws itself.
class _DrawnTick extends StatelessWidget {
  const _DrawnTick();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Transform.scale(
        scale: 0.7 + 0.3 * Curves.easeOutBack.transform(t.clamp(0, 1)),
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: OpColors.forest, borderRadius: OpRadius.cardAll),
          child: CustomPaint(painter: _TickPainter(t)),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = OpColors.leaf
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.27, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.34);
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), p);
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.t != t;
}
