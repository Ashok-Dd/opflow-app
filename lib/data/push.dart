import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/errors.dart';
import '../router/app_router.dart';
import '../state/session.dart';
import 'api.dart';
import 'config.dart';

/// Push notifications on Android and iPhone, through Firebase Cloud Messaging (FCM delivers to iPhones via
/// Apple's service). API mode only: demo mode and the web version never start Firebase.
///
/// The server sends the notifications ("Your turn is near", "Money back sent"). The app only has to:
/// ask permission after login, tell the server this phone's token, and open the right screen on a tap.
class Push {
  Push._();
  static final instance = Push._();

  bool _ready = false;
  final _local = FlutterLocalNotificationsPlugin();
  int _nextId = 1;
  RemoteMessage?
  _pending; // tapped while the app was closed: opened after the splash

  static const _system = MethodChannel('opflow/notifications');

  /// Whether this phone lets OPflow show notifications (null: not checked yet). Some phones (Vivo, Oppo, Xiaomi…)
  /// switch them off for apps installed outside the Play Store, and pushes then arrive but never show.
  final allowed = ValueNotifier<bool?>(null);

  Future<void> checkAllowed() async {
    if (!_supported) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        allowed.value = await _system.invokeMethod<bool>('enabled') ?? true;
      } else if (_ready) {
        final st = (await FirebaseMessaging.instance.getNotificationSettings()).authorizationStatus;
        allowed.value = st == AuthorizationStatus.authorized || st == AuthorizationStatus.provisional;
      }
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'push.checkAllowed');
    }
  }

  /// "Turn on": ask once more (Android 13+ / iPhone show the system question), else open OPflow's settings.
  Future<void> turnOn() async {
    try {
      if (_ready) await FirebaseMessaging.instance.requestPermission();
      await checkAllowed();
      if (allowed.value == false && defaultTargetPlatform == TargetPlatform.android) {
        await _system.invokeMethod<bool>('openSettings');
      }
      if (allowed.value == true) unawaited(register());
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'push.turnOn');
    }
  }

  /// Every push that arrives while the app is open (its data), so open screens can refresh at once.
  static final arrived = StreamController<Map<String, dynamic>>.broadcast();

  static bool get _supported => AppConfig.isApi && !kIsWeb;

  /// Called once from main(). Never throws: without push the app still works.
  Future<void> start() async {
    if (!_supported) return;
    try {
      await Firebase.initializeApp();
      final m = FirebaseMessaging.instance;
      _ready = true;
      // iPhone: show the banner even while the app is open. Android: [_onForeground] posts it itself.
      await m.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      // Android only: it draws notifications itself while the app is open. (iPhone shows them natively, and
      // this setup without iPhone settings would fail there and stop the rest of push from being set up.)
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _local.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_opflow'),
          ),
          onDidReceiveNotificationResponse: (r) {
            final p = r.payload;
            if (p == null) return;
            final to = routeFor(
              Map<String, dynamic>.from(jsonDecode(p) as Map),
              SessionStore.instance.side,
            );
            if (to != null) appRouter.push(to);
          },
        );
      }
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      m.onTokenRefresh.listen((t) => _send(t));
      _pending = await m.getInitialMessage();
      if (SessionStore.instance.side != Side.none) unawaited(register());
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'push.start');
    }
  }

  /// After a login (and at each start): asks permission once, then tells the server this phone's token.
  Future<void> register() async {
    if (!_ready) return;
    try {
      final m = FirebaseMessaging.instance;
      final s = await m.requestPermission();
      if (s.authorizationStatus == AuthorizationStatus.denied) return;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // The Apple token arrives a moment after permission; FCM needs it first.
        for (var i = 0; i < 5 && await m.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      final token = await m.getToken();
      if (token != null) await _send(token);
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'push.register');
    }
  }

  Future<void> _send(String token) async {
    if (SessionStore.instance.side == Side.none || !Api.instance.hasSession) {
      return;
    }
    try {
      await Api.instance.post('/v1/me/devices', {
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'fcmToken': token,
        'appVersion': AppConfig.appVersion,
      });
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'push.send');
    }
  }

  /// Android shows nothing for a push while the app is open, so the app posts it in the notification bar
  /// itself (same channel, icon and tap action as a push that arrives in the background).
  void _onForeground(RemoteMessage msg) {
    arrived.add(msg.data);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return; // the system banner shows
    }
    final n = msg.notification;
    if (n == null) return;
    _local
        .show(
          id: _nextId++,
          title: n.title,
          body: n.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'opflow',
              'Bookings and your line',
              channelDescription:
                  'Booking updates, reminders and when your turn is near',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_stat_opflow',
              color: Color(0xFF0B3A2E),
              styleInformation: DefaultStyleInformation(true, true),
            ),
          ),
          payload: jsonEncode(msg.data),
        )
        .catchError(
          (Object e, StackTrace st) =>
              ErrorReporter.report(e, st, where: 'push.foreground'),
        );
  }

  /// Called by the splash once it has moved on, so a tap from a closed app lands on the right screen.
  void openPending() {
    final m = _pending;
    _pending = null;
    if (m != null) _open(m);
  }

  void _open(RemoteMessage msg) {
    final to = routeFor(msg.data, SessionStore.instance.side);
    if (to != null) appRouter.push(to);
  }

  /// The screen a tapped notification opens. Unknown or empty data: none (the app just opens).
  @visibleForTesting
  static String? routeFor(Map<String, dynamic> data, Side side) {
    final booking = data['bookingId'];
    switch (side) {
      case Side.patient:
        if (booking is String && booking.isNotEmpty) return '/booking/$booking';
        return '/messages';
      case Side.doctor:
        if (booking is String && booking.isNotEmpty) {
          return '/d/booking/$booking';
        }
        return '/d/messages';
      case Side.none:
        return null;
    }
  }
}
