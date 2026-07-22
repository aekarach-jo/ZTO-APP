import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/home/data/home_parcel_repository.dart';
import 'package:zto_app/features/home/presentation/screens/home_screen.dart';
import 'package:zto_app/features/main_layout/application/main_layout_navigation_provider.dart';
import 'package:zto_app/features/send/application/send_forward_prefill_provider.dart';

import '../../test_helpers/mock_asset_loader.dart';

class _ParcelLocaleAssetLoader extends AssetLoader {
  const _ParcelLocaleAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final buttonTranslations = switch (locale.languageCode) {
      'lo' => const {'action_pickup': 'ຮັບເອງ', 'action_forward': 'ສົ່ງຕໍ່'},
      'zh' => const {'action_pickup': '自取', 'action_forward': '转运'},
      _ => const {'action_pickup': 'Pickup', 'action_forward': 'Forward'},
    };

    return {...kTestTranslations, ...buttonTranslations};
  }
}

Widget _buildTestApp(
  Widget child, {
  List<Locale> supportedLocales = const [Locale('en')],
  AssetLoader assetLoader = const MockAssetLoader(kTestTranslations),
  bool showLocaleControls = false,
  List<HomeParcel> parcels = const [
    HomeParcel(
      id: '1',
      title: 'Sony WH-1000XM5 Headphones',
      trackingNo: '#TH88291039',
      weightLabel: '0.5 kg',
      dateLabel: '14/5/2026',
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
  ],
}) {
  return EasyLocalization(
    supportedLocales: supportedLocales,
    path: 'unused',
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    saveLocale: false,
    assetLoader: assetLoader,
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
                    return parcels;
                  }),
                ],
                child: Scaffold(
                  appBar: showLocaleControls
                      ? AppBar(
                          actions: [
                            for (final locale in supportedLocales)
                              TextButton(
                                key: ValueKey('switch-${locale.languageCode}'),
                                onPressed: () => context.setLocale(locale),
                                child: Text(locale.languageCode),
                              ),
                          ],
                        )
                      : null,
                  body: child,
                ),
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

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-track-status-button')),
      findsNothing,
    );
    expect(find.text('Track'), findsNothing);
    expect(find.text('Sony WH-1000XM5 Headphones'), findsNothing);
    expect(find.text('#TH88291039'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Phillips');
    await tester.pumpAndSettle();

    expect(find.text('Phillips Air Fryer'), findsNothing);
    expect(find.text('#TH88291040'), findsOneWidget);
    expect(find.text('#TH88291039'), findsNothing);

    await tester.enterText(find.byType(TextField), 'not-found-keyword');
    await tester.pumpAndSettle();

    expect(find.text('No parcels match your search'), findsOneWidget);
  });

  testWidgets('grouped parcels hide titles and share one action row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        const HomeScreen(),
        parcels: const [
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
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sony WH-1000XM5 Headphones'), findsNothing);
    expect(find.text('Phillips Air Fryer'), findsNothing);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Forward'), findsOneWidget);
    expect(find.text('#TH88291039'), findsOneWidget);
    expect(find.text('#TH88291040'), findsOneWidget);
  });

  testWidgets('tapping forward pre-selects the parcel and requests send tab', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Phillips');
    await tester.pumpAndSettle();

    expect(find.text('Pickup'), findsOneWidget);
    final actionButton = find.text('Forward');
    expect(actionButton, findsOneWidget);
    await tester.ensureVisible(actionButton);
    await tester.pumpAndSettle();
    await tester.tap(actionButton);
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    // Forward pre-selects the parcel (id '2') and asks the shell to jump to
    // the Send tab (index 1) instead of showing a "coming soon" snackbar.
    expect(container.read(sendForwardPrefillProvider), '2');
    expect(container.read(customerTabJumpTargetProvider), 1);
  });

  testWidgets('updates parcel actions when locale changes', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        const HomeScreen(),
        supportedLocales: const [Locale('en'), Locale('lo'), Locale('zh')],
        assetLoader: const _ParcelLocaleAssetLoader(),
        showLocaleControls: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Forward'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('switch-lo')));
    await tester.pumpAndSettle();

    expect(find.text('ຮັບເອງ'), findsOneWidget);
    expect(find.text('ສົ່ງຕໍ່'), findsOneWidget);
    expect(find.text('Pickup'), findsNothing);
    expect(find.text('Forward'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('switch-zh')));
    await tester.pumpAndSettle();

    expect(find.text('自取'), findsOneWidget);
    expect(find.text('转运'), findsOneWidget);
    expect(find.text('ຮັບເອງ'), findsNothing);
    expect(find.text('ສົ່ງຕໍ່'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('switch-en')));
    await tester.pumpAndSettle();

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Forward'), findsOneWidget);
    expect(find.text('自取'), findsNothing);
    expect(find.text('转运'), findsNothing);
  });
}
