import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
        return true;
      } catch (_) {
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
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> onTokenRefresh() {
    try {
      return FirebaseMessaging.instance.onTokenRefresh.where((token) => token.isNotEmpty);
    } catch (_) {
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

