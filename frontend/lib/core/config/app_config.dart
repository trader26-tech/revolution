/// App-wide configuration and environment values.
///
/// [apiBaseUrl] resolution order:
///   1. A build-time override always wins — useful for pointing a build at a
///      staging server or a local backend during development:
///        flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
///   2. Otherwise it defaults to the hosted production backend, so the app
///      works the same on the Android emulator, the iOS simulator, and real
///      physical devices in users' hands — all talk to the live server.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Revolution';

  /// The live, internet-reachable backend. Real devices and emulators alike
  /// connect here by default.
  static const String _productionApiBaseUrl =
      'https://revolution-backend-production.up.railway.app';

  /// Optional override from `--dart-define=API_BASE_URL=...`. Empty when unset.
  static const String _override =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get apiBaseUrl =>
      _override.isNotEmpty ? _override : _productionApiBaseUrl;
}
