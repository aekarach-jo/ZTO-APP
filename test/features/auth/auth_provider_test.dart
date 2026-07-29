import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/core/notifications/current_fcm_token_provider.dart';
import 'package:zto_app/core/notifications/push_token_service.dart';
import 'package:zto_app/core/network/network_providers.dart';
import 'package:zto_app/features/auth/application/auth_provider.dart';
import 'package:zto_app/features/auth/data/auth_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

  @override
  Future<void> requestOtpForRegister({required String phoneNumber}) async {
    return;
  }

  @override
  Future<void> sendForgotPasswordOtp({required String phoneNumber}) async {
    return;
  }

  @override
  Future<String> verifyForgotPasswordOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    return 'reset-token-123';
  }

  @override
  Future<void> resetPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  }) async {
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

class _FakePushTokenService implements PushTokenService {
  _FakePushTokenService(this._token);

  final String? _token;
  int initializeCalls = 0;

  @override
  Future<String?> initializeAndGetToken() async {
    initializeCalls += 1;
    return _token;
  }

  @override
  Stream<String> onTokenRefresh() => const Stream<String>.empty();
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

  test('requestForgotPasswordOtp validates Laos phone format', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(authProvider.notifier)
        .requestForgotPasswordOtp(phoneNumber: '+8561091234567');

    final state = container.read(authProvider);
    expect(success, isFalse);
    expect(state.message, 'invalid_phone_number');
  });

  test('verifyForgotPasswordOtp stores reset token', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    final token = await container
        .read(authProvider.notifier)
        .verifyForgotPasswordOtp(phoneNumber: '+8562091234567', otp: '123456');

    final state = container.read(authProvider);
    expect(token, 'reset-token-123');
    expect(state.resetToken, 'reset-token-123');
    expect(state.message, 'otp_verified');
  });

  test('resetForgotPassword success clears reset token', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authProvider.notifier)
        .verifyForgotPasswordOtp(phoneNumber: '+8562091234567', otp: '123456');
    final success = await container
        .read(authProvider.notifier)
        .resetForgotPassword(
          phoneNumber: '+8562091234567',
          resetToken: 'reset-token-123',
          newPassword: 'NewPass123!',
        );

    final state = container.read(authProvider);
    expect(success, isTrue);
    expect(state.resetToken, isNull);
    expect(state.message, 'password_reset_success');
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

  test('login fetches a token when none has arrived yet', () async {
    final trackingRepository = _TrackingAuthRepository();
    final pushTokenService = _FakePushTokenService('fcm-late');
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(trackingRepository),
        pushTokenServiceProvider.overrideWithValue(pushTokenService),
      ],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(authProvider.notifier)
        .login(phoneNumber: '+66891234567', password: '12345678');
    await Future<void>.delayed(Duration.zero);

    expect(success, isTrue);
    expect(pushTokenService.initializeCalls, 1);
    expect(trackingRepository.registeredFcmToken, 'fcm-late');
    expect(container.read(currentFcmTokenProvider), 'fcm-late');
  });

  test('login skips fcm registration when no token can be fetched', () async {
    final trackingRepository = _TrackingAuthRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(trackingRepository),
        pushTokenServiceProvider.overrideWithValue(_FakePushTokenService(null)),
      ],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(authProvider.notifier)
        .login(phoneNumber: '+66891234567', password: '12345678');
    await Future<void>.delayed(Duration.zero);

    expect(success, isTrue);
    expect(trackingRepository.registeredFcmToken, isNull);
  });

  test('login success invalidates cached current user phone', () async {
    var currentPhoneReads = 0;
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
        currentUserPhoneProvider.overrideWith((ref) async {
          currentPhoneReads += 1;
          return currentPhoneReads == 1 ? '+8562011111111' : '+8562022222222';
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(currentUserPhoneProvider.future),
      '+8562011111111',
    );

    final success = await container
        .read(authProvider.notifier)
        .login(phoneNumber: '+8562022222222', password: '12345678');

    expect(success, isTrue);
    expect(
      await container.read(currentUserPhoneProvider.future),
      '+8562022222222',
    );
  });

  test('logout success invalidates cached current user phone', () async {
    var currentPhoneReads = 0;
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
        currentUserPhoneProvider.overrideWith((ref) async {
          currentPhoneReads += 1;
          return currentPhoneReads == 1 ? '+8562011111111' : null;
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(currentUserPhoneProvider.future),
      '+8562011111111',
    );

    final success = await container.read(authProvider.notifier).logout();

    expect(success, isTrue);
    expect(await container.read(currentUserPhoneProvider.future), isNull);
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
