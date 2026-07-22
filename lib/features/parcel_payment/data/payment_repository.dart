import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';

/// Payment method identifiers accepted by `POST /orders/{id}/pay`.
abstract final class PaymentMethods {
  static const String onepay = 'onepay';
  static const String creditCard = 'credit_card';
}

/// Order created from `POST /parcels/{id}/pickup` or `POST /parcels/{id}/forward`.
class ParcelOrder {
  const ParcelOrder({
    required this.id,
    required this.type,
    required this.paymentStatus,
    required this.amount,
    this.currency = 'LAK',
    this.weight,
    this.recipientName,
  });

  final String id;
  final String type;
  final String paymentStatus;
  final int amount;
  final String currency;
  final double? weight;
  final String? recipientName;

  bool get isPaid => paymentStatus == 'paid';

  factory ParcelOrder.fromJson(Map<String, dynamic> json) {
    return ParcelOrder(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      paymentStatus: (json['paymentStatus'] ?? 'pending').toString(),
      amount: _readInt(json['amount']) ?? 0,
      currency: (json['currency'] ?? 'LAK').toString(),
      weight: _readDouble(json['weight']),
      recipientName: json['recipientName']?.toString(),
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
  });

  final String transactionRef;
  final String method;
  final String? qrString;
  final String? paymentUrl;

  factory PaymentInitiation.fromResponse(dynamic data) {
    final json = unwrapDataEnvelope(data);
    return PaymentInitiation(
      transactionRef: (json['transactionRef'] ?? '').toString(),
      method: (json['method'] ?? '').toString(),
      qrString: json['qrString']?.toString(),
      paymentUrl: json['paymentUrl']?.toString(),
    );
  }
}

/// Result of `GET /orders/{orderId}/payment-status`.
class OrderPaymentStatus {
  const OrderPaymentStatus({required this.isPaid, this.bankRef, this.paidAt});

  final bool isPaid;
  final String? bankRef;
  final DateTime? paidAt;

  factory OrderPaymentStatus.fromResponse(dynamic data) {
    final json = unwrapDataEnvelope(data);
    return OrderPaymentStatus(
      isPaid: json['isPaid'] == true,
      bankRef: json['bankRef']?.toString(),
      paidAt: json['paidAt'] is String
          ? DateTime.tryParse(json['paidAt'] as String)
          : null,
    );
  }
}

/// Forward service fee preview. The amount actually charged must come from
/// the created order (`ParcelOrder.amount`).
class ForwardFeeQuote {
  const ForwardFeeQuote({
    required this.billableKg,
    required this.fee,
    required this.vat,
  });

  final int billableKg;
  final int fee;
  final int vat;

  int get total => fee + vat;

  factory ForwardFeeQuote.fromWeight(double weightKg) {
    final billableKg = weightKg <= 1 ? 1 : weightKg.ceil();
    final fee = 13000 + (billableKg - 1) * 2000;
    final vat = (fee * 0.07).round();
    return ForwardFeeQuote(billableKg: billableKg, fee: fee, vat: vat);
  }
}

class PaymentRepository {
  PaymentRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<ParcelOrder> createPickupOrder({
    required String parcelId,
    int amount = 0,
  }) async {
    final response = await _dio.post<dynamic>(
      '/parcels/$parcelId/pickup',
      data: {'amount': amount},
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
