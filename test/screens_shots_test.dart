// Screenshots of the main screens, with the real fonts, for design reviews. Off by default:
//   flutter test test/screens_shots_test.dart --dart-define=SHOTS=1 --update-goldens
// Pictures land in test/shots/ (not checked: nothing is compared, they are only written).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opflow/l10n/lang.dart';
import 'package:opflow/main.dart';
import 'package:opflow/router/app_router.dart';
import 'package:opflow/state/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _on = String.fromEnvironment('SHOTS') == '1';
const _telugu = String.fromEnvironment('TELUGU') == '1';

const _shots = {
  'who': '/who',
  'login': '/login',
  'otp': '/login/otp',
  'about': '/login/about',
  'home': '/home',
  'find': '/find',
  'doctors': '/doctors?type=child',
  'doctor': '/doctor/d1',
  'hospital': '/hospital/h1',
  'book': '/book/d1',
  'bookings': '/bookings',
  'booking': '/booking/b1',
  'me': '/me',
  'messages': '/messages',
  'emergency': '/emergency',
  'first_aid': '/emergency/snake',
  'place': '/me/place',
  'help': '/me/help',
  'd_login': '/doctor-login',
  'd_today': '/d/today',
  'd_bookings': '/d/bookings',
  'd_timings': '/d/timings',
  'd_me': '/d/me',
  'd_profile': '/d/me/profile',
  'd_messages': '/d/messages',
  'd_alerts': '/d/me/alerts',
};

Future<void> _loadFonts() async {
  Future<ByteData> read(String f) async => ByteData.sublistView(await File('assets/fonts/$f').readAsBytes());
  const fonts = {
    'Newsreader': ['Newsreader.ttf', 'Newsreader-Italic.ttf'],
    'IBMPlexSans': ['IBMPlexSans.ttf'],
    'IBMPlexMono': ['IBMPlexMono-Regular.ttf', 'IBMPlexMono-Medium.ttf', 'IBMPlexMono-SemiBold.ttf'],
    'NotoSansTelugu': ['NotoSansTelugu.ttf', 'NotoSansTelugu-SemiBold.ttf'],
    'OpflowMedIcons': ['OpflowMedIcons.ttf'],
    'MaterialIcons': [],
  };
  for (final e in fonts.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(read(f));
    }
    if (e.key == 'MaterialIcons') {
      final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
      if (icons.existsSync()) loader.addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    }
    await loader.load();
  }
}

void main() {
  if (!_on) {
    test('screenshots (off: pass --dart-define=SHOTS=1 --update-goldens)', () {}, skip: true);
    return;
  }
  setUpAll(_loadFonts);

  testWidgets('screens', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await SessionStore.instance.load();
    if (_telugu) Lang.instance.code = Lang.telugu;
    await tester.pumpWidget(const ProviderScope(child: OpflowApp()));
    appRouter.go('/');
    // The splash: the mark and name, then the OP loader while the app gets ready.
    for (var i = 0; i < 17; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/${_telugu ? 'te_' : ''}splash.png'));
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (final e in _shots.entries) {
      appRouter.go(e.value);
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/${_telugu ? 'te_' : ''}${e.key}.png'));
    }
  });
}
