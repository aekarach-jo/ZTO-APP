import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/home/data/home_parcel_repository.dart';
import 'package:zto_app/features/home/presentation/screens/home_screen.dart';

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
                        status: 'ready_to_ship',
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

  testWidgets('filters parcel list and shows empty state', (tester) async {
    await tester.pumpWidget(_buildTestApp(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Sony WH-1000XM5 Headphones'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Phillips');
    await tester.pumpAndSettle();

    expect(find.text('Phillips Air Fryer'), findsOneWidget);
    expect(find.text('Sony WH-1000XM5 Headphones'), findsNothing);

    await tester.enterText(find.byType(TextField), 'not-found-keyword');
    await tester.pumpAndSettle();

    expect(find.text('No parcels match your search'), findsOneWidget);
  });

  testWidgets('tapping parcel action shows not implemented snackbar', (tester) async {
    await tester.pumpWidget(_buildTestApp(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Phillips');
    await tester.pumpAndSettle();

    final actionButton = find.text('Drop at Service Point');
    expect(actionButton, findsOneWidget);
    await tester.ensureVisible(actionButton);
    await tester.pumpAndSettle();
    await tester.tap(actionButton);
    await tester.pump();

    expect(find.text('This action is coming soon'), findsOneWidget);
  });
}


