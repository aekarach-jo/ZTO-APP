import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../parcel_payment/data/payment_repository.dart';

/// Payment status of an order as returned by `GET /orders`.
enum OrderPaymentState {
  pending,
  paid,
  failed;

  static OrderPaymentState fromApi(String? raw) {
    switch (raw) {
      case 'paid':
        return OrderPaymentState.paid;
      case 'failed':
        return OrderPaymentState.failed;
      case 'pending':
      default:
        return OrderPaymentState.pending;
    }
  }
}

/// A single order in the history list (`GET /orders`).
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.type,
    required this.paymentStatus,
    required this.amount,
    this.currency = 'LAK',
    this.recipientName,
    this.createdAt,
    this.paidAt,
  });

  final String id;
  final String type;
  final OrderPaymentState paymentStatus;
  final int amount;
  final String currency;
  final String? recipientName;
  final DateTime? createdAt;
  final DateTime? paidAt;

  bool get isForward => type == 'forward';

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      paymentStatus: OrderPaymentState.fromApi(
        json['paymentStatus']?.toString(),
      ),
      amount: _readInt(json['amount']) ?? 0,
      currency: (json['currency'] ?? 'LAK').toString(),
      recipientName: json['recipientName']?.toString(),
      createdAt: _readDate(json['createdAt'] ?? json['created_at']),
      paidAt: _readDate(json['paidAt'] ?? json['paid_at']),
    );
  }
}

class OrderRepository {
  OrderRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// All orders of the current user, newest first.
  Future<List<OrderSummary>> fetchOrders() async {
    final response = await _dio.get<dynamic>('/orders');
    final list = _extractList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .map(OrderSummary.fromJson)
        .toList(growable: false);
  }

  /// Detail of a single order.
  Future<ParcelOrder> fetchOrder(String orderId) async {
    final response = await _dio.get<dynamic>('/orders/$orderId');
    return ParcelOrder.fromResponse(response.data);
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is List) {
        return inner;
      }
      if (inner is Map<String, dynamic>) {
        final nested = inner['data'] ?? inner['orders'];
        if (nested is List) {
          return nested;
        }
      }
    }
    return const <dynamic>[];
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

DateTime? _readDate(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return OrderRepository(dio: dio);
});

final ordersProvider = FutureProvider<List<OrderSummary>>((ref) {
  return ref.watch(orderRepositoryProvider).fetchOrders();
});
