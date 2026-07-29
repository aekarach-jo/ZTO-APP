import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/core/network/network_providers.dart';
import 'package:zto_app/features/parcel_claim/data/parcel_claim_repository.dart';
import 'package:zto_app/features/parcel_claim/presentation/screens/parcel_claim_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

class _FakeParcelClaimRepository implements ParcelClaimRepository {
  final List<UnownedParcelsQuery> receivedQueries = <UnownedParcelsQuery>[];
  final List<List<Object>> submittedParcelIds = <List<Object>>[];

  @override
  Future<UnownedParcelPage> fetchUnownedParcels(
    UnownedParcelsQuery query,
  ) async {
    receivedQueries.add(query);

    final normalizedSearch = query.searchText.toLowerCase();
    final filtered = _allItems
        .where(
          (item) =>
              normalizedSearch.isEmpty ||
              item.trackNo.toLowerCase().contains(normalizedSearch) ||
              (item.name?.toLowerCase().contains(normalizedSearch) ?? false),
        )
        .toList(growable: false);

    final start = (query.page - 1) * query.perPage;
    final end = (start + query.perPage).clamp(0, filtered.length);
    final pagedItems = start >= filtered.length
        ? const <UnownedParcel>[]
        : filtered.sublist(start, end);

    return UnownedParcelPage(
      items: pagedItems,
      currentPage: query.page,
      perPage: query.perPage,
      total: filtered.length,
    );
  }

  @override
  Future<void> submitClaim({required List<Object> parcelIds}) async {
    submittedParcelIds.add(parcelIds);
  }
}

final List<UnownedParcel> _allItems = <UnownedParcel>[
  const UnownedParcel(
    selectionKey: 'num:2',
    claimId: 2,
    trackNo: '#xxxxx01',
    status: 'wait_import',
    weightLabel: '1.2 kg',
    name: 'Sony Headphones',
  ),
  for (var i = 2; i <= 20; i++)
    UnownedParcel(
      selectionKey: 'num:${100 + i}',
      claimId: 100 + i,
      trackNo: '#xxxxx${i.toString().padLeft(2, '0')}',
      status: i.isEven ? 'pending' : 'wait_import',
      weightLabel: '${i / 10} kg',
      name: 'Parcel $i',
    ),
  const UnownedParcel(
    selectionKey: 'str:parcel_003',
    claimId: 'parcel_003',
    trackNo: '#xxxxx21',
    status: 'ready',
    weightLabel: '3.0 kg',
    name: 'Phillips Air Fryer',
  ),
  for (var i = 22; i <= 25; i++)
    UnownedParcel(
      selectionKey: 'num:${100 + i}',
      claimId: 100 + i,
      trackNo: '#xxxxx$i',
      status: 'pending',
      weightLabel: '${i / 10} kg',
      name: 'Parcel $i',
    ),
];

Widget _buildTestApp(_FakeParcelClaimRepository repository) {
  return EasyLocalization(
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
            parcelClaimRepositoryProvider.overrideWithValue(repository),
            currentUserPhoneProvider.overrideWith(
              (ref) async => '+85620123456789',
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, _) {
              return MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: const ParcelClaimScreen(),
              );
            },
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parcels stay hidden until the full tracking number is typed', (
    tester,
  ) async {
    final repository = _FakeParcelClaimRepository();

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    // ดึงข้อมูลมาครบทุกหน้าตั้งแต่เข้าหน้าจอ แต่ยังไม่แสดงรายการ
    expect(
      repository.receivedQueries,
      contains(const UnownedParcelsQuery(page: 2, perPage: 20)),
    );
    expect(find.byType(Checkbox), findsNothing);
    expect(
      find.text('Enter the full tracking number to find your parcel'),
      findsOneWidget,
    );

    // กรอกยังไม่ครบเลข — ยังไม่แสดงรายการ
    await tester.enterText(find.byType(TextField), 'xxxxx');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    expect(
      find.text('Enter the full tracking number to find your parcel'),
      findsOneWidget,
    );

    // #xxxxx21 อยู่หน้าที่ 2 — กรอกเลขครบแล้วเจอ เพราะโหลดมาครบทุกหน้า
    await tester.enterText(find.byType(TextField), 'xxxxx21');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('1 parcels found'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('search filters unowned parcels and submit sends selected ids', (
    tester,
  ) async {
    final repository = _FakeParcelClaimRepository();

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Claim Parcel Ownership'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);

    await tester.enterText(find.byType(TextField), 'xxxxx01');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('1 parcels found'), findsOneWidget);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '#xxxxx01'), findsOneWidget);

    await tester.tap(find.text('Confirm these parcels are mine'));
    await tester.pumpAndSettle();

    // ต้องยืนยันผ่าน modal ก่อนถึงจะส่งคำขอจริง
    expect(find.text('Submit a claim for 1 parcel(s)?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('parcel-claim-confirm-submit')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      repository.submittedParcelIds,
      equals(const <List<Object>>[
        <Object>[2],
      ]),
    );
    expect(
      find.text('Claim request submitted. Please wait for admin approval'),
      findsOneWidget,
    );
    // การค้นหาเป็นการกรองฝั่ง frontend — ไม่ส่งคำค้นไป backend
    expect(
      repository.receivedQueries.every((query) => query.searchText.isEmpty),
      isTrue,
    );
  });

  testWidgets('selected parcel preview can clear hidden selections', (
    tester,
  ) async {
    final repository = _FakeParcelClaimRepository();

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'xxxxx01');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, '#xxxxx01'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'xxxxx21');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('1 parcels found'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '#xxxxx01'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('parcel-claim-clear-selection')),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 selected'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '#xxxxx01'), findsNothing);
  });
}
