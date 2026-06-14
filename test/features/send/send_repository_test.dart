import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/send/data/send_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('createForwardRequest uses Swagger parcel forward endpoint', () async {
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
              data: const <String, dynamic>{'ok': true},
            ),
          );
        },
      ),
    );

    final repository = SendRepository(dio: dio);

    await repository.createForwardRequest(
      const CreateForwardRequest(
        parcelId: 'parcel-123',
        recipientName: 'Jane Doe',
        recipientPhone: '0891234567',
        recipientAddress: '123 Main Road',
        courier: 'Flash',
        branch: 'VTE-01',
        latitude: 17.9757,
        longitude: 102.6331,
        paymentMethod: 'bcel',
      ),
    );

    expect(captured.method, 'POST');
    expect(captured.path, '/parcels/parcel-123/forward');
    expect(
      captured.data,
      {
        'parcelId': 'parcel-123',
        'recipientName': 'Jane Doe',
        'recipientPhone': '0891234567',
        'recipientAddress': '123 Main Road',
        'courier': 'Flash',
        'branch': 'VTE-01',
        'paymentMethod': 'bcel',
        'location': {
          'latitude': 17.9757,
          'longitude': 102.6331,
        },
      },
    );
  });
}

