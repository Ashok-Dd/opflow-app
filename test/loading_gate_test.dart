import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opflow/data/api.dart';
import 'package:opflow/data/config.dart';
import 'package:opflow/data/remote.dart';
import 'package:opflow/widgets/directory_gate.dart';
import 'package:opflow/widgets/op_loader.dart';

void main() {
  testWidgets('live build: the OP loader shows while doctors load, then "Try again" if the server cannot be reached', (tester) async {
    AppConfig.override(api: true, base: 'http://127.0.0.1:9');
    Api.instance = Api(tokens: MemoryTokenStore(), client: MockClient((_) async => http.Response('{}', 503)));
    addTearDown(() => AppConfig.override());
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DirectoryGate(builder: (_) => const Text('DOCTORS')))));
    expect(find.byType(OpLoadingPanel), findsOneWidget);
    expect(find.text('DOCTORS'), findsNothing);
    // The request fails (no server): the loader gives way to a retry button.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('DOCTORS'), findsNothing);
    Remote.instance.stopRetrying();
  });
}
