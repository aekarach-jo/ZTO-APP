import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/orders/data/order_repository.dart';
import 'package:zto_app/features/orders/presentation/screens/order_history_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

Widget _buildTestApp(List<OrderSummary> orders) {
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
                  ordersProvider.overrideWith((ref) async => orders),
                ],
                child: const OrderHistoryScreen(),
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

  testWidgets('renders orders with LAK amount and status badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(const [
        OrderSummary(
          id: 'order-1',
          type: 'forward',
          paymentStatus: OrderPaymentState.paid,
          amount: 16050,
          recipientName: 'Somchai S.',
        ),
        OrderSummary(
          id: 'order-2',
          type: 'pickup',
          paymentStatus: OrderPaymentState.pending,
          amount: 25000,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forwarding order'), findsOneWidget);
    expect(find.text('Pickup order'), findsOneWidget);
    expect(find.text('₭16,050'), findsOneWidget);
    expect(find.text('₭25,000'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no orders', (tester) async {
    await tester.pumpWidget(_buildTestApp(const []));
    await tester.pumpAndSettle();

    expect(find.text('No orders yet'), findsOneWidget);
  });
}
