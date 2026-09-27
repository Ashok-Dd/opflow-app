// The live WebSocket against a REAL OPflow API. Skipped unless an address is given:
//   flutter test test/live_socket_test.dart --dart-define=API_TEST=http://localhost:3000
import 'package:flutter_test/flutter_test.dart';
import 'package:opflow/data/api.dart';
import 'package:opflow/data/config.dart';
import 'package:opflow/data/live_socket.dart';

const base = String.fromEnvironment('API_TEST');

void main() {
  if (base.isEmpty) {
    test('live socket (skipped: pass --dart-define=API_TEST=http://localhost:3000)', () {}, skip: true);
    return;
  }

  test('a logged-in phone connects to the live line over WebSocket', () async {
    AppConfig.override(api: true, base: base);
    Api.instance = Api(tokens: MemoryTokenStore());
    const phone = '+919000099901';
    final sent = Map<String, dynamic>.from(await Api.instance.post('/v1/auth/patient/otp', {'phone': phone}, false) as Map);
    expect(sent['testCode'], isNotNull, reason: 'needs a server without an SMS provider');
    final pair = Map<String, dynamic>.from(
        await Api.instance.post('/v1/auth/patient/otp/verify', {'phone': phone, 'code': sent['testCode'], 'device': {'platform': 'android'}}, false) as Map);
    await Api.instance.saveTokens(pair);

    await LiveSocket.instance.follow(['01a0d9d4-bd1a-7a99-91e3-d28728ffed32']);
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (!LiveSocket.instance.connected && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    expect(LiveSocket.instance.connected, isTrue);
    LiveSocket.instance.close();
  });
}
