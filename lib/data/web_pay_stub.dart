/// Phones use Cashfree's Flutter SDK; this stands in for the web-only checkout (lib/data/web_pay.dart) there.
Future<void> payInBrowser(String paymentSessionId, {required bool production}) => throw UnsupportedError('web only');

class WebPayUnavailable implements Exception {}
