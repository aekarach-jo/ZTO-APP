import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_tokens.dart';

abstract class TokenStorage {
  Future<AuthTokens?> read();
  Future<void> save(AuthTokens tokens);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'auth_tokens';

  @override
  Future<AuthTokens?> read() async {
    final rawValue = await _storage.read(key: _tokenKey);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawValue) as Map<String, dynamic>;
      return AuthTokens.fromJson(decoded);
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(AuthTokens tokens) {
    return _storage.write(key: _tokenKey, value: jsonEncode(tokens.toJson()));
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _tokenKey);
  }
}

