import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/forgot_password_otp_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_otp_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/main_layout/presentation/screens/main_layout_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: LoginScreen.routePath,
    redirect: (context, state) {
      // Normalize app entry and stale deep links to a valid auth entry route.
      if (state.matchedLocation == '/') {
        return LoginScreen.routePath;
      }
      return null;
    },
    errorBuilder: (context, state) => const LoginScreen(),
    routes: [
      GoRoute(path: '/', redirect: (context, state) => LoginScreen.routePath),
      GoRoute(
        path: LoginScreen.routePath,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: ForgotPasswordScreen.routePath,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: ForgotPasswordOtpScreen.routePath,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! ForgotPasswordOtpArgs) {
            return const ForgotPasswordScreen();
          }
          return ForgotPasswordOtpScreen(args: extra);
        },
      ),
      GoRoute(
        path: ResetPasswordScreen.routePath,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! ResetPasswordArgs) {
            return const ForgotPasswordScreen();
          }
          return ResetPasswordScreen(args: extra);
        },
      ),
      GoRoute(
        path: RegisterScreen.routePath,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RegisterOtpScreen.routePath,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! RegisterOtpArgs) {
            return const RegisterScreen();
          }
          return RegisterOtpScreen(args: extra);
        },
      ),
      GoRoute(
        path: MainLayoutScreen.routePath,
        builder: (context, state) => const MainLayoutScreen(),
      ),
    ],
  );
});
