import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/parcel_status/data/parcel_status_repository.dart';
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
                  parcelStatusProvider.overrideWith((ref) async {
                    return const ParcelStatusPage(
                      counts: ParcelStatusCounts(
                        inProgress: 1,
                        selfPickup: 1,
                        forwarded: 0,
                      ),
                      parcels: [
                        ParcelStatusItem(
                          id: '1',
                          name: 'Sony WH-1000XM5 Headphones',
                          trackNo: 'TH88291039',
                          weight: 0.5,
                          status: 'pending',
                          step: 1,
                          category: ParcelStatusCategory.inProgress,
                        ),
                        ParcelStatusItem(
                          id: '2',
                          name: 'One Piece Vol.100',
                          trackNo: 'TH88291040',
                          status: 'success',
                          step: 4,
                          category: ParcelStatusCategory.selfPickup,
                        ),
                      ],
                    );
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
    expect(
      find.byKey(const ValueKey('profile-summary-inProgress')),
      findsOneWidget,
    );
    expect(find.text('At home'), findsNothing);
    expect(find.text('Sony WH-1000XM5 Headphones'), findsOneWidget);

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

  testWidgets('switches shared status content when tapping summary cards', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const ProfileScreen()));
    await tester.pumpAndSettle();

    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Sony WH-1000XM5 Headphones'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-summary-selfPickup')));
    await tester.pumpAndSettle();

    expect(find.text('One Piece Vol.100'), findsOneWidget);
    expect(find.text('Sony WH-1000XM5 Headphones'), findsNothing);
    expect(find.text('At home'), findsNothing);
  });
}
