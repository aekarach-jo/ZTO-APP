import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/parcel_status/data/parcel_status_repository.dart';
import 'package:zto_app/features/parcel_status/presentation/screens/parcel_status_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

ParcelStatusPage _samplePage() {
  return const ParcelStatusPage(
    counts: ParcelStatusCounts(inProgress: 1, selfPickup: 1, forwarded: 0),
    parcels: [
      ParcelStatusItem(
        id: '1',
        trackNo: 'TH88291039',
        name: 'Sony WH-1000XM5',
        status: 'pending',
        step: 1,
        category: ParcelStatusCategory.inProgress,
        weight: 0.5,
      ),
      ParcelStatusItem(
        id: '2',
        trackNo: 'OP100',
        name: 'One Piece Vol.100',
        status: 'success',
        step: 4,
        category: ParcelStatusCategory.selfPickup,
        order: ParcelStatusOrder(
          nestOrderId: 'uuid',
          type: 'pickup',
          amountLak: 25000,
          paymentRef: 'FCCREF123',
        ),
      ),
    ],
  );
}

Widget _buildTestApp(ParcelStatusPage page) {
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
                  parcelStatusProvider.overrideWith((ref) async => page),
                ],
                child: const ParcelStatusScreen(),
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

  testWidgets('shows counts and in-progress parcels by default', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(_samplePage()));
    await tester.pumpAndSettle();

    // in-progress parcel visible, self-pickup parcel hidden until tab switch
    expect(find.text('Sony WH-1000XM5'), findsOneWidget);
    expect(find.text('One Piece Vol.100'), findsNothing);
  });

  testWidgets('switching to self-pickup tab shows its parcels and order', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(_samplePage()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('parcel-status-count-selfPickup')),
    );
    await tester.pumpAndSettle();

    expect(find.text('One Piece Vol.100'), findsOneWidget);
    expect(find.text('Sony WH-1000XM5'), findsNothing);
    expect(find.text('₭25,000'), findsOneWidget);
  });

  testWidgets('empty category shows empty state', (tester) async {
    await tester.pumpWidget(_buildTestApp(_samplePage()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('parcel-status-count-forwarded')),
    );
    await tester.pumpAndSettle();

    expect(find.text('No parcels in this category'), findsOneWidget);
  });
}
