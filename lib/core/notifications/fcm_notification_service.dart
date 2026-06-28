import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/data/home_parcel_repository.dart';
import '../../features/main_layout/application/main_layout_navigation_provider.dart';
import '../../features/main_layout/presentation/screens/main_layout_screen.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../router/app_router.dart';

const AndroidNotificationChannel _ztoNotificationChannel =
    AndroidNotificationChannel(
      'zto_push_notifications',
      'CLS Global Notifications',
      description:
          'Notifications about parcels, account updates, and CLS Global alerts.',
      importance: Importance.high,
    );

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

void refreshFcmRelatedProviders(
  void Function(ProviderOrFamily provider) invalidate,
) {
  invalidate(notificationsProvider);
  invalidate(homeParcelsProvider);
}

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

Future<void> _initializeLocalNotifications() async {
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
    macOS: DarwinInitializationSettings(),
  );

  await _localNotifications.initialize(settings: initializationSettings);

  final androidPlugin = _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(_ztoNotificationChannel);
  await androidPlugin?.requestNotificationsPermission();
}

Future<void> configureFcmBackgroundHandler() async {
  final initialized = await _ensureFirebaseInitialized();
  if (!initialized) {
    _logFcm('Firebase init failed; background handler not registered');
    return;
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  _logFcm('Background handler registered');
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) {
    return;
  }

  final initialized = await _ensureFirebaseInitialized();
  if (!initialized) {
    _logFcm('Background message ignored: Firebase init failed');
    return;
  }

  _logRemoteMessage('Background message received', message);

  // Android/iOS display notification payloads themselves while the app is in the
  // background. Show a local notification only for data-only messages.
  if (message.notification != null) {
    _logFcm('Background message has notification payload; OS will display it');
    return;
  }

  await _initializeLocalNotifications();
  await _showLocalNotification(message);
}

class FcmNotificationService {
  FcmNotificationService(this._ref);

  final Ref _ref;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) {
      return;
    }
    _isInitialized = true;

    final initialized = await _ensureFirebaseInitialized();
    if (!initialized) {
      _logFcm('Foreground service init skipped: Firebase init failed');
      return;
    }

    await _initializeLocalNotifications();
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _logFcm('Permission status=${settings.authorizationStatus.name}');
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _logRemoteMessage('Initial message opened app', initialMessage);
      _handleNotificationOpened(initialMessage);
    }

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      _logRemoteMessage('Foreground message received', message);
      _refreshFcmRelatedData();
      unawaited(_showLocalNotification(message));
    });

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationOpened,
    );
    _logFcm('Foreground/opened listeners ready');
  }

  void dispose() {
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
  }

  void _handleNotificationOpened(RemoteMessage message) {
    _logRemoteMessage('Notification opened', message);
    _refreshFcmRelatedData();
    _ref.read(customerTabJumpTargetProvider.notifier).state = 0;
    _ref.read(appRouterProvider).go(MainLayoutScreen.routePath);
  }

  void _refreshFcmRelatedData() {
    _logFcm('Refreshing notificationsProvider');
    _logFcm('Refreshing homeParcelsProvider');
    refreshFcmRelatedProviders(_ref.invalidate);
  }
}

final fcmNotificationServiceProvider = Provider<FcmNotificationService>((ref) {
  final service = FcmNotificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});

final fcmNotificationBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(fcmNotificationServiceProvider).initialize();
});

Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  final title =
      notification?.title ??
      _readDataString(message.data, 'title') ??
      'CLS Global';
  final body =
      notification?.body ??
      _readDataString(message.data, 'body') ??
      _readDataString(message.data, 'message') ??
      '';

  if (title.trim().isEmpty && body.trim().isEmpty) {
    _logFcm('Local notification skipped: empty title/body');
    return;
  }

  _logFcm('Showing local notification title="$title" body="$body"');

  await _localNotifications.show(
    id:
        message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _ztoNotificationChannel.id,
        _ztoNotificationChannel.name,
        channelDescription: _ztoNotificationChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

String? _readDataString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

void _logRemoteMessage(String event, RemoteMessage message) {
  _logFcm(
    '$event '
    'id=${message.messageId ?? '-'} '
    'title=${message.notification?.title ?? message.data['title'] ?? '-'} '
    'body=${message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? '-'} '
    'data=${message.data}',
  );
}

void _logFcm(String message) {
  if (kDebugMode) {
    debugPrint('[FCM] $message');
  }
}
