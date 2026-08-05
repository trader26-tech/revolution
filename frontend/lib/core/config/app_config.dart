import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// App-wide configuration and environment values.
///
/// [apiBaseUrl] resolution order:
///   1. A build-time override always wins — pass your deployed URL for
///      release builds:
///        flutter build apk --dart-define=API_BASE_URL=https://api.example.com
///   2. Otherwise, for local dev, we pick the address that actually reaches a
///      backend running on *this dev machine's* localhost, which differs per
///      platform:
///        - Android emulator: 10.0.2.2  (the emulator's alias for the host;
///          its own "localhost" is the emulated device, not your Mac)
///        - iOS simulator / web / desktop: localhost
class AppConfig {
  const AppConfig._();

  static const String appName = 'Revolution';

  /// Explicit override from `--dart-define=API_BASE_URL=...`. Empty when unset.
  static const String _override =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static const int _devPort = 8000;

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    return 'http://${_devHost()}:$_devPort';
  }

  static String _devHost() {
    // Web and desktop reach the host's localhost directly.
    if (kIsWeb) return 'localhost';
    // The Android emulator cannot see the host as "localhost"; 10.0.2.2 is the
    // special loopback-to-host alias. iOS simulator uses localhost as normal.
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }
}
