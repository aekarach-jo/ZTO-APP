import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/lak_currency.dart';
import '../../data/payment_repository.dart';

/// A parcel to pay pickup service fee for. The pickup order is created on the
/// backend when the user confirms payment.
class PickupPaymentParcel {
  const PickupPaymentParcel({
    required this.parcelId,
    required this.title,
    required this.amount,
  });

  final String parcelId;
  final String title;
  final int amount;
}

/// Arguments passed to [ParcelPaymentScreen] via GoRouter `extra`.
///
/// Supports two flows:
/// - [ParcelPaymentArgs.pickup]: pickup orders are created per parcel when the
///   user taps pay.
/// - [ParcelPaymentArgs.forOrder]: the order (e.g. forward) already exists and
///   only needs to be paid.
class ParcelPaymentArgs {
  const ParcelPaymentArgs.pickup({required this.parcels})
    : existingOrder = null,
      itemName = null;

  const ParcelPaymentArgs.forOrder({required ParcelOrder order, this.itemName})
    : existingOrder = order,
      parcels = const [];

  final List<PickupPaymentParcel> parcels;
  final ParcelOrder? existingOrder;
  final String? itemName;
}

class ParcelPaymentScreen extends ConsumerStatefulWidget {
  const ParcelPaymentScreen({super.key, required this.args});

  static const String routePath = '/parcels/payment';

  final ParcelPaymentArgs args;

  @override
  ConsumerState<ParcelPaymentScreen> createState() =>
      _ParcelPaymentScreenState();
}

enum _PaymentPhase { review, qr, success }

/// One line in the payment summary (a single parcel). Amounts shown before the
/// order is created are previews; the charged total comes from the order.
class _PaymentLine {
  const _PaymentLine({required this.title, required this.amount});

  final String title;
  final int amount;
}

class _ParcelPaymentScreenState extends ConsumerState<ParcelPaymentScreen> {
  static const Duration _pollInterval = Duration(seconds: 3);
  static const Duration _pollTimeout = Duration(minutes: 5);

  /// Summary lines rendered in the review card and QR header.
  late final List<_PaymentLine> _lines;

  /// Laravel parcel ids to bundle into a single pickup order. Empty when an
  /// order already exists (e.g. forward).
  late final List<String> _pickupParcelIds;

  /// Single order for the whole payment. Resolved from the existing order or
  /// created once from [_pickupParcelIds].
  String? _orderId;
  late int _totalAmount;

  _PaymentPhase _phase = _PaymentPhase.review;
  String _selectedMethodId = 'bcel';
  bool _isProcessing = false;
  bool _isTimedOut = false;

  /// Polling runs from the moment the QR is shown; this only controls whether
  /// the "waiting for confirmation" indicator is revealed. It flips to true
  /// when the user taps the "I've paid" button.
  bool _paymentConfirmTapped = false;
  String? _qrString;
  Timer? _pollTimer;
  DateTime? _pollStartedAt;

  @override
  void initState() {
    super.initState();
    final existingOrder = widget.args.existingOrder;
    if (existingOrder != null) {
      _orderId = existingOrder.id;
      _totalAmount = existingOrder.amount;
      _pickupParcelIds = const [];
      _lines = [
        _PaymentLine(
          title: widget.args.itemName ??
              existingOrder.recipientName ??
              existingOrder.id,
          amount: existingOrder.amount,
        ),
      ];
    } else {
      _pickupParcelIds = [
        for (final parcel in widget.args.parcels) parcel.parcelId,
      ];
      _lines = [
        for (final parcel in widget.args.parcels)
          _PaymentLine(title: parcel.title, amount: parcel.amount),
      ];
      _totalAmount = _lines.fold(0, (total, line) => total + line.amount);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String get _qrTitle => _lines.length == 1
      ? _lines.first.title
      : 'pickup_payment_qr_items'.tr(args: ['${_lines.length}']);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('pickup_payment_title'.tr())),
      body: SafeArea(
        bottom: false,
        child: switch (_phase) {
          _PaymentPhase.review => _buildReview(),
          _PaymentPhase.qr => _buildQr(),
          _PaymentPhase.success => _buildSuccess(),
        },
      ),
      bottomNavigationBar: switch (_phase) {
        _PaymentPhase.review => _PayBar(
          buttonKey: const ValueKey('pickup-payment-pay-button'),
          label: 'pickup_payment_pay_button'.tr(args: [formatLak(_totalAmount)]),
          isProcessing: _isProcessing,
          onPressed: _handlePay,
        ),
        _PaymentPhase.qr => null,
        _PaymentPhase.success => _PayBar(
          buttonKey: const ValueKey('pickup-payment-done-button'),
          label: 'pickup_payment_done_button'.tr(),
          isProcessing: false,
          onPressed: () => context.pop(true),
        ),
      },
    );
  }

  Widget _buildReview() {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
      children: [
        _SummaryCard(lines: _lines, totalAmount: _totalAmount),
        SizedBox(height: 18.h),
        Text(
          'pickup_payment_method_label'.tr(),
          style: TextStyle(
            color: const Color(0xFF8B98AA),
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10.h),
        _PaymentMethodCard(
          key: const ValueKey('pickup-payment-method-bcel'),
          titleKey: 'pickup_payment_bcel_title',
          subtitleKey: 'pickup_payment_bcel_subtitle',
          badgeText: 'BCEL',
          badgeColor: const Color(0xFFE71F30),
          selected: _selectedMethodId == 'bcel',
          onTap: () {
            setState(() {
              _selectedMethodId = 'bcel';
            });
          },
        ),
      ],
    );
  }

  Widget _buildQr() {
    final qrString = _qrString;
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
      children: [
        Text(
          _qrTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF101010),
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          formatLak(_totalAmount),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.brandBlueDark,
            fontSize: 28.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F9FC),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: const Color(0xFFE2E7EF)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: const Color(0xFFE71F30),
                    width: 1.4,
                  ),
                ),
                child: qrString == null
                    ? SizedBox(
                        width: 220.w,
                        height: 220.w,
                        child: const Center(child: CircularProgressIndicator()),
                      )
                    : QrImageView(
                        key: const ValueKey('pickup-payment-qr-image'),
                        data: qrString,
                        version: QrVersions.auto,
                        size: 220.w,
                      ),
              ),
              SizedBox(height: 14.h),
              Text(
                'pickup_payment_bcel_qr_caption'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF6E7D92),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18.h),
        if (_isTimedOut) ...[
          Text(
            'pickup_payment_qr_expired'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFB14A39),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.h),
          Center(
            child: TextButton(
              key: const ValueKey('pickup-payment-new-qr-button'),
              onPressed: _isProcessing ? null : _startPayment,
              child: Text('pickup_payment_new_qr_button'.tr()),
            ),
          ),
        ] else if (!_paymentConfirmTapped)
          SizedBox(
            height: 52.h,
            child: ElevatedButton(
              key: const ValueKey('pickup-payment-confirm-paid-button'),
              onPressed: _handleConfirmPaid,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                textStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text('pickup_payment_confirm_paid_button'.tr()),
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16.w,
                height: 16.w,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10.w),
              Flexible(
                child: Text(
                  'pickup_payment_waiting'.tr(),
                  style: TextStyle(
                    color: const Color(0xFF6E7D92),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          Container(
            width: 86.w,
            height: 86.w,
            decoration: const BoxDecoration(
              color: Color(0xFFDDF6E7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: const Color(0xFF198754),
              size: 48.sp,
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            'pickup_payment_success_title'.tr(),
            style: TextStyle(
              color: const Color(0xFF101010),
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'pickup_payment_success_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF6E7D92),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            formatLak(_totalAmount),
            style: TextStyle(
              color: AppTheme.brandBlueDark,
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePay() async {
    if (_orderId == null && _pickupParcelIds.isEmpty) {
      return;
    }
    await _startPayment();
  }

  /// Creates the pickup order once (if needed) then initiates onepay and shows
  /// the QR. Re-callable to regenerate the QR after a timeout without creating
  /// another order.
  Future<void> _startPayment() async {
    final repository = ref.read(paymentRepositoryProvider);

    setState(() {
      _isProcessing = true;
      _isTimedOut = false;
    });
    _pollTimer?.cancel();

    try {
      if (_orderId == null) {
        final order = await repository.createPickupOrder(
          parcelIds: _pickupParcelIds,
        );
        _orderId = order.id;
        if (order.amount > 0) {
          _totalAmount = order.amount;
        }
      }

      final initiation = await repository.initiatePayment(
        orderId: _orderId!,
        method: PaymentMethods.onepay,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
        _phase = _PaymentPhase.qr;
        _qrString = initiation.qrString;
        _paymentConfirmTapped = false;
      });
      _startPolling(_orderId!);
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.response?.statusCode == 409) {
        // Order already paid — treat as success.
        setState(() {
          _isProcessing = false;
        });
        _markPaid();
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      _showError();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      _showError();
    }
  }

  void _startPolling(String orderId) {
    _pollStartedAt = DateTime.now();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (timer) async {
      final startedAt = _pollStartedAt;
      if (startedAt != null &&
          DateTime.now().difference(startedAt) > _pollTimeout) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isTimedOut = true;
          });
        }
        return;
      }

      try {
        final status = await ref
            .read(paymentRepositoryProvider)
            .fetchPaymentStatus(orderId);
        if (!mounted || !timer.isActive) {
          return;
        }
        if (status.isPaid) {
          timer.cancel();
          _markPaid();
        }
      } catch (_) {
        // Transient polling errors are ignored; the next tick retries.
      }
    });
  }

  /// Reveals the waiting indicator and does an immediate status check so a
  /// user who already paid doesn't have to wait for the next 3s poll tick.
  Future<void> _handleConfirmPaid() async {
    setState(() {
      _paymentConfirmTapped = true;
    });

    final orderId = _orderId;
    if (orderId == null) {
      return;
    }
    try {
      final status = await ref
          .read(paymentRepositoryProvider)
          .fetchPaymentStatus(orderId);
      if (!mounted) {
        return;
      }
      if (status.isPaid) {
        _pollTimer?.cancel();
        _markPaid();
      }
    } catch (_) {
      // Ignore; the periodic poll will retry on its next tick.
    }
  }

  void _markPaid() {
    _pollTimer?.cancel();
    setState(() {
      _phase = _PaymentPhase.success;
      _qrString = null;
    });
  }

  void _showError() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('pickup_payment_error'.tr())));
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.lines, required this.totalAmount});

  final List<_PaymentLine> lines;
  final int totalAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E7EF)),
      ),
      child: Column(
        children: [
          for (final line in lines) ...[
            _SummaryRow(
              label: 'pickup_payment_item_label'.tr(),
              value: line.title,
              trailing: formatLak(line.amount),
            ),
            SizedBox(height: 12.h),
          ],
          Divider(height: 1, color: const Color(0xFFE8EEF6)),
          SizedBox(height: 12.h),
          _SummaryRow(
            label: 'pickup_payment_total_label'.tr(),
            value: formatLak(totalAmount),
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.trailing,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? trailing;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF7E8EA3),
            fontSize: highlight ? 15.sp : 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: highlight
                  ? AppTheme.brandBlueDark
                  : const Color(0xFF161616),
              fontSize: highlight ? 20.sp : 15.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: 12.w),
          Text(
            trailing!,
            style: TextStyle(
              color: const Color(0xFF161616),
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    super.key,
    required this.titleKey,
    required this.subtitleKey,
    required this.badgeText,
    required this.badgeColor,
    required this.selected,
    required this.onTap,
  });

  final String titleKey;
  final String subtitleKey;
  final String badgeText;
  final Color badgeColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: onTap,
      child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: selected ? AppTheme.softBlue : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected ? AppTheme.brandBlue : const Color(0xFFDDE4EE),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleKey.tr(),
                      style: TextStyle(
                        color: const Color(0xFF101010),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitleKey.tr(),
                      style: TextStyle(
                        color: const Color(0xFF7E8EA3),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? AppTheme.brandBlue : const Color(0xFFD3DBE7),
                size: 22.sp,
              ),
            ],
          ),
        ),
      );
  }
}

class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.buttonKey,
    required this.label,
    required this.isProcessing,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final bool isProcessing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE3E8EF))),
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
        child: SizedBox(
          height: 54.h,
          child: ElevatedButton(
            key: buttonKey,
            onPressed: isProcessing ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              textStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
            ),
            child: isProcessing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(label),
          ),
        ),
      ),
    );
  }
}
