import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/send/data/send_repository.dart';
import 'package:zto_app/features/send/presentation/screens/send_screen.dart';

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
                  sendParcelsProvider.overrideWith((ref) async {
                    return const [
                      SendParcelItem(
                        id: 'TH88291039',
                        title: 'Sony WH-1000XM5 Headphones',
                        trackNo: '#TH88291039',
                        weightKg: 0.5,
                      ),
                      SendParcelItem(
                        id: 'TH88291040',
                        title: 'Phillips Air Fryer',
                        trackNo: '#TH88291040',
                        weightKg: 3.2,
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

/// Opens the delivery-branch dropdown and picks ອານຸສິດ. The option exists twice
/// once the menu is open — in the closed field and in the overlay — so tap the
/// last one.
Future<void> _selectDeliveryBranch(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('send-input-branch')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('send-input-branch')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('send-branch-option-ອານຸສິດ')).last,
  );
  await tester.pumpAndSettle();
}

/// Picks the first parcel and moves on to the recipient-details step.
Future<void> _openRecipientStep(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('send-item-TH88291039')));
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('send-next-button')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('send-next-button')),
      matching: find.byType(ElevatedButton),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows send list and keeps next disabled until selection', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const SendScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Select parcel to forward'), findsOneWidget);
    expect(find.text('Sony WH-1000XM5 Headphones'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-item-TH88291040')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Phillips Air Fryer'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-next-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final nextButtonFinder = find.descendant(
      of: find.byKey(const ValueKey('send-next-button')),
      matching: find.byType(ElevatedButton),
    );

    ElevatedButton nextButton = tester.widget<ElevatedButton>(nextButtonFinder);
    expect(nextButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('send-item-TH88291040')));
    await tester.pumpAndSettle();

    nextButton = tester.widget<ElevatedButton>(nextButtonFinder);
    expect(nextButton.onPressed, isNotNull);
  });

  testWidgets(
    'moves to recipient details after selecting item and tapping next',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(const SendScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('send-item-TH88291039')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('send-next-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final nextButtonFinder = find.descendant(
        of: find.byKey(const ValueKey('send-next-button')),
        matching: find.byType(ElevatedButton),
      );
      await tester.tap(nextButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('send-recipient-step')), findsOneWidget);
    },
  );

  testWidgets('recipient phone keeps only the digits after +856 20', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const SendScreen()));
    await tester.pumpAndSettle();
    await _openRecipientStep(tester);

    final phoneField = find.descendant(
      of: find.byKey(const ValueKey('send-input-recipient-phone')),
      matching: find.byType(TextField),
    );
    await tester.enterText(phoneField, 'abc 99-88-77-66 xyz');
    await tester.pumpAndSettle();

    expect(find.text('+856 20 '), findsOneWidget);
    expect(tester.widget<TextField>(phoneField).controller?.text, '99887766');
  });

  testWidgets('delivery branch offers the Lao branch names', (tester) async {
    await tester.pumpWidget(_buildTestApp(const SendScreen()));
    await tester.pumpAndSettle();
    await _openRecipientStep(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-input-branch')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('send-input-branch')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('send-branch-option-ອານຸສິດ')),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('send-branch-option-ມີໄຊ')), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('send-branch-option-ມີໄຊ')).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('ມີໄຊ'), findsOneWidget);
  });

  testWidgets('enables pin-address button when recipient form is complete', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const SendScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('send-item-TH88291039')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-next-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('send-next-button')),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pumpAndSettle();

    final pinButtonFinder = find.descendant(
      of: find.byKey(const ValueKey('send-pin-map-button')),
      matching: find.byType(ElevatedButton),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-pin-map-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    ElevatedButton pinButton = tester.widget<ElevatedButton>(pinButtonFinder);
    expect(pinButton.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('send-input-recipient-name')),
      'John Doe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('send-input-recipient-phone')),
      '0891234567',
    );
    await tester.enterText(
      find.byKey(const ValueKey('send-input-recipient-address')),
      '123 Main Road',
    );
    await tester.enterText(
      find.byKey(const ValueKey('send-input-courier')),
      'Flash',
    );

    await _selectDeliveryBranch(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-pin-map-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    pinButton = tester.widget<ElevatedButton>(pinButtonFinder);
    expect(pinButton.onPressed, isNotNull);
  });

  testWidgets('moves to map step after tapping pin-address button', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const SendScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('send-item-TH88291039')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-next-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('send-next-button')),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-pin-map-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('send-input-recipient-name')),
      'John Doe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('send-input-recipient-phone')),
      '0891234567',
    );
    await tester.enterText(
      find.byKey(const ValueKey('send-input-recipient-address')),
      '123 Main Road',
    );
    await tester.enterText(
      find.byKey(const ValueKey('send-input-courier')),
      'Flash',
    );
    await _selectDeliveryBranch(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-pin-map-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('send-pin-map-button')),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('send-pin-step')), findsOneWidget);
  });

  testWidgets('moves to payment step and shows LAK fee breakdown', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const SendScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('send-item-TH88291039')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-next-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('send-next-button')),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-pin-map-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('send-input-recipient-name')),
      'John Doe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('send-input-recipient-phone')),
      '0891234567',
    );
    await tester.enterText(
      find.byKey(const ValueKey('send-input-recipient-address')),
      '123 Main Road',
    );
    await tester.enterText(
      find.byKey(const ValueKey('send-input-courier')),
      'Flash',
    );
    await _selectDeliveryBranch(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-pin-map-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('send-pin-map-button')),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-next-summary-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('send-next-summary-button')),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('send-summary-step')), findsOneWidget);
    expect(find.text('Forwarding payment'), findsOneWidget);

    // 0.5 kg → billed 1 kg → shipping fee 13,000 kip (LAK, no VAT).
    expect(find.text('₭13,000'), findsWidgets);
    expect(find.text('₭910'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('send-confirm-forward-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('send-confirm-forward-button')),
      findsOneWidget,
    );
  });
}
