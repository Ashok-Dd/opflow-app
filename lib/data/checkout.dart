import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';

import 'api.dart';
import 'web_pay_stub.dart' if (dart.library.js_interop) 'web_pay.dart';

/// Which order the checkout was for. Only the order id goes to the server: the server asks Cashfree itself
/// whether it was paid (nothing from the phone is trusted).
typedef CheckoutResult = Map<String, String>;

/// Pays one order on Cashfree.
///
/// - The server says `fake: true` (a local server without Cashfree keys): its stand-in checkout is used, and
///   [fail] makes the payment fail (the demo "make it fail" switch).
/// - The phone app: Cashfree's checkout (UPI, cards, net banking) opens over the app.
/// - The web version (iPhone users in Safari): Cashfree's page opens in this same tab (no pop-ups, which phones
///   block); afterwards Cashfree brings the person back to /pay-return or /pick-return, and this never returns.
Future<CheckoutResult> payOrder(Map<String, dynamic> payment, {bool fail = false}) async {
  final orderId = payment['orderId'] as String;
  if (payment['fake'] == true) {
    await Api.instance.post('/v1/dev/cashfree/pay', {'orderId': orderId, 'fail': fail}, false);
    return {'orderId': orderId};
  }
  final sessionId = payment['paymentSessionId'] as String;
  final production = payment['environment'] == 'production';
  if (kIsWeb) {
    try {
      await payInBrowser(sessionId, production: production);
    } on WebPayUnavailable {
      throw ApiException('PAYMENT_UNAVAILABLE', 'The payment page could not open. Please check your internet and try again.', retryable: true);
    }
    // The page is leaving for Cashfree; nothing after this runs.
    return Completer<CheckoutResult>().future;
  }
  final done = Completer<CheckoutResult>();
  final service = CFPaymentGatewayService();
  service.setCallback(
    (id) {
      if (!done.isCompleted) done.complete({'orderId': id.isEmpty ? orderId : id});
    },
    (CFErrorResponse e, String id) {
      if (done.isCompleted) return;
      final code = (e.getCode() ?? '').toLowerCase();
      done.completeError(code.contains('cancel') || code.contains('dropped')
          ? ApiException('PAYMENT_CANCELLED', 'Payment was not finished. No money was taken. Your place is kept for a few minutes.')
          : ApiException('PAYMENT_FAILED', 'The payment did not go through. No money was taken. Please try again.'));
    },
  );
  try {
    final session = CFSessionBuilder()
        .setEnvironment(production ? CFEnvironment.PRODUCTION : CFEnvironment.SANDBOX)
        .setOrderId(orderId)
        .setPaymentSessionId(sessionId)
        .build();
    service.doPayment(CFWebCheckoutPaymentBuilder().setSession(session).build());
    return await done.future.timeout(const Duration(minutes: 12));
  } on TimeoutException {
    throw ApiException('PAYMENT_TIMEOUT', 'Payment took too long. If money was taken, it will come back automatically.');
  } on ApiException {
    rethrow;
  } catch (_) {
    throw ApiException('PAYMENT_UNAVAILABLE', 'The payment page could not open. Please try again.', retryable: true);
  }
}

/// On the web: this app's own address, so the server can tell Cashfree where to bring the person back.
String? get webReturnTo => kIsWeb ? '${Uri.base.origin}${Uri.base.path}'.replaceAll(RegExp(r'/$'), '') : null;
