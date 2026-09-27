import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors.dart';
import '../../../data/remote.dart';
import '../../../l10n/lang.dart';
import '../../../mock/models.dart';
import '../../../state/patient_store.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/op_button.dart';
import '../../../widgets/op_loader.dart';
import 'booking_flow.dart' show BookingSuccessView;

/// The web version comes back here after Cashfree's payment page (redirect mode: no pop-ups, which iPhones
/// block). It asks the server "was I charged?" — the same check the phone app uses — then shows "Booking done!"
/// or "Payment did not go through". Nothing from the address bar is trusted except which booking to check.
class PayReturnScreen extends ConsumerStatefulWidget {
  const PayReturnScreen({super.key, required this.bookingId, required this.checkoutSaidPaid});

  final String bookingId;
  final bool checkoutSaidPaid;

  @override
  ConsumerState<PayReturnScreen> createState() => _PayReturnScreenState();
}

enum _State { checking, booked, notPaid, unsure }

class _PayReturnScreenState extends ConsumerState<PayReturnScreen> {
  _State _state = _State.checking;
  Booking? _booking;
  String? _message;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _state = _State.checking);
    try {
      // The page was reloaded by the bank: load the doctor list first so the booking can be shown.
      Remote.instance.prepare();
      await Remote.instance.loadDirectory().timeout(const Duration(seconds: 20)).catchError((_) {});
      final b = await ref.read(patientProvider).settleReturned(widget.bookingId, checkoutSaidPaid: widget.checkoutSaidPaid);
      if (!mounted) return;
      setState(() {
        _booking = b;
        _state = b == null ? _State.notPaid : _State.booked;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = friendlyMessage(e);
        _state = _State.unsure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _State.booked) return BookingSuccessView(booking: _booking!);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(OpSpace.gutter),
          child: _state == _State.checking
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const OpLoader(size: 72),
                    const SizedBox(height: 16),
                    Text('Checking your payment…'.tr, style: OpText.title, textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Text('Please do not close the app.'.tr, style: OpText.small, textAlign: TextAlign.center),
                  ]),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Icon(_state == _State.notPaid ? Icons.error_outline : Icons.hourglass_top_rounded,
                        size: 56, color: _state == _State.notPaid ? OpColors.alarm : OpColors.amber),
                    const SizedBox(height: 14),
                    Text(_state == _State.notPaid ? 'Payment did not go through'.tr : 'Still confirming your payment'.tr,
                        style: OpText.display, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text(
                      _state == _State.notPaid
                          ? 'No money was taken. Your place is kept for a few minutes: open My bookings to pay again.'.tr
                          : (_message ?? 'Please check My bookings in a minute. If money was taken and there is no booking, it comes back automatically.'.tr),
                      style: OpText.body.copyWith(color: OpColors.inkSoft),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    if (_state == _State.unsure) ...[
                      OpButton(label: 'Check again'.tr, icon: Icons.refresh, onPressed: _check),
                      const SizedBox(height: 10),
                    ],
                    OpButton(
                      label: 'Go to my bookings'.tr,
                      kind: _state == _State.unsure ? OpButtonKind.secondary : OpButtonKind.primary,
                      onPressed: () => context.go('/bookings'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
