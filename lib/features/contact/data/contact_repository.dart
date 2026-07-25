import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/media_upload_repository.dart';
import '../../../core/network/network_providers.dart';
import 'chat_socket_service.dart';

enum ContactMessageRole { user, agent }

class ContactSendException implements Exception {
  const ContactSendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ContactMessage {
  const ContactMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.senderName,
    this.imageUrl,
  });

  final String id;
  final ContactMessageRole role;
  final String text;
  final DateTime createdAt;

  /// Display name of the admin who replied (from `consoleAdminName`).
  /// Null for customer messages.
  final String? senderName;

  /// Attached image path (e.g. `/uploads/chat/x.jpg`), when the message
  /// carries a photo. Resolve to an absolute URL before rendering.
  final String? imageUrl;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// Parses both the REST history payload and the `new-message` socket event.
  /// A message counts as an admin (agent) reply when it carries a
  /// `consoleAdminId`; otherwise it is treated as the customer's own message.
  factory ContactMessage.fromJson(Map<String, dynamic> json) {
    final consoleAdminId =
        _readString(json, const ['consoleAdminId', 'console_admin_id']);
    final role = (consoleAdminId != null && consoleAdminId.isNotEmpty)
        ? ContactMessageRole.agent
        : ContactMessageRole.user;

    final imageUrl =
        _readString(json, const ['imageUrl', 'image_url', 'image']);
    // Image-only messages carry no text; keep the bubble empty rather than
    // showing a placeholder dash next to the photo.
    final rawText = _readString(json, const ['content', 'message', 'text', 'body']);
    final text = rawText ?? (imageUrl != null ? '' : '-');
    final id = _readString(json, const ['id', '_id', 'messageId']) ??
        '${role.name}-${DateTime.now().microsecondsSinceEpoch}';
    final createdAt = _parseDate(json['createdAt'] ?? json['created_at'] ?? json['sentAt']) ??
        DateTime.now();
    final senderName =
        _readString(json, const ['consoleAdminName', 'console_admin_name']);

    return ContactMessage(
      id: id,
      role: role,
      text: text,
      createdAt: createdAt,
      senderName: senderName,
      imageUrl: imageUrl,
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

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }
}

class ContactRepository {
  ContactRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Builds the chat room id for the logged-in customer using the convention
  /// `branch-<branchId>-user-<userId>`, reading both ids from `GET /users/me`.
  Future<String> resolveRoomId() async {
    final response = await _dio.get<dynamic>('/users/me');
    if (kDebugMode) {
      debugPrint('[ContactRepository] GET /users/me status=${response.statusCode} body=${response.data}');
    }
    final data = _unwrap(response.data);
    if (data == null) {
      throw const ContactSendException('Failed to load profile for chat.');
    }

    final userId = _readString(data, const ['id', 'userId', '_id', 'uuid']);
    final branchId = _readBranchId(data);

    if (kDebugMode) {
      debugPrint('[ContactRepository] resolveRoomId keys=${data.keys.toList()} userId=$userId branchId=$branchId');
    }

    if (userId == null || userId.isEmpty) {
      throw const ContactSendException('Your account is missing an id for chat.');
    }
    if (branchId == null || branchId.isEmpty) {
      throw const ContactSendException(
        'Please select a branch before starting a chat.',
      );
    }

    return 'branch-$branchId-user-$userId';
  }

  Future<List<ContactMessage>> fetchMessages(String roomId) async {
    final response = await _dio.get<dynamic>(
      '/chat/messages',
      queryParameters: {'roomId': roomId},
    );
    if (kDebugMode) {
      debugPrint('[ContactRepository] GET /chat/messages status=${response.statusCode}');
    }

    final list = _extractList(response.data);
    final messages = list
        .whereType<Map<String, dynamic>>()
        .map(ContactMessage.fromJson)
        .toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return messages;
  }

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }
    final inner = data['data'];
    if (inner is Map<String, dynamic>) {
      return inner;
    }
    return data;
  }

  static String? _readBranchId(Map<String, dynamic> data) {
    final direct = _readString(data, const ['branchId', 'branch_id']);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final branch = data['branch'];
    if (branch is Map<String, dynamic>) {
      return _readString(branch, const ['id', 'branchId', '_id']);
    }
    return null;
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

  List<dynamic> _extractList(dynamic data) {
    if (data is List<dynamic>) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final direct = data['data'];
      if (direct is List<dynamic>) {
        return direct;
      }
      if (direct is Map<String, dynamic>) {
        final nested = direct['items'] ?? direct['messages'] ?? direct['results'];
        if (nested is List<dynamic>) {
          return nested;
        }
      }
      final root = data['items'] ?? data['messages'] ?? data['results'];
      if (root is List<dynamic>) {
        return root;
      }
    }
    return const <dynamic>[];
  }
}

/// Manages the customer chat: resolves the room, loads history over REST, and
/// streams live messages over the Socket.IO connection. Sending is delegated to
/// the socket (there is no REST send endpoint).
class ContactThreadController extends AsyncNotifier<List<ContactMessage>> {
  String? _roomId;
  ChatSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<String>? _errorSub;

  @override
  Future<List<ContactMessage>> build() async {
    try {
      return await _initThread();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ContactThread] init failed: $error');
        debugPrint('$stackTrace');
      }
      rethrow;
    }
  }

  Future<List<ContactMessage>> _initThread() async {
    final repository = ref.watch(contactRepositoryProvider);
    final tokenStorage = ref.watch(tokenStorageProvider);

    final initialTokens = await tokenStorage.read();
    if (initialTokens?.accessToken == null ||
        initialTokens!.accessToken.isEmpty) {
      throw const ContactSendException('You need to sign in to use chat.');
    }

    // resolveRoomId hits /users/me over REST. If the access token is expired,
    // the AuthInterceptor refreshes it and persists the new one to storage, so
    // we must read the token AGAIN afterwards to hand the socket a fresh one.
    final roomId = await repository.resolveRoomId();
    _roomId = roomId;

    final refreshedTokens = await tokenStorage.read();
    final accessToken =
        refreshedTokens?.accessToken ?? initialTokens.accessToken;

    final socket = ref.watch(chatSocketProvider);
    _socket = socket;

    _messageSub = socket.messages.listen(_onSocketMessage);
    _errorSub = socket.errors.listen((message) {
      if (kDebugMode) {
        debugPrint('[ContactThread] socket error: $message');
      }
      if (message.toLowerCase().contains('unauthorized')) {
        unawaited(_recoverAuth());
      }
    });

    socket.connect(accessToken);
    socket.joinRoom(roomId);

    ref.onDispose(() {
      _messageSub?.cancel();
      _errorSub?.cancel();
      socket.leaveRoom(roomId);
      socket.disconnect();
    });

    return repository.fetchMessages(roomId);
  }

  bool _recovering = false;
  int _authRecoveryAttempts = 0;

  /// Called when the socket is rejected with `Unauthorized` (typically an
  /// expired access token mid-session). Forces a token refresh via a REST call
  /// and reconnects the socket with the fresh token. Capped to avoid loops.
  Future<void> _recoverAuth() async {
    if (_recovering || _authRecoveryAttempts >= 2) {
      return;
    }
    _recovering = true;
    _authRecoveryAttempts++;
    try {
      final tokenStorage = ref.read(tokenStorageProvider);
      // A 401 here triggers the AuthInterceptor to refresh + persist the token.
      await ref.read(contactRepositoryProvider).resolveRoomId();
      final accessToken = (await tokenStorage.read())?.accessToken;
      final roomId = _roomId;
      final socket = _socket;
      if (accessToken != null &&
          accessToken.isNotEmpty &&
          roomId != null &&
          socket != null) {
        if (kDebugMode) {
          debugPrint('[ContactThread] reconnecting socket with refreshed token');
        }
        socket.connect(accessToken);
        socket.joinRoom(roomId);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ContactThread] auth recovery failed: $error');
      }
    } finally {
      _recovering = false;
    }
  }

  void _onSocketMessage(Map<String, dynamic> data) {
    // A live message proves the socket is authenticated again.
    _authRecoveryAttempts = 0;
    final message = ContactMessage.fromJson(data);
    final current = state.valueOrNull ?? const <ContactMessage>[];
    if (current.any((existing) => existing.id == message.id)) {
      return;
    }
    final updated = [...current, message]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = AsyncData(updated);
  }

  /// Sends a message over the socket. The server echoes it back via
  /// `new-message`, which appends it to the thread. Requires text, an
  /// [imageUrl], or both.
  void sendMessage(String text, {String? imageUrl}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty && (imageUrl == null || imageUrl.isEmpty)) {
      return;
    }
    final roomId = _roomId;
    final socket = _socket;
    if (roomId == null || socket == null) {
      throw const ContactSendException('Chat is not ready yet.');
    }
    if (!socket.isConnected) {
      throw const ContactSendException('Chat is offline. Please try again.');
    }
    socket.sendMessage(roomId: roomId, content: trimmed, imageUrl: imageUrl);
  }

  /// Uploads [file] to `POST /chat/upload`, then sends it as an image message
  /// (optionally with a text [caption]).
  Future<void> sendImage(File file, {String caption = ''}) async {
    final roomId = _roomId;
    final socket = _socket;
    if (roomId == null || socket == null || !socket.isConnected) {
      throw const ContactSendException('Chat is offline. Please try again.');
    }
    final imageUrl = await ref.read(mediaUploadRepositoryProvider).uploadImage(file);
    socket.sendMessage(roomId: roomId, content: caption.trim(), imageUrl: imageUrl);
  }
}

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return ContactRepository(dio: dio);
});

final chatSocketProvider = Provider<ChatSocket>((ref) {
  final service = ChatSocketService();
  ref.onDispose(service.dispose);
  return service;
});

final contactThreadProvider =
    AsyncNotifierProvider<ContactThreadController, List<ContactMessage>>(
  ContactThreadController.new,
);
