import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';

/// The signed-in user as returned by `GET /users/me`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.profileImage,
    required this.language,
  });

  final String id;
  final String displayName;
  final String email;
  final String phone;

  /// Push/notification language the backend has on file (`lo`/`zh`/`en`), or
  /// empty when the backend did not return a supported value.
  final String language;

  /// Avatar URL/path (may be relative, e.g. `/uploads/chat/x.jpg`).
  final String profileImage;

  bool get hasProfileImage => profileImage.isNotEmpty;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Backends vary in how they name the user's name; try the common variants
    // and fall back to joining first/last name when there is no single field.
    var displayName = _readString(json, const [
      'displayName',
      'display_name',
      'name',
      'fullName',
      'full_name',
      'username',
    ]);
    if (displayName.isEmpty) {
      final first = _readString(json, const ['firstName', 'first_name']);
      final last = _readString(json, const ['lastName', 'last_name']);
      displayName = [first, last].where((p) => p.isNotEmpty).join(' ');
    }

    return UserProfile(
      id: _readString(json, const ['id', 'userId', '_id', 'uuid']),
      displayName: displayName,
      email: _readString(json, const ['email', 'emailAddress', 'email_address']),
      phone: _readString(json, const ['phone', 'phoneNumber', 'phone_number']),
      profileImage: _readString(
        json,
        const ['profileImage', 'profile_image', 'avatar', 'photo', 'image'],
      ),
      language: normalizeUserLanguage(
        _readString(json, const ['language', 'lang', 'locale']),
      ),
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
}

/// Language codes `PATCH /users/me/language` accepts. The backend defaults a
/// user to `lo`, so anything the app sends has to be one of these.
const Set<String> kSupportedUserLanguages = {'lo', 'zh', 'en'};

/// Maps a raw value (e.g. `zh-CN`, `EN`) onto a supported code, or `''`.
String normalizeUserLanguage(String? raw) {
  if (raw == null || raw.isEmpty) {
    return '';
  }
  final code = raw.trim().toLowerCase().split(RegExp('[-_]')).first;
  return kSupportedUserLanguages.contains(code) ? code : '';
}

class ProfileRepository {
  ProfileRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<UserProfile> fetchProfile() async {
    final response = await _dio.get<dynamic>('/users/me');
    final data = _unwrap(response.data);
    final profile = UserProfile.fromJson(data);
    if (kDebugMode) {
      // Surface the real /users/me shape so field-name mismatches (empty
      // name/email falling back to placeholders) are obvious in the logs.
      debugPrint(
        '[ProfileRepository] GET /users/me status=${response.statusCode} '
        'keys=${data.keys.toList()} '
        'name="${profile.displayName}" email="${profile.email}" '
        'image="${profile.profileImage}"',
      );
    }
    return profile;
  }

  /// Updates the profile via `PATCH /users/me`. Only non-null fields are sent,
  /// so callers can patch a single field (e.g. just the avatar) at a time.
  Future<UserProfile> updateProfile({
    String? displayName,
    String? email,
    String? profileImage,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (email != null) body['email'] = email;
    if (profileImage != null) body['profileImage'] = profileImage;

    final response = await _dio.patch<dynamic>('/users/me', data: body);
    if (kDebugMode) {
      debugPrint(
        '[ProfileRepository] PATCH /users/me fields=${body.keys.toList()} '
        'status=${response.statusCode}',
      );
    }
    return UserProfile.fromJson(_unwrap(response.data));
  }

  /// Stores the customer's language via `PATCH /users/me/language`. The backend
  /// composes every push notification from this value, so it has to be kept in
  /// sync with the language shown in the UI.
  Future<UserProfile> updateLanguage(String language) async {
    final code = normalizeUserLanguage(language);
    if (code.isEmpty) {
      throw ArgumentError.value(language, 'language', 'unsupported language');
    }

    final response = await _dio.patch<dynamic>(
      '/users/me/language',
      data: {'language': code},
    );
    if (kDebugMode) {
      debugPrint(
        '[ProfileRepository] PATCH /users/me/language language=$code '
        'status=${response.statusCode}',
      );
    }
    return UserProfile.fromJson(_unwrap(response.data));
  }

  /// Deletes the signed-in account via `DELETE /users/me`. The backend strips
  /// the PII, soft-deletes the user and frees the phone number for a fresh
  /// registration, so there is nothing left to read back afterwards.
  Future<void> deleteAccount() async {
    final response = await _dio.delete<dynamic>('/users/me');
    if (kDebugMode) {
      debugPrint(
        '[ProfileRepository] DELETE /users/me status=${response.statusCode}',
      );
    }
  }

  static Map<String, dynamic> _unwrap(dynamic data) {
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

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return ProfileRepository(dio: dio);
});

final userProfileProvider = FutureProvider<UserProfile>((ref) {
  return ref.watch(profileRepositoryProvider).fetchProfile();
});
