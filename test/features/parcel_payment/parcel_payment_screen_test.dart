import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/parcel_payment/data/payment_repository.dart';
import 'package:zto_app/features/parcel_payment/presentation/screens/parcel_payment_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

/// Fake repository: initiating returns a QR, status always reports unpaid so
/// the screen stays on the QR step for the duration of the test.
class _FakePaymentRepository extends PaymentRepository {
  _FakePaymentRepository() : super(dio: Dio());

  int statusChecks = 0;

  @override
  Future<PaymentInitiation> initiatePayment({
    required String orderId,
    String method = PaymentMethods.onepay,
  }) async {
    return const PaymentInitiation(
      transactionRef: 'ref',
      method: 'onepay',
      qrString: '00020101021138TESTQR6304ABCD',
    );
  }

  @override
  Future<OrderPaymentStatus> fetchPaymentStatus(String orderId) async {
    statusChecks++;
    return const OrderPaymentStatus(isPaid: false);
  }
}

Widget _buildTestApp(
  _FakePaymentRepository repository, {
  ParcelPaymentArgs args = const ParcelPaymentArgs.forOrder(
    order: ParcelOrder(
      id: 'order-1',
      type: 'pickup',
      paymentStatus: 'pending',
      amount: 14000,
    ),
    itemName: '美玉',
  ),
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
                  paymentRepositoryProvider.overrideWithValue(repository),
                ],
                child: ParcelPaymentScreen(args: args),
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

  testWidgets(
    'forward review uses item.price, combined shipping, and order total',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakePaymentRepository();
      await tester.pumpWidget(
        _buildTestApp(
          repository,
          args: const ParcelPaymentArgs.forOrder(
            order: ParcelOrder(
              id: 'forward-order-1',
              type: 'forward',
              paymentStatus: 'pending',
              amount: 43000,
              items: [
                OrderItem(
                  laravelParcelId: 'parcel-1',
                  price: 10000,
                  shippingFee: 13000,
                  itemTotal: 23000,
                ),
                OrderItem(
                  laravelParcelId: 'parcel-2',
                  price: 20000,
                  shippingFee: 0,
                  itemTotal: 20000,
                ),
              ],
            ),
            shippingFee: 13000,
            parcels: [
              PickupPaymentParcel(
                parcelId: 'parcel-1',
                title: 'Parcel one',
                amount: 10000,
              ),
              PickupPaymentParcel(
                parcelId: 'parcel-2',
                title: 'Parcel two',
                amount: 20000,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₭10,000'), findsOneWidget);
      expect(find.text('₭20,000'), findsOneWidget);
      expect(find.text('Forwarding fee'), findsOneWidget);
      expect(find.text('₭13,000'), findsOneWidget);
      expect(find.text('₭43,000'), findsWidgets);
      expect(find.text('₭23,000'), findsNothing);
    },
  );

  testWidgets(
    'QR step shows "I\'ve paid" button first, waiting indicator only after tap',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakePaymentRepository();
      await tester.pumpWidget(_buildTestApp(repository));
      // Review step has no polling timer yet, so settle to load localization.
      await tester.pumpAndSettle();

      // Review step → start payment.
      await tester.tap(find.byKey(const ValueKey('pickup-payment-pay-button')));
      await tester.pump(); // start _startJob
      await tester.pump(const Duration(milliseconds: 50)); // resolve futures
      await tester.pump(); // rebuild QR phase

      // QR content is tall; scroll the button into view (it is built lazily).
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pickup-payment-confirm-paid-button')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // QR step: button visible, waiting indicator hidden.
      expect(
        find.byKey(const ValueKey('pickup-payment-confirm-paid-button')),
        findsOneWidget,
      );
      expect(find.text("I've paid"), findsOneWidget);
      expect(find.text('Waiting for payment confirmation...'), findsNothing);

      // Tap "I've paid" → waiting indicator revealed, button gone.
      await tester.tap(
        find.byKey(const ValueKey('pickup-payment-confirm-paid-button')),
      );
      await tester.pump(); // rebuild + resolve immediate status check
      await tester.pump();

      expect(
        find.byKey(const ValueKey('pickup-payment-confirm-paid-button')),
        findsNothing,
      );
      expect(find.text('Waiting for payment confirmation...'), findsOneWidget);
      // Tapping "I've paid" triggers an immediate status check.
      expect(repository.statusChecks, greaterThanOrEqualTo(1));
    },
  );
}
