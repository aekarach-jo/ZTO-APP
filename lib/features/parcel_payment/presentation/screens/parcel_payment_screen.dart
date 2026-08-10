import 'dart:async';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gal/gal.dart';
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
    this.trackingNo,
  });

  final String parcelId;
  final String title;
  final int amount;

  /// Tracking number printed on the receipt.
  final String? trackingNo;
}

/// Arguments passed to [ParcelPaymentScreen] via GoRouter `extra`.
///
/// Supports three flows:
/// - [ParcelPaymentArgs.pickup]: pickup orders are created per parcel when the
///   user taps pay.
/// - [ParcelPaymentArgs.draft]: the caller creates the order itself, also only
///   when the user taps pay (forward).
/// - [ParcelPaymentArgs.forOrder]: the order already exists and only needs to
///   be paid.
class ParcelPaymentArgs {
  const ParcelPaymentArgs.pickup({required this.parcels})
    : existingOrder = null,
      itemName = null,
      shippingFee = null,
      trackingNo = null,
      createOrder = null;

  /// No order exists yet: [createOrder] runs on the pay tap. Keeping creation
  /// that late means backing out of this screen leaves nothing behind — the
  /// parcels stay in the customer's list instead of being held by an unpaid
  /// order.
  const ParcelPaymentArgs.draft({
    required this.parcels,
    required Future<ParcelOrder> Function() this.createOrder,
    this.itemName,
    this.shippingFee,
    this.trackingNo,
  }) : existingOrder = null;

  const ParcelPaymentArgs.forOrder({
    required ParcelOrder order,
    this.itemName,
    this.shippingFee,
    this.trackingNo,
    this.parcels = const [],
  }) : existingOrder = order,
       createOrder = null;

  /// Parcels covered by this payment. For pickup these are also the parcels
  /// the order is created from; for an existing order (forward) they only
  /// drive the summary lines, since the order already exists.
  final List<PickupPaymentParcel> parcels;
  final ParcelOrder? existingOrder;
  final String? itemName;

  /// Tracking number of the parcel being paid for (existing-order flows).
  final String? trackingNo;

  /// Shipping fee charged on top of the parcel rows. Before the order exists
  /// this is the app's preview; afterwards the net total comes from
  /// `order.amount`.
  final int? shippingFee;

  /// Creates the order on the pay tap ([ParcelPaymentArgs.draft]).
  final Future<ParcelOrder> Function()? createOrder;
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

/// Progress of the automatic receipt-image save on the success step.
enum _ReceiptSaveState { idle, saving, saved, failed }

/// One line in the payment summary (a single parcel). Amounts shown before the
/// order is created are previews; the charged total comes from the order.
class _PaymentLine {
  const _PaymentLine({
    required this.title,
    required this.amount,
    this.trackingNo,
  });

  final String title;
  final int amount;
  final String? trackingNo;
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

  /// Captures the rendered QR card so it can be saved to the gallery.
  final GlobalKey _qrBoundaryKey = GlobalKey();
  bool _savingQr = false;

  /// Receipt data resolved when the payment settles. [_billNo] / [_paymentNo]
  /// stay null until the backend sends them; the receipt hides those rows.
  String? _billNo;
  String? _paymentNo;
  DateTime? _paidAt;

  /// Captures the whole receipt so it can be auto-saved to the gallery.
  final GlobalKey _receiptBoundaryKey = GlobalKey();
  _ReceiptSaveState _receiptSaveState = _ReceiptSaveState.idle;

  @override
  void initState() {
    super.initState();
    final existingOrder = widget.args.existingOrder;
    if (existingOrder != null) {
      _orderId = existingOrder.id;
      final amount = existingOrder.amount;
      _totalAmount = amount;
      _pickupParcelIds = const [];
      _billNo = existingOrder.billNo;
      _lines = widget.args.parcels.isNotEmpty
          ? [
              for (final parcel in widget.args.parcels)
                _PaymentLine(
                  title: parcel.title,
                  amount: parcel.amount,
                  trackingNo: parcel.trackingNo,
                ),
            ]
          : [
              _PaymentLine(
                title:
                    widget.args.itemName ??
                    existingOrder.recipientName ??
                    existingOrder.id,
                amount: amount,
                trackingNo: widget.args.trackingNo,
              ),
            ];
    } else {
      // A draft brings its own creator, so the parcel ids are only summary data.
      _pickupParcelIds = widget.args.createOrder != null
          ? const []
          : [for (final parcel in widget.args.parcels) parcel.parcelId];
      _lines = [
        for (final parcel in widget.args.parcels)
          _PaymentLine(
            title: parcel.title,
            amount: parcel.amount,
            trackingNo: parcel.trackingNo,
          ),
      ];
      _totalAmount =
          _lines.fold(0, (total, line) => total + line.amount) +
          (widget.args.shippingFee ?? 0);
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
          label: 'pickup_payment_pay_button'.tr(
            args: [formatLak(_totalAmount)],
          ),
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
        _SummaryCard(
          lines: _lines,
          shippingFee: widget.args.shippingFee,
          totalAmount: _totalAmount,
        ),
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
              RepaintBoundary(
                key: _qrBoundaryKey,
                child: Container(
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
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : QrImageView(
                          key: const ValueKey('pickup-payment-qr-image'),
                          data: qrString,
                          version: QrVersions.auto,
                          size: 220.w,
                        ),
                ),
              ),
              SizedBox(height: 14.h),
              if (qrString != null)
                OutlinedButton.icon(
                  key: const ValueKey('pickup-payment-save-qr-button'),
                  onPressed: _savingQr ? null : _saveQrImage,
                  icon: _savingQr
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.download_rounded, size: 18.sp),
                  label: Text('pickup_payment_save_qr'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.brandBlueDark,
                    side: const BorderSide(color: Color(0xFFCBD6E4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 18.w,
                      vertical: 10.h,
                    ),
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

  /// Value encoded in the receipt barcode: strictly the bill number. The order
  /// id is a Nest uuid the admin console cannot scan, so it is not a fallback —
  /// the receipt shows a placeholder instead when the bill number is missing.
  String? get _barcodeValue => _billNo;

  /// Receipt step: a scannable barcode on top of the payment details, captured
  /// as one image and auto-saved to the gallery for the admin to scan later.
  Widget _buildSuccess() {
    final paidAt = _paidAt ?? DateTime.now();
    final trackingNos = [
      for (final line in _lines)
        if (line.trackingNo != null && line.trackingNo!.isNotEmpty)
          line.trackingNo!,
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
      children: [
        RepaintBoundary(
          key: _receiptBoundaryKey,
          child: Container(
            padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 22.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: const Color(0xFFE2E7EF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReceiptBarcode(value: _barcodeValue),
                SizedBox(height: 8.h),
                Text(
                  'pickup_payment_receipt_barcode_hint'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF8B98AA),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 18.h),
                const _ReceiptDashedDivider(),
                SizedBox(height: 18.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDDF6E7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: const Color(0xFF198754),
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Flexible(
                      child: Text(
                        'pickup_payment_success_title'.tr(),
                        style: TextStyle(
                          color: const Color(0xFF101010),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  formatLak(_totalAmount),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.brandBlueDark,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 18.h),
                const _ReceiptDashedDivider(),
                SizedBox(height: 14.h),
                if (trackingNos.isNotEmpty)
                  _ReceiptRow(
                    label: 'pickup_payment_receipt_track_no'.tr(),
                    value: trackingNos.join('\n'),
                    monospace: true,
                  ),
                if (_billNo != null)
                  _ReceiptRow(
                    label: 'pickup_payment_receipt_bill_no'.tr(),
                    value: _billNo!,
                    monospace: true,
                    emphasize: true,
                  ),
                if (_paymentNo != null)
                  _ReceiptRow(
                    label: 'pickup_payment_receipt_payment_no'.tr(),
                    value: _paymentNo!,
                    monospace: true,
                  ),
                _ReceiptRow(
                  label: 'pickup_payment_receipt_method'.tr(),
                  value: 'pickup_payment_bcel_title'.tr(),
                ),
                _ReceiptRow(
                  label: 'pickup_payment_receipt_date'.tr(),
                  value: _formatReceiptDate(paidAt),
                ),
                _ReceiptRow(
                  label: 'pickup_payment_receipt_time'.tr(),
                  value: _formatReceiptTime(paidAt),
                ),
                SizedBox(height: 4.h),
                const _ReceiptDashedDivider(),
                SizedBox(height: 12.h),
                Text(
                  'pickup_payment_receipt_footer'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF8B98AA),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 14.h),
        _buildReceiptSaveStatus(),
      ],
    );
  }

  /// Feedback line for the automatic save, with a manual retry when it fails
  /// (e.g. the user denied the photo-library permission).
  Widget _buildReceiptSaveStatus() {
    return switch (_receiptSaveState) {
      _ReceiptSaveState.idle || _ReceiptSaveState.saving => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14.w,
            height: 14.w,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8.w),
          Text(
            'pickup_payment_receipt_saving'.tr(),
            style: TextStyle(
              color: const Color(0xFF6E7D92),
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      _ReceiptSaveState.saved => Row(
        key: const ValueKey('pickup-payment-receipt-saved'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: const Color(0xFF198754),
            size: 16.sp,
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              'pickup_payment_receipt_saved'.tr(),
              style: TextStyle(
                color: const Color(0xFF198754),
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      _ReceiptSaveState.failed => Column(
        children: [
          Text(
            'pickup_payment_receipt_save_failed'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFB14A39),
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          TextButton.icon(
            key: const ValueKey('pickup-payment-receipt-retry-save-button'),
            onPressed: _saveReceiptImage,
            icon: Icon(Icons.download_rounded, size: 18.sp),
            label: Text('pickup_payment_receipt_save_button'.tr()),
          ),
        ],
      ),
    };
  }

  String _formatReceiptDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  String _formatReceiptTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handlePay() async {
    if (_orderId == null &&
        _pickupParcelIds.isEmpty &&
        widget.args.createOrder == null) {
      return;
    }
    await _startPayment();
  }

  /// Creates the order once (if needed) then initiates onepay and shows the QR.
  /// Re-callable to regenerate the QR after a timeout without creating another
  /// order.
  Future<void> _startPayment() async {
    final repository = ref.read(paymentRepositoryProvider);

    setState(() {
      _isProcessing = true;
      _isTimedOut = false;
    });
    _pollTimer?.cancel();

    try {
      if (_orderId == null) {
        final createOrder = widget.args.createOrder;
        final order = createOrder != null
            ? await createOrder()
            : await repository.createPickupOrder(parcelIds: _pickupParcelIds);
        _orderId = order.id;
        _billNo = order.billNo ?? _billNo;
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
        // Receipt numbers, if the backend already issues them at this step.
        _billNo = initiation.billNo ?? _billNo;
        _paymentNo = initiation.paymentNo ?? _paymentNo;
      });
      _startPolling(_orderId!);
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.response?.statusCode == 409) {
        // Order already paid — treat as success. Pull the status once so the
        // receipt still gets its bill number and paid-at time.
        setState(() {
          _isProcessing = false;
        });
        OrderPaymentStatus? status;
        final orderId = _orderId;
        if (orderId != null) {
          try {
            status = await repository.fetchPaymentStatus(orderId);
          } catch (_) {
            // Fall back to a receipt without the backend numbers.
          }
        }
        if (!mounted) {
          return;
        }
        _markPaid(status);
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
          _markPaid(status);
          return;
        }
        // The backend expired the order (10 minutes unpaid). Nothing can
        // settle it now, so stop polling and offer a fresh QR.
        if (status.isFailed) {
          timer.cancel();
          setState(() {
            _isTimedOut = true;
          });
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
        _markPaid(status);
        return;
      }
      if (status.isFailed) {
        _pollTimer?.cancel();
        setState(() {
          _isTimedOut = true;
        });
      }
    } catch (_) {
      // Ignore; the periodic poll will retry on its next tick.
    }
  }

  /// Switches to the receipt step, filling in whatever receipt data the paid
  /// status carried, then auto-saves the receipt image once it has rendered.
  void _markPaid([OrderPaymentStatus? status]) {
    _pollTimer?.cancel();
    setState(() {
      _phase = _PaymentPhase.success;
      _qrString = null;
      _billNo = status?.billNo ?? _billNo;
      _paymentNo = status?.paymentNo ?? _paymentNo;
      _paidAt = status?.paidAt ?? DateTime.now();
      if (status?.amount != null && status!.amount! > 0) {
        _totalAmount = status.amount!;
      }
      _receiptSaveState = _ReceiptSaveState.idle;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _saveReceiptImage();
      }
    });
  }

  void _showError() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('pickup_payment_error'.tr())));
  }

  /// Captures the rendered QR card and saves it to the device gallery.
  Future<void> _saveQrImage() async {
    setState(() => _savingQr = true);
    try {
      final boundary =
          _qrBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('QR is not ready to capture yet.');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Failed to encode the QR image.');
      }

      await Gal.putImageBytes(
        byteData.buffer.asUint8List(),
        name: 'zto-qr-${_orderId ?? DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('pickup_payment_qr_saved'.tr())));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ParcelPayment] save QR failed: $error');
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('pickup_payment_qr_save_failed'.tr())),
      );
    } finally {
      if (mounted) {
        setState(() => _savingQr = false);
      }
    }
  }

  /// Captures the whole receipt card and saves it to the gallery. Runs
  /// automatically when the receipt appears; the user can retry if it fails.
  Future<void> _saveReceiptImage() async {
    if (_receiptSaveState == _ReceiptSaveState.saving) {
      return;
    }
    setState(() => _receiptSaveState = _ReceiptSaveState.saving);
    try {
      final boundary =
          _receiptBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Receipt is not ready to capture yet.');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Failed to encode the receipt image.');
      }

      await Gal.putImageBytes(
        byteData.buffer.asUint8List(),
        name: 'zto-receipt-${_barcodeValue ?? _paidAt?.millisecondsSinceEpoch}',
      );

      if (!mounted) {
        return;
      }
      setState(() => _receiptSaveState = _ReceiptSaveState.saved);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ParcelPayment] save receipt failed: $error');
      }
      if (!mounted) {
        return;
      }
      setState(() => _receiptSaveState = _ReceiptSaveState.failed);
    }
  }
}

/// Full-width Code128 barcode of the bill number, printed at the top of the
/// receipt for the admin to scan. Shows a placeholder while the backend does
/// not send a bill number yet.
class _ReceiptBarcode extends StatelessWidget {
  const _ReceiptBarcode({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final data = value;
    if (data == null || data.isEmpty) {
      return SizedBox(
        height: 96.h,
        child: Center(
          child: Text(
            'pickup_payment_receipt_barcode_missing'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF8B98AA),
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return BarcodeWidget(
      key: const ValueKey('pickup-payment-receipt-barcode'),
      barcode: Barcode.code128(),
      data: data,
      width: double.infinity,
      height: 96.h,
      drawText: true,
      color: const Color(0xFF101010),
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}

/// One label/value line of the receipt.
class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.monospace = false,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool monospace;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF7E8EA3),
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: emphasize
                    ? AppTheme.brandBlueDark
                    : const Color(0xFF101010),
                fontSize: emphasize ? 15.sp : 13.5.sp,
                fontWeight: FontWeight.w800,
                fontFamily: monospace ? 'monospace' : null,
                letterSpacing: monospace ? 0.4 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed separator that gives the card its paper-receipt look.
class _ReceiptDashedDivider extends StatelessWidget {
  const _ReceiptDashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const gapWidth = 4.0;
        final dashCount = (constraints.maxWidth / (dashWidth + gapWidth))
            .floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount < 0 ? 0 : dashCount,
            (_) => const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFD9E1EC)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.lines,
    required this.totalAmount,
    this.shippingFee,
  });

  final List<_PaymentLine> lines;
  final int totalAmount;
  final int? shippingFee;

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
          if (shippingFee != null) ...[
            _SummaryRow(
              label: 'send_payment_fee_label'.tr(),
              value: formatLak(shippingFee!),
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
              textStyle: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
              ),
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
