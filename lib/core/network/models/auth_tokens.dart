import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_tokens.freezed.dart';
part 'auth_tokens.g.dart';

@freezed
abstract class AuthTokens with _$AuthTokens {
  const AuthTokens._();

  const factory AuthTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? expiresAt,
  }) = _AuthTokens;

  factory AuthTokens.fromJson(Map<String, dynamic> json) =>
      _$AuthTokensFromJson(json);

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) {
      return false;
    }
    return DateTime.now().isAfter(expiry);
  }
}

