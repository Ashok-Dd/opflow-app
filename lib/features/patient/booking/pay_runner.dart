import 'package:flutter/material.dart';

import '../../../core/errors.dart';
import '../../../l10n/lang.dart';
import '../../../mock/models.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/op_loader.dart';

/// What happened to a payment, as the screens show it.
enum PayOutcome { booked, notPaid, problem }

/// Runs a payment behind the OP loader. The Cashfree screen can stay open for many minutes (UPI apps), so there
/// is no short time limit. Only a clear "not paid" from the server means [PayOutcome.notPaid]; any other
/// problem (time just got full, no internet, still confirming) is shown as a red note and the screen stays.
Future<(PayOutcome, Booking?)> runPayment(BuildContext context, Future<Booking?> Function() pay) async {
  Booking? booking;
  Object? error;
  await runWithLoader(
    context,
    'Checking your payment…'.tr,
    detail: 'Please do not close the app.'.tr,
    () async {
      try {
        booking = await pay();
      } catch (e) {
        error = e;
      }
    },
    timeout: const Duration(minutes: 20),
  );
  if (error != null) {
    if (context.mounted) showError(context, friendlyMessage(error!));
    return (PayOutcome.problem, null);
  }
  return booking == null ? (PayOutcome.notPaid, null) : (PayOutcome.booked, booking);
}
