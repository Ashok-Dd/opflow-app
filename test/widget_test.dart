import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opflow/l10n/lang.dart';
import 'package:opflow/core/errors.dart';
import 'package:opflow/main.dart';
import 'package:opflow/mock/data.dart';
import 'package:opflow/mock/first_aid.dart';
import 'package:opflow/router/app_router.dart';
import 'package:opflow/state/directory_store.dart';
import 'package:opflow/state/doctor_store.dart';
import 'package:opflow/state/session.dart';
import 'package:opflow/widgets/op_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every screen, at a small phone size. Any overflow or crash fails the test.
const _routes = [
  '/who',
  '/emergency',
  '/emergency/heart',
  '/emergency/snake',
  '/emergency/other',
  '/emergency/snake/near',
  '/emergency-consult/d1?kind=child',
  '/login',
  '/login/otp',
  '/login/about',
  '/doctor-login',
  '/doctor-login/new-password',
  '/home',
  '/find',
  '/find?tab=1',
  '/find?tab=2',
  '/bookings',
  '/me',
  '/messages',
  '/doctors?type=child',
  '/doctors?problem=fever&who=child',
  '/doctors?hospital=h1',
  '/doctor/d1',
  '/hospital/h1',
  '/problem/fever',
  '/warning?problem=chest',
  '/book/d1',
  '/booking/b1',
  '/booking/b3',
  '/booking/b2/change',
  '/me/details',
  '/me/payments',
  '/me/alerts',
  '/me/help',
  '/me/rules',
  '/me/rules/money',
  '/me/place',
  '/d/today',
  '/d/bookings',
  '/d/timings',
  '/d/me',
  '/d/leave',
  '/d/me/profile',
  '/d/me/hospitals',
  '/d/me/earnings',
  '/d/me/reports',
  '/d/me/password',
  '/d/me/alerts',
  '/d/messages',
];

Future<void> _startApp(WidgetTester tester, {double textScale = 1}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({});
  await SessionStore.instance.load();
  await tester.pumpWidget(const ProviderScope(child: OpflowApp()));
  // The router is shared between tests, so always start from the splash.
  appRouter.go('/');
  await _settle(tester, 3200); // the mark, then the OP loader, then the first screen
}

Future<void> _settle(WidgetTester tester, [int ms = 1800]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Load the real app fonts, so text is measured like on a phone (the default test font is much wider).
Future<void> _loadFonts() async {
  Future<ByteData> read(String f) async => ByteData.sublistView(await File('assets/fonts/$f').readAsBytes());
  const fonts = {
    'Newsreader': ['Newsreader.ttf', 'Newsreader-Italic.ttf'],
    'IBMPlexSans': ['IBMPlexSans.ttf'],
    'IBMPlexMono': ['IBMPlexMono-Regular.ttf', 'IBMPlexMono-Medium.ttf', 'IBMPlexMono-SemiBold.ttf'],
    'NotoSansTelugu': ['NotoSansTelugu.ttf', 'NotoSansTelugu-SemiBold.ttf'],
  };
  for (final e in fonts.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(read(f));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('Splash goes to onboarding, then to Who are you', (tester) async {
    await _startApp(tester);
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await _settle(tester);
    expect(find.textContaining('Who are you?'), findsOneWidget);
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets('Every screen opens without errors (text ×$scale)', (tester) async {
      await _startApp(tester, textScale: scale);
      for (final r in _routes) {
        appRouter.go(r);
        await _settle(tester, 1600);
        expect(tester.takeException(), isNull, reason: 'Error on $r');
      }
    });
  }

  // Telugu words are often longer: every screen must still fit (no overflow) at normal and large text.
  for (final scale in [1.0, 1.5]) {
    testWidgets('Every screen opens in Telugu without errors (text ×$scale)', (tester) async {
      Lang.instance.code = Lang.telugu;
      addTearDown(() => Lang.instance.code = Lang.english);
      await _startApp(tester, textScale: scale);
      for (final r in _routes) {
        appRouter.go(r);
        await _settle(tester, 1600);
        expect(tester.takeException(), isNull, reason: 'Error on $r (Telugu)');
      }
    });
  }

  testWidgets('Switching to Telugu redraws the app at once, and back to English', (tester) async {
    addTearDown(() => Lang.instance.code = Lang.english);
    await _startApp(tester);
    appRouter.go('/who');
    await _settle(tester);
    expect(find.textContaining('Who are you?'), findsOneWidget);
    await tester.tap(find.text('తెలుగు'));
    await _settle(tester);
    expect(find.textContaining('మీరు ఎవరు?'), findsOneWidget);
    expect(find.text('నేను పేషెంట్‌ని'), findsOneWidget);
    await tester.tap(find.text('English'));
    await _settle(tester);
    expect(find.textContaining('Who are you?'), findsOneWidget);
  });

  testWidgets('Bad links show a friendly page, never an error', (tester) async {
    await _startApp(tester);
    for (final r in [
      '/doctor/nope',
      '/hospital/nope',
      '/book/nope',
      '/book/d1?hospital=nope',
      '/booking/nope',
      '/booking/nope/change',
      '/problem/nope',
      '/warning?problem=nope',
      '/emergency/nope',
              '/doctors?type=nope',
      '/doctors?problem=nope',
      '/doctors?hospital=nope',
      '/d/booking/nope',
      '/this/does/not/exist',
    ]) {
      appRouter.go(r);
      await _settle(tester, 1000);
      expect(tester.takeException(), isNull, reason: 'Error on $r');
    }
    appRouter.go('/doctor/nope');
    await _settle(tester, 600);
    expect(find.text('We could not find this doctor'), findsOneWidget);
    // Back with nothing behind it goes home instead of throwing.
    await tester.tap(find.byTooltip('Back'));
    await _settle(tester, 1200);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Good '), findsOneWidget); // back on Home
  });

  testWidgets('A failing action shows a calm message and the app keeps going', (tester) async {
    await _startApp(tester);
    appRouter.go('/home');
    await _settle(tester, 1200);
    final context = tester.element(find.byType(Scaffold).first);
    Object? result = 'not set';
    runWithLoader<int>(context, 'Testing…', () async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      throw const AppFailure('This time just got full. Please pick another.');
    }).then((v) => result = v);
    await _settle(tester, 600);
    expect(result, isNull);
    expect(find.text('This time just got full. Please pick another.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Every emergency situation opens its first-aid page at large text size', (tester) async {
    await _startApp(tester, textScale: 1.5);
    for (final k in MockData.emergencyKinds) {
      appRouter.go('/emergency/${k.id}');
      await _settle(tester, 800);
      expect(find.text('Call 108 — Ambulance'), findsOneWidget, reason: k.id);
      expect(tester.takeException(), isNull, reason: 'Error on first aid ${k.id}');
    }
    // Every situation except "Other" has Do's, Don'ts and at least one WHO source.
    for (final k in MockData.emergencyKinds.where((k) => k.id != 'other')) {
      final g = FirstAid.forKind(k.id);
      expect(g, isNotNull, reason: 'No first aid for ${k.id}');
      expect(g!.dos, isNotEmpty);
      expect(g.donts, isNotEmpty);
      expect(g.callNowIf, isNotEmpty);
      expect(g.sources, isNotEmpty);
    }
  });

  testWidgets('Doctor pauses bookings: patients cannot book; resume opens them again', (tester) async {
    await _startApp(tester);
    final dir = DirectoryStore.instance;
    await tester.runAsync(() => dir.update(MockData.doctor('d1').copyWith(bookingsPaused: true)));
    appRouter.go('/doctor/d1');
    await _settle(tester);
    expect(find.text('Bookings paused'), findsWidgets);
    appRouter.go('/book/d1');
    await _settle(tester);
    expect(find.text('Bookings are paused'), findsOneWidget);
    await tester.runAsync(() => dir.update(MockData.doctor('d1').copyWith(bookingsPaused: false)));
    appRouter.go('/doctor/d1');
    await _settle(tester);
    expect(find.text('Book a time'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Emergency consultation: fee + emergency charge, then an E-token', (tester) async {
    await _startApp(tester);
    appRouter.go('/emergency-consult/d1?kind=child');
    await _settle(tester);
    // Dr. Srinivas Rao: fee ₹300 → emergency charge ₹60 → total ₹360.
    expect(find.text('₹60'), findsOneWidget);
    expect(find.text('₹360'), findsWidgets);
    await tester.scrollUntilVisible(find.text('I understand'), 150, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await _settle(tester, 400);
    await tester.tap(find.text('I understand'));
    await tester.pump();
    await tester.tap(find.text('Pay ₹360').last);
    await _settle(tester, 800);
    await tester.tap(find.text('Pay ₹360').last);
    await _settle(tester, 2600);
    expect(find.text('YOUR EMERGENCY TOKEN'), findsOneWidget);
    expect(find.text('E1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Opens one screen and lets the framework print full error details:
  // flutter test --dart-define=ROUTE=/home --dart-define=SCALE=1.5 --plain-name "Debug one screen"
  testWidgets('Debug one screen', (tester) async {
    const route = String.fromEnvironment('ROUTE');
    if (route.isEmpty) return;
    await _startApp(tester, textScale: double.parse(const String.fromEnvironment('SCALE', defaultValue: '1')));
    for (final r in route.split(',')) {
      appRouter.go(r);
      await _settle(tester, 1600);
    }
  });

  testWidgets('Patient books a doctor and pays', (tester) async {
    await _startApp(tester);
    appRouter.go('/book/d3');
    await _settle(tester);
    // Step 1: a day is already picked.
    await tester.tap(find.text('Next'));
    await _settle(tester, 600);
    // Step 2: pick the first open time.
    final open = find.textContaining(RegExp(r'place(s)? left'));
    await tester.ensureVisible(open.first);
    await _settle(tester, 300);
    // Clear of the bottom "Next" bar: scroll only as far as needed.
    final y = tester.getCenter(open.first).dy;
    if (y > 780 - 200) await tester.drag(find.byType(ListView).first, Offset(0, -(y - 380)));
    await _settle(tester, 400);
    await tester.tap(open.first);
    await tester.pump();
    await tester.tap(find.text('Next'));
    await _settle(tester, 600);
    // Step 3: check, agree and pay (always for the logged-in patient).
    await tester.scrollUntilVisible(find.text('I understand'), 150, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('I understand'));
    await tester.pump();
    await tester.tap(find.text('Pay ₹250').last);
    await _settle(tester, 800);
    await tester.tap(find.text('Pay ₹250').last);
    await _settle(tester, 2600);
    expect(find.text('Booking done!'), findsOneWidget);
  });

  testWidgets('Saved doctor profile shows on the patient doctor page', (tester) async {
    await _startApp(tester);
    final dir = DirectoryStore.instance;
    await tester.runAsync(() => dir.update(MockData.doctor('d1').copyWith(fee: 450, about: 'New about text for patients.')));
    appRouter.go('/doctor/d1');
    await _settle(tester);
    expect(find.text('₹450'), findsWidgets);
    await tester.scrollUntilVisible(find.text('New about text for patients.'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('New about text for patients.'), findsOneWidget);
    // Put the sample back for the other tests.
    await tester.runAsync(() => dir.update(MockData.doctor('d1').copyWith(fee: 300)));
  });

  testWidgets('Doctor bookings: each hour opens to show its patients and closes again', (tester) async {
    await _startApp(tester);
    appRouter.go('/d/bookings');
    await _settle(tester, 1200);
    // Closed: the hour shows who is in it at a glance, not the patient rows.
    final glance = find.textContaining('Harshini, Omkar');
    expect(glance, findsOneWidget);
    expect(find.text('Harshini'), findsNothing);
    await tester.tap(glance);
    await _settle(tester, 800);
    expect(find.text('Harshini'), findsOneWidget); // open: her row
    expect(find.textContaining('Harshini, Omkar'), findsNothing);
    await tester.tap(find.text('Harshini'));
    await _settle(tester, 800);
    expect(find.textContaining('Token'), findsWidgets); // her booking page
    appRouter.go('/d/bookings');
    await _settle(tester, 800);
    // Tap the hour again: closed.
    await tester.tap(find.text('Open all'));
    await _settle(tester, 600);
    expect(find.text('Close all'), findsOneWidget);
    await tester.tap(find.text('Close all'));
    await _settle(tester, 800);
    expect(find.text('Harshini'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Doctor: bell opens Messages; a message opens; settings switch', (tester) async {
    await _startApp(tester);
    appRouter.go('/d/today');
    await _settle(tester, 1200);
    await tester.tap(find.byIcon(Icons.notifications_active_outlined));
    await _settle(tester, 800);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('New booking'), findsOneWidget);
    await tester.tap(find.text('Mark all read'));
    await _settle(tester, 400);
    expect(find.text('Mark all read'), findsNothing);
    appRouter.go('/d/me/alerts');
    await _settle(tester, 800);
    final sw = find.byType(Switch).first;
    expect((tester.widget(sw) as Switch).value, isTrue);
    await tester.tap(sw);
    await _settle(tester, 300);
    expect((tester.widget(find.byType(Switch).first) as Switch).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Doctor Today: no one booked yet shows a kind message, not an empty space', (tester) async {
    await _startApp(tester);
    appRouter.go('/d/today');
    await _settle(tester, 1200);
    final store = ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(doctorProvider);
    store.line.clear();
    store.notifyListeners();
    await _settle(tester, 600);
    await tester.scrollUntilVisible(find.text('No one has booked this session yet'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('No one has booked this session yet'), findsOneWidget);
    if (const String.fromEnvironment('SHOTS') == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/d_today_empty.png'));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Doctor console: start, break, late, pause bookings, call next, end OPD', (tester) async {
    await _startApp(tester);
    appRouter.go('/d/today');
    await _settle(tester, 1200);
    expect(find.text('OPD HOURS TODAY'), findsOneWidget);
    await tester.tap(find.text('START OPD'));
    await _settle(tester, 600);
    expect(find.text('Start OPD now?'), findsOneWidget); // asks first, like the website
    await tester.tap(find.text('Yes, start OPD'));
    await _settle(tester, 1500);
    expect(find.text('CALL NEXT'), findsOneWidget);

    await tester.tap(find.text('Take a break'));
    await _settle(tester, 400);
    expect(find.text('You are on break'), findsOneWidget);
    await tester.tap(find.text('Start again'));
    await _settle(tester, 400);

    await tester.tap(find.text('I am late'));
    await _settle(tester, 600);
    await tester.tap(find.text('+10 min'));
    await _settle(tester, 600);
    expect(find.text('10 min late'), findsOneWidget);

    await tester.tap(find.text('Pause bookings'));
    await _settle(tester, 600);
    await tester.tap(find.text('Yes, pause bookings'));
    await _settle(tester, 1200);
    expect(find.text('Resume bookings'), findsOneWidget);
    await tester.tap(find.text('Resume bookings'));
    await _settle(tester, 600);
    await tester.tap(find.text('Yes, take bookings'));
    await _settle(tester, 1200);
    expect(find.text('Pause bookings'), findsOneWidget);

    await tester.tap(find.text('CALL NEXT'));
    await _settle(tester, 600);
    expect(find.text('WITH DOCTOR NOW'), findsOneWidget);
    await tester.tap(find.text('Done').first);
    await _settle(tester, 600);

    await tester.scrollUntilVisible(find.text('END OPD'), 300, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400)); // clear of the tab bar
    await _settle(tester, 4500); // the last note ("Bookings open again") goes away
    await tester.tap(find.text('END OPD'));
    await _settle(tester, 600);
    await tester.tap(find.text('Yes, end OPD'));
    await _settle(tester, 800);
    if (find.text('Move them to another day').evaluate().isNotEmpty) {
      await tester.tap(find.text('Move them to another day'));
    }
    await _settle(tester, 2400);
    expect(find.text('OPD is over'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Doctor logs in, starts OPD and calls the next patient', (tester) async {
    await _startApp(tester);
    appRouter.go('/doctor-login');
    await _settle(tester, 600);
    await tester.enterText(find.byType(TextField).at(0), 'OPD-10234');
    await tester.enterText(find.byType(TextField).at(1), 'demo1234');
    await tester.pump();
    await tester.tap(find.text('Log in'));
    await _settle(tester, 2000);
    expect(find.text('Set your own password'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'newpass123');
    await tester.enterText(find.byType(TextField).at(1), 'newpass123');
    await tester.pump();
    await tester.tap(find.text('Save password'));
    await _settle(tester, 1500);
    expect(find.text('START OPD'), findsOneWidget);
    await tester.tap(find.text('START OPD'));
    await _settle(tester, 600);
    expect(find.text('Start OPD now?'), findsOneWidget); // asks first, like the website
    await tester.tap(find.text('Yes, start OPD'));
    await _settle(tester, 1500);
    expect(find.text('CALL NEXT'), findsOneWidget);
    await tester.tap(find.text('CALL NEXT'));
    await _settle(tester, 600);
    expect(find.text('WITH DOCTOR NOW'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
