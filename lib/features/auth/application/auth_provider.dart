import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/current_fcm_token_provider.dart';
import '../data/auth_repository.dart';

enum UserRole { customer, staff }

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.message,
    this.role = UserRole.customer,
  });

  final bool isLoading;
  final String? message;
  final UserRole role;

  AuthState copyWith({
    bool? isLoading,
    String? message,
    UserRole? role,
    bool clearMessage = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      message: clearMessage ? null : (message ?? this.message),
      role: role ?? this.role,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(
    this._authRepository, {
    required String? Function() readCurrentFcmToken,
  }) : _readCurrentFcmToken = readCurrentFcmToken,
       super(const AuthState());

  final AuthRepository _authRepository;
  final String? Function() _readCurrentFcmToken;
  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
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
      final fcmToken = _readCurrentFcmToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        unawaited(_authRepository.registerFcmToken(fcmToken: fcmToken));
      }
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
      final fcmToken = _readCurrentFcmToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        unawaited(_authRepository.registerFcmToken(fcmToken: fcmToken));
      }
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
  );
});
