import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/parcel_response_parser.dart';
import '../../../core/network/network_providers.dart';

class StaffParcelItem {
  const StaffParcelItem({
    required this.id,
    required this.title,
    required this.trackNo,
    required this.weightLabel,
    required this.dateLabel,
    required this.status,
  });

  final String id;
  final String title;
  final String trackNo;
  final String weightLabel;
  final String dateLabel;
  final String status;

  factory StaffParcelItem.fromJson(Map<String, dynamic> json) {
    final tracking =
        _readString(json, const [
          'trackingNo',
          'tracking_no',
          'trackingNumber',
          'track_no',
        ]) ??
        '-';
    final weight =
        _readString(json, const ['weightLabel']) ??
        _readNum(json, const ['weight'])?.toString();
    return StaffParcelItem(
      id: _readString(json, const ['id', '_id', 'parcelId']) ?? tracking,
      title:
          _readString(json, const [
            'name',
            'title',
            'itemName',
            'productName',
            'recipientName',
            'description',
          ]) ??
          tracking,
      trackNo: tracking.startsWith('#') ? tracking : '#$tracking',
      weightLabel: (weight == null || weight.isEmpty) ? '-' : '$weight kg',
      dateLabel: _formatDate(
        _readString(json, const [
          'createdAt',
          'created_at',
          'updatedAt',
          'updated_at',
        ]),
      ),
      status: (_readString(json, const ['status', 'parcelStatus']) ?? 'pending')
          .toLowerCase(),
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

  static num? _readNum(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value;
      }
      if (value is String) {
        return num.tryParse(value.trim());
      }
    }
    return null;
  }

  static String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  bool matches(String query) {
    if (query.isEmpty) {
      return true;
    }
    final lower = query.toLowerCase();
    return title.toLowerCase().contains(lower) ||
        trackNo.toLowerCase().contains(lower);
  }
}

class StaffStatusStyle {
  const StaffStatusStyle({
    required this.statusKey,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String statusKey;
  final Color backgroundColor;
  final Color foregroundColor;
}

StaffStatusStyle staffStatusStyleOf(String status) {
  switch (status) {
    case 'ready':
    case 'ready_to_ship':
      return const StaffStatusStyle(
        statusKey: 'status_ready_to_ship',
        backgroundColor: Color(0xFFD8E9FF),
        foregroundColor: Color(0xFF2B6FC8),
      );
    case 'in_transit':
      return const StaffStatusStyle(
        statusKey: 'status_shipping_started',
        backgroundColor: Color(0xFFEDF1F5),
        foregroundColor: Color(0xFF6F8196),
      );
    case 'arrived':
    case 'picked_up':
      return const StaffStatusStyle(
        statusKey: 'status_received',
        backgroundColor: Color(0xFFD6F4E1),
        foregroundColor: Color(0xFF19964C),
      );
    default:
      return const StaffStatusStyle(
        statusKey: 'status_waiting_inspection',
        backgroundColor: Color(0xFFFDF0A6),
        foregroundColor: Color(0xFF8D7000),
      );
  }
}

class StaffParcelRepository {
  StaffParcelRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<StaffParcelItem>> fetchParcels() async {
    final response = await _dio.get<dynamic>('/parcels');
    final list = _extractList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .map(StaffParcelItem.fromJson)
        .toList(growable: false);
  }

  Future<void> markInspected(String parcelId) async {
    try {
      await _dio.post<dynamic>('/staff/parcels/$parcelId/inspect');
      return;
    } on DioException {
      await _dio.patch<dynamic>(
        '/parcels/$parcelId',
        data: {'status': 'ready_to_ship'},
      );
    }
  }

  Future<void> confirmHandover(String parcelId) async {
    try {
      await _dio.post<dynamic>('/staff/parcels/$parcelId/handover');
      return;
    } on DioException {
      await _dio.patch<dynamic>(
        '/parcels/$parcelId',
        data: {'status': 'picked_up'},
      );
    }
  }

  List<dynamic> _extractList(dynamic data) {
    return _flattenGroupedList(extractParcelPayloadList(data));
  }

  List<dynamic> _flattenGroupedList(List<dynamic> rawList) {
    final flattened = <dynamic>[];

    for (final item in rawList) {
      if (item is! Map<String, dynamic>) {
        flattened.add(item);
        continue;
      }

      final nestedParcels = item['parcels'];
      if (nestedParcels is! List<dynamic>) {
        flattened.add(item);
        continue;
      }

      flattened.addAll(nestedParcels.whereType<Map<String, dynamic>>());
    }

    return flattened;
  }
}

final staffParcelRepositoryProvider = Provider<StaffParcelRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return StaffParcelRepository(dio: dio);
});

final staffParcelsProvider = FutureProvider<List<StaffParcelItem>>((ref) {
  return ref.watch(staffParcelRepositoryProvider).fetchParcels();
});

final handoverReadyParcelsProvider = FutureProvider<List<StaffParcelItem>>((
  ref,
) async {
  final items = await ref.watch(staffParcelRepositoryProvider).fetchParcels();
  return items
      .where((item) => item.status == 'ready_to_ship' || item.status == 'ready')
      .toList(growable: false);
});
