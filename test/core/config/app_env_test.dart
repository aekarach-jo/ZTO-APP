import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/core/config/app_env.dart';

void main() {
  group('AppEnv.removeEndpointPort', () {
    test('removes port 3001 from login endpoint', () {
      expect(
        AppEnv.removeEndpointPort(
          'http://14.207.141.82:3001/api/v1/auth/login',
        ),
        'http://14.207.141.82/api/v1/auth/login',
      );
    });

    test('removes any explicit port from an API endpoint', () {
      expect(
        AppEnv.removeEndpointPort('http://14.207.141.82:3000/api/v1'),
        'http://14.207.141.82/api/v1',
      );

      expect(
        AppEnv.removeEndpointPort('http://14.207.141.82:53757/api/v1'),
        'http://14.207.141.82/api/v1',
      );
    });

    test('preserves path, query, and fragment when removing port', () {
      expect(
        AppEnv.removeEndpointPort(
          'https://api.example.com:53757/api/v1/parcels?status=open#latest',
        ),
        'https://api.example.com/api/v1/parcels?status=open#latest',
      );
    });

    test('keeps endpoints without port unchanged', () {
      expect(
        AppEnv.removeEndpointPort('http://14.207.141.82/api/v1'),
        'http://14.207.141.82/api/v1',
      );
    });
  });
}
