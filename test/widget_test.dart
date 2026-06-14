import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zto_app/features/auth/data/auth_repository.dart';
import 'package:zto_app/features/auth/presentation/screens/login_screen.dart';

import 'test_helpers/mock_asset_loader.dart';

const Map<String, dynamic> _smokeTestTranslations = {
  ...kTestTranslations,
  'member_portal': 'Member Portal',
  'welcome_back': 'Welcome Back',
  'login': 'Login',
  'dont_have_account': "Don't have an account? Register",
  'phone_number': 'Phone number',
  'phone_number_hint': 'Enter phone number',
  'password': 'Password',
};

class _SmokeAuthRepository implements AuthRepository {
  const _SmokeAuthRepository();

  @override
  Future<void> loginWithPassword({
    required String phoneNumber,
    required String password,
  }) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> registerFcmToken({required String fcmToken}) async {}

  @override
  Future<void> registerWithOtp({
    required String phoneNumber,
    required String password,
    required String otp,
  }) async {}

  @override
  Future<void> requestOtpForRegister({required String phoneNumber}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App shows login screen', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: LoginScreen.routePath,
      routes: [
        GoRoute(
          path: LoginScreen.routePath,
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const _SmokeAuthRepository(),
          ),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'unused',
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          assetLoader: const MockAssetLoader(_smokeTestTranslations),
          child: ScreenUtilInit(
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
