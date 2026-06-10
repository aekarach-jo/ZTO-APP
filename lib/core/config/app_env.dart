import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  AppEnv._();

  static String get appEnv => dotenv.env['APP_ENV'] ?? 'dev';

  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://14.207.141.82:3001/api/v1';

}

Future<void> loadAppEnv({String? fileName}) async {
  final resolvedFileName =
      fileName ?? const String.fromEnvironment('ENV_FILE', defaultValue: '.env');
  try {
    await dotenv.load(fileName: resolvedFileName);
  } catch (_) {
    // Keep app bootable in local/test environments where .env is absent.
  }
}

