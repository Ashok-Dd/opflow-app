import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/errors.dart';
import 'api.dart';
import 'config.dart';

/// The live line over a WebSocket (the server's Socket.IO namespace `/live`): changes arrive the moment the
/// doctor taps, instead of every 10–15 seconds. The stores keep a slow check as a safety net, so the line is
/// still right if the connection drops (lifts, weak signal).
///
/// Patients get `board` (their own place); doctors get `line` (the whole list). Both have the same shape as
/// the polling endpoints, so the stores apply them with the same code.
class LiveSocket {
  LiveSocket._();
  static final instance = LiveSocket._();

  io.Socket? _socket;
  final _sessions = <String>{};
  final _board = StreamController<Map<String, dynamic>>.broadcast();
  final _line = StreamController<Map<String, dynamic>>.broadcast();

  /// A patient's place changed (`sessionId`, `nowSeeing`, `lateMinutes`, `onBreak`, …).
  Stream<Map<String, dynamic>> get boards => _board.stream;

  /// The doctor's whole line changed (same shape as one session in `GET /v1/doctor/today`).
  Stream<Map<String, dynamic>> get lines => _line.stream;

  bool get connected => _socket?.connected ?? false;

  /// Follow these OPD sessions (today's). Connects on first use; leaves sessions no longer listed.
  Future<void> follow(Iterable<String> sessionIds) async {
    if (!AppConfig.isApi) return;
    final wanted = sessionIds.toSet();
    for (final gone in _sessions.difference(wanted)) {
      _socket?.emit('leave', {'sessionId': gone});
    }
    final added = wanted.difference(_sessions);
    _sessions
      ..clear()
      ..addAll(wanted);
    if (_sessions.isEmpty) return;
    if (_socket == null) {
      await _connect();
    } else if (connected) {
      for (final id in added) {
        _socket!.emit('join', {'sessionId': id});
      }
    }
  }

  /// Logged out: stop listening.
  void close() {
    _sessions.clear();
    _socket?.dispose();
    _socket = null;
  }

  Future<void> _connect() async {
    final token = await Api.instance.freshAccessToken();
    if (token == null) return;
    final s = io.io(
      '${AppConfig.apiBase}/live',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(15000)
          .disableAutoConnect()
          .build(),
    );
    _socket = s;
    s.onConnect((_) {
      for (final id in _sessions) {
        s.emit('join', {'sessionId': id});
      }
    });
    // Before each reconnect, a fresh token (the old one may have expired while offline).
    s.io.on('reconnect_attempt', (_) async {
      final t = await Api.instance.freshAccessToken();
      if (t != null) s.auth = {'token': t};
    });
    // The server asks a minute before the token runs out.
    s.on('reauth', (_) async {
      final t = await Api.instance.freshAccessToken();
      if (t != null) {
        s.auth = {'token': t};
        s.emit('auth', {'token': t});
      }
    });
    s.on('board', (data) => _emit(_board, data));
    s.on('line', (data) => _emit(_line, data));
    s.on('error_message', (data) => debugPrint('[live] $data'));
    s.connect();
  }

  void _emit(StreamController<Map<String, dynamic>> c, dynamic data) {
    try {
      if (data is Map) c.add(Map<String, dynamic>.from(data));
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'live.socket');
    }
  }
}
