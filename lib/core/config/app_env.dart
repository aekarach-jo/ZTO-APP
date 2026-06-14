import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  AppEnv._();

  static String get appEnv => dotenv.env['APP_ENV'] ?? 'dev';

  static String get apiBaseUrl => removeEndpointPort(
    dotenv.env['API_BASE_URL'] ?? 'http://14.207.141.82/api/v1',
  );

  static String removeEndpointPort(String endpoint) {
    final trimmedEndpoint = endpoint.trim();
    final uri = Uri.tryParse(trimmedEndpoint);
    if (uri == null || !uri.hasAuthority || !uri.hasPort) {
      return trimmedEndpoint;
    }

    final portSuffix = ':${uri.port}';
    if (!uri.authority.endsWith(portSuffix)) {
      return trimmedEndpoint;
    }

    final authorityWithoutPort = uri.authority.substring(
      0,
      uri.authority.length - portSuffix.length,
    );
    final originalPrefix = uri.scheme.isEmpty
        ? '//${uri.authority}'
        : '${uri.scheme}://${uri.authority}';
    final updatedPrefix = uri.scheme.isEmpty
        ? '//$authorityWithoutPort'
        : '${uri.scheme}://$authorityWithoutPort';

    return trimmedEndpoint.replaceFirst(originalPrefix, updatedPrefix);
  }
}

Future<void> loadAppEnv({String? fileName}) async {
  final resolvedFileName =
      fileName ??
      const String.fromEnvironment('ENV_FILE', defaultValue: '.env');
  try {
    await dotenv.load(fileName: resolvedFileName);
  } catch (_) {
    // Keep app bootable in local/test environments where .env is absent.
  }
}
