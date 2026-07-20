import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/core/network/models/auth_tokens.dart';
import 'package:zto_app/core/network/network_providers.dart';
import 'package:zto_app/core/network/storage/token_storage.dart';
import 'package:zto_app/features/contact/data/chat_socket_service.dart';
import 'package:zto_app/features/contact/data/contact_repository.dart';
import 'package:zto_app/features/contact/presentation/screens/contact_screen.dart';

import '../../test_helpers/mock_asset_loader.dart';

class _FakeContactRepository extends ContactRepository {
  _FakeContactRepository() : super(dio: Dio());

  @override
  Future<String> resolveRoomId() async => 'branch-1-user-2';

  @override
  Future<List<ContactMessage>> fetchMessages(String roomId) async {
    return [
      ContactMessage(
        id: 'welcome',
        role: ContactMessageRole.agent,
        text: 'Welcome to support. Ask parcel status now!',
        createdAt: DateTime.now(),
      ),
    ];
  }
}

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<AuthTokens?> read() async =>
      const AuthTokens(accessToken: 'test-token', refreshToken: 'r');

  @override
  Future<void> save(AuthTokens tokens) async {}

  @override
  Future<void> clear() async {}
}

/// Fake socket that echoes the customer message and an admin auto-reply, the
/// way the real backend broadcasts `new-message` back to the sender.
class _FakeChatSocket implements ChatSocket {
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _status = StreamController<ChatSocketStatus>.broadcast();
  bool _connected = false;
  var _counter = 0;

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Stream<ChatSocketStatus> get status => _status.stream;

  @override
  bool get isConnected => _connected;

  @override
  void connect(String accessToken) {
    _connected = true;
    _status.add(ChatSocketStatus.connected);
  }

  @override
  void joinRoom(String roomId) {}

  @override
  void leaveRoom(String roomId) {}

  @override
  void sendMessage({required String roomId, required String content}) {
    _messages.add({
      'id': 'user-${_counter++}',
      'senderId': 'user-2',
      'consoleAdminId': null,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
    });
    _messages.add({
      'id': 'agent-${_counter++}',
      'senderId': 'console-admin:admin-1',
      'consoleAdminId': 'admin-1',
      'consoleAdminName': 'Nina Ops',
      'content': 'Support received: $content',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  void disconnect() {
    _connected = false;
  }

  @override
  void dispose() {
    _messages.close();
    _errors.close();
    _status.close();
  }
}

Widget _buildTestApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('en')],
    path: 'unused',
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    assetLoader: const MockAssetLoader(kTestTranslations),
    child: Builder(
      builder: (context) {
        return ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, _) {
            return MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: ProviderScope(
                overrides: [
                  contactRepositoryProvider.overrideWith(
                    (ref) => _FakeContactRepository(),
                  ),
                  tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
                  chatSocketProvider.overrideWithValue(_FakeChatSocket()),
                ],
                child: Scaffold(body: child),
              ),
            );
          },
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sends a message over the socket and shows support auto-reply',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(const ContactScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(
      find.text('Welcome to support. Ask parcel status now!'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Where is parcel #FW123');
    await tester.tap(find.byKey(const ValueKey('contact-send-button')));
    await tester.pumpAndSettle();

    expect(find.text('Where is parcel #FW123'), findsOneWidget);
    expect(
      find.text('Support received: Where is parcel #FW123'),
      findsOneWidget,
    );

    final bubbleFinder = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey &&
          (widget.key! as ValueKey).value.toString().startsWith(
            'contact-bubble-',
          ),
    );

    expect(bubbleFinder, findsAtLeastNWidgets(2));
  });
}
