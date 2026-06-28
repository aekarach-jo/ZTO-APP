import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/home/data/home_parcel_repository.dart';
import 'package:zto_app/features/profile/presentation/screens/profile_screen.dart';

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
                      HomeParcel(
                        id: '2',
                        title: 'Phillips Air Fryer',
                        trackingNo: '#TH88291040',
                        weightLabel: '3.2 kg',
                        dateLabel: '15/5/2026',
                        status: 'completed',
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

  testWidgets('shows profile overview content', (tester) async {
    await tester.pumpWidget(_buildTestApp(const ProfileScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Somchai Rakdee'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-summary-0')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-save-button')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-save-button')), findsOneWidget);
  });

  testWidgets('save button shows feedback snackbar', (tester) async {
    await tester.pumpWidget(_buildTestApp(const ProfileScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-save-button')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-save-button')));
    await tester.pump();

    expect(find.text('Profile location saved'), findsOneWidget);
  });

  testWidgets('switches section content when tapping summary cards', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const ProfileScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Processing'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-summary-1')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Service history'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Service history'), findsOneWidget);
    expect(find.text('No received history'), findsOneWidget);

    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 520),
      1200,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-summary-2')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Home delivery history'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Home delivery history'), findsOneWidget);
    expect(find.text('No home delivery history'), findsOneWidget);

    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 520),
      1200,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-summary-3')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delivery history'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Delivery history'), findsOneWidget);
    expect(find.text('Phillips Air Fryer'), findsOneWidget);
  });
}
