/// Build-time API configuration.
///
/// Override per flavour:
/// `flutter run --dart-define=WISHTICK_API_BASE_URL=https://api.wishtick.app`
abstract final class ApiConfig {
  static const host = String.fromEnvironment(
    'WISHTICK_API_BASE_URL',
    // Android emulator loopback to the host machine's NestJS dev server.
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// The backend sets a global prefix (`API_PREFIX`, default `api`) and URI
  /// versioning with default version `1` — see `wishtick_backend/src/main.ts`.
  /// So a controller route `auth/login` is served at `/api/v1/auth/login`.
  static const prefix = 'api';
  static const version = 'v1';

  static String get baseUrl => '$host/$prefix/$version';

  /// `/health` and `/ready` are mounted outside the prefix for orchestrators.
  static String get healthUrl => '$host/health';

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 20);
}
