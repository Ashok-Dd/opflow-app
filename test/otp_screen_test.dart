// The code screen: a wrong code must never leave old digits behind (typing again would be ignored and
// "Check code" would resend the same wrong code). After a wrong try, the boxes are empty and a new code works.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opflow/data/api.dart';
import 'package:opflow/data/config.dart';
import 'package:opflow/features/auth/patient_otp.dart';
import 'package:opflow/state/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('wrong code → boxes cleared; the right code then goes through', (tester) async {
    AppConfig.override(api: true, base: 'http://test.local');
    addTearDown(() => AppConfig.override());
    final tried = <String>[];
    Api.instance = Api(
      tokens: MemoryTokenStore(),
      client: MockClient((req) async {
        final json = {'content-type': 'application/json'};
        if (req.url.path == '/v1/auth/patient/otp/verify') {
          final code = (jsonDecode(req.body) as Map)['code'] as String;
          tried.add(code);
          // Only 482913 is right; anything else is "not right" (and no login happens in this test).
          return http.Response(jsonEncode({'error': {'code': 'OTP_INVALID', 'message': 'The code is not right.'}}), 401, headers: json);
        }
        return http.Response('{}', 404, headers: json);
      }),
    );
    SharedPreferences.setMockInitialValues({});
    await SessionStore.instance.load();
    SessionStore.instance
      ..phone = '9392954525'
      ..otpMode = 'sms';

    await tester.pumpWidget(const MaterialApp(home: PatientOtpScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    final field = find.byType(TextField);

    await tester.enterText(field, '111111'); // wrong: checked automatically at 6 digits
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tried, ['111111']);
    expect(find.textContaining('This code is not right'), findsOneWidget);
    // The old digits are gone, so the next code can be typed.
    expect((tester.widget(field) as TextField).controller!.text, isEmpty);

    await tester.enterText(field, '482913');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tried, ['111111', '482913']); // the NEW code was sent, not the old one again
  });

  testWidgets('tapping a box puts the cursor there: a filled box is retyped from that digit', (tester) async {
    AppConfig.override(api: false);
    addTearDown(() => AppConfig.override());
    SharedPreferences.setMockInitialValues({});
    await SessionStore.instance.load();
    SessionStore.instance.phone = '9392954525';
    await tester.pumpWidget(const MaterialApp(home: PatientOtpScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    final field = find.byType(TextField);
    await tester.enterText(field, '1234');
    await tester.pump();
    // The six boxes are the GestureDetectors that hold a digit; tap the second one.
    await tester.tap(find.text('2'), warnIfMissed: false); // the tap lands on the box around the digit
    await tester.pump();
    expect((tester.widget(field) as TextField).controller!.text, '1');
    await tester.enterText(field, '19');
    await tester.pump();
    expect(find.text('9'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
