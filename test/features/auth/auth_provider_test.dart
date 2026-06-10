import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/core/notifications/current_fcm_token_provider.dart';
import 'package:zto_app/features/auth/application/auth_provider.dart';
import 'package:zto_app/features/auth/data/auth_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

  @override
  Future<void> requestOtpForRegister({required String phoneNumber}) async {
    return;
  }

  @override
  Future<void> loginWithPassword({
    required String phoneNumber,
    required String password,
  }) async {
    return;
  }

  @override
  Future<void> registerFcmToken({required String fcmToken}) async {
    return;
  }

  @override
  Future<void> registerWithOtp({
    required String phoneNumber,
    required String password,
    required String otp,
  }) async {
    return;
  }

  @override
  Future<void> logout() async {
    return;
  }
}

class _TrackingAuthRepository extends _FakeAuthRepository {
  _TrackingAuthRepository();

  String? registeredFcmToken;

  @override
  Future<void> registerFcmToken({required String fcmToken}) async {
    registeredFcmToken = fcmToken;
  }
}

class _ErroringAuthRepository extends _FakeAuthRepository {
  const _ErroringAuthRepository({this.otpStatusCode, this.registerStatusCode});

  final int? otpStatusCode;
  final int? registerStatusCode;

  @override
  Future<void> requestOtpForRegister({required String phoneNumber}) async {
    if (otpStatusCode == null) {
      return;
    }
    throw DioException(
      requestOptions: RequestOptions(path: '/auth/send-otp'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/auth/send-otp'),
        statusCode: otpStatusCode,
      ),
    );
  }

  @override
  Future<void> registerWithOtp({
    required String phoneNumber,
    required String password,
    required String otp,
  }) async {
    if (registerStatusCode == null) {
      return;
    }
    throw DioException(
      requestOptions: RequestOptions(path: '/auth/register'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/auth/register'),
        statusCode: registerStatusCode,
      ),
    );
  }
}

void main() {
  test('default role starts as customer', () {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(authProvider);
    expect(state.role, UserRole.customer);
  });

  test('switchRole toggles from customer to staff', () {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    container.read(authProvider.notifier).switchRole();

    final state = container.read(authProvider);
    expect(state.role, UserRole.staff);
  });

  test('requestRegisterOtp success sets otp_sent message', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(authProvider.notifier)
        .requestRegisterOtp(phoneNumber: '+66891234567');

    final state = container.read(authProvider);
    expect(success, isTrue);
    expect(state.message, 'otp_sent');
  });

  test('login success keeps role as customer', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    container.read(authProvider.notifier).switchRole();
    final success = await container
        .read(authProvider.notifier)
        .login(phoneNumber: '+66891234567', password: '12345678');

    final state = container.read(authProvider);
    expect(success, isTrue);
    expect(state.role, UserRole.customer);
    expect(state.message, 'login_success');
  });

  test('login success registers fcm token when available', () async {
    final trackingRepository = _TrackingAuthRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(trackingRepository),
        currentFcmTokenProvider.overrideWith((ref) => 'fcm-123'),
      ],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(authProvider.notifier)
        .login(phoneNumber: '+66891234567', password: '12345678');
    await Future<void>.delayed(Duration.zero);

    expect(success, isTrue);
    expect(trackingRepository.registeredFcmToken, 'fcm-123');
  });

  test('requestRegisterOtp maps 429 to otp_too_many_requests', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const _ErroringAuthRepository(otpStatusCode: 429),
        ),
      ],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(authProvider.notifier)
        .requestRegisterOtp(phoneNumber: '+66891234567');

    final state = container.read(authProvider);
    expect(success, isFalse);
    expect(state.message, 'otp_too_many_requests');
  });

  test('register maps 409 to phone_already_registered', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const _ErroringAuthRepository(registerStatusCode: 409),
        ),
      ],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(authProvider.notifier)
        .register(
          phoneNumber: '+66891234567',
          password: '12345678',
          otp: '123456',
        );

    final state = container.read(authProvider);
    expect(success, isFalse);
    expect(state.message, 'phone_already_registered');
  });

  test('logout success resets role to customer', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    container.read(authProvider.notifier).switchRole();
    final success = await container.read(authProvider.notifier).logout();

    final state = container.read(authProvider);
    expect(success, isTrue);
    expect(state.role, UserRole.customer);
    expect(state.message, 'logout_success');
  });
}
