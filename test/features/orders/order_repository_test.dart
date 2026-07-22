import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/orders/data/order_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchOrders parses a wrapped list of orders', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/orders');
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: const <String, dynamic>{
                'success': true,
                'data': [
                  {
                    'id': 'order-1',
                    'type': 'forward',
                    'paymentStatus': 'paid',
                    'amount': 16050,
                    'currency': 'LAK',
                    'recipientName': 'Somchai S.',
                    'createdAt': '2026-07-20T10:00:00Z',
                    'paidAt': '2026-07-20T10:03:12Z',
                  },
                  {
                    'id': 'order-2',
                    'type': 'pickup',
                    'paymentStatus': 'pending',
                    'amount': 25000,
                    'currency': 'LAK',
                  },
                ],
              },
            ),
          );
        },
      ),
    );

    final orders = await OrderRepository(dio: dio).fetchOrders();

    expect(orders, hasLength(2));
    expect(orders.first.id, 'order-1');
    expect(orders.first.isForward, isTrue);
    expect(orders.first.paymentStatus, OrderPaymentState.paid);
    expect(orders.first.amount, 16050);
    expect(orders.first.paidAt, isNotNull);
    expect(orders.last.type, 'pickup');
    expect(orders.last.paymentStatus, OrderPaymentState.pending);
  });

  test('fetchOrders returns empty list on unexpected payload', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: const <String, dynamic>{'success': true, 'data': null},
            ),
          );
        },
      ),
    );

    final orders = await OrderRepository(dio: dio).fetchOrders();
    expect(orders, isEmpty);
  });

  test('fetchOrder returns single order detail', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/orders/order-1');
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: const <String, dynamic>{
                'success': true,
                'data': {
                  'id': 'order-1',
                  'type': 'forward',
                  'paymentStatus': 'paid',
                  'amount': 16050,
                  'currency': 'LAK',
                },
              },
            ),
          );
        },
      ),
    );

    final order = await OrderRepository(dio: dio).fetchOrder('order-1');
    expect(order.id, 'order-1');
    expect(order.isPaid, isTrue);
    expect(order.amount, 16050);
  });
}
