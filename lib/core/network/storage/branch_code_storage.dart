import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the branch the user picked (e.g. `KD` / `CLS`) so it can be attached
/// as the `x-branch-code` header on every request. NestJS routes to the right
/// Laravel backend based on this value, so it must ride along with each call.
abstract class BranchCodeStore {
  /// The last read/saved code, available synchronously. Null until [read] has
  /// hydrated it from persistence or [save] has been called.
  String? get codeOrNull;

  /// Returns the persisted code, caching it in memory after the first read.
  Future<String?> read();

  /// Persists [code] and updates the in-memory copy.
  Future<void> save(String code);

  /// Forgets the selected branch (e.g. on sign-out).
  Future<void> clear();
}

class SecureBranchCodeStore implements BranchCodeStore {
  SecureBranchCodeStore(this._storage);

  final FlutterSecureStorage _storage;

  static const String _codeKey = 'selected_branch_code';

  String? _code;
  bool _loaded = false;

  @override
  String? get codeOrNull => _code;

  @override
  Future<String?> read() async {
    if (_loaded) {
      return _code;
    }
    _code = await _storage.read(key: _codeKey);
    _loaded = true;
    return _code;
  }

  @override
  Future<void> save(String code) async {
    _code = code;
    _loaded = true;
    await _storage.write(key: _codeKey, value: code);
  }

  @override
  Future<void> clear() async {
    _code = null;
    _loaded = true;
    await _storage.delete(key: _codeKey);
  }
}
