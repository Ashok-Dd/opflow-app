import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Razorpay Checkout for the web version (iPhone users open OPflow in Safari). Same order, same keys and the same
/// server check as the phone app; only the payment window is Razorpay's web one (web/index.html loads it).
@JS('Razorpay')
extension type _Razorpay._(JSObject _) implements JSObject {
  external factory _Razorpay(JSObject options);
  external void open();
}

/// Opens Razorpay's web Checkout. Resolves with its three ids; throws [WebPayClosed] when the person closes the
/// window without paying, [WebPayUnavailable] when Razorpay's script could not load (no internet, blocked).
Future<Map<String, String>> payInBrowser(Map<String, Object?> options) {
  if (!globalContext.has('Razorpay')) throw WebPayUnavailable();
  final done = Completer<Map<String, String>>();
  final o = options.jsify() as JSObject;
  o['handler'] = ((JSObject r) {
    String read(String k) => (r[k] as JSString?)?.toDart ?? '';
    if (!done.isCompleted) {
      done.complete({
        'razorpay_order_id': read('razorpay_order_id'),
        'razorpay_payment_id': read('razorpay_payment_id'),
        'razorpay_signature': read('razorpay_signature'),
      });
    }
  }).toJS;
  // A failed try stays inside Razorpay's window (it offers "Retry"); closing the window ends it.
  final modal = JSObject();
  modal['ondismiss'] = (() {
    if (!done.isCompleted) done.completeError(WebPayClosed());
  }).toJS;
  modal['confirm_close'] = true.toJS;
  o['modal'] = modal;
  _Razorpay(o).open();
  return done.future;
}

class WebPayClosed implements Exception {}

class WebPayUnavailable implements Exception {}
