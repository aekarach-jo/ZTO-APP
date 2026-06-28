import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/parcel_response_parser.dart';
import '../../../core/network/network_providers.dart';

class SendParcelItem {
  const SendParcelItem({
    required this.id,
    required this.title,
    required this.trackNo,
    this.weightKg,
  });

  final String id;
  final String title;
  final String trackNo;
  final double? weightKg;

  factory SendParcelItem.fromJson(Map<String, dynamic> json) {
    final tracking =
        _readString(json, const [
          'trackingNo',
          'tracking_no',
          'trackingNumber',
          'track_no',
        ]) ??
        '-';
    return SendParcelItem(
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
      weightKg: _readNum(json, const ['weight']),
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

  static double? _readNum(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value.trim());
      }
    }
    return null;
  }
}

class CreateForwardRequest {
  const CreateForwardRequest({
    required this.parcelId,
    required this.recipientName,
    required this.recipientPhone,
    required this.recipientAddress,
    required this.courier,
    required this.branch,
    required this.latitude,
    required this.longitude,
    required this.paymentMethod,
  });

  final String parcelId;
  final String recipientName;
  final String recipientPhone;
  final String recipientAddress;
  final String courier;
  final String branch;
  final double latitude;
  final double longitude;
  final String paymentMethod;
}

class SendRepository {
  SendRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<SendParcelItem>> fetchForwardableParcels() async {
    final response = await _dio.get<dynamic>('/parcels');
    final list = _extractList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .map(SendParcelItem.fromJson)
        .toList(growable: false);
  }

  Future<void> createForwardRequest(CreateForwardRequest request) async {
    final payload = <String, dynamic>{
      'parcelId': request.parcelId,
      'recipientName': request.recipientName,
      'recipientPhone': request.recipientPhone,
      'recipientAddress': request.recipientAddress,
      'courier': request.courier,
      'branch': request.branch,
      'paymentMethod': request.paymentMethod,
      'location': {
        'latitude': request.latitude,
        'longitude': request.longitude,
      },
    };

    await _dio.post<dynamic>(
      '/parcels/${request.parcelId}/forward',
      data: payload,
    );
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

final sendRepositoryProvider = Provider<SendRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return SendRepository(dio: dio);
});

final sendParcelsProvider = FutureProvider<List<SendParcelItem>>((ref) {
  return ref.watch(sendRepositoryProvider).fetchForwardableParcels();
});
