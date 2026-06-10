import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';

class HomeParcel {
  const HomeParcel({
    required this.id,
    required this.title,
    required this.trackingNo,
    required this.weightLabel,
    required this.dateLabel,
    required this.status,
  });

  final String id;
  final String title;
  final String trackingNo;
  final String weightLabel;
  final String dateLabel;
  final String status;

  factory HomeParcel.fromJson(Map<String, dynamic> json) {
    final trackingNo = _readString(
          json,
          const ['trackingNo', 'tracking_no', 'trackingNumber'],
        ) ??
        '-';

    final id = _readString(json, const ['id', '_id', 'parcelId']) ?? trackingNo;
    final title = _readString(
          json,
          const [
            'title',
            'itemName',
            'productName',
            'recipientName',
            'description',
          ],
        ) ??
        trackingNo;

    final status = _readString(json, const ['status', 'parcelStatus']) ?? 'pending';

    final weightRaw =
        _readString(json, const ['weightLabel']) ?? _readNumberAsString(json, const ['weight']);
    final weightLabel = weightRaw == null || weightRaw.isEmpty ? '-' : '$weightRaw kg';

    final dateRaw = _readString(
      json,
      const ['dateLabel', 'createdAt', 'created_at', 'updatedAt', 'updated_at'],
    );
    final dateLabel = _formatDateLabel(dateRaw);

    return HomeParcel(
      id: id,
      title: title,
      trackingNo: trackingNo.startsWith('#') ? trackingNo : '#$trackingNo',
      weightLabel: weightLabel,
      dateLabel: dateLabel,
      status: status.toLowerCase(),
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

  static String? _readNumberAsString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value.toString();
      }
      if (value is String) {
        final text = value.trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  static String _formatDateLabel(String? raw) {
    if (raw == null || raw.isEmpty) {
      return '-';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }
}

class HomeParcelRepository {
  HomeParcelRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<HomeParcel>> fetchMyParcels() async {
    final response = await _dio.get<dynamic>('/parcels');
    final list = _extractList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .map(HomeParcel.fromJson)
        .toList(growable: false);
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
        final nested = direct['items'] ?? direct['parcels'] ?? direct['results'];
        if (nested is List<dynamic>) {
          return nested;
        }
      }

      final root = data['items'] ?? data['parcels'] ?? data['results'];
      if (root is List<dynamic>) {
        return root;
      }
    }

    return const <dynamic>[];
  }
}

final homeParcelRepositoryProvider = Provider<HomeParcelRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return HomeParcelRepository(dio: dio);
});

final homeParcelsProvider = FutureProvider<List<HomeParcel>>((ref) {
  return ref.watch(homeParcelRepositoryProvider).fetchMyParcels();
});

