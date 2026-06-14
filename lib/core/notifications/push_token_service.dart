import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'current_fcm_token_provider.dart';

abstract class PushTokenService {
  Future<String?> initializeAndGetToken();
  Stream<String> onTokenRefresh();
}

class FirebasePushTokenService implements PushTokenService {
  const FirebasePushTokenService();

  Future<bool> _ensureFirebaseInitialized() async {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      try {
        await Firebase.initializeApp();
        _logPushToken('Firebase initialized');
        return true;
      } catch (error) {
        _logPushToken('Firebase init failed: $error');
        return false;
      }
    }
  }

  @override
  Future<String?> initializeAndGetToken() async {
    final initialized = await _ensureFirebaseInitialized();
    if (!initialized) {
      return null;
    }

    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      _logPushToken('getToken=${_previewToken(token)}');
      return token;
    } catch (error) {
      _logPushToken('getToken failed: $error');
      return null;
    }
  }

  @override
  Stream<String> onTokenRefresh() {
    try {
      return FirebaseMessaging.instance.onTokenRefresh
          .where((token) => token.isNotEmpty)
          .map((token) {
            _logPushToken('onTokenRefresh=${_previewToken(token)}');
            return token;
          });
    } catch (error) {
      _logPushToken('onTokenRefresh unavailable: $error');
      return const Stream<String>.empty();
    }
  }
}

final pushTokenServiceProvider = Provider<PushTokenService>((ref) {
  return const FirebasePushTokenService();
});

final pushTokenBootstrapProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(pushTokenServiceProvider);

  final token = await service.initializeAndGetToken();
  if (token != null && token.isNotEmpty) {
    ref.read(currentFcmTokenProvider.notifier).state = token;
  }

  final subscription = service.onTokenRefresh().listen((token) {
    ref.read(currentFcmTokenProvider.notifier).state = token;
  });

  ref.onDispose(subscription.cancel);
});

String _previewToken(String? token) {
  if (token == null || token.isEmpty) {
    return '<null>';
  }
  if (token.length <= 16) {
    return token;
  }
  return '${token.substring(0, 8)}...${token.substring(token.length - 6)}';
}

void _logPushToken(String message) {
  if (kDebugMode) {
    debugPrint('[FCM_TOKEN] $message');
  }
}
