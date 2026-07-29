import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/orders/data/order_repository.dart';
import 'package:zto_app/features/parcel_status/data/parcel_status_repository.dart';
import 'package:zto_app/features/profile/data/profile_repository.dart';
import 'package:zto_app/features/profile/presentation/screens/profile_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

Widget _buildTestApp(
  Widget child, {
  VoidCallback? onStatusFetch,
  VoidCallback? onOrdersFetch,
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
                  userProfileProvider.overrideWith((ref) async {
                    return const UserProfile(
                      id: 'u1',
                      displayName: 'Somchai Rakdee',
                      email: 'somchai@email.com',
                      phone: '02000000',
                      profileImage: '',
                    );
                  }),
                  ordersProvider.overrideWith((ref) async {
                    onOrdersFetch?.call();
                    return const [
                      OrderSummary(
                        id: 'o1',
                        type: 'pickup',
                        paymentStatus: OrderPaymentState.paid,
                        amount: 10000,
                        recipientName: 'rolan',
                      ),
                    ];
                  }),
                  parcelStatusProvider.overrideWith((ref) async {
                    onStatusFetch?.call();
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

    // The "current receiver location" card was removed from the profile page.
    expect(find.byKey(const ValueKey('profile-save-button')), findsNothing);
  });

  testWidgets('shows order history inline when tapping the 4th card', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const ProfileScreen()));
    await tester.pumpAndSettle();

    // Parcel content is shown first; orders are not.
    expect(find.byKey(const ValueKey('profile-order-item-o1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-summary-orders')));
    await tester.pumpAndSettle();

    // The order row is now rendered inline (no navigation).
    expect(find.byKey(const ValueKey('profile-order-item-o1')), findsOneWidget);
    expect(find.text('Sony WH-1000XM5 Headphones'), findsNothing);
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

  testWidgets('every summary card tap refetches the parcel status', (
    tester,
  ) async {
    var statusFetches = 0;
    await tester.pumpWidget(
      _buildTestApp(
        const ProfileScreen(),
        onStatusFetch: () => statusFetches++,
      ),
    );
    await tester.pumpAndSettle();
    expect(statusFetches, 1);

    await tester.tap(find.byKey(const ValueKey('profile-summary-selfPickup')));
    await tester.pumpAndSettle();
    expect(statusFetches, 2);

    // Tapping the tab that is already selected still refetches.
    await tester.tap(find.byKey(const ValueKey('profile-summary-selfPickup')));
    await tester.pumpAndSettle();
    expect(statusFetches, 3);
  });

  testWidgets('every order history card tap refetches the orders', (
    tester,
  ) async {
    var orderFetches = 0;
    await tester.pumpWidget(
      _buildTestApp(
        const ProfileScreen(),
        onOrdersFetch: () => orderFetches++,
      ),
    );
    await tester.pumpAndSettle();

    // Orders are only loaded once their tab is opened.
    expect(orderFetches, 0);

    await tester.tap(find.byKey(const ValueKey('profile-summary-orders')));
    await tester.pumpAndSettle();
    expect(orderFetches, 1);

    await tester.tap(find.byKey(const ValueKey('profile-summary-orders')));
    await tester.pumpAndSettle();
    expect(orderFetches, 2);
  });

  testWidgets('pull to refresh reloads the selected tab, not the parcel page', (
    tester,
  ) async {
    var statusFetches = 0;
    var orderFetches = 0;
    await tester.pumpWidget(
      _buildTestApp(
        const ProfileScreen(),
        onStatusFetch: () => statusFetches++,
        onOrdersFetch: () => orderFetches++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-summary-orders')));
    await tester.pumpAndSettle();
    expect(statusFetches, 1);
    expect(orderFetches, 1);

    await tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();

    // Orders tab is open, so the drag reloads the orders and leaves the
    // parcel page alone.
    expect(orderFetches, 2);
    expect(statusFetches, 1);
  });

  testWidgets('pull to refresh on a parcel tab reloads the parcel page', (
    tester,
  ) async {
    var statusFetches = 0;
    await tester.pumpWidget(
      _buildTestApp(
        const ProfileScreen(),
        onStatusFetch: () => statusFetches++,
      ),
    );
    await tester.pumpAndSettle();
    expect(statusFetches, 1);

    await tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();

    expect(statusFetches, 2);
  });
}
