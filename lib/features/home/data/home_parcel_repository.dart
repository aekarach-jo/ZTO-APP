import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/parcel_response_parser.dart';
import '../../../core/network/network_providers.dart';

class HomeParcel {
  const HomeParcel({
    required this.id,
    required this.title,
    required this.trackingNo,
    required this.weightLabel,
    required this.dateLabel,
    required this.status,
    this.price,
  });

  final String id;
  final String title;
  final String trackingNo;
  final String weightLabel;
  final String dateLabel;
  final String status;

  /// ค่าส่งเป็นกีบ (ใช้เป็น amount ตอนสร้าง pickup order)
  final int? price;

  factory HomeParcel.fromJson(
    Map<String, dynamic> json, {
    String? inheritedDateRaw,
  }) {
    final trackingNo =
        _readString(json, const [
          'trackingNo',
          'tracking_no',
          'trackingNumber',
        ]) ??
        _readString(json, const ['track_no']) ??
        '-';

    final id = _readString(json, const ['id', '_id', 'parcelId']) ?? trackingNo;
    final title =
        _readString(json, const [
          'name',
          'title',
          'itemName',
          'productName',
          'recipientName',
          'description',
        ]) ??
        trackingNo;

    final status =
        _readString(json, const ['status', 'parcelStatus']) ?? 'pending';

    final weightRaw =
        _readString(json, const ['weightLabel']) ??
        _readNumberAsString(json, const ['weight']);
    final weightLabel = weightRaw == null || weightRaw.isEmpty
        ? '-'
        : '$weightRaw kg';

    final dateRaw = _readString(json, const [
      'dateLabel',
      'incoming_at',
      'incoming_at_str',
      'createdAt',
      'created_at',
      'updatedAt',
      'updated_at',
    ]);
    final dateLabel = _formatDateLabel(dateRaw ?? inheritedDateRaw);

    return HomeParcel(
      id: id,
      title: title,
      trackingNo: trackingNo.startsWith('#') ? trackingNo : '#$trackingNo',
      weightLabel: weightLabel,
      dateLabel: dateLabel,
      status: status.toLowerCase(),
      price: _readInt(json, const ['price']),
    );
  }

  static int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.round();
      }
      if (value is String) {
        final parsed = num.tryParse(value.trim());
        if (parsed != null) {
          return parsed.round();
        }
      }
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

  static String? _readNumberAsString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
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
        .map((item) {
          if (item is HomeParcel) {
            return item;
          }
          if (item is Map<String, dynamic>) {
            return HomeParcel.fromJson(item);
          }
          return null;
        })
        .whereType<HomeParcel>()
        .toList(growable: false);
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

      final inheritedDate = (item['incoming_at'] ?? item['incoming_at_str'])
          ?.toString();
      for (final parcel in nestedParcels.whereType<Map<String, dynamic>>()) {
        flattened.add(
          HomeParcel.fromJson(parcel, inheritedDateRaw: inheritedDate),
        );
      }
    }

    return flattened;
  }
}

final homeParcelRepositoryProvider = Provider<HomeParcelRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return HomeParcelRepository(dio: dio);
});

final homeParcelsProvider = FutureProvider<List<HomeParcel>>((ref) {
  return ref.watch(homeParcelRepositoryProvider).fetchMyParcels();
});
