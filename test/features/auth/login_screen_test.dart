import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zto_app/features/auth/data/auth_repository.dart';
import 'package:zto_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:zto_app/features/auth/presentation/screens/login_screen.dart';
import 'package:zto_app/features/auth/presentation/screens/register_screen.dart';
import 'package:zto_app/features/main_layout/presentation/screens/main_layout_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

const Map<String, dynamic> _authTestTranslations = {
  ...kTestTranslations,
  'member_portal': 'Member Portal',
  'welcome_back': 'Welcome Back',
  'login': 'Login',
  'dont_have_account': "Don't have an account? Register",
  'phone_number': 'Phone number',
  'phone_number_hint': 'Enter phone number',
  'password': 'Password',
  'required_field': 'This field is required',
  'invalid_phone_number': 'Please enter a valid phone number',
  'login_failed': 'Login failed',
};

class _SuccessAuthRepository implements AuthRepository {
  const _SuccessAuthRepository();

  @override
  Future<void> requestOtpForRegister({required String phoneNumber}) async {}

  @override
  Future<void> sendForgotPasswordOtp({required String phoneNumber}) async {}

  @override
  Future<String> verifyForgotPasswordOtp({
    required String phoneNumber,
    required String otp,
  }) async => 'reset-token-123';

  @override
  Future<void> resetPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  }) async {}

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

class _FailingAuthRepository implements AuthRepository {
  const _FailingAuthRepository();

  @override
  Future<void> requestOtpForRegister({required String phoneNumber}) async {}

  @override
  Future<void> sendForgotPasswordOtp({required String phoneNumber}) async {}

  @override
  Future<String> verifyForgotPasswordOtp({
    required String phoneNumber,
    required String otp,
  }) async => 'reset-token-123';

  @override
  Future<void> resetPassword({
    required String phoneNumber,
    required String resetToken,
    required String newPassword,
  }) async {}

  @override
  Future<void> loginWithPassword({
    required String phoneNumber,
    required String password,
  }) async {
    throw Exception('mock login failed');
  }

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

Widget _buildTestApp({required AuthRepository authRepository}) {
  final router = GoRouter(
    initialLocation: LoginScreen.routePath,
    routes: [
      GoRoute(
        path: LoginScreen.routePath,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RegisterScreen.routePath,
        builder: (context, state) =>
            const Scaffold(body: Text('REGISTER_SCREEN')),
      ),
      GoRoute(
        path: ForgotPasswordScreen.routePath,
        builder: (context, state) =>
            const Scaffold(body: Text('FORGOT_PASSWORD_SCREEN')),
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
      assetLoader: const MockAssetLoader(_authTestTranslations),
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

  testWidgets('shows validation message when required fields are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: const _SuccessAuthRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required'), findsNWidgets(2));
  });

  testWidgets('stays on login screen when login fails', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: const _FailingAuthRepository()),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '20 9123456');
    await tester.enterText(fields.at(1), '123456');

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('MAIN_SCREEN'), findsNothing);
  });

  testWidgets('navigates to main screen when login succeeds', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: const _SuccessAuthRepository()),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '20 9123456');
    await tester.enterText(fields.at(1), '123456');

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('MAIN_SCREEN'), findsOneWidget);
  });

  testWidgets('navigates to register screen from login link', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: const _SuccessAuthRepository()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text("Don't have an account? Register"));
    await tester.tap(find.text("Don't have an account? Register"));
    await tester.pumpAndSettle();

    expect(find.text('REGISTER_SCREEN'), findsOneWidget);
  });

  testWidgets('navigates to forgot password screen from login link', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(authRepository: const _SuccessAuthRepository()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('FORGOT_PASSWORD_SCREEN'), findsOneWidget);
  });
}
