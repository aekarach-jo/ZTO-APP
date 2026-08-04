import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/notifications/data/notification_repository.dart';
import 'package:zto_app/features/notifications/presentation/screens/notifications_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

class _FakeNotificationRepository extends NotificationRepository {
  _FakeNotificationRepository() : super(dio: Dio());

  final List<String> markedReadIds = [];
  int deleteAllCallCount = 0;

  @override
  Future<void> markAsRead(String id) async {
    markedReadIds.add(id);
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCallCount += 1;
  }
}

Widget _buildTestApp(
  Widget child, {
  _FakeNotificationRepository? notificationRepository,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('en')],
    path: 'unused',
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    assetLoader: const MockAssetLoader(kTestTranslations),
    child: Builder(
      builder: (context) {
        return ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, _) {
            return MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: ProviderScope(
                overrides: [
                  if (notificationRepository != null)
                    notificationRepositoryProvider.overrideWithValue(
                      notificationRepository,
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
                      AppNotification(
                        id: 'n2',
                        title: 'Welcome to QuickPick!',
                        message: 'Thanks for signing up.',
                        timeLabel: '2h ago',
                        isUnread: false,
                      ),
                    ];
                  }),
                ],
                child: Scaffold(body: child),
              ),
            );
          },
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows notification list with count badge', (tester) async {
    await tester.pumpWidget(_buildTestApp(const NotificationsScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Forwarding completed'), findsOneWidget);
    expect(find.text('Welcome to QuickPick!'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
  });

  testWidgets('does not mark notifications as read when the screen loads', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository();

    await tester.pumpWidget(
      _buildTestApp(
        const NotificationsScreen(),
        notificationRepository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.markedReadIds, isEmpty);
  });

  testWidgets(
    'marks an unread notification as read only when its item is tapped',
    (tester) async {
      final repository = _FakeNotificationRepository();

      await tester.pumpWidget(
        _buildTestApp(
          const NotificationsScreen(),
          notificationRepository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Welcome to QuickPick!'));
      await tester.pumpAndSettle();
      expect(repository.markedReadIds, isEmpty);

      await tester.tap(find.text('Forwarding completed'));
      await tester.pumpAndSettle();

      expect(repository.markedReadIds, ['n1']);
    },
  );

  testWidgets('clears all notifications only after confirmation', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository();

    await tester.pumpWidget(
      _buildTestApp(
        const NotificationsScreen(),
        notificationRepository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    expect(find.text('Clear all notifications?'), findsOneWidget);
    expect(repository.deleteAllCallCount, 0);

    await tester.tap(find.text('Clear').last);
    await tester.pumpAndSettle();

    expect(repository.deleteAllCallCount, 1);
    expect(find.text('All notifications cleared'), findsOneWidget);
  });
}
