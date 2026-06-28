import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zto_app/features/auth/data/auth_repository.dart';
import 'package:zto_app/features/auth/presentation/screens/forgot_password_otp_screen.dart';
import 'package:zto_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:zto_app/features/auth/presentation/screens/login_screen.dart';
import 'package:zto_app/features/auth/presentation/screens/reset_password_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

const Map<String, dynamic> _forgotPasswordTranslations = {
  ...kTestTranslations,
  'phone_number': 'Phone number',
  'send_otp': 'Send OTP',
  'resend_otp': 'Resend OTP',
  'verify_otp': 'Verify OTP',
  'otp_sent': 'OTP has been sent',
  'otp_expires_in': 'OTP expires in {}',
  'otp_expired': 'OTP expired. Please resend OTP',
  'otp_send_failed': 'Unable to send OTP, please try again',
  'invalid_otp_code': 'Please enter a valid 6-digit OTP',
  'required_field': 'This field is required',
  'password': 'Password',
  'confirm_password': 'Confirm Password',
  'password_too_short': 'Password must be at least 8 characters',
  'password_not_match': 'Passwords do not match',
};

class _SuccessForgotPasswordRepository implements AuthRepository {
  _SuccessForgotPasswordRepository();

  String? sentOtpPhoneNumber;
  String? verifiedPhoneNumber;
  String? verifiedOtp;
  String? resetPhoneNumber;
  String? resetToken;
  String? newPassword;

  @override
  Future<void> requestOtpForRegister({required String phoneNumber}) async {}

  @override
  Future<void> sendForgotPasswordOtp({required String phoneNumber}) async {
    sentOtpPhoneNumber = phoneNumber;
  }

  @override
  Future<String> verifyForgotPasswordOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    verifiedPhoneNumber = phoneNumber;
    verifiedOtp = otp;
    return 'reset-token-123';
  }

  @override
  Future<void> resetPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  }) async {
    resetPhoneNumber = phoneNumber;
    this.resetToken = resetToken;
    this.newPassword = newPassword;
  }

  @override
  Future<void> loginWithPassword({
    required String phoneNumber,
    required String password,
  }) async {}

  @override
  Future<void> registerFcmToken({required String fcmToken}) async {}

  @override
  Future<void> registerWithOtp({
    required String phoneNumber,
    required String password,
    required String otp,
  }) async {}

  @override
  Future<void> logout() async {}
}

class _FailingSendOtpRepository extends _SuccessForgotPasswordRepository {
  @override
  Future<void> sendForgotPasswordOtp({required String phoneNumber}) async {
    throw Exception('mock forgot password send otp failed');
  }
}

Widget _buildTestApp({required AuthRepository authRepository}) {
  final router = GoRouter(
    initialLocation: ForgotPasswordScreen.routePath,
    routes: [
      GoRoute(
        path: LoginScreen.routePath,
        builder: (context, state) => const Scaffold(body: Text('LOGIN_SCREEN')),
      ),
      GoRoute(
        path: ForgotPasswordScreen.routePath,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: ForgotPasswordOtpScreen.routePath,
        builder: (context, state) {
          final args = state.extra;
          if (args is! ForgotPasswordOtpArgs) {
            return const Scaffold(body: Text('INVALID_OTP_ARGS'));
          }
          return ForgotPasswordOtpScreen(args: args);
        },
      ),
      GoRoute(
        path: ResetPasswordScreen.routePath,
        builder: (context, state) {
          final args = state.extra;
          if (args is! ResetPasswordArgs) {
            return const Scaffold(body: Text('INVALID_RESET_ARGS'));
          }
          return ResetPasswordScreen(args: args);
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
    child: EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'unused',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      assetLoader: const MockAssetLoader(_forgotPasswordTranslations),
      child: Builder(
        builder: (context) {
          return ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, _) {
              return MaterialApp.router(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                routerConfig: router,
              );
            },
          );
        },
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> sendOtp(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).first, '20 91234567');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows validation when phone number is empty', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: _SuccessForgotPasswordRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required'), findsOneWidget);
  });

  testWidgets('navigates to OTP screen after send OTP succeeds', (
    tester,
  ) async {
    final repository = _SuccessForgotPasswordRepository();
    await tester.pumpWidget(_buildTestApp(authRepository: repository));
    await tester.pumpAndSettle();

    await sendOtp(tester);

    expect(repository.sentOtpPhoneNumber, '+8562091234567');
    expect(find.text('Verify OTP'), findsOneWidget);
    expect(find.textContaining('OTP expires in'), findsOneWidget);
  });

  testWidgets('stays on forgot password screen when send OTP fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: _FailingSendOtpRepository()),
    );
    await tester.pumpAndSettle();

    await sendOtp(tester);

    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('Verify OTP'), findsNothing);
  });

  testWidgets('verifies OTP then navigates to reset password screen', (
    tester,
  ) async {
    final repository = _SuccessForgotPasswordRepository();
    await tester.pumpWidget(_buildTestApp(authRepository: repository));
    await tester.pumpAndSettle();
    await sendOtp(tester);

    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-otp-hidden-input')),
      '123456',
    );
    await tester.pumpAndSettle();

    expect(repository.verifiedPhoneNumber, '+8562091234567');
    expect(repository.verifiedOtp, '123456');
    expect(find.text('Reset password'), findsWidgets);
  });

  testWidgets('resets password then navigates back to login', (tester) async {
    final repository = _SuccessForgotPasswordRepository();
    await tester.pumpWidget(_buildTestApp(authRepository: repository));
    await tester.pumpAndSettle();
    await sendOtp(tester);
    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-otp-hidden-input')),
      '123456',
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'NewPass123!');
    await tester.enterText(fields.at(1), 'NewPass123!');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
    await tester.pumpAndSettle();

    expect(repository.resetPhoneNumber, '+8562091234567');
    expect(repository.resetToken, 'reset-token-123');
    expect(repository.newPassword, 'NewPass123!');
    expect(find.text('LOGIN_SCREEN'), findsOneWidget);
  });
}
