import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/parcel_response_parser.dart';
import '../../../core/network/network_providers.dart';
import '../../parcel_payment/data/payment_repository.dart';

class SendParcelItem {
  const SendParcelItem({
    required this.id,
    required this.title,
    required this.trackNo,
    this.address = '',
    this.weightKg,
    this.priceLak,
  });

  final String id;
  final String title;
  final String trackNo;

  /// Delivery address the admin imported with the parcel. The forward flow
  /// prefills the recipient address field with it; empty when not imported.
  final String address;

  final double? weightKg;

  /// The parcel's own price in LAK. A forward order bills this on top of the
  /// shipping fee, so the summary needs it to preview the real total.
  final int? priceLak;

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
      address:
          _readString(json, const [
            'address',
            'recipientAddress',
            'recipient_address',
            'addressLine',
          ]) ??
          '',
      weightKg: _readNum(json, const ['weight']),
      priceLak: _readNum(json, const [
        'price',
        'price_lak',
        'priceLak',
      ])?.round(),
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
    required this.courierName,
    required this.branchName,
    required this.latitude,
    required this.longitude,
  });

  /// Laravel parcel id. The backend resolves price and weight from it, so the
  /// app never sends price/weight.
  final String parcelId;
  final String recipientName;
  final String recipientPhone;
  final String recipientAddress;
  final String courierName;
  final String branchName;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'laravelParcelId': asLaravelParcelId(parcelId),
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      if (recipientAddress.isNotEmpty) 'recipientAddress': recipientAddress,
      'courierName': courierName,
      if (branchName.isNotEmpty) 'branchName': branchName,
      'lat': latitude,
      'lng': longitude,
    };
  }
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

  /// Creates a single forward order covering every parcel in [parcels]. The
  /// recipient details are repeated per parcel because the endpoint keys them
  /// to each `laravelParcelId`.
  Future<ParcelOrder> createForwardOrder(
    List<CreateForwardRequest> parcels,
  ) async {
    final body = <String, dynamic>{
      'parcels': [for (final parcel in parcels) parcel.toJson()],
    };
    try {
      final response = await _dio.post<dynamic>('/orders/forward', data: body);
      if (kDebugMode) {
        debugPrint(
          '[SendRepository] POST /orders/forward ok: '
          'status=${response.statusCode} body=${response.data}',
        );
      }
      return ParcelOrder.fromResponse(response.data);
    } on DioException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[SendRepository] POST /orders/forward failed: '
          'status=${error.response?.statusCode} type=${error.type} '
          'request=$body body=${error.response?.data}',
        );
      }
      rethrow;
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

final sendRepositoryProvider = Provider<SendRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return SendRepository(dio: dio);
});

final sendParcelsProvider = FutureProvider<List<SendParcelItem>>((ref) {
  return ref.watch(sendRepositoryProvider).fetchForwardableParcels();
});
