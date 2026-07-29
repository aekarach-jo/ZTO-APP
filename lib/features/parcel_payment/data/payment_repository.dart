import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';

/// Payment method identifiers accepted by `POST /orders/{id}/pay`.
abstract final class PaymentMethods {
  static const String onepay = 'onepay';
  static const String creditCard = 'credit_card';
}

/// A single parcel line inside an order (`data.items[]`). One order can carry
/// many parcels; each has its own price, shipping fee and total.
class OrderItem {
  const OrderItem({
    required this.laravelParcelId,
    required this.price,
    required this.shippingFee,
    required this.itemTotal,
  });

  final String laravelParcelId;
  final int price;
  final int shippingFee;
  final int itemTotal;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      laravelParcelId: (json['laravelParcelId'] ?? '').toString(),
      price: _readInt(json['price']) ?? 0,
      shippingFee: _readInt(json['shippingFee']) ?? 0,
      itemTotal: _readInt(json['itemTotal']) ?? 0,
    );
  }
}

/// Order created from `POST /orders/pickup` or `POST /orders/forward`.
/// One order may cover several parcels (see [items]); [amount] is the total.
class ParcelOrder {
  const ParcelOrder({
    required this.id,
    required this.type,
    required this.paymentStatus,
    required this.amount,
    this.currency = 'LAK',
    this.weight,
    this.recipientName,
    this.billNo,
    this.items = const [],
  });

  final String id;
  final String type;
  final String paymentStatus;
  final int amount;
  final String currency;
  final double? weight;
  final String? recipientName;

  /// Human-readable bill number shown on the receipt (e.g. `2607-00020`).
  /// Null until the backend starts sending it.
  final String? billNo;
  final List<OrderItem> items;

  bool get isPaid => paymentStatus == 'paid';
  bool get isForward => type == 'forward';

  factory ParcelOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ParcelOrder(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      paymentStatus: (json['paymentStatus'] ?? 'pending').toString(),
      amount: _readInt(json['amount']) ?? 0,
      currency: (json['currency'] ?? 'LAK').toString(),
      weight: _readDouble(json['weight']),
      recipientName: json['recipientName']?.toString(),
      billNo: _readRef(json['billNo']),
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(OrderItem.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  factory ParcelOrder.fromResponse(dynamic data) {
    return ParcelOrder.fromJson(unwrapDataEnvelope(data));
  }
}

/// Result of `POST /orders/{orderId}/pay`.
class PaymentInitiation {
  const PaymentInitiation({
    required this.transactionRef,
    required this.method,
    this.qrString,
    this.paymentUrl,
    this.billNo,
    this.paymentNo,
  });

  final String transactionRef;
  final String method;
  final String? qrString;
  final String? paymentUrl;

  /// Receipt numbers, if the backend already issues them at this step.
  final String? billNo;
  final String? paymentNo;

  factory PaymentInitiation.fromResponse(dynamic data) {
    final json = unwrapDataEnvelope(data);
    return PaymentInitiation(
      transactionRef: (json['transactionRef'] ?? '').toString(),
      method: (json['method'] ?? '').toString(),
      qrString: json['qrString']?.toString(),
      paymentUrl: json['paymentUrl']?.toString(),
      billNo: _readRef(json['billNo']),
      paymentNo: _readRef(json['paymentNo']),
    );
  }
}

/// Result of `GET /orders/{orderId}/payment-status`.
class OrderPaymentStatus {
  const OrderPaymentStatus({
    required this.isPaid,
    this.bankRef,
    this.paidAt,
    this.billNo,
    this.paymentNo,
    this.amount,
  });

  final bool isPaid;
  final String? bankRef;
  final DateTime? paidAt;

  /// Receipt numbers issued once the payment settles. Null until the backend
  /// adds them (see API_REQUEST_BILL_NO.md); the receipt hides missing rows.
  final String? billNo;
  final String? paymentNo;

  /// Amount actually charged, used to reconcile the receipt total.
  final int? amount;

  factory OrderPaymentStatus.fromResponse(dynamic data) {
    final json = unwrapDataEnvelope(data);
    return OrderPaymentStatus(
      isPaid: json['isPaid'] == true,
      bankRef: json['bankRef']?.toString(),
      paidAt: json['paidAt'] is String
          ? DateTime.tryParse(json['paidAt'] as String)
          : null,
      billNo: _readRef(json['billNo']),
      paymentNo: _readRef(json['paymentNo']),
      amount: _readInt(json['amount']),
    );
  }
}

/// Forward shipping-fee preview (LAK, no VAT). The amount actually charged
/// must come from the created order (`ParcelOrder.amount`), which also adds the
/// parcel price the backend resolves from Laravel.
class ForwardFeeQuote {
  const ForwardFeeQuote({required this.billableKg, required this.fee});

  final int billableKg;
  final int fee;

  int get total => fee;

  factory ForwardFeeQuote.fromWeight(double weightKg) {
    final billableKg = weightKg <= 1 ? 1 : weightKg.ceil();
    final fee = 13000 + (billableKg - 1) * 2000;
    return ForwardFeeQuote(billableKg: billableKg, fee: fee);
  }
}

class PaymentRepository {
  PaymentRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Creates a single pickup order covering all [parcelIds] (Laravel ids).
  /// The backend resolves each parcel's price and returns the order total.
  Future<ParcelOrder> createPickupOrder({
    required List<String> parcelIds,
  }) async {
    final response = await _dio.post<dynamic>(
      '/orders/pickup',
      data: {'parcelIds': parcelIds.map(asLaravelParcelId).toList()},
    );
    return ParcelOrder.fromResponse(response.data);
  }

  Future<PaymentInitiation> initiatePayment({
    required String orderId,
    String method = PaymentMethods.onepay,
  }) async {
    final response = await _dio.post<dynamic>(
      '/orders/$orderId/pay',
      data: {'method': method},
    );
    return PaymentInitiation.fromResponse(response.data);
  }

  Future<OrderPaymentStatus> fetchPaymentStatus(String orderId) async {
    final response = await _dio.get<dynamic>('/orders/$orderId/payment-status');
    return OrderPaymentStatus.fromResponse(response.data);
  }
}

/// Unwraps the standard `{ success, data: {...} }` envelope, tolerating
/// responses that are not wrapped.
Map<String, dynamic> unwrapDataEnvelope(dynamic data) {
  if (data is! Map<String, dynamic>) {
    return const <String, dynamic>{};
  }
  final inner = data['data'];
  if (inner is Map<String, dynamic>) {
    return inner;
  }
  return data;
}

/// Laravel parcel ids are large integers. Send them as numbers when they parse
/// cleanly, falling back to the raw string for non-numeric ids.
Object asLaravelParcelId(String id) {
  return int.tryParse(id.trim()) ?? id;
}

/// Reads an optional reference string (bill/payment number), treating empty
/// strings as absent so the receipt doesn't render blank rows.
String? _readRef(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
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

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return PaymentRepository(dio: dio);
});
