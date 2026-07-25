import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/app_env.dart';

/// Connection state of the chat socket.
enum ChatSocketStatus { disconnected, connecting, connected, error }

/// Abstraction over the chat socket so the UI/controller can be tested with a
/// fake transport instead of a live Socket.IO connection.
abstract class ChatSocket {
  Stream<Map<String, dynamic>> get messages;
  Stream<String> get errors;
  Stream<ChatSocketStatus> get status;
  bool get isConnected;

  void connect(String accessToken);
  void joinRoom(String roomId);
  void leaveRoom(String roomId);
  void sendMessage({
    required String roomId,
    String content,
    String? imageUrl,
  });
  void disconnect();
  void dispose();
}

/// Thin wrapper around the Socket.IO `/chat` namespace described in the
/// ZTO Chat API guide. Sending messages is only possible over this socket —
/// there is no REST endpoint for it.
class ChatSocketService implements ChatSocket {
  ChatSocketService();

  io.Socket? _socket;
  String? _joinedRoomId;

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _status = StreamController<ChatSocketStatus>.broadcast();

  /// Emits every `new-message` payload broadcast by the server.
  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  /// Emits server `error` messages (auth failures, invalid payloads, ...).
  @override
  Stream<String> get errors => _errors.stream;

  /// Emits connection lifecycle changes.
  @override
  Stream<ChatSocketStatus> get status => _status.stream;

  @override
  bool get isConnected => _socket?.connected ?? false;

  /// Opens the socket with the given access token. Safe to call repeatedly;
  /// an existing connection is torn down first.
  @override
  void connect(String accessToken) {
    disconnect();

    _status.add(ChatSocketStatus.connecting);

    final socket = io.io(
      '${AppEnv.socketBaseUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': accessToken})
          .setExtraHeaders({'Authorization': 'Bearer $accessToken'})
          .build(),
    );

    socket.onConnect((_) {
      if (kDebugMode) {
        debugPrint('[ChatSocket] connected');
      }
      _status.add(ChatSocketStatus.connected);
      // Re-join the active room after a reconnect.
      final room = _joinedRoomId;
      if (room != null) {
        socket.emit('join-room', room);
      }
    });

    socket.onDisconnect((_) {
      if (kDebugMode) {
        debugPrint('[ChatSocket] disconnected');
      }
      _status.add(ChatSocketStatus.disconnected);
    });

    socket.onConnectError((error) {
      if (kDebugMode) {
        debugPrint('[ChatSocket] connect_error: $error');
      }
      _status.add(ChatSocketStatus.error);
    });

    socket.on('new-message', (data) {
      final map = _asMap(data);
      if (map != null) {
        _messages.add(map);
      }
    });

    socket.on('error', (data) {
      final message = _extractErrorMessage(data);
      if (kDebugMode) {
        debugPrint('[ChatSocket] error event: $message');
      }
      _status.add(ChatSocketStatus.error);
      _errors.add(message);
    });

    _socket = socket;
    socket.connect();
  }

  @override
  void joinRoom(String roomId) {
    _joinedRoomId = roomId;
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emit('join-room', roomId);
    }
  }

  @override
  void leaveRoom(String roomId) {
    if (_joinedRoomId == roomId) {
      _joinedRoomId = null;
    }
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emit('leave-room', roomId);
    }
  }

  /// Emits a `send-message` event. The server echoes the stored message back
  /// via `new-message`, so callers should render from that stream. A message
  /// may carry text ([content]), an [imageUrl] (from `POST /chat/upload`), or
  /// both — the server requires at least one.
  @override
  void sendMessage({
    required String roomId,
    String content = '',
    String? imageUrl,
  }) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      throw StateError('Chat socket is not connected');
    }
    socket.emit('send-message', {
      'roomId': roomId,
      if (content.isNotEmpty) 'content': content,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    });
  }

  @override
  void disconnect() {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    _socket = null;
    try {
      socket.clearListeners();
      socket.dispose();
    } catch (_) {
      // ignore teardown errors
    }
  }

  @override
  void dispose() {
    disconnect();
    _messages.close();
    _errors.close();
    _status.close();
  }

  static Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static String _extractErrorMessage(dynamic data) {
    final map = _asMap(data);
    if (map != null) {
      final message = map['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return 'Unknown chat error';
  }
}
