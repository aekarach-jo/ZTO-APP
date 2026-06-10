import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import '../config/app_env.dart';
import 'interceptors/auth_interceptor.dart';
import 'models/auth_tokens.dart';
import 'storage/token_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return SecureTokenStorage(storage);
});

final refreshTokenHandlerProvider = Provider<RefreshTokenHandler>((ref) {
  return (refreshToken) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppEnv.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ),
    );

    final response = await dio.post<dynamic>(
      '/auth/refresh',
      data: {
        'refreshToken': refreshToken,
      },
      options: Options(extra: {'skipAuth': true}),
    );

    return _tryExtractTokens(response.data);
  };
});

AuthTokens? _tryExtractTokens(dynamic data) {
  if (data is! Map<String, dynamic>) {
    return null;
  }

  final payload =
      data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : data;

  final accessToken = (payload['accessToken'] ?? payload['access_token'])?.toString();
  final refreshToken = (payload['refreshToken'] ?? payload['refresh_token'])?.toString();
  final expiresAt = _parseExpiresAt(
    payload['expiresAt'] ?? payload['expires_at'] ?? payload['accessTokenExpiresAt'],
  );

  if (accessToken == null || accessToken.isEmpty) {
    return null;
  }
  if (refreshToken == null || refreshToken.isEmpty) {
    return null;
  }

  return AuthTokens(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: expiresAt,
  );
}

DateTime? _parseExpiresAt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final refreshHandler = ref.watch(refreshTokenHandlerProvider);

  return ApiClient.create(
    tokenStorage: tokenStorage,
    onRefreshToken: refreshHandler,
    onRefreshFailed: () async {
      await tokenStorage.clear();
    },
  );
});

final authTokensProvider = FutureProvider<AuthTokens?>((ref) {
  return ref.watch(tokenStorageProvider).read();
});

