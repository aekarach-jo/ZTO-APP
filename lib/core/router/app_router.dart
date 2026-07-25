import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../network/network_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_otp_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_otp_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/main_layout/presentation/screens/main_layout_screen.dart';
import '../../features/parcel_claim/presentation/screens/parcel_claim_screen.dart';
import '../../features/parcel_payment/presentation/screens/parcel_payment_screen.dart';
import '../../features/parcel_status/presentation/screens/parcel_status_screen.dart';
import '../../features/orders/presentation/screens/order_history_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';

const String appStartupRoutePath = '/startup';

final Set<String> _publicAuthRoutes = {
  LoginScreen.routePath,
  ForgotPasswordScreen.routePath,
  ForgotPasswordOtpScreen.routePath,
  ResetPasswordScreen.routePath,
  RegisterScreen.routePath,
  RegisterOtpScreen.routePath,
};

String? resolveAppRedirect({
  required String location,
  required bool isAuthLoading,
  required bool isAuthenticated,
}) {
  final normalizedLocation = location == '/' ? appStartupRoutePath : location;
  final isStartupRoute = normalizedLocation == appStartupRoutePath;
  final isPublicRoute = _publicAuthRoutes.contains(normalizedLocation);

  if (isAuthLoading) {
    return isStartupRoute ? null : appStartupRoutePath;
  }

  if (isStartupRoute) {
    return isAuthenticated ? MainLayoutScreen.routePath : LoginScreen.routePath;
  }

  if (!isAuthenticated && !isPublicRoute) {
    return LoginScreen.routePath;
  }

  if (isAuthenticated && isPublicRoute) {
    return MainLayoutScreen.routePath;
  }

  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authTokens = ref.watch(authTokensProvider);
  final isAuthLoading = authTokens.isLoading;
  final isAuthenticated = authTokens.asData?.value != null;

  return GoRouter(
    initialLocation: appStartupRoutePath,
    redirect: (context, state) {
      return resolveAppRedirect(
        location: state.matchedLocation,
        isAuthLoading: isAuthLoading,
        isAuthenticated: isAuthenticated,
      );
    },
    errorBuilder: (context, state) =>
        isAuthenticated ? const MainLayoutScreen() : const LoginScreen(),
    routes: [
      GoRoute(
        path: appStartupRoutePath,
        builder: (context, state) => const _AppStartupScreen(),
      ),
      GoRoute(path: '/', redirect: (context, state) => appStartupRoutePath),
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
      GoRoute(
        path: ParcelClaimScreen.routePath,
        builder: (context, state) => const ParcelClaimScreen(),
      ),
      GoRoute(
        path: ParcelStatusScreen.routePath,
        builder: (context, state) => const ParcelStatusScreen(),
      ),
      GoRoute(
        path: OrderHistoryScreen.routePath,
        builder: (context, state) => const OrderHistoryScreen(),
      ),
      GoRoute(
        path: EditProfileScreen.routePath,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: ParcelPaymentScreen.routePath,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! ParcelPaymentArgs) {
            return const MainLayoutScreen();
          }
          return ParcelPaymentScreen(args: extra);
        },
      ),
    ],
  );
});

class _AppStartupScreen extends StatelessWidget {
  const _AppStartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
