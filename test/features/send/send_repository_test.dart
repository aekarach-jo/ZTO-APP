import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/send/data/send_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchForwardableParcels flattens grouped parcel payload', () async {
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

    final repository = SendRepository(dio: dio);
    final parcels = await repository.fetchForwardableParcels();

    expect(parcels, hasLength(2));
    expect(parcels.first.id, 'parcel_001');
    expect(parcels.first.trackNo, '#xxxxx00');
    expect(parcels.first.weightKg, 2.5);
    expect(parcels.last.id, 'parcel_002');
    expect(parcels.last.trackNo, '#xxxxx01');
    expect(parcels.last.weightKg, 1.2);
  });

  test('createForwardRequest posts NestJS forward payload and returns order', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    late RequestOptions captured;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 201,
              data: const <String, dynamic>{
                'success': true,
                'message': 'Forward order created',
                'data': {
                  'id': 'order-uuid-1',
                  'type': 'forward',
                  'amount': 40000,
                  'currency': 'LAK',
                  'items': [
                    {
                      'laravelParcelId': 999053943084,
                      'price': 25000,
                      'shippingFee': 15000,
                      'itemTotal': 40000,
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );

    final repository = SendRepository(dio: dio);

    final order = await repository.createForwardRequest(
      const CreateForwardRequest(
        parcelId: '999053943084',
        recipientName: 'Jane Doe',
        recipientPhone: '0891234567',
        recipientAddress: '123 Main Road',
        courierName: 'Flash',
        branchName: 'VTE-01',
        latitude: 17.9757,
        longitude: 102.6331,
      ),
    );

    expect(captured.method, 'POST');
    expect(captured.path, '/orders/forward');
    expect(captured.data, {
      'parcels': [
        {
          'laravelParcelId': 999053943084,
          'recipientName': 'Jane Doe',
          'recipientPhone': '0891234567',
          'recipientAddress': '123 Main Road',
          'courierName': 'Flash',
          'branchName': 'VTE-01',
          'lat': 17.9757,
          'lng': 102.6331,
        },
      ],
    });
    expect(order.id, 'order-uuid-1');
    expect(order.type, 'forward');
    expect(order.amount, 40000);
    expect(order.items.single.laravelParcelId, '999053943084');
    expect(order.items.single.shippingFee, 15000);
  });

  test(
    'fetchForwardableParcels reads nested Swagger payload under data.data',
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

      final repository = SendRepository(dio: dio);
      final parcels = await repository.fetchForwardableParcels();

      expect(parcels, hasLength(1));
      expect(parcels.first.id, '1');
      expect(parcels.first.title, 'Aekarach');
      expect(parcels.first.trackNo, '#DPK212498891087-1');
      expect(parcels.first.weightKg, 17.32);
    },
  );
}
