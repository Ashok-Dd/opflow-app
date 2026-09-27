import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Cashfree's web checkout for the web version (iPhone users open OPflow in Safari). Same order and the same
/// server check as the phone app; web/index.html loads Cashfree's script.
@JS('Cashfree')
external JSFunction? get _cashfreeFactory;

/// Opens Cashfree's payment page in this same tab (`redirectTarget: _self`). After paying (or giving up) Cashfree
/// sends the browser to the order's return address, which brings the person back into the app.
/// Throws [WebPayUnavailable] when Cashfree's script could not load (no internet, blocked).
Future<void> payInBrowser(String paymentSessionId, {required bool production}) async {
  final make = _cashfreeFactory;
  if (make == null) throw WebPayUnavailable();
  final options = JSObject()..['mode'] = (production ? 'production' : 'sandbox').toJS;
  final cashfree = make.callAsFunction(null, options) as JSObject?;
  if (cashfree == null) throw WebPayUnavailable();
  final checkout = JSObject()
    ..['paymentSessionId'] = paymentSessionId.toJS
    ..['redirectTarget'] = '_self'.toJS;
  cashfree.callMethod('checkout'.toJS, checkout);
}

class WebPayUnavailable implements Exception {}
