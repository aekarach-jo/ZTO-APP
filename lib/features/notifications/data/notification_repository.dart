import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timeLabel,
    required this.isUnread,
  });

  final String id;
  final String title;
  final String message;
  final String timeLabel;
  final bool isUnread;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final id = _readString(json, const ['id', '_id', 'notificationId']) ??
        DateTime.now().microsecondsSinceEpoch.toString();

    final title =
        _readString(json, const ['title', 'subject', 'name']) ?? 'Notification';
    final message = _readString(
          json,
          const ['message', 'body', 'description', 'content'],
        ) ??
        '-';

    final sentAtRaw = _readString(
      json,
      const ['createdAt', 'created_at', 'sentAt', 'sent_at', 'updatedAt'],
    );

    return AppNotification(
      id: id,
      title: title,
      message: message,
      timeLabel: _formatTimeLabel(sentAtRaw),
      isUnread: _readBool(json, const ['isUnread', 'unread', 'is_read']) ?? false,
    );
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
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
    return null;
  }

  static bool? _readBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' || normalized == '0' || normalized == 'no') {
          return false;
        }
      }
    }

    final isRead = json['isRead'];
    if (isRead is bool) {
      return !isRead;
    }
    return null;
  }

  static String _formatTimeLabel(String? raw) {
    if (raw == null || raw.isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }

    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inMinutes < 1) {
      return 'just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    }
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }
}

class NotificationRepository {
  NotificationRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<AppNotification>> fetchNotifications() async {
    final response = await _dio.get<dynamic>('/notifications');
    final list = _extractList(response.data);
    final notifications = list
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);

    if (kDebugMode) {
      final statusCode = response.statusCode;
      final rootType = response.data.runtimeType;
      debugPrint(
        '[NotificationRepository] GET /notifications status=$statusCode rootType=$rootType extractedCount=${notifications.length}',
      );
      if (notifications.isEmpty) {
        debugPrint(
          '[NotificationRepository] Empty list. Raw payload preview: ${response.data}',
        );
      }
    }

    return notifications;
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List<dynamic>) {
      if (kDebugMode) {
        debugPrint('[NotificationRepository] Extracted from root list');
      }
      return data;
    }

    if (data is Map<String, dynamic>) {
      if (data['notifications'] is Map<String, dynamic>) {
        final nestedMap = data['notifications'] as Map<String, dynamic>;
        final nestedInNotifications =
            nestedMap['items'] ?? nestedMap['results'] ?? nestedMap['data'];
        if (nestedInNotifications is List<dynamic>) {
          if (kDebugMode) {
            debugPrint('[NotificationRepository] Extracted from notifications.items/results/data');
          }
          return nestedInNotifications;
        }
      }

      final direct = data['data'];
      if (direct is List<dynamic>) {
        if (kDebugMode) {
          debugPrint('[NotificationRepository] Extracted from data[]');
        }
        return direct;
      }
      if (direct is Map<String, dynamic>) {
        final nested =
            direct['items'] ??
            direct['notifications'] ??
            direct['results'] ??
            direct['rows'] ??
            direct['records'];
        if (nested is List<dynamic>) {
          if (kDebugMode) {
            debugPrint('[NotificationRepository] Extracted from data.items/notifications/results/rows/records');
          }
          return nested;
        }

        if (nested is Map<String, dynamic>) {
          final nestedList = nested['items'] ?? nested['results'] ?? nested['data'];
          if (nestedList is List<dynamic>) {
            if (kDebugMode) {
              debugPrint('[NotificationRepository] Extracted from nested map items/results/data');
            }
            return nestedList;
          }
        }
      }

      final root =
          data['items'] ??
          data['notifications'] ??
          data['results'] ??
          data['rows'] ??
          data['records'];
      if (root is List<dynamic>) {
        if (kDebugMode) {
          debugPrint('[NotificationRepository] Extracted from root items/notifications/results/rows/records');
        }
        return root;
      }
    }

    if (kDebugMode) {
      debugPrint('[NotificationRepository] Could not match a list path in payload');
    }
    return const <dynamic>[];
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return NotificationRepository(dio: dio);
});

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationRepositoryProvider).fetchNotifications();
});

