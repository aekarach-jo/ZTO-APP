import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// Arguments passed to [ParcelPaymentScreen] via GoRouter `extra`.
class ParcelPaymentArgs {
  const ParcelPaymentArgs({required this.itemName, required this.amount});

  final String itemName;
  final double amount;
}

class ParcelPaymentScreen extends StatefulWidget {
  const ParcelPaymentScreen({super.key, required this.args});

  static const String routePath = '/parcels/payment';

  final ParcelPaymentArgs args;

  @override
  State<ParcelPaymentScreen> createState() => _ParcelPaymentScreenState();
}

class _ParcelPaymentScreenState extends State<ParcelPaymentScreen> {
  static const List<_PaymentMethodOption> _paymentMethods = [
    _PaymentMethodOption(
      id: 'card',
      titleKey: 'pickup_payment_card_title',
      subtitleKey: 'pickup_payment_card_subtitle',
      badgeText: 'VISA',
      badgeColor: Color(0xFF1E2A84),
    ),
    _PaymentMethodOption(
      id: 'bcel',
      titleKey: 'pickup_payment_bcel_title',
      subtitleKey: 'pickup_payment_bcel_subtitle',
      badgeText: 'BCEL',
      badgeColor: Color(0xFFE71F30),
    ),
  ];

  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  String _selectedMethodId = _paymentMethods.first.id;
  bool _isProcessing = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String get _plainAmount => widget.args.amount.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('pickup_payment_title'.tr())),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
          children: [
            _SummaryCard(
              itemName: widget.args.itemName,
              amount: _plainAmount,
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
            for (var i = 0; i < _paymentMethods.length; i++) ...[
              _PaymentMethodCard(
                key: ValueKey('pickup-payment-method-${_paymentMethods[i].id}'),
                option: _paymentMethods[i],
                selected: _selectedMethodId == _paymentMethods[i].id,
                onTap: () {
                  setState(() {
                    _selectedMethodId = _paymentMethods[i].id;
                  });
                },
              ),
              if (i != _paymentMethods.length - 1) SizedBox(height: 12.h),
            ],
            SizedBox(height: 18.h),
            if (_selectedMethodId == 'card')
              _CardDetailsForm(
                cardNumberController: _cardNumberController,
                expiryController: _expiryController,
                cvvController: _cvvController,
              )
            else
              const _BcelQrPanel(),
          ],
        ),
      ),
      bottomNavigationBar: _PayBar(
        label: 'pickup_payment_pay_button'.tr(args: [_plainAmount]),
        isProcessing: _isProcessing,
        onPressed: _handlePay,
      ),
    );
  }

  Future<void> _handlePay() async {
    setState(() {
      _isProcessing = true;
    });

    // Simulated payment gateway round-trip.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) {
      return;
    }
    setState(() {
      _isProcessing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('pickup_payment_success_message'.tr())),
    );

    if (context.canPop()) {
      context.pop();
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.itemName, required this.amount});

  final String itemName;
  final String amount;

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
          _SummaryRow(label: 'pickup_payment_item_label'.tr(), value: itemName),
          SizedBox(height: 12.h),
          Divider(height: 1, color: const Color(0xFFE8EEF6)),
          SizedBox(height: 12.h),
          _SummaryRow(
            label: 'pickup_payment_total_label'.tr(),
            value: amount,
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
    this.highlight = false,
  });

  final String label;
  final String value;
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
      ],
    );
  }
}

class _CardDetailsForm extends StatelessWidget {
  const _CardDetailsForm({
    required this.cardNumberController,
    required this.expiryController,
    required this.cvvController,
  });

  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('pickup_payment_card_number_label'.tr()),
        SizedBox(height: 8.h),
        _PaymentTextField(
          key: const ValueKey('pickup-payment-card-number-field'),
          controller: cardNumberController,
          hint: 'pickup_payment_card_number_hint'.tr(),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        SizedBox(height: 14.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('pickup_payment_expiry_label'.tr()),
                  SizedBox(height: 8.h),
                  _PaymentTextField(
                    key: const ValueKey('pickup-payment-expiry-field'),
                    controller: expiryController,
                    hint: 'pickup_payment_expiry_hint'.tr(),
                    keyboardType: TextInputType.datetime,
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('pickup_payment_cvv_label'.tr()),
                  SizedBox(height: 8.h),
                  _PaymentTextField(
                    key: const ValueKey('pickup-payment-cvv-field'),
                    controller: cvvController,
                    hint: 'pickup_payment_cvv_hint'.tr(),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: const Color(0xFF49576A),
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PaymentTextField extends StatelessWidget {
  const _PaymentTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFFA2AFBF),
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: Color(0xFFE0E6EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: Color(0xFFE0E6EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: AppTheme.brandBlue),
        ),
      ),
    );
  }
}

class _BcelQrPanel extends StatelessWidget {
  const _BcelQrPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9FC),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E7EF)),
      ),
      child: Column(
        children: [
          Container(
            width: 170.w,
            height: 170.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFE71F30), width: 1.4),
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Text(
                'pickup_payment_bcel_qr_placeholder'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFE71F30),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
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
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PaymentMethodOption option;
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
                color: option.badgeColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              alignment: Alignment.center,
              child: Text(
                option.badgeText,
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
                    option.titleKey.tr(),
                    style: TextStyle(
                      color: const Color(0xFF101010),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    option.subtitleKey.tr(),
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
    required this.label,
    required this.isProcessing,
    required this.onPressed,
  });

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
            key: const ValueKey('pickup-payment-pay-button'),
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

class _PaymentMethodOption {
  const _PaymentMethodOption({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.badgeText,
    required this.badgeColor,
  });

  final String id;
  final String titleKey;
  final String subtitleKey;
  final String badgeText;
  final Color badgeColor;
}
