import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/network_providers.dart';
import 'current_fcm_token_provider.dart';

/// Keeps backend token registration in sync when Firebase rotates the device token.
final fcmTokenSyncProvider = Provider<void>((ref) {
  String? lastSyncedToken;

  Future<void> syncToken(String token) async {
    if (token.isEmpty || token == lastSyncedToken) {
      return;
    }

    final authTokens = await ref.read(tokenStorageProvider).read();
    final accessToken = authTokens?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    try {
      final dio = ref.read(apiClientProvider).dio;
      try {
        await dio.patch<dynamic>('/auth/fcm-token', data: {'fcmToken': token});
      } on DioException catch (error) {
        final statusCode = error.response?.statusCode;
        if (statusCode != 404 && statusCode != 405) {
          rethrow;
        }
        await dio.post<dynamic>('/auth/fcm-token', data: {'fcmToken': token});
      }
      lastSyncedToken = token;
    } catch (_) {
      // Ignore transient failures; next token update or login flow will retry.
    }
  }

  final initialToken = ref.read(currentFcmTokenProvider);
  if (initialToken != null && initialToken.isNotEmpty) {
    unawaited(syncToken(initialToken));
  }

  ref.listen<String?>(currentFcmTokenProvider, (previous, next) {
    if (next == null || next.isEmpty || next == previous) {
      return;
    }
    unawaited(syncToken(next));
  });
});


