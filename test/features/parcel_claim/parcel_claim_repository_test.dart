import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/parcel_claim/data/parcel_claim_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fetchUnownedParcels uses expected endpoint and parses pagination',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
      late RequestOptions captured;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: const <String, dynamic>{
                  'success': true,
                  'data': {
                    'data': [
                      {
                        'id': 2,
                        'track_no': 'xxxxx01',
                        'status': 'wait_import',
                        'weight': 1.2,
                      },
                      {
                        'id': 'parcel_003',
                        'track_no': 'xxxxx02',
                        'status': 'ready',
                        'weight': 3.0,
                      },
                    ],
                    'meta': {'current_page': 2, 'per_page': 20, 'total': 41},
                  },
                },
              ),
            );
          },
        ),
      );

      final repository = ApiParcelClaimRepository(dio: dio);

      final page = await repository.fetchUnownedParcels(
        const UnownedParcelsQuery(page: 2, perPage: 20, searchText: 'sony'),
      );

      expect(captured.method, 'GET');
      expect(captured.path, '/parcels/unowned');
      expect(
        captured.queryParameters,
        equals({
          'page': 2,
          'perPage': 20,
          'trackNo': 'sony',
          'searchText': 'sony',
        }),
      );
      expect(page.currentPage, 2);
      expect(page.perPage, 20);
      expect(page.total, 41);
      expect(page.hasNextPage, isTrue);
      expect(page.items.first.claimId, 2);
      expect(page.items.first.trackNo, '#xxxxx01');
      expect(page.items.last.claimId, 'parcel_003');
      expect(page.items.last.status, 'ready');
    },
  );

  test('submitClaim posts parcel ids only', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    late RequestOptions captured;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: const <String, dynamic>{'success': true},
            ),
          );
        },
      ),
    );

    final repository = ApiParcelClaimRepository(dio: dio);

    await repository.submitClaim(parcelIds: const [2, 'parcel_003']);

    expect(captured.method, 'POST');
    expect(captured.path, '/parcels/claim-owner');
    expect(captured.data, {
      'parcelIds': const [2, 'parcel_003'],
    });
  });

  test('UnownedParcel falls back to tracking number when id is missing', () {
    final parcel = UnownedParcel.fromJson(const {
      'track_no': 'fallback-001',
      'status': 'pending',
      'weight': 0.8,
    });

    expect(parcel.claimId, 'fallback-001');
    expect(parcel.selectionKey, 'str:fallback-001');
    expect(parcel.trackNo, '#fallback-001');
  });
}
