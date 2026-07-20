import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/network_providers.dart';
import 'current_fcm_token_provider.dart';

/// Keeps backend token registration in sync when Firebase rotates the device token.
final fcmTokenSyncProvider = Provider<void>((ref) {
  String? lastSyncedToken;

  Future<void> syncToken(String token) async {
    if (token.isEmpty || token == lastSyncedToken) {
      _logFcmSync('Skip sync: empty or already synced');
      return;
    }

    final authTokens = await ref.read(tokenStorageProvider).read();
    final accessToken = authTokens?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      _logFcmSync('Skip sync: no access token yet');
      return;
    }

    try {
      final dio = ref.read(apiClientProvider).dio;
      await dio.post<dynamic>('/auth/fcm-token', data: {'fcmToken': token});
      lastSyncedToken = token;
      _logFcmSync('Synced token=${_previewToken(token)}');
    } catch (error) {
      _logFcmSync('Sync failed: $error');
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

String _previewToken(String token) {
  if (token.length <= 16) {
    return token;
  }
  return '${token.substring(0, 8)}...${token.substring(token.length - 6)}';
}

void _logFcmSync(String message) {
  if (kDebugMode) {
    debugPrint('[FCM_SYNC] $message');
  }
}
