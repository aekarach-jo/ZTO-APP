import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';

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
  });

  final String id;
  final ContactMessageRole role;
  final String text;
  final DateTime createdAt;

  factory ContactMessage.fromJson(Map<String, dynamic> json) {
    final roleValue = _readString(json, const ['role', 'senderType', 'sender'])?.toLowerCase();
    final role = (roleValue == 'user' || roleValue == 'customer' || roleValue == 'client')
        ? ContactMessageRole.user
        : ContactMessageRole.agent;

    final text = _readString(json, const ['message', 'text', 'content', 'body']) ?? '-';
    final id = _readString(json, const ['id', '_id', 'messageId']) ??
        '${role.name}-${DateTime.now().microsecondsSinceEpoch}';
    final createdAt = _parseDate(json['createdAt'] ?? json['created_at'] ?? json['sentAt']) ??
        DateTime.now();

    return ContactMessage(
      id: id,
      role: role,
      text: text,
      createdAt: createdAt,
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

  Future<List<ContactMessage>> fetchMessages() async {
    Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>('/contact/messages');
      if (kDebugMode) {
        debugPrint('[ContactRepository] GET /contact/messages status=${response.statusCode}');
      }
    } on DioException {
      response = await _dio.get<dynamic>('/chat/messages');
      if (kDebugMode) {
        debugPrint('[ContactRepository] Fallback GET /chat/messages status=${response.statusCode}');
      }
    }

    final list = _extractList(response.data);
    final messages = list
        .whereType<Map<String, dynamic>>()
        .map(ContactMessage.fromJson)
        .toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return messages;
  }

  Future<List<ContactMessage>> sendMessage({required String text}) async {
    final response = await _postMessageWithFallback(text);
    return _extractMessagesFromSendResponse(response.data, originalText: text);
  }

  Future<Response<dynamic>> _postMessageWithFallback(String text) async {
    const endpoints = <String>['/contact/messages', '/chat/messages'];
    final payloads = <Map<String, String>>[
      {'message': text},
      {'text': text},
      {'content': text},
      {'body': text},
      {'messageText': text},
    ];

    final errors = <DioException>[];
    for (final endpoint in endpoints) {
      for (final payload in payloads) {
        if (kDebugMode) {
          debugPrint('[ContactRepository] Try POST $endpoint payloadKeys=${payload.keys.join(',')}');
        }
        try {
          final response = await _dio.post<dynamic>(endpoint, data: payload);
          if (kDebugMode) {
            debugPrint('[ContactRepository] Success POST $endpoint status=${response.statusCode}');
          }
          return response;
        } on DioException catch (error) {
          errors.add(error);
          if (kDebugMode) {
            debugPrint(
              '[ContactRepository] Failed POST $endpoint status=${error.response?.statusCode} message=${_extractErrorMessage(error)}',
            );
          }
        }
      }
    }

    final hasOnlyNotFound = errors.isNotEmpty &&
        errors.every((error) => error.response?.statusCode == 404);
    if (hasOnlyNotFound) {
      if (kDebugMode) {
        debugPrint('[ContactRepository] All POST attempts returned 404 (send endpoint not available)');
      }
      throw const ContactSendException(
        'Failed to send message: Backend has no send endpoint (GET /chat/messages is available, but POST is not).',
      );
    }

    final lastError = errors.isNotEmpty ? errors.last : null;
    if (lastError != null) {
      final statusCode = lastError.response?.statusCode;
      final apiMessage = _extractErrorMessage(lastError);
      if (kDebugMode) {
        debugPrint('[ContactRepository] Final send error status=$statusCode details=$apiMessage');
      }
      throw ContactSendException(
        'Failed to send message${statusCode != null ? ' ($statusCode)' : ''}${apiMessage.isNotEmpty ? ': $apiMessage' : ''}',
      );
    }

    throw const ContactSendException('Failed to send message');
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is String) {
      return data.trim();
    }
    if (data is Map<String, dynamic>) {
      final raw = data['message'] ?? data['error'] ?? data['detail'];
      if (raw is String) {
        return raw.trim();
      }
      if (raw is List && raw.isNotEmpty) {
        return raw.join(' ').trim();
      }
    }
    return '';
  }

  List<ContactMessage> _extractMessagesFromSendResponse(
    dynamic data, {
    required String originalText,
  }) {
    final list = _extractList(data);
    final parsed = list.whereType<Map<String, dynamic>>().map(ContactMessage.fromJson).toList();
    if (parsed.isNotEmpty) {
      return parsed;
    }

    if (data is Map<String, dynamic>) {
      final payload = data['data'];
      if (payload is Map<String, dynamic>) {
        final maybeReply = payload['reply'] ?? payload['message'];
        if (maybeReply is String && maybeReply.trim().isNotEmpty) {
          return [
            ContactMessage(
              id: 'agent-${DateTime.now().microsecondsSinceEpoch}',
              role: ContactMessageRole.agent,
              text: maybeReply.trim(),
              createdAt: DateTime.now(),
            ),
          ];
        }
      }
    }

    return [];
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

class ContactThreadController extends AsyncNotifier<List<ContactMessage>> {
  @override
  Future<List<ContactMessage>> build() {
    return ref.watch(contactRepositoryProvider).fetchMessages();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final optimistic = ContactMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      role: ContactMessageRole.user,
      text: trimmed,
      createdAt: DateTime.now(),
    );

    final current = state.valueOrNull ?? const <ContactMessage>[];
    state = AsyncData([...current, optimistic]);

    final reply = await ref.read(contactRepositoryProvider).sendMessage(text: trimmed);
    if (reply.isEmpty) {
      return;
    }

    final latest = state.valueOrNull ?? [...current, optimistic];
    state = AsyncData([...latest, ...reply]);
  }
}

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return ContactRepository(dio: dio);
});

final contactThreadProvider =
    AsyncNotifierProvider<ContactThreadController, List<ContactMessage>>(
  ContactThreadController.new,
);

