import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class CurrentUserStorage {
  Future<String?> readPhoneNumber();
  Future<void> savePhoneNumber(String phoneNumber);
  Future<void> clear();
}

class SecureCurrentUserStorage implements CurrentUserStorage {
  SecureCurrentUserStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const String _phoneNumberKey = 'current_user_phone_number';

  @override
  Future<String?> readPhoneNumber() async {
    final value = await _storage.read(key: _phoneNumberKey);
    if (value == null) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  @override
  Future<void> savePhoneNumber(String phoneNumber) {
    return _storage.write(key: _phoneNumberKey, value: phoneNumber.trim());
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _phoneNumberKey);
  }
}
