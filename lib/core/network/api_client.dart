import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import 'interceptors/auth_interceptor.dart';
import 'models/auth_tokens.dart';
import 'storage/branch_code_storage.dart';
import 'storage/token_storage.dart';

class ApiClient {
  ApiClient._(this.dio);

  final Dio dio;

  static ApiClient create({
    required TokenStorage tokenStorage,
    required RefreshTokenHandler onRefreshToken,
    BranchCodeStore? branchCodeStore,
    VoidCallback? onRefreshFailed,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppEnv.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ),
    );

    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        tokenStorage: tokenStorage,
        branchCodeStore: branchCodeStore,
        onRefreshToken: onRefreshToken,
        onRefreshFailed: onRefreshFailed,
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
      ),
    );

    return ApiClient._(dio);
  }
}

Future<AuthTokens?> noOpRefreshTokenHandler(String _) async {
  return null;
}


