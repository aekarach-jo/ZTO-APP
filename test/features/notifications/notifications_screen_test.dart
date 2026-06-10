import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/notifications/data/notification_repository.dart';
import 'package:zto_app/features/notifications/presentation/screens/notifications_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

Widget _buildTestApp(Widget child) {
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

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Forwarding completed'), findsOneWidget);
    expect(find.text('Welcome to QuickPick!'), findsOneWidget);
  });
}

