import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';

/// Tab a parcel belongs to on the status page. Decided server-side when a
/// payment succeeds.
enum ParcelStatusCategory {
  inProgress,
  selfPickup,
  forwarded;

  static ParcelStatusCategory fromApi(String? raw) {
    switch (raw) {
      case 'self_pickup':
        return ParcelStatusCategory.selfPickup;
      case 'forwarded':
        return ParcelStatusCategory.forwarded;
      case 'in_progress':
      default:
        return ParcelStatusCategory.inProgress;
    }
  }
}

/// Card counts shown above the tabs.
class ParcelStatusCounts {
  const ParcelStatusCounts({
    required this.inProgress,
    required this.selfPickup,
    required this.forwarded,
  });

  final int inProgress;
  final int selfPickup;
  final int forwarded;

  int forCategory(ParcelStatusCategory category) {
    switch (category) {
      case ParcelStatusCategory.inProgress:
        return inProgress;
      case ParcelStatusCategory.selfPickup:
        return selfPickup;
      case ParcelStatusCategory.forwarded:
        return forwarded;
    }
  }

  factory ParcelStatusCounts.fromJson(Map<String, dynamic>? json) {
    return ParcelStatusCounts(
      inProgress: _readInt(json?['in_progress']) ?? 0,
      selfPickup: _readInt(json?['self_pickup']) ?? 0,
      forwarded: _readInt(json?['forwarded']) ?? 0,
    );
  }
}

/// Paid order attached to a parcel (present once a payment succeeded).
class ParcelStatusOrder {
  const ParcelStatusOrder({
    required this.nestOrderId,
    required this.type,
    this.amountLak,
    this.method,
    this.paymentRef,
    this.paidAt,
  });

  final String nestOrderId;
  final String type;
  final double? amountLak;
  final String? method;
  final String? paymentRef;
  final DateTime? paidAt;

  factory ParcelStatusOrder.fromJson(Map<String, dynamic> json) {
    return ParcelStatusOrder(
      nestOrderId: (json['nest_order_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      // The total actually charged (`price_lak`); older/other shapes may send
      // `amount_lak` or only `item_total_lak`, so fall back through them.
      amountLak: _readDouble(
        json['price_lak'] ?? json['amount_lak'] ?? json['item_total_lak'],
      ),
      method: json['method']?.toString(),
      paymentRef: json['payment_ref']?.toString(),
      paidAt: json['paid_at'] is String
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
    );
  }
}

class ParcelStatusItem {
  const ParcelStatusItem({
    required this.id,
    required this.trackNo,
    required this.name,
    required this.status,
    required this.step,
    required this.category,
    this.weight,
    this.stepLabel,
    this.isForward = false,
    this.createdAt,
    this.order,
  });

  final String id;
  final String trackNo;
  final String name;
  final String status;

  /// 1–4 tracker step reached (see [ParcelStatusStep]).
  final int step;
  final ParcelStatusCategory category;
  final double? weight;

  /// Server-supplied step label; the app renders its own localized label
  /// keyed off [step] and only falls back to this.
  final String? stepLabel;
  final bool isForward;
  final DateTime? createdAt;
  final ParcelStatusOrder? order;

  factory ParcelStatusItem.fromJson(Map<String, dynamic> json) {
    final order = json['order'];
    return ParcelStatusItem(
      id: (json['id'] ?? '').toString(),
      trackNo: (json['track_no'] ?? '-').toString(),
      name: (json['name'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      step: _readInt(json['step']) ?? 1,
      category: ParcelStatusCategory.fromApi(json['category']?.toString()),
      weight: _readDouble(json['weight']),
      stepLabel: json['step_label']?.toString(),
      isForward: json['is_forward'] == true,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      order: order is Map<String, dynamic>
          ? ParcelStatusOrder.fromJson(order)
          : null,
    );
  }
}

class ParcelStatusPage {
  const ParcelStatusPage({required this.counts, required this.parcels});

  final ParcelStatusCounts counts;
  final List<ParcelStatusItem> parcels;

  List<ParcelStatusItem> forCategory(ParcelStatusCategory category) {
    return parcels
        .where((parcel) => parcel.category == category)
        .toList(growable: false);
  }

  factory ParcelStatusPage.fromResponse(dynamic data) {
    final payload = _unwrapToPayload(data);

    final rawParcels = payload['parcels'];
    final parcels = rawParcels is List
        ? rawParcels
              .whereType<Map<String, dynamic>>()
              .map(ParcelStatusItem.fromJson)
              .toList(growable: false)
        : const <ParcelStatusItem>[];

    return ParcelStatusPage(
      counts: ParcelStatusCounts.fromJson(
        payload['counts'] is Map<String, dynamic>
            ? payload['counts'] as Map<String, dynamic>
            : null,
      ),
      parcels: parcels,
    );
  }

  /// The API wraps the payload in nested `data` envelopes
  /// (`{ data: { code, status, data: { counts, parcels } } }`). Dig through the
  /// `data` layers until we reach the object that actually holds
  /// `counts`/`parcels`, tolerating single- or un-nested shapes too.
  static Map<String, dynamic> _unwrapToPayload(dynamic data) {
    dynamic current = data;
    for (var depth = 0; depth < 5; depth++) {
      if (current is! Map<String, dynamic>) {
        break;
      }
      if (current.containsKey('parcels') || current.containsKey('counts')) {
        return current;
      }
      final inner = current['data'];
      if (inner is Map<String, dynamic>) {
        current = inner;
      } else {
        break;
      }
    }
    return current is Map<String, dynamic>
        ? current
        : const <String, dynamic>{};
  }
}

class ParcelStatusRepository {
  ParcelStatusRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<ParcelStatusPage> fetchStatus() async {
    try {
      final response = await _dio.get<dynamic>('/parcels/status');
      return ParcelStatusPage.fromResponse(response.data);
    } on DioException catch (error) {
      // Surface the real cause behind the retry state (status code / body)
      // instead of silently swallowing it in the UI's error branch.
      if (kDebugMode) {
        debugPrint(
          '[ParcelStatusRepository] GET /parcels/status failed: '
          'status=${error.response?.statusCode} type=${error.type} '
          'message=${error.message} body=${error.response?.data}',
        );
      }
      rethrow;
    }
  }
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? double.tryParse(value.trim())?.round();
  }
  return null;
}

double? _readDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

final parcelStatusRepositoryProvider = Provider<ParcelStatusRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return ParcelStatusRepository(dio: dio);
});

final parcelStatusProvider = FutureProvider<ParcelStatusPage>((ref) {
  return ref.watch(parcelStatusRepositoryProvider).fetchStatus();
});
