import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/lak_currency.dart';
import '../../data/order_repository.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  static const String routePath = '/orders';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: Text('order_history_title'.tr())),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(ordersProvider.future),
          child: ordersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16.w),
                  children: [
                    SizedBox(height: 200.h),
                    Center(
                      child: Text(
                        'order_history_empty'.tr(),
                        style: TextStyle(
                          color: const Color(0xFF768499),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
                itemCount: orders.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) => OrderHistoryCard(
                  key: ValueKey('order-history-item-${orders[index].id}'),
                  order: orders[index],
                ),
              );
            },
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 240),
                Center(child: CircularProgressIndicator()),
              ],
            ),
            error: (error, stackTrace) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 220),
                Center(
                  child: TextButton(
                    key: const ValueKey('order-history-retry'),
                    onPressed: () => ref.invalidate(ordersProvider),
                    child: Text('common_retry'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single order row, reused by the order-history screen and the inline
/// order-history view on the profile/status section.
class OrderHistoryCard extends StatelessWidget {
  const OrderHistoryCard({super.key, required this.order});

  final OrderSummary order;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  (order.isForward
                          ? 'order_history_type_forward'
                          : 'order_history_type_pickup')
                      .tr(),
                  style: TextStyle(
                    color: const Color(0xFF161616),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusBadge(status: order.paymentStatus),
            ],
          ),
          if (order.recipientName != null &&
              order.recipientName!.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              order.recipientName!,
              style: TextStyle(
                color: const Color(0xFF8A99AD),
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (order.billNo != null || order.paymentNo != null) ...[
            SizedBox(height: 10.h),
            if (order.billNo != null)
              _ReceiptRefRow(
                label: 'pickup_payment_receipt_bill_no'.tr(),
                value: order.billNo!,
              ),
            if (order.paymentNo != null) ...[
              SizedBox(height: 4.h),
              _ReceiptRefRow(
                label: 'pickup_payment_receipt_payment_no'.tr(),
                value: order.paymentNo!,
              ),
            ],
          ],
          SizedBox(height: 12.h),
          Divider(height: 1, color: const Color(0xFFE8EEF6)),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  _dateLabel(order),
                  style: TextStyle(
                    color: const Color(0xFF9AA7B8),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatLak(order.amount),
                style: TextStyle(
                  color: AppTheme.brandBlueDark,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dateLabel(OrderSummary order) {
    final date = order.paidAt ?? order.createdAt;
    if (date == null) {
      return '';
    }
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// Label/value pair for the receipt numbers on an order card.
class _ReceiptRefRow extends StatelessWidget {
  const _ReceiptRefRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF9AA7B8),
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xFF6E7D92),
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final OrderPaymentState status;

  @override
  Widget build(BuildContext context) {
    final style = _badgeStyle(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: style.foregroundColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        style.labelKey.tr(),
        style: TextStyle(
          color: style.foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 12.sp,
        ),
      ),
    );
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.labelKey,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String labelKey;
  final Color backgroundColor;
  final Color foregroundColor;
}

_BadgeStyle _badgeStyle(OrderPaymentState status) {
  switch (status) {
    case OrderPaymentState.paid:
      return const _BadgeStyle(
        labelKey: 'order_status_paid',
        backgroundColor: Color(0xFFDDF6E7),
        foregroundColor: Color(0xFF198754),
      );
    case OrderPaymentState.failed:
      return const _BadgeStyle(
        labelKey: 'order_status_failed',
        backgroundColor: Color(0xFFFDE5E1),
        foregroundColor: Color(0xFFB14A39),
      );
    case OrderPaymentState.pending:
      return const _BadgeStyle(
        labelKey: 'order_status_pending',
        backgroundColor: Color(0xFFFDF0A6),
        foregroundColor: Color(0xFF8D7000),
      );
  }
}
