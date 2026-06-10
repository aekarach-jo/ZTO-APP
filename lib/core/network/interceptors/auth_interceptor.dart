import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/auth_tokens.dart';
import '../storage/token_storage.dart';

typedef RefreshTokenHandler = Future<AuthTokens?> Function(String refreshToken);

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required TokenStorage tokenStorage,
    required RefreshTokenHandler onRefreshToken,
    this.onRefreshFailed,
  })  : _dio = dio,
        _tokenStorage = tokenStorage,
        _onRefreshToken = onRefreshToken;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final RefreshTokenHandler _onRefreshToken;
  final VoidCallback? onRefreshFailed;

  bool _isRefreshing = false;
  Completer<AuthTokens?>? _refreshCompleter;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] == true) {
      return handler.next(options);
    }

    final tokens = await _tokenStorage.read();
    if (tokens?.accessToken case final accessToken?) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final statusCode = err.response?.statusCode;

    final alreadyRetried = request.extra['retriedAfterRefresh'] == true;
    final shouldRefresh =
        statusCode == 401 && !alreadyRetried && request.extra['skipAuth'] != true;

    if (!shouldRefresh) {
      return handler.next(err);
    }

    final currentTokens = await _tokenStorage.read();
    final refreshToken = currentTokens?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      onRefreshFailed?.call();
      return handler.next(err);
    }

    final refreshedTokens = await _refreshTokens(refreshToken);
    if (refreshedTokens == null) {
      onRefreshFailed?.call();
      return handler.next(err);
    }

    final retryOptions = request.copyWith(
      headers: {
        ...request.headers,
        'Authorization': 'Bearer ${refreshedTokens.accessToken}',
      },
      extra: {
        ...request.extra,
        'retriedAfterRefresh': true,
      },
    );

    try {
      final response = await _dio.fetch<dynamic>(retryOptions);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  Future<AuthTokens?> _refreshTokens(String refreshToken) async {
    if (_isRefreshing && _refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<AuthTokens?>();

    try {
      final newTokens = await _onRefreshToken(refreshToken);
      if (newTokens != null) {
        await _tokenStorage.save(newTokens);
      }
      _refreshCompleter?.complete(newTokens);
      return newTokens;
    } catch (_) {
      _refreshCompleter?.complete(null);
      return null;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }
}


