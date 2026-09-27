import 'package:flutter/foundation.dart';

/// Where the app gets its data.
///
///   flutter run                                   → mock data (no server; demos and widget tests)
///   flutter run --dart-define=BACKEND=api         → the OPflow API at [AppConfig.devServer]
///   flutter run --dart-define=BACKEND=api --dart-define=API_BASE_URL=https://opflow-api.onrender.com
///                                                 → another server, just for this build
class AppConfig {
  AppConfig._();

  static const _backend = String.fromEnvironment('BACKEND', defaultValue: 'mock');
  static const _base = String.fromEnvironment('API_BASE_URL');

  /// ▶ THE SERVER ON YOUR COMPUTER. Change this when the computer's Wi-Fi address changes (Windows: run
  /// `ipconfig` and use the "IPv4 Address" of the Wi-Fi adapter). The phone must be on the same Wi-Fi.
  /// (The web version uses localhost. The Android emulator: use http://10.0.2.2:3000.)
  static const devServer = 'http://10.249.28.154:3000';

  /// The live test server on Render. Build with it: --dart-define=API_BASE_URL=https://opflow-backend.onrender.com
  static const renderServer = 'https://opflow-backend.onrender.com';

  /// The app's own version, sent with every request (old apps are asked to update).
  static const appVersion = '1.0.0';

  static bool? _apiOverride;
  static String? _baseOverride;

  static bool get isApi => _apiOverride ?? _backend == 'api';

  static String get apiBase {
    final b = _baseOverride ?? (_base.isNotEmpty ? _base : _defaultBase());
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

  static String _defaultBase() {
    if (kIsWeb) return 'http://localhost:3000';
    return devServer;
  }

  /// Tests only.
  @visibleForTesting
  static void override({bool? api, String? base}) {
    _apiOverride = api;
    _baseOverride = base;
  }

  /// Guntur centre: used for "near you" until the patient shares a location.
  static const nearLat = 16.3067;
  static const nearLng = 80.4365;
}
