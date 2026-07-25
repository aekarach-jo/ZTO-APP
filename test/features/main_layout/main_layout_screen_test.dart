import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/core/network/models/auth_tokens.dart';
import 'package:zto_app/core/network/network_providers.dart';
import 'package:zto_app/core/network/storage/token_storage.dart';
import 'package:zto_app/features/branch/data/branch_repository.dart';
import 'package:zto_app/features/contact/data/chat_socket_service.dart';
import 'package:zto_app/features/contact/data/contact_repository.dart';
import 'package:zto_app/features/home/data/home_parcel_repository.dart';
import 'package:zto_app/features/notifications/data/notification_repository.dart';
import 'package:zto_app/features/parcel_status/data/parcel_status_repository.dart';
import 'package:zto_app/features/profile/data/profile_repository.dart';
import 'package:zto_app/features/send/data/send_repository.dart';
import 'package:zto_app/features/staff/data/staff_parcel_repository.dart';
import 'package:zto_app/features/auth/data/auth_repository.dart';
import 'package:zto_app/features/main_layout/application/main_layout_navigation_provider.dart';
import 'package:zto_app/features/main_layout/presentation/screens/main_layout_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

class _MainLayoutLocaleAssetLoader extends AssetLoader {
  const _MainLayoutLocaleAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final translations = switch (locale.languageCode) {
      'lo' => const {
        'your_parcels': 'ລາຍການພັດສະດຸຂອງທ່ານ',
        'switch_branch': 'ປ່ຽນສາຂາ',
        'brand_subtitle': 'ສູນຮັບ-ສົ່ງພັດສະດຸດ່ວນ',
      },
      'zh' => const {
        'your_parcels': '您的包裹',
        'switch_branch': '切换网点',
        'brand_subtitle': '快捷取件中心',
      },
      _ => const {
        'your_parcels': 'Your Parcels',
        'switch_branch': 'SWITCH BRANCH',
        'brand_subtitle': 'Express Pickup Hub',
      },
    };

    return {...kTestTranslations, ...translations};
  }
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

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

class _FakeContactRepository extends ContactRepository {
  _FakeContactRepository() : super(dio: Dio());

  @override
  Future<String> resolveRoomId() async => 'branch-1-user-2';

  @override
  Future<List<ContactMessage>> fetchMessages(String roomId) async {
    return const [];
  }
}

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<AuthTokens?> read() async =>
      const AuthTokens(accessToken: 'test-token', refreshToken: 'r');

  @override
  Future<void> save(AuthTokens tokens) async {}

  @override
  Future<void> clear() async {}
}

class _NoopChatSocket implements ChatSocket {
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _status = StreamController<ChatSocketStatus>.broadcast();

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Stream<ChatSocketStatus> get status => _status.stream;

  @override
  bool get isConnected => true;

  @override
  void connect(String accessToken) {}

  @override
  void joinRoom(String roomId) {}

  @override
  void leaveRoom(String roomId) {}

  @override
  void sendMessage({
    required String roomId,
    String content = '',
    String? imageUrl,
  }) {}

  @override
  void disconnect() {}

  @override
  void dispose() {
    _messages.close();
    _errors.close();
    _status.close();
  }
}

List<Override> _baseOverrides() {
  return [
    authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
    userProfileProvider.overrideWith((ref) async {
      return const UserProfile(
        id: 'u1',
        displayName: 'Somchai Rakdee',
        email: 'somchai@email.com',
        phone: '02000000',
        profileImage: '',
      );
    }),
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
    parcelStatusProvider.overrideWith(
      (ref) async => const ParcelStatusPage(
        counts: ParcelStatusCounts(inProgress: 1, selfPickup: 0, forwarded: 0),
        parcels: [
          ParcelStatusItem(
            id: '1',
            trackNo: 'TH88291039',
            name: 'Sony WH-1000XM5 Headphones',
            status: 'pending',
            step: 1,
            category: ParcelStatusCategory.inProgress,
            weight: 0.5,
          ),
        ],
      ),
    ),
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
    tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
    chatSocketProvider.overrideWithValue(_NoopChatSocket()),
    branchesProvider.overrideWith(
      (ref) async => const [
        Branch(id: 'b-cls', name: 'CLS Express', code: 'CLS'),
        Branch(id: 'b-kd', name: 'KD Express', code: 'KD'),
      ],
    ),
    currentBranchIdProvider.overrideWith((ref) async => 'b-cls'),
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
    expect(find.text('SWITCH BRANCH'), findsOneWidget);
    expect(find.byKey(const ValueKey('topbar-language-en')), findsOneWidget);
    expect(find.byKey(const ValueKey('topbar-language-lo')), findsOneWidget);
    expect(find.byKey(const ValueKey('topbar-language-zh')), findsOneWidget);
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
    await tester.pumpAndSettle();

    expect(find.text('Your Parcels'), findsOneWidget);
  });

  testWidgets('top menu flags switch the whole app locale', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('lo'), Locale('zh')],
        path: 'unused',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        saveLocale: false,
        assetLoader: const _MainLayoutLocaleAssetLoader(),
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
    await tester.pumpAndSettle();

    expect(find.text('Your Parcels'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('topbar-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topbar-language-lo')));
    await tester.pumpAndSettle();

    expect(find.text('ລາຍການພັດສະດຸຂອງທ່ານ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('topbar-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topbar-language-zh')));
    await tester.pumpAndSettle();

    expect(find.text('您的包裹'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('topbar-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topbar-language-en')));
    await tester.pumpAndSettle();

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

  testWidgets('notification badge shows unread count while on another tab', (
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
                  (ref) async => const <AppNotification>[
                    AppNotification(
                      id: 'n1',
                      title: 'Unread 1',
                      message: 'First unread notification',
                      timeLabel: '1m ago',
                      isUnread: true,
                    ),
                    AppNotification(
                      id: 'n2',
                      title: 'Read notification',
                      message: 'Already read notification',
                      timeLabel: '2m ago',
                      isUnread: false,
                    ),
                    AppNotification(
                      id: 'n3',
                      title: 'Unread 2',
                      message: 'Second unread notification',
                      timeLabel: '3m ago',
                      isUnread: true,
                    ),
                  ],
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

    await tester.pumpAndSettle();

    expect(find.text('Your Parcels'), findsOneWidget);

    final navBadgeFinder = find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.byType(Badge),
    );
    expect(navBadgeFinder, findsOneWidget);
    expect(
      find.descendant(of: navBadgeFinder, matching: find.text('2')),
      findsOneWidget,
    );
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
    expect(
      find.byKey(const ValueKey('profile-summary-inProgress')),
      findsOneWidget,
    );
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
