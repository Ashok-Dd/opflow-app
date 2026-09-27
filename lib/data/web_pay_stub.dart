/// Phones use razorpay_flutter; this stands in for the web-only Checkout (lib/data/web_pay.dart) there.
Future<Map<String, String>> payInBrowser(Map<String, Object?> options) => throw UnsupportedError('web only');

class WebPayClosed implements Exception {}

class WebPayUnavailable implements Exception {}
