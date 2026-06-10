import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/staff/data/staff_parcel_repository.dart';
import 'package:zto_app/features/staff/presentation/screens/staff_scan_pay_screen.dart';

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
                  handoverReadyParcelsProvider.overrideWith((ref) async => const []),
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

  testWidgets('shows scanner controls and empty ready list', (tester) async {
    await tester.pumpWidget(_buildTestApp(const StaffScanPayScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Scan parcel delivery'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('scan-pay-request-permission')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('scan-pay-scan-image')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('No pending handover items'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('No pending handover items'), findsOneWidget);
  });
}
