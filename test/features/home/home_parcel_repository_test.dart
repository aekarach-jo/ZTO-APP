import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/home/data/home_parcel_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fetchMyParcels flattens grouped parcel payload into parcel list',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: const <String, dynamic>{
                  'success': true,
                  'data': [
                    {
                      'incoming_at': '2024-06-19T10:00:00Z',
                      'incoming_at_str': '2024-06-19',
                      'parcels': [
                        {
                          'id': 'parcel_001',
                          'track_no': 'xxxxx00',
                          'status': 'ready',
                          'weight': 2.5,
                        },
                      ],
                    },
                    {
                      'incoming_at': '2024-06-20T12:30:00Z',
                      'incoming_at_str': '2024-06-20',
                      'parcels': [
                        {
                          'id': 'parcel_002',
                          'track_no': 'xxxxx01',
                          'status': 'pending',
                          'weight': 1.2,
                        },
                      ],
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final repository = HomeParcelRepository(dio: dio);
      final parcels = await repository.fetchMyParcels();

      expect(parcels, hasLength(2));
      expect(parcels.first.id, 'parcel_001');
      expect(parcels.first.trackingNo, '#xxxxx00');
      expect(parcels.first.dateLabel, '19/6/2024');
      expect(parcels.last.id, 'parcel_002');
      expect(parcels.last.dateLabel, '20/6/2024');
    },
  );

  test('fetchMyParcels reads nested Swagger payload under data.data', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: const <String, dynamic>{
                'success': true,
                'data': {
                  'code': 200,
                  'status': 'OK',
                  'total': 1,
                  'data': [
                    {
                      'incoming_at': '2026-06-28 17:08:28',
                      'incoming_at_str': '2026-06-28',
                      'parcels': [
                        {
                          'id': 1,
                          'track_no': 'DPK212498891087-1',
                          'name': 'Aekarach',
                          'weight': 17.32,
                          'status': 'ready',
                        },
                      ],
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );

    final repository = HomeParcelRepository(dio: dio);
    final parcels = await repository.fetchMyParcels();

    expect(parcels, hasLength(1));
    expect(parcels.first.id, '1');
    expect(parcels.first.title, 'Aekarach');
    expect(parcels.first.trackingNo, '#DPK212498891087-1');
    expect(parcels.first.dateLabel, '28/6/2026');
  });
}
