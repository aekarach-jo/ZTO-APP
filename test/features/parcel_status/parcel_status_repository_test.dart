import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/parcel_status/data/parcel_status_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchStatus parses counts, categories, steps and order', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/parcels/status');
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: const <String, dynamic>{
                'success': true,
                'data': {
                  'counts': {
                    'in_progress': 2,
                    'self_pickup': 1,
                    'forwarded': 0,
                  },
                  'parcels': [
                    {
                      'id': 999053943084,
                      'track_no': 'TH88291039',
                      'name': 'Sony WH-1000XM5',
                      'weight': 0.5,
                      'status': 'pending',
                      'step': 1,
                      'step_label': 'Arrived',
                      'category': 'in_progress',
                      'is_forward': false,
                      'order': null,
                    },
                    {
                      'id': 291841,
                      'track_no': 'OP100',
                      'name': 'One Piece Vol.100',
                      'status': 'success',
                      'step': 4,
                      'step_label': 'Done',
                      'category': 'self_pickup',
                      'order': {
                        'nest_order_id': 'uuid',
                        'type': 'pickup',
                        'amount_lak': '25000.00',
                        'method': 'onepay',
                        'payment_ref': 'FCCREF123',
                        'paid_at': '2026-07-21T10:00:00Z',
                      },
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );

    final repository = ParcelStatusRepository(dio: dio);
    final page = await repository.fetchStatus();

    expect(page.counts.inProgress, 2);
    expect(page.counts.selfPickup, 1);
    expect(page.counts.forwarded, 0);

    final inProgress = page.forCategory(ParcelStatusCategory.inProgress);
    expect(inProgress, hasLength(1));
    expect(inProgress.first.id, '999053943084');
    expect(inProgress.first.step, 1);
    expect(inProgress.first.order, isNull);

    final selfPickup = page.forCategory(ParcelStatusCategory.selfPickup);
    expect(selfPickup, hasLength(1));
    expect(selfPickup.first.step, 4);
    expect(selfPickup.first.order, isNotNull);
    expect(selfPickup.first.order!.type, 'pickup');
    expect(selfPickup.first.order!.amountLak, 25000.0);
    expect(selfPickup.first.order!.paymentRef, 'FCCREF123');
  });

  test('fetchStatus tolerates missing counts and parcels', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: const <String, dynamic>{'success': true, 'data': {}},
            ),
          );
        },
      ),
    );

    final page = await ParcelStatusRepository(dio: dio).fetchStatus();

    expect(page.counts.inProgress, 0);
    expect(page.parcels, isEmpty);
  });
}
