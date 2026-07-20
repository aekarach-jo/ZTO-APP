import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/core/router/app_router.dart';
import 'package:zto_app/features/auth/presentation/screens/login_screen.dart';
import 'package:zto_app/features/auth/presentation/screens/register_screen.dart';
import 'package:zto_app/features/main_layout/presentation/screens/main_layout_screen.dart';
import 'package:zto_app/features/parcel_claim/presentation/screens/parcel_claim_screen.dart';

void main() {
  group('resolveAppRedirect', () {
    test('sends startup requests to splash while auth state is loading', () {
      expect(
        resolveAppRedirect(
          location: MainLayoutScreen.routePath,
          isAuthLoading: true,
          isAuthenticated: false,
        ),
        appStartupRoutePath,
      );
    });

    test('keeps startup route while auth state is loading', () {
      expect(
        resolveAppRedirect(
          location: appStartupRoutePath,
          isAuthLoading: true,
          isAuthenticated: false,
        ),
        isNull,
      );
    });

    test('opens main screen when a saved session exists', () {
      expect(
        resolveAppRedirect(
          location: appStartupRoutePath,
          isAuthLoading: false,
          isAuthenticated: true,
        ),
        MainLayoutScreen.routePath,
      );
    });

    test('blocks authenticated users from returning to login', () {
      expect(
        resolveAppRedirect(
          location: LoginScreen.routePath,
          isAuthLoading: false,
          isAuthenticated: true,
        ),
        MainLayoutScreen.routePath,
      );
    });

    test('sends unauthenticated users to login for protected routes', () {
      expect(
        resolveAppRedirect(
          location: ParcelClaimScreen.routePath,
          isAuthLoading: false,
          isAuthenticated: false,
        ),
        LoginScreen.routePath,
      );
    });

    test('allows unauthenticated users to stay on public auth screens', () {
      expect(
        resolveAppRedirect(
          location: RegisterScreen.routePath,
          isAuthLoading: false,
          isAuthenticated: false,
        ),
        isNull,
      );
    });
  });
}
