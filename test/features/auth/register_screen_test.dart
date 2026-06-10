import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zto_app/features/auth/data/auth_repository.dart';
import 'package:zto_app/features/auth/presentation/screens/login_screen.dart';
import 'package:zto_app/features/auth/presentation/screens/register_otp_screen.dart';
import 'package:zto_app/features/auth/presentation/screens/register_screen.dart';
import 'package:zto_app/features/main_layout/presentation/screens/main_layout_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

const Map<String, dynamic> _registerTestTranslations = {
  ...kTestTranslations,
  'member_portal': 'Member Portal',
  'create_account': 'Create Account',
  'phone_number': 'Phone number',
  'phone_number_hint': 'Enter phone number',
  'password': 'Password',
  'otp_code': 'OTP code',
  'otp_code_hint': '6-digit code',
  'invalid_phone_number': 'Please enter a valid phone number',
  'invalid_otp_code': 'Please enter a valid 6-digit OTP',
  'send_otp': 'Send OTP',
  'resend_otp': 'Resend OTP',
  'verify_otp': 'Verify OTP',
  'otp_sent': 'OTP has been sent',
  'otp_expires_in': 'OTP expires in {}',
  'otp_expired': 'OTP expired. Please resend OTP',
  'required_field': 'This field is required',
  'password_too_short': 'Password must be at least 8 characters',
  'register': 'Register',
  'already_have_account': 'Already have an account?',
  'register_failed': 'Register failed',
  'register_success': 'Register success',
  'otp_send_failed': 'Unable to send OTP, please try again',
};

class _SuccessAuthRepository implements AuthRepository {
  const _SuccessAuthRepository();

  @override
  Future<void> requestOtpForRegister({required String phoneNumber}) async {}

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

class _FailingOtpAuthRepository extends _SuccessAuthRepository {
  const _FailingOtpAuthRepository();

  @override
  Future<void> requestOtpForRegister({required String phoneNumber}) async {
    throw Exception('mock send otp failed');
  }
}

class _FailingRegisterAuthRepository extends _SuccessAuthRepository {
  const _FailingRegisterAuthRepository();

  @override
  Future<void> registerWithOtp({
    required String phoneNumber,
    required String password,
    required String otp,
  }) async {
    throw Exception('mock register failed');
  }
}

Widget _buildTestApp({required AuthRepository authRepository}) {
  final router = GoRouter(
    initialLocation: RegisterScreen.routePath,
    routes: [
      GoRoute(
        path: LoginScreen.routePath,
        builder: (context, state) => const Scaffold(body: Text('LOGIN_SCREEN')),
      ),
      GoRoute(
        path: RegisterScreen.routePath,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RegisterOtpScreen.routePath,
        builder: (context, state) {
          final args = state.extra;
          if (args is! RegisterOtpArgs) {
            return const Scaffold(body: Text('INVALID_OTP_ARGS'));
          }
          return RegisterOtpScreen(args: args);
        },
      ),
      GoRoute(
        path: MainLayoutScreen.routePath,
        builder: (context, state) => const Scaffold(body: Text('MAIN_SCREEN')),
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
      assetLoader: const MockAssetLoader(_registerTestTranslations),
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

  Future<void> enterOtp(WidgetTester tester, String otp) async {
    await tester.enterText(find.byKey(const ValueKey('otp-hidden-input')), otp);
    await tester.pumpAndSettle();
  }

  testWidgets('shows validation when required fields are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: const _SuccessAuthRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required'), findsNWidgets(2));
  });

  testWidgets('navigates to otp screen after send otp succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: const _SuccessAuthRepository()),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '20 9123456');
    await tester.enterText(fields.at(1), '12345678');

    await tester.ensureVisible(find.text('Send OTP'));
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Verify OTP'), findsOneWidget);
    expect(find.textContaining('OTP expires in'), findsOneWidget);
  });

  testWidgets('stays on register when send otp fails', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: const _FailingOtpAuthRepository()),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '20 9123456');
    await tester.enterText(fields.at(1), '12345678');

    await tester.ensureVisible(find.text('Send OTP'));
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('MAIN_SCREEN'), findsNothing);
  });

  testWidgets('keeps user on otp screen when code is incomplete', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: const _SuccessAuthRepository()),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '20 9123456');
    await tester.enterText(fields.at(1), '12345678');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    await enterOtp(tester, '111');
    await tester.pumpAndSettle();

    expect(find.text('Verify OTP'), findsOneWidget);
    expect(find.text('MAIN_SCREEN'), findsNothing);
  });

  testWidgets('navigates to main screen when otp submit succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: const _SuccessAuthRepository()),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '20 9123456');
    await tester.enterText(fields.at(1), '12345678');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    await enterOtp(tester, '123456');
    await tester.pumpAndSettle();

    expect(find.text('MAIN_SCREEN'), findsOneWidget);
  });

  testWidgets('otp screen can navigate back to register screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: const _SuccessAuthRepository()),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '20 9123456');
    await tester.enterText(fields.at(1), '12345678');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Verify OTP'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('otp-back-to-register-button')));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('stays on otp screen when register fails', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: const _FailingRegisterAuthRepository()),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '20 9123456');
    await tester.enterText(fields.at(1), '12345678');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    await enterOtp(tester, '123456');
    await tester.pumpAndSettle();

    expect(find.text('Verify OTP'), findsOneWidget);
    expect(find.text('MAIN_SCREEN'), findsNothing);
  });
}
