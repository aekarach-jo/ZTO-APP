import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/staff/data/staff_parcel_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchParcels reads nested Swagger payload under data.data', () async {
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

    final repository = StaffParcelRepository(dio: dio);
    final parcels = await repository.fetchParcels();

    expect(parcels, hasLength(1));
    expect(parcels.first.id, '1');
    expect(parcels.first.title, 'Aekarach');
    expect(parcels.first.trackNo, '#DPK212498891087-1');
    expect(parcels.first.weightLabel, '17.32 kg');
    expect(parcels.first.status, 'ready');
  });
}
