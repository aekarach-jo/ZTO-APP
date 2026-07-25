import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  AppEnv._();

  static String get appEnv => dotenv.env['APP_ENV'] ?? 'dev';

  static String get apiBaseUrl => removeEndpointPort(
    dotenv.env['API_BASE_URL'] ?? 'http://14.207.141.82/api/v1',
  );

  /// Base URL for the Socket.IO chat server (without namespace).
  ///
  /// Defaults to the SAME origin as the REST API (e.g. `http://14.207.141.82`),
  /// which is served by nginx in front of the backend that issues the JWT.
  /// The raw backend port (:3000) can be a different instance/secret and reject
  /// REST-issued tokens with `Unauthorized`, so we reuse the REST origin.
  /// Overridable with the `SOCKET_URL` env var.
  static String get socketBaseUrl {
    final override = dotenv.env['SOCKET_URL']?.trim();
    if (override != null && override.isNotEmpty) {
      return _stripTrailingSlash(override);
    }
    return _deriveSocketBaseUrl(apiBaseUrl);
  }

  /// Resolves a media path returned by the API (e.g. `/uploads/chat/x.jpg`)
  /// to an absolute URL against the API origin. Absolute URLs pass through
  /// unchanged. Used to render chat/profile images.
  static String resolveMediaUrl(String pathOrUrl) {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return trimmed;
    }
    final origin = _deriveSocketBaseUrl(apiBaseUrl);
    return trimmed.startsWith('/') ? '$origin$trimmed' : '$origin/$trimmed';
  }

  static String _deriveSocketBaseUrl(String apiBaseUrl) {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasAuthority) {
      return 'http://14.207.141.82';
    }
    final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://${uri.host}$port';
  }

  static String _stripTrailingSlash(String value) {
    return value.endsWith('/')
        ? value.substring(0, value.length - 1)
        : value;
  }

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
