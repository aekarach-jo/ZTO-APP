import 'package:test/test.dart';
import 'package:zto_app/core/network/models/auth_tokens.dart';

void main() {
  group('AuthTokens', () {
    test('isExpired returns false when expiresAt is null', () {
      const tokens = AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
      );

      expect(tokens.isExpired, isFalse);
    });

    test('isExpired returns true when expiry is in the past', () {
      final tokens = AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(tokens.isExpired, isTrue);
    });
  });
}

