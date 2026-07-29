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

  static const int _appleTokenWaitAttempts = 30;
  static const Duration _appleTokenWaitInterval = Duration(seconds: 1);
  static const int _fcmTokenRetryAttempts = 10;

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
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _logPushToken('permission=${settings.authorizationStatus.name}');

      if (_isApplePushPlatform()) {
        await _waitForApplePushToken();
      }

      await FirebaseMessaging.instance.deleteToken(); // ลบ token เก่า

      for (var attempt = 1; attempt <= _fcmTokenRetryAttempts; attempt++) {
        final token = await FirebaseMessaging.instance.getToken();
        _logPushToken(
          'getToken attempt=$attempt token=${_previewToken(token)}',
        );
        if (token != null && token.isNotEmpty) {
          return token;
        }
        if (attempt < _fcmTokenRetryAttempts) {
          await Future<void>.delayed(_appleTokenWaitInterval);
        }
      }

      _logPushToken('getToken unavailable after retries');
      return null;
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

  Future<void> _waitForApplePushToken() async {
    for (var attempt = 1; attempt <= _appleTokenWaitAttempts; attempt++) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      _logPushToken(
        'getAPNSToken attempt=$attempt token=${_previewToken(apnsToken)}',
      );
      if (apnsToken != null && apnsToken.isNotEmpty) {
        return;
      }
      if (attempt < _appleTokenWaitAttempts) {
        await Future<void>.delayed(_appleTokenWaitInterval);
      }
    }

    _logPushToken('APNs token unavailable after waiting');
  }
}

final pushTokenServiceProvider = Provider<PushTokenService>((ref) {
  return const FirebasePushTokenService();
});

/// Returns the device token, fetching one when the app does not have it yet.
///
/// The bootstrap attempt can legitimately come back empty on iOS: APNs
/// registration is slower there than on Android and can outlast the retry
/// window, and [initializeAndGetToken] gives up for the rest of the session
/// once that happens. Login and app resume both call this so a device that lost
/// the first race still ends up registered with the backend.
Future<String?> ensurePushToken(Ref ref) async {
  final existing = ref.read(currentFcmTokenProvider);
  if (existing != null && existing.isNotEmpty) {
    return existing;
  }

  final token = await ref
      .read(pushTokenServiceProvider)
      .initializeAndGetToken();
  if (token == null || token.isEmpty) {
    return null;
  }

  ref.read(currentFcmTokenProvider.notifier).state = token;
  return token;
}

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

bool _isApplePushPlatform() {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}
