import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network_providers.dart';

/// Raised when an image cannot be uploaded (too large, wrong type, or the
/// server rejected it).
class MediaUploadException implements Exception {
  const MediaUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Uploads images to `POST /chat/upload` (multipart, field `file`). The same
/// endpoint backs both chat image messages and the profile avatar, so the
/// returned path (e.g. `/uploads/chat/xxx.jpg`) is reused across features.
class MediaUploadRepository {
  MediaUploadRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// The server caps uploads at 5 MB and accepts images only.
  static const int maxBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'heic',
  };

  /// Uploads [file] and returns the stored image path (relative to the API
  /// origin). Validates the size/type locally first to fail fast with a clear
  /// message instead of a generic server error.
  Future<String> uploadImage(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      throw const MediaUploadException(
        'Only image files (jpg, png, gif, webp, heic) are allowed.',
      );
    }

    final length = await file.length();
    if (length > maxBytes) {
      throw const MediaUploadException('Image must be 5 MB or smaller.');
    }

    final fileName = file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    try {
      final response = await _dio.post<dynamic>('/chat/upload', data: formData);
      final imageUrl = _extractImageUrl(response.data);
      if (imageUrl == null || imageUrl.isEmpty) {
        throw const MediaUploadException('Upload succeeded but returned no url.');
      }
      return imageUrl;
    } on DioException catch (error) {
      final apiMessage = _apiMessage(error.response?.data);
      throw MediaUploadException(
        apiMessage ?? 'Failed to upload image. Please try again.',
      );
    }
  }

  static String? _extractImageUrl(dynamic data) {
    if (data is! Map) {
      return null;
    }
    final inner = data['data'];
    final source = inner is Map ? inner : data;
    final value = source['imageUrl'] ?? source['url'] ?? source['path'];
    return value?.toString();
  }

  static String? _apiMessage(dynamic data) {
    if (data is Map && data['message'] != null) {
      final text = data['message'].toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }
}

final mediaUploadRepositoryProvider = Provider<MediaUploadRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return MediaUploadRepository(dio: dio);
});
