import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/contact/data/contact_repository.dart';
import 'package:zto_app/features/home/data/home_parcel_repository.dart';
import 'package:zto_app/features/notifications/data/notification_repository.dart';
import 'package:zto_app/features/send/data/send_repository.dart';
import 'package:zto_app/features/staff/data/staff_parcel_repository.dart';
import 'package:zto_app/features/auth/data/auth_repository.dart';
import 'package:zto_app/features/main_layout/application/main_layout_navigation_provider.dart';
import 'package:zto_app/features/main_layout/presentation/screens/main_layout_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

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

class _FakeContactRepository extends ContactRepository {
  _FakeContactRepository() : super(dio: Dio());

  @override
  Future<List<ContactMessage>> fetchMessages() async {
    return const [];
  }

  @override
  Future<List<ContactMessage>> sendMessage({required String text}) async {
    return [];
  }
}

List<Override> _baseOverrides() {
  return [
    authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
    homeParcelsProvider.overrideWith((ref) async {
      return const [
        HomeParcel(
          id: '1',
          title: 'Sony WH-1000XM5 Headphones',
          trackingNo: '#TH88291039',
          weightLabel: '0.5 kg',
          dateLabel: '15/5/2026',
          status: 'pending',
        ),
      ];
    }),
    notificationsProvider.overrideWith((ref) async {
      return const [
        AppNotification(
          id: 'n1',
          title: 'Forwarding completed',
          message: 'Your parcel has arrived.',
          timeLabel: '1h ago',
          isUnread: true,
        ),
      ];
    }),
    sendParcelsProvider.overrideWith((ref) async {
      return const [
        SendParcelItem(
          id: 'TH88291039',
          title: 'Sony WH-1000XM5 Headphones',
          trackNo: '#TH88291039',
          weightKg: 0.5,
        ),
      ];
    }),
    handoverReadyParcelsProvider.overrideWith(
      (ref) async => const <StaffParcelItem>[],
    ),
    contactRepositoryProvider.overrideWith((ref) => _FakeContactRepository()),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switch role updates first tab via top menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'unused',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        assetLoader: const MockAssetLoader(kTestTranslations),
        child: Builder(
          builder: (context) {
            return ProviderScope(
              overrides: [..._baseOverrides()],
              child: ScreenUtilInit(
                designSize: const Size(390, 844),
                minTextAdapt: true,
                splitScreenMode: true,
                builder: (context, child) {
                  return MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    home: const MainLayoutScreen(),
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Your Parcels'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('topbar-menu-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('topbar-menu-switch-role')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('topbar-menu-switch-language')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('topbar-menu-switch-role')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Receive Incoming Parcels'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('topbar-menu-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('topbar-menu-switch-role')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('topbar-menu-switch-role')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Your Parcels'), findsOneWidget);
  });

  testWidgets('customer tab jump request returns to parcel tab', (
    tester,
  ) async {
    final container = ProviderContainer(overrides: [..._baseOverrides()]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'unused',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        assetLoader: const MockAssetLoader(kTestTranslations),
        child: Builder(
          builder: (context) {
            return UncontrolledProviderScope(
              container: container,
              child: ScreenUtilInit(
                designSize: const Size(390, 844),
                minTextAdapt: true,
                splitScreenMode: true,
                builder: (context, child) {
                  return MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    home: const MainLayoutScreen(),
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Send'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Select parcel to forward'), findsOneWidget);

    container.read(customerTabJumpTargetProvider.notifier).state = 0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Your Parcels'), findsOneWidget);
  });

  testWidgets('customer notifications tab renders notifications screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'unused',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        assetLoader: const MockAssetLoader(kTestTranslations),
        child: Builder(
          builder: (context) {
            return ProviderScope(
              overrides: [..._baseOverrides()],
              child: ScreenUtilInit(
                designSize: const Size(390, 844),
                minTextAdapt: true,
                splitScreenMode: true,
                builder: (context, child) {
                  return MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    home: const MainLayoutScreen(),
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Notifications'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Notifications'), findsWidgets);
    expect(find.text('Forwarding completed'), findsOneWidget);
  });

  testWidgets('notification badge is hidden when there are no notifications', (
    tester,
  ) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'unused',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        assetLoader: const MockAssetLoader(kTestTranslations),
        child: Builder(
          builder: (context) {
            return ProviderScope(
              overrides: [
                ..._baseOverrides(),
                notificationsProvider.overrideWith(
                  (ref) async => const <AppNotification>[],
                ),
              ],
              child: ScreenUtilInit(
                designSize: const Size(390, 844),
                minTextAdapt: true,
                splitScreenMode: true,
                builder: (context, child) {
                  return MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    home: const MainLayoutScreen(),
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));

    final navBadgeFinder = find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.byType(Badge),
    );
    expect(navBadgeFinder, findsNothing);
  });

  testWidgets('customer profile tab renders profile screen', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'unused',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        assetLoader: const MockAssetLoader(kTestTranslations),
        child: Builder(
          builder: (context) {
            return ProviderScope(
              overrides: [..._baseOverrides()],
              child: ScreenUtilInit(
                designSize: const Size(390, 844),
                minTextAdapt: true,
                splitScreenMode: true,
                builder: (context, child) {
                  return MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    home: const MainLayoutScreen(),
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Somchai Rakdee'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-summary-0')), findsOneWidget);
  });

  testWidgets('customer contact tab renders contact screen', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'unused',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        assetLoader: const MockAssetLoader(kTestTranslations),
        child: Builder(
          builder: (context) {
            return ProviderScope(
              overrides: [..._baseOverrides()],
              child: ScreenUtilInit(
                designSize: const Size(390, 844),
                minTextAdapt: true,
                splitScreenMode: true,
                builder: (context, child) {
                  return MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    home: const MainLayoutScreen(),
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Contact'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Help/Contact Staff'), findsOneWidget);
    expect(find.byKey(const ValueKey('contact-send-button')), findsOneWidget);
  });

  testWidgets('staff scan pay tab renders scan pay screen', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'unused',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        assetLoader: const MockAssetLoader(kTestTranslations),
        child: Builder(
          builder: (context) {
            return ProviderScope(
              overrides: [..._baseOverrides()],
              child: ScreenUtilInit(
                designSize: const Size(390, 844),
                minTextAdapt: true,
                splitScreenMode: true,
                builder: (context, child) {
                  return MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    home: const MainLayoutScreen(),
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('topbar-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topbar-menu-switch-role')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Scan Pay'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey('staff-scan-pay-screen')), findsOneWidget);
    expect(find.text('Scan parcel delivery'), findsOneWidget);
  });
}
