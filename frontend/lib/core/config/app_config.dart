/// App-wide configuration and environment values.
///
/// Override [apiBaseUrl] at build time with:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
class AppConfig {
  const AppConfig._();

  static const String appName = 'Revolution';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
