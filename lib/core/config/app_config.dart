/// Central place for values that change between environments.
///
/// The server address can be overridden at build time without touching code:
///   flutter run --dart-define=API_BASE=https://your-server.example.com
class AppConfig {
  const AppConfig._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://labconnect.melticetech.com',
  );

  /// Every endpoint in the guide lives under this prefix.
  static const String apiPrefix = '/api/v1';

  /// Optional tenant slug for servers that do not configure a default tenant.
  static const String defaultTenant = String.fromEnvironment('API_TENANT');

  static const Duration requestTimeout = Duration(seconds: 30);

  /// How long the app may sit in the background before the session is
  /// closed (the guide asks for a lock after "long" in the background).
  static const Duration backgroundLockAfter = Duration(minutes: 5);

  /// Largest page the server accepts.
  static const int maxPageSize = 100;

  /// Safety net so a misbehaving server can never make us loop forever
  /// while following `next` links.
  static const int maxPagesPerList = 50;
}
