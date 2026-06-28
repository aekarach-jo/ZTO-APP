import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zto_app/core/network/network_providers.dart';
import 'package:zto_app/features/home/data/home_parcel_repository.dart';
import 'package:zto_app/features/home/presentation/screens/home_screen.dart';
import 'package:zto_app/features/parcel_claim/data/parcel_claim_repository.dart';
import 'package:zto_app/features/parcel_claim/presentation/screens/parcel_claim_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

class _FakeParcelClaimRepository implements ParcelClaimRepository {
  @override
  Future<UnownedParcelPage> fetchUnownedParcels(
    UnownedParcelsQuery query,
  ) async {
    return const UnownedParcelPage(
      items: [
        UnownedParcel(
          selectionKey: 'num:1',
          claimId: 1,
          trackNo: '#track-001',
          status: 'pending',
          weightLabel: '1.0 kg',
          name: 'Sample Parcel',
        ),
      ],
      currentPage: 1,
      perPage: 20,
      total: 1,
    );
  }

  @override
  Future<void> submitClaim({required List<Object> parcelIds}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home claim entry navigates to parcel claim screen', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: HomeScreen()),
        ),
        GoRoute(
          path: ParcelClaimScreen.routePath,
          builder: (context, state) =>
              const Scaffold(body: ParcelClaimScreen()),
        ),
      ],
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'unused',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        saveLocale: false,
        assetLoader: const MockAssetLoader(kTestTranslations),
        child: Builder(
          builder: (context) {
            return ProviderScope(
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
                  ];
                }),
                parcelClaimRepositoryProvider.overrideWithValue(
                  _FakeParcelClaimRepository(),
                ),
                currentUserPhoneProvider.overrideWith(
                  (ref) async => '+85620123456789',
                ),
              ],
              child: ScreenUtilInit(
                designSize: const Size(390, 844),
                minTextAdapt: true,
                splitScreenMode: true,
                builder: (context, child) {
                  return MaterialApp.router(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    routerConfig: router,
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-claim-entry-card')));
    await tester.pumpAndSettle();

    expect(find.byType(ParcelClaimScreen), findsOneWidget);
    expect(find.text('Claim Parcel Ownership'), findsOneWidget);
  });
}
