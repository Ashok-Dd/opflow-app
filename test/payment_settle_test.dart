// The payment screen must never say "did not go through" when the money was taken, and never say "booked"
// when it was not. The phone's Checkout result is only a hint: the server decides.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opflow/data/api.dart';
import 'package:opflow/data/config.dart';
import 'package:opflow/mock/data.dart';
import 'package:opflow/mock/models.dart';
import 'package:opflow/state/patient_store_api.dart';

Map<String, dynamic> _booking(String status) => {
      'id': 'b-1',
      'status': status,
      'doctor': {'id': 'd1', 'name': 'Dr. Srinivas Rao', 'type': 'Child doctor'},
      'hospital': {'id': 'h1'},
      'date': '2026-09-27',
      'time': {'startsAt': '2026-09-27T04:30:00Z'},
      'token': 7,
      'fee': {'paise': 30000},
      'emergencyCharge': {'paise': 0},
      'payment': {'orderId': 'order_1'},
      'refunds': [],
    };

/// A fake server: the hold works; Checkout "fails"; then /check answers with [checkStatus].
MockClient _server(String checkStatus, {required bool paid, List<String>? calls}) => MockClient((req) async {
      calls?.add(req.url.path);
      final json = {'content-type': 'application/json'};
      switch (req.url.path) {
        case '/v1/bookings/hold':
          return http.Response(jsonEncode({'booking': _booking('pending_payment'), 'payment': {'fake': true, 'orderId': 'order_1', 'amount': {'paise': 30000}}}), 201, headers: json);
        case '/v1/dev/cashfree/pay':
          // What the phone sees: "payment failed" (a UPI app, a timeout…).
          return http.Response(jsonEncode({'error': {'code': 'PAYMENT_FAILED', 'message': 'The payment did not go through.'}}), 402, headers: json);
        case '/v1/payments/b-1/check':
          return http.Response(jsonEncode({'status': checkStatus, 'paid': paid, 'booking': _booking(checkStatus)}), 200, headers: json);
      }
      return http.Response('{}', 404, headers: json);
    });

Future<Booking?> _pay() => ApiPatientStore().payAndBook(
      doctor: MockData.doctor('d1'),
      hospitalId: 'h1',
      day: DateTime(2026, 9, 27),
      window: const TimeWindow(start: 10, capacity: 4, booked: 0, id: 'w-1'),
      note: '',
    );

void main() {
  setUp(() => AppConfig.override(api: true, base: 'http://test.local'));
  tearDown(() => AppConfig.override());

  test('Checkout said "failed" but the money was taken: the booking is shown, not a failure', () async {
    final calls = <String>[];
    Api.instance = Api(tokens: MemoryTokenStore(), client: _server('confirmed', paid: true, calls: calls));
    final b = await _pay();
    expect(b, isNotNull);
    expect(b!.token, 7);
    expect(calls, contains('/v1/payments/b-1/check'));
  });

  test('really not paid: the failure screen (no booking), and a booking waiting for payment is never "booked"', () async {
    Api.instance = Api(tokens: MemoryTokenStore(), client: _server('pending_payment', paid: false));
    expect(await _pay(), isNull);
  });
}
