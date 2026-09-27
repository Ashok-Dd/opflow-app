import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'api.dart';
import 'config.dart';
import 'web_pay_stub.dart' if (dart.library.js_interop) 'web_pay.dart';

/// What Razorpay Checkout returns after a payment: sent to the server, which checks it with Razorpay.
typedef CheckoutResult = Map<String, String>;

/// Pays one order.
///
/// - The server says `fake: true` (a local server without Razorpay keys): its stand-in Checkout is used, and
///   [fail] makes the payment fail (the demo "make it fail" switch).
/// - Otherwise the real Razorpay Checkout opens (UPI, cards, net banking) on the phone.
/// OPflow's logo in Razorpay's window (without it Razorpay shows the letter "O").
const _logo = 'https://opflow-alpha.vercel.app/icons/Icon-192.png';

Future<CheckoutResult> payOrder(Map<String, dynamic> payment, {required String description, bool fail = false, String? phone, String? bookingId}) async {
  if (payment['fake'] == true) {
    final r = await Api.instance.post('/v1/dev/razorpay/pay', {'orderId': payment['orderId'], 'fail': fail}, false);
    return Map<String, String>.from((r as Map).map((k, v) => MapEntry('$k', '$v')));
  }
  if (kIsWeb) {
    // The web version (iPhone users in Safari): Razorpay's web Checkout, same order and server check.
    try {
      // Redirect mode: the bank / UPI page opens in this same tab (pop-up windows are blocked on iPhones and
      // often come up blank), then the server's return address brings the person back to /pay-return.
      final back = '${Uri.base.origin}${Uri.base.path}'.replaceAll(RegExp(r'/$'), '');
      return await payInBrowser({
        'key': payment['keyId'],
        'order_id': payment['orderId'],
        'amount': (payment['amount'] as Map)['paise'],
        'currency': 'INR',
        'name': 'OPflow',
        'description': description,
        'image': '${Uri.base.origin}/icons/Icon-192.png',
        'prefill': {'contact': ?phone},
        'theme': {'color': '#1F7A5C'},
        if (bookingId != null) ...{
          'redirect': true,
          'callback_url': '${AppConfig.apiBase}/v1/payments/return?b=$bookingId&to=${Uri.encodeComponent(back)}',
        },
      }).timeout(const Duration(minutes: 12));
    } on WebPayClosed {
      throw ApiException('PAYMENT_CANCELLED', 'Payment was not finished. No money was taken. Your place is kept for a few minutes.');
    } on WebPayUnavailable {
      throw ApiException('PAYMENT_UNAVAILABLE', 'The payment window could not open. Please check your internet and try again.', retryable: true);
    } on TimeoutException {
      throw ApiException('PAYMENT_TIMEOUT', 'Payment took too long. If money was taken, it will come back automatically.');
    }
  }
  final done = Completer<CheckoutResult>();
  final rp = Razorpay();
  rp.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
    if (!done.isCompleted) {
      done.complete({'razorpay_order_id': r.orderId ?? '', 'razorpay_payment_id': r.paymentId ?? '', 'razorpay_signature': r.signature ?? ''});
    }
  });
  rp.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
    if (done.isCompleted) return;
    done.completeError(r.code == Razorpay.PAYMENT_CANCELLED
        ? ApiException('PAYMENT_CANCELLED', 'Payment was not finished. No money was taken. Your place is kept for a few minutes.')
        : ApiException('PAYMENT_FAILED', 'The payment did not go through. No money was taken. Please try again.'));
  });
  rp.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse _) {});
  try {
    rp.open({
      'key': payment['keyId'],
      'order_id': payment['orderId'],
      'amount': (payment['amount'] as Map)['paise'],
      'currency': 'INR',
      'name': 'OPflow',
      'description': description,
      'image': _logo,
      'prefill': {'contact': ?phone},
      'theme': {'color': '#1F7A5C'},
    });
    return await done.future.timeout(const Duration(minutes: 12));
  } on TimeoutException {
    throw ApiException('PAYMENT_TIMEOUT', 'Payment took too long. If money was taken, it will come back automatically.');
  } finally {
    rp.clear();
  }
}
