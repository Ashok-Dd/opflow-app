import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

/// An error from the API, already in simple English (the server writes the message for people).
class ApiException implements Exception {
  ApiException(this.code, this.message, {this.status = 0, this.retryable = false, this.details});

  final String code;
  final String message;
  final int status;
  final bool retryable;
  final Map<String, dynamic>? details;

  @override
  String toString() => message;
}

/// Where the login tokens are kept: the phone's secure storage (Keychain / Keystore).
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureTokenStore implements TokenStore {
  static const _s = FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _s.read(key: key);
    } catch (_) {
      return null; // a broken keystore must never crash the app: the user just logs in again
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _s.write(key: key, value: value);
    } catch (_) {}
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _s.delete(key: key);
    } catch (_) {}
  }
}

class MemoryTokenStore implements TokenStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
}

/// The one way the app talks to the OPflow API.
///
/// - Access token (15 min) + refresh token (30 days) in secure storage. A 401 refreshes once, then retries; parallel
///   requests share that one refresh (the server treats a reused refresh token as stolen).
/// - Changing requests carry an Idempotency-Key, so a retry after a timeout never books or pays twice.
/// - Every failure becomes an [ApiException] with a message the screens can show as it is.
class Api {
  Api({TokenStore? tokens, http.Client? client})
      : _tokens = tokens ?? SecureTokenStore(),
        _http = client ?? http.Client();

  static Api instance = Api();

  final TokenStore _tokens;
  final http.Client _http;
  String? _access;
  String? _refresh;
  Future<_Refresh>? _refreshing;

  /// Called when the session is over (refresh refused): the app goes back to login.
  VoidCallback? onSignedOut;

  bool get hasSession => _refresh != null;

  /// An access token with at least 90 seconds left (refreshed first if needed), for the live connection.
  Future<String?> freshAccessToken() async {
    if (_access == null || _expiresWithin(_access!, 90)) {
      if (_refresh == null || await _refreshOnce() != _Refresh.ok) return null;
    }
    return _access;
  }

  static bool _expiresWithin(String jwt, int seconds) {
    try {
      final part = jwt.split('.')[1];
      final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part)))) as Map;
      final exp = (claims['exp'] as num).toInt();
      return exp * 1000 - DateTime.now().millisecondsSinceEpoch < seconds * 1000;
    } catch (_) {
      return true;
    }
  }

  Future<void> load() async {
    _access = await _tokens.read('opf_access');
    _refresh = await _tokens.read('opf_refresh');
  }

  Future<void> saveTokens(Map<String, dynamic> pair) async {
    _access = pair['accessToken'] as String?;
    _refresh = pair['refreshToken'] as String?;
    if (_access != null) await _tokens.write('opf_access', _access!);
    if (_refresh != null) await _tokens.write('opf_refresh', _refresh!);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    await _tokens.delete('opf_access');
    await _tokens.delete('opf_refresh');
  }

  /// Logs out on the server too (best effort), then forgets the tokens.
  Future<void> logout() async {
    final r = _refresh;
    if (r != null) {
      try {
        await post('/v1/auth/logout', {'refreshToken': r}, false);
      } catch (_) {}
    }
    await clear();
  }

  Future<dynamic> get(String path, {Map<String, Object?>? query, bool auth = true}) => _send('GET', path, query: query, auth: auth);
  Future<dynamic> post(String path, [Object? body, bool auth = true, bool idempotent = false]) =>
      _send('POST', path, body: body ?? const <String, Object?>{}, auth: auth, idempotent: idempotent);
  Future<dynamic> postOnce(String path, [Object? body]) => post(path, body, true, true);
  Future<dynamic> put(String path, Object? body) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, Object? body) => _send('PATCH', path, body: body);

  static String newKey() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool auth = true,
    bool idempotent = false,
    String? key,
    bool retried = false,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}$path').replace(
      queryParameters: query == null
          ? null
          : {
              for (final e in query.entries)
                if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
            },
    );
    final idem = idempotent ? (key ?? newKey()) : null;
    final headers = <String, String>{
      'accept': 'application/json',
      'x-app-version': AppConfig.appVersion,
      if (body != null) 'content-type': 'application/json',
      if (auth && _access != null) 'authorization': 'Bearer $_access',
      'idempotency-key': ?idem,
    };

    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      // 45 s: a free-plan server can take up to a minute to wake up; a short limit would report errors for work that succeeds.
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 45)));
    } on TimeoutException {
      throw ApiException('TIMEOUT', 'This is taking too long. Please check your internet and try again.', retryable: true);
    } catch (_) {
      throw ApiException('OFFLINE', 'No internet connection. Please check and try again.', retryable: true);
    }

    if (res.statusCode == 401 && auth && !retried && _refresh != null) {
      switch (await _refreshOnce()) {
        case _Refresh.ok:
          return _send(method, path, query: query, body: body, auth: auth, idempotent: idempotent, key: idem, retried: true);
        case _Refresh.unreachable:
          // No internet / slow server: the login is still good. Never sign someone out for a bad signal.
          throw ApiException('OFFLINE', 'No internet connection. Please check and try again.', retryable: true);
        case _Refresh.refused:
          await clear();
          onSignedOut?.call();
      }
    }

    final text = utf8.decode(res.bodyBytes);
    dynamic data;
    try {
      data = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      data = text;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final err = data is Map && data['error'] is Map ? data['error'] as Map : const {};
    throw ApiException(
      (err['code'] as String?) ?? 'ERROR',
      (err['message'] as String?) ?? 'Something went wrong. Please try again.',
      status: res.statusCode,
      retryable: (err['retryable'] as bool?) ?? res.statusCode >= 500,
      details: err['details'] is Map ? Map<String, dynamic>.from(err['details'] as Map) : null,
    );
  }

  /// One refresh at a time. Only the server's own "no" (401/403: expired, logged out, reused) ends the session;
  /// no internet, a timeout or a server error keep it.
  Future<_Refresh> _refreshOnce() {
    return _refreshing ??= () async {
      try {
        final pair = await _send('POST', '/v1/auth/refresh', body: {'refreshToken': _refresh}, auth: false, retried: true);
        await saveTokens(Map<String, dynamic>.from(pair as Map));
        return _Refresh.ok;
      } on ApiException catch (e) {
        return e.status == 401 || e.status == 403 ? _Refresh.refused : _Refresh.unreachable;
      } catch (_) {
        return _Refresh.unreachable;
      } finally {
        _refreshing = null;
      }
    }();
  }
}

enum _Refresh { ok, refused, unreachable }
