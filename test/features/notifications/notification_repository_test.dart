import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/features/notifications/data/notification_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('markAsRead uses Swagger notification read endpoint', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    late RequestOptions captured;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: const <String, dynamic>{'ok': true},
            ),
          );
        },
      ),
    );

    final repository = NotificationRepository(dio: dio);

    await repository.markAsRead('notification-123');

    expect(captured.method, 'PATCH');
    expect(captured.path, '/notifications/notification-123/read');
  });

  test('AppNotification maps API read flags to isUnread correctly', () {
    final unreadNotification = AppNotification.fromJson(const {
      'id': 'n1',
      'title': 'Unread notification',
      'message': 'Please read me',
      'is_read': false,
    });
    final readNotification = AppNotification.fromJson(const {
      'id': 'n2',
      'title': 'Read notification',
      'message': 'Already read',
      'is_read': true,
    });

    expect(unreadNotification.isUnread, isTrue);
    expect(readNotification.isUnread, isFalse);
  });

  test('AppNotification treats null or empty read timestamps as unread', () {
    final nullReadAtNotification = AppNotification.fromJson(const {
      'id': 'n1',
      'title': 'Unread notification',
      'message': 'Please read me',
      'readAt': null,
    });
    final emptyReadAtNotification = AppNotification.fromJson(const {
      'id': 'n2',
      'title': 'Unread notification',
      'message': 'Please read me',
      'read_at': '',
    });
    final readAtNotification = AppNotification.fromJson(const {
      'id': 'n3',
      'title': 'Read notification',
      'message': 'Already read',
      'read_at': '2026-06-15T10:00:00.000Z',
    });

    expect(nullReadAtNotification.isUnread, isTrue);
    expect(emptyReadAtNotification.isUnread, isTrue);
    expect(readAtNotification.isUnread, isFalse);
  });

  test('AppNotification maps status-style read fields to isUnread', () {
    final unreadNotification = AppNotification.fromJson(const {
      'id': 'n1',
      'title': 'Unread notification',
      'message': 'Please read me',
      'status': 'UNREAD',
    });
    final readNotification = AppNotification.fromJson(const {
      'id': 'n2',
      'title': 'Read notification',
      'message': 'Already read',
      'readStatus': 'seen',
    });

    expect(unreadNotification.isUnread, isTrue);
    expect(readNotification.isUnread, isFalse);
  });
}
