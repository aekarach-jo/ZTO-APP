import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/current_fcm_token_provider.dart';
import '../../../core/notifications/push_token_service.dart';
import '../../../core/network/network_providers.dart';
import '../data/auth_repository.dart';

enum UserRole { customer, staff }

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.message,
    this.role = UserRole.customer,
    this.resetToken,
  });

  final bool isLoading;
  final String? message;
  final UserRole role;
  final String? resetToken;

  AuthState copyWith({
    bool? isLoading,
    String? message,
    UserRole? role,
    String? resetToken,
    bool clearMessage = false,
    bool clearResetToken = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      message: clearMessage ? null : (message ?? this.message),
      role: role ?? this.role,
      resetToken: clearResetToken ? null : (resetToken ?? this.resetToken),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(
    this._authRepository, {
    required String? Function() readCurrentFcmToken,
    required Future<String?> Function() ensureFcmToken,
    required VoidCallback onSessionDataChanged,
  }) : _readCurrentFcmToken = readCurrentFcmToken,
       _ensureFcmToken = ensureFcmToken,
       _onSessionDataChanged = onSessionDataChanged,
       super(const AuthState());

  final AuthRepository _authRepository;
  final String? Function() _readCurrentFcmToken;
  final Future<String?> Function() _ensureFcmToken;
  final VoidCallback _onSessionDataChanged;
  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
  static final RegExp _forgotPasswordPhoneRegex = RegExp(
    r'^\+856(?:20|30)[0-9]{8}$',
  );
  static final RegExp _otpRegex = RegExp(r'^[0-9]{6}$');

  Future<bool> requestRegisterOtp({required String phoneNumber}) async {
    if (phoneNumber.isEmpty) {
      state = state.copyWith(message: 'required_field');
      return false;
    }

    if (!_phoneRegex.hasMatch(phoneNumber)) {
      state = state.copyWith(message: 'invalid_phone_number');
      return false;
    }

    state = state.copyWith(isLoading: true, clearMessage: true);

    try {
      await _authRepository.requestOtpForRegister(phoneNumber: phoneNumber);
      state = state.copyWith(isLoading: false, message: 'otp_sent');
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        message: _mapRequestOtpError(error),
      );
      return false;
    }
  }

  Future<bool> login({
    required String phoneNumber,
    required String password,
  }) async {
    if (phoneNumber.isEmpty || password.isEmpty) {
      state = state.copyWith(message: 'required_field');
      return false;
    }

    if (!_phoneRegex.hasMatch(phoneNumber)) {
      state = state.copyWith(message: 'invalid_phone_number');
      return false;
    }

    state = state.copyWith(isLoading: true, clearMessage: true);

    try {
      await _authRepository.loginWithPassword(
        phoneNumber: phoneNumber,
        password: password,
      );
      _onSessionDataChanged();
      unawaited(_registerFcmTokenWhenAvailable());
      state = state.copyWith(
        isLoading: false,
        message: 'login_success',
        role: UserRole.customer,
      );
      return true;
    } catch (_) {
      state = state.copyWith(isLoading: false, message: 'login_failed');
      return false;
    }
  }

  Future<bool> requestForgotPasswordOtp({required String phoneNumber}) async {
    if (phoneNumber.isEmpty) {
      state = state.copyWith(message: 'required_field', clearResetToken: true);
      return false;
    }

    if (!_forgotPasswordPhoneRegex.hasMatch(phoneNumber)) {
      state = state.copyWith(
        message: 'invalid_phone_number',
        clearResetToken: true,
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      clearMessage: true,
      clearResetToken: true,
    );

    try {
      await _authRepository.sendForgotPasswordOtp(phoneNumber: phoneNumber);
      state = state.copyWith(isLoading: false, message: 'otp_sent');
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        message: _mapForgotPasswordSendOtpError(error),
      );
      return false;
    }
  }

  Future<String?> verifyForgotPasswordOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    if (phoneNumber.isEmpty || otp.isEmpty) {
      state = state.copyWith(message: 'required_field', clearResetToken: true);
      return null;
    }

    if (!_forgotPasswordPhoneRegex.hasMatch(phoneNumber)) {
      state = state.copyWith(
        message: 'invalid_phone_number',
        clearResetToken: true,
      );
      return null;
    }

    if (!_otpRegex.hasMatch(otp)) {
      state = state.copyWith(
        message: 'invalid_otp_code',
        clearResetToken: true,
      );
      return null;
    }

    state = state.copyWith(
      isLoading: true,
      clearMessage: true,
      clearResetToken: true,
    );

    try {
      final resetToken = await _authRepository.verifyForgotPasswordOtp(
        phoneNumber: phoneNumber,
        otp: otp,
      );
      state = state.copyWith(
        isLoading: false,
        message: 'otp_verified',
        resetToken: resetToken,
      );
      return resetToken;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        message: _mapForgotPasswordVerifyOtpError(error),
        clearResetToken: true,
      );
      return null;
    }
  }

  Future<bool> resetForgotPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  }) async {
    if (phoneNumber.isEmpty || resetToken.isEmpty || newPassword.isEmpty) {
      state = state.copyWith(message: 'required_field');
      return false;
    }

    if (!_forgotPasswordPhoneRegex.hasMatch(phoneNumber)) {
      state = state.copyWith(message: 'invalid_phone_number');
      return false;
    }

    if (newPassword.length < 8) {
      state = state.copyWith(message: 'password_too_short');
      return false;
    }

    state = state.copyWith(isLoading: true, clearMessage: true);

    try {
      await _authRepository.resetPassword(
        phoneNumber: phoneNumber,
        resetToken: resetToken,
        newPassword: newPassword,
      );
      state = state.copyWith(
        isLoading: false,
        message: 'password_reset_success',
        clearResetToken: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        message: _mapForgotPasswordResetError(error),
      );
      return false;
    }
  }

  Future<bool> register({
    required String phoneNumber,
    required String password,
    required String otp,
  }) async {
    if (phoneNumber.isEmpty || password.isEmpty || otp.isEmpty) {
      state = state.copyWith(message: 'required_field');
      return false;
    }

    if (!_phoneRegex.hasMatch(phoneNumber)) {
      state = state.copyWith(message: 'invalid_phone_number');
      return false;
    }

    if (password.length < 8) {
      state = state.copyWith(message: 'password_too_short');
      return false;
    }

    if (!_otpRegex.hasMatch(otp)) {
      state = state.copyWith(message: 'invalid_otp_code');
      return false;
    }

    state = state.copyWith(isLoading: true, clearMessage: true);

    try {
      await _authRepository.registerWithOtp(
        phoneNumber: phoneNumber,
        password: password,
        otp: otp,
      );
      _onSessionDataChanged();
      unawaited(_registerFcmTokenWhenAvailable());
      state = state.copyWith(
        isLoading: false,
        message: 'register_success',
        role: UserRole.customer,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        message: _mapRegisterError(error),
      );
      return false;
    }
  }

  /// Points the backend at this device's push token once a session exists.
  ///
  /// Reading the cached token is enough on Android, where it is ready long
  /// before anyone finishes logging in. iOS has to wait for APNs first, so the
  /// token is often still missing at this point — falling back to a fresh fetch
  /// is what keeps that device from staying unreachable by push for the rest of
  /// the session.
  Future<void> _registerFcmTokenWhenAvailable() async {
    try {
      final cached = _readCurrentFcmToken();
      final token = (cached != null && cached.isNotEmpty)
          ? cached
          : await _ensureFcmToken();
      if (token == null || token.isEmpty) {
        return;
      }
      await _authRepository.registerFcmToken(fcmToken: token);
    } catch (_) {
      // Nothing to surface to the user: fcmTokenSyncProvider re-posts the token
      // on the next refresh or app resume.
    }
  }

  String _mapRequestOtpError(Object error) {
    if (error is! DioException) {
      return 'otp_send_failed';
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 429) {
      return 'otp_too_many_requests';
    }
    if (statusCode == 400) {
      return 'invalid_phone_number';
    }

    return 'otp_send_failed';
  }

  String _mapForgotPasswordSendOtpError(Object error) {
    if (error is! DioException) {
      return 'otp_send_failed';
    }

    final statusCode = error.response?.statusCode;
    final errorText = _extractErrorText(error);
    if (statusCode == 404) {
      return 'phone_not_registered';
    }
    if (statusCode == 429 ||
        errorText.contains('too') ||
        errorText.contains('60')) {
      return 'otp_too_many_requests';
    }
    if (statusCode == 400) {
      return 'invalid_phone_number';
    }

    return 'otp_send_failed';
  }

  String _mapForgotPasswordVerifyOtpError(Object error) {
    if (error is! DioException) {
      return 'otp_verify_failed';
    }

    final errorText = _extractErrorText(error);
    if (errorText.isNotEmpty) {
      if (errorText.contains('attempt') || errorText.contains('remaining')) {
        return _extractOriginalErrorMessage(error) ?? 'invalid_otp_code';
      }
      if (errorText.contains('expired') || errorText.contains('request')) {
        return 'otp_expired_or_not_requested';
      }
      if (errorText.contains('invalid') || errorText.contains('otp')) {
        return 'invalid_otp_code';
      }
    }

    return 'otp_verify_failed';
  }

  String _mapForgotPasswordResetError(Object error) {
    if (error is! DioException) {
      return 'password_reset_failed';
    }

    final statusCode = error.response?.statusCode;
    final errorText = _extractErrorText(error);
    if (statusCode == 404) {
      return 'phone_not_registered';
    }
    if (errorText.contains('password') || errorText.contains('8')) {
      return 'password_too_short';
    }
    if (errorText.contains('token') || errorText.contains('expired')) {
      return 'reset_token_invalid_or_expired';
    }

    return 'password_reset_failed';
  }

  String _mapRegisterError(Object error) {
    if (error is! DioException) {
      return 'register_failed';
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 409) {
      return 'phone_already_registered';
    }

    final errorText = _extractErrorText(error);
    if (statusCode == 400 && errorText.isNotEmpty) {
      if (errorText.contains('otp')) {
        return 'invalid_otp_code';
      }
      if (errorText.contains('already') ||
          errorText.contains('exists') ||
          errorText.contains('registered')) {
        return 'phone_already_registered';
      }
    }

    return 'register_failed';
  }

  String _extractErrorText(DioException error) {
    final data = error.response?.data;
    if (data is String) {
      return data.toLowerCase();
    }
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'] ?? data['detail'];
      if (message is String) {
        return message.toLowerCase();
      }
      if (message is List && message.isNotEmpty) {
        return message.join(' ').toLowerCase();
      }
    }
    return '';
  }

  String? _extractOriginalErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is String && data.isNotEmpty) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'] ?? data['detail'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      if (message is List && message.isNotEmpty) {
        return message.join(' ');
      }
    }
    return null;
  }

  void switchRole() {
    final nextRole = state.role == UserRole.customer
        ? UserRole.staff
        : UserRole.customer;
    state = state.copyWith(role: nextRole, clearMessage: true);
  }

  Future<bool> logout() async {
    state = state.copyWith(isLoading: true, clearMessage: true);

    try {
      await _authRepository.logout();
      _onSessionDataChanged();
      state = state.copyWith(
        isLoading: false,
        role: UserRole.customer,
        message: 'logout_success',
      );
      return true;
    } catch (_) {
      state = state.copyWith(isLoading: false, message: 'logout_failed');
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(
    authRepository,
    readCurrentFcmToken: () => ref.read(currentFcmTokenProvider),
    ensureFcmToken: () => ensurePushToken(ref),
    onSessionDataChanged: () {
      ref.invalidate(currentUserPhoneProvider);
      ref.invalidate(authTokensProvider);
    },
  );
});
