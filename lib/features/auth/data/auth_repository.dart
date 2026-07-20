import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/models/auth_tokens.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/storage/current_user_storage.dart';
import '../../../core/network/storage/token_storage.dart';

abstract class AuthRepository {
  Future<void> requestOtpForRegister({required String phoneNumber});

  Future<void> sendForgotPasswordOtp({required String phoneNumber});

  Future<String> verifyForgotPasswordOtp({
    required String phoneNumber,
    required String otp,
  });

  Future<void> resetPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  });

  Future<void> loginWithPassword({
    required String phoneNumber,
    required String password,
  });

  Future<void> registerFcmToken({required String fcmToken});

  Future<void> logout();

  Future<void> registerWithOtp({
    required String phoneNumber,
    required String password,
    required String otp,
  });
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required Dio dio,
    required TokenStorage tokenStorage,
    required CurrentUserStorage currentUserStorage,
  }) : _dio = dio,
       _tokenStorage = tokenStorage,
       _currentUserStorage = currentUserStorage;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final CurrentUserStorage _currentUserStorage;

  @override
  Future<void> requestOtpForRegister({required String phoneNumber}) async {
    await _dio.post<dynamic>(
      '/auth/send-otp',
      data: {'phoneNumber': phoneNumber},
      options: Options(extra: {'skipAuth': true}),
    );
  }

  @override
  Future<void> sendForgotPasswordOtp({required String phoneNumber}) async {
    await _dio.post<dynamic>(
      '/auth/forgot-password/send-otp',
      data: {'phoneNumber': phoneNumber},
      options: Options(extra: {'skipAuth': true}),
    );
  }

  @override
  Future<String> verifyForgotPasswordOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final response = await _dio.post<dynamic>(
      '/auth/forgot-password/verify-otp',
      data: {'phoneNumber': phoneNumber, 'otp': otp},
      options: Options(extra: {'skipAuth': true}),
    );

    final resetToken = _extractResetToken(response.data);
    if (resetToken == null || resetToken.isEmpty) {
      throw const FormatException(
        'Reset token is missing in response payload.',
      );
    }
    return resetToken;
  }

  @override
  Future<void> resetPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  }) async {
    await _dio.post<dynamic>(
      '/auth/forgot-password/reset',
      data: {
        'phoneNumber': phoneNumber,
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
      options: Options(extra: {'skipAuth': true}),
    );
  }

  @override
  Future<void> loginWithPassword({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _dio.post<dynamic>(
      '/auth/login',
      data: {'phoneNumber': phoneNumber, 'password': password},
      options: Options(extra: {'skipAuth': true}),
    );

    final tokens = _extractTokens(response.data);
    await _tokenStorage.save(tokens);
    await _currentUserStorage.savePhoneNumber(phoneNumber);
  }

  @override
  Future<void> registerFcmToken({required String fcmToken}) async {
    final payload = {'fcmToken': fcmToken};
    await _dio.post<dynamic>('/auth/fcm-token', data: payload);
  }

  @override
  Future<void> logout() async {
    await _dio.post<dynamic>('/auth/logout');
    await _tokenStorage.clear();
    await _currentUserStorage.clear();
  }

  @override
  Future<void> registerWithOtp({
    required String phoneNumber,
    required String password,
    required String otp,
  }) async {
    final response = await _dio.post<dynamic>(
      '/auth/register',
      data: {'phoneNumber': phoneNumber, 'password': password, 'otp': otp},
      options: Options(extra: {'skipAuth': true}),
    );

    final extractedTokens = _extractTokens(response.data);
    await _tokenStorage.save(extractedTokens);
    await _currentUserStorage.savePhoneNumber(phoneNumber);
  }

  AuthTokens _extractTokens(dynamic data) {
    final tokens = _tryExtractTokens(data);
    if (tokens == null) {
      throw const FormatException(
        'Auth tokens are missing in response payload.',
      );
    }
    return tokens;
  }

  AuthTokens? _tryExtractTokens(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final payload = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;

    final accessToken = (payload['accessToken'] ?? payload['access_token'])
        ?.toString();
    final refreshToken = (payload['refreshToken'] ?? payload['refresh_token'])
        ?.toString();
    final expiresAt = _parseExpiresAt(
      payload['expiresAt'] ??
          payload['expires_at'] ??
          payload['accessTokenExpiresAt'],
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

  String? _extractResetToken(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final payload = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;

    return payload['resetToken']?.toString();
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
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final currentUserStorage = ref.watch(currentUserStorageProvider);

  final dio = ref.watch(apiClientProvider).dio;
  return ApiAuthRepository(
    dio: dio,
    tokenStorage: tokenStorage,
    currentUserStorage: currentUserStorage,
  );
});
