import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/staff/data/staff_parcel_repository.dart';
import 'package:zto_app/features/staff/presentation/screens/staff_receive_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

class _FakeStaffParcelRepository extends StaffParcelRepository {
  _FakeStaffParcelRepository() : super(dio: Dio());

  @override
  Future<void> markInspected(String parcelId) async {}
}

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
                  staffParcelsProvider.overrideWith((ref) async {
                    return const [
                      StaffParcelItem(
                        id: '1',
                        title: 'Sony WH-1000XM5 Headphones',
                        trackNo: '#TH88291039',
                        weightLabel: '0.5 kg',
                        dateLabel: '15/5/2026',
                        status: 'pending',
                      ),
                    ];
                  }),
                  staffParcelRepositoryProvider.overrideWith(
                    (ref) => _FakeStaffParcelRepository(),
                  ),
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

  testWidgets('filters receive list and shows empty state', (tester) async {
    await tester.pumpWidget(_buildTestApp(const StaffReceiveScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Sony WH-1000XM5 Headphones'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'unknown-track');
    await tester.pump();

    expect(find.text('No incoming parcels match your search'), findsOneWidget);
  });

  testWidgets('tapping confirm inspection shows success or failure snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const StaffReceiveScreen()));
    await tester.pumpAndSettle();

    final confirmButton = find.byType(ElevatedButton);
    expect(confirmButton, findsOneWidget);
    await tester.ensureVisible(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
