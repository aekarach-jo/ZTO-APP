import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';

/// One entry of the customer's address book (`/users/me/addresses`).
///
/// The entry flagged [isDefault] is what the forward flow falls back to for the
/// recipient phone and the map pin, so it is the only one the send screen reads.
class UserAddress {
  const UserAddress({
    required this.id,
    required this.label,
    required this.phone,
    required this.addressLine,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
  });

  final String id;
  final String label;

  /// Recipient phone in full international form (e.g. `2091234567` as the
  /// backend stores it). May be empty — the field is optional.
  final String phone;
  final String addressLine;
  final double latitude;
  final double longitude;
  final bool isDefault;

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: _readString(json, const ['id', '_id', 'addressId']),
      label: _readString(json, const ['label', 'name', 'title']),
      phone: _readString(json, const ['phone', 'phoneNumber', 'phone_number']),
      addressLine: _readString(json, const [
        'addressLine',
        'address_line',
        'address',
      ]),
      latitude: _readDouble(json, const ['lat', 'latitude']) ?? 0,
      longitude: _readDouble(json, const ['lng', 'longitude', 'lon']) ?? 0,
      isDefault: _readBool(json, const ['isDefault', 'is_default', 'default']),
    );
  }

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  static double? _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static bool _readBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final text = value.trim().toLowerCase();
        if (text == 'true' || text == '1') {
          return true;
        }
        if (text == 'false' || text == '0') {
          return false;
        }
      }
    }
    return false;
  }
}

class AddressRepository {
  AddressRepository({required Dio dio}) : _dio = dio;

  static const String _basePath = '/users/me/addresses';

  final Dio _dio;

  Future<List<UserAddress>> fetchAddresses() async {
    final response = await _dio.get<dynamic>(_basePath);
    final addresses = _unwrapList(response.data)
        .whereType<Map<String, dynamic>>()
        .map(UserAddress.fromJson)
        .toList(growable: false);
    if (kDebugMode) {
      debugPrint(
        '[AddressRepository] GET $_basePath status=${response.statusCode} '
        'count=${addresses.length}',
      );
    }
    return addresses;
  }

  /// Creates an address. The backend makes every new address the default and
  /// clears the previous one, so `isDefault` is never sent.
  Future<UserAddress> createAddress({
    required String label,
    required String addressLine,
    required double latitude,
    required double longitude,
    String? phone,
  }) async {
    final body = <String, dynamic>{
      'label': label,
      'addressLine': addressLine,
      'lat': latitude,
      'lng': longitude,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };
    final response = await _dio.post<dynamic>(_basePath, data: body);
    return UserAddress.fromJson(_unwrapMap(response.data));
  }

  /// Patches an address. Only non-null fields are sent so a caller can change
  /// one field at a time.
  Future<UserAddress> updateAddress(
    String id, {
    String? label,
    String? phone,
    String? addressLine,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) async {
    final body = <String, dynamic>{};
    if (label != null) body['label'] = label;
    if (phone != null) body['phone'] = phone;
    if (addressLine != null) body['addressLine'] = addressLine;
    if (latitude != null) body['lat'] = latitude;
    if (longitude != null) body['lng'] = longitude;
    if (isDefault != null) body['isDefault'] = isDefault;

    final response = await _dio.patch<dynamic>('$_basePath/$id', data: body);
    return UserAddress.fromJson(_unwrapMap(response.data));
  }

  Future<void> deleteAddress(String id) async {
    await _dio.delete<dynamic>('$_basePath/$id');
  }

  Future<void> setDefaultAddress(String id) async {
    await _dio.patch<dynamic>('$_basePath/$id/default');
  }

  static List<dynamic> _unwrapList(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is List) {
        return inner;
      }
      if (inner is Map<String, dynamic>) {
        final nested = inner['data'];
        if (nested is List) {
          return nested;
        }
      }
    }
    return const <dynamic>[];
  }

  static Map<String, dynamic> _unwrapMap(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return const <String, dynamic>{};
    }
    final inner = data['data'];
    if (inner is Map<String, dynamic>) {
      return inner;
    }
    return data;
  }
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return AddressRepository(dio: dio);
});

final userAddressesProvider = FutureProvider<List<UserAddress>>((ref) {
  return ref.watch(addressRepositoryProvider).fetchAddresses();
});

/// The address flagged `isDefault`, or null when the book is empty. Falls back
/// to the first entry when the backend returns a book with no flag set.
final defaultUserAddressProvider = Provider<UserAddress?>((ref) {
  final addresses = ref.watch(userAddressesProvider).valueOrNull;
  if (addresses == null || addresses.isEmpty) {
    return null;
  }
  for (final address in addresses) {
    if (address.isDefault) {
      return address;
    }
  }
  return addresses.first;
});
