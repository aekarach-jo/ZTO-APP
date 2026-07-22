import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/lak_currency.dart';
import '../../data/parcel_status_repository.dart';

class ParcelStatusScreen extends ConsumerStatefulWidget {
  const ParcelStatusScreen({super.key});

  static const String routePath = '/parcels/status';

  @override
  ConsumerState<ParcelStatusScreen> createState() => _ParcelStatusScreenState();
}

class _ParcelStatusScreenState extends ConsumerState<ParcelStatusScreen> {
  ParcelStatusCategory _selectedCategory = ParcelStatusCategory.inProgress;

  static const List<ParcelStatusCategory> _categories = [
    ParcelStatusCategory.inProgress,
    ParcelStatusCategory.selfPickup,
    ParcelStatusCategory.forwarded,
  ];

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(parcelStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text('status_title'.tr())),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(parcelStatusProvider.future),
          child: statusAsync.when(
            data: (page) => _buildContent(page),
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
                    key: const ValueKey('parcel-status-retry'),
                    onPressed: () => ref.invalidate(parcelStatusProvider),
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

  Widget _buildContent(ParcelStatusPage page) {
    final items = page.forCategory(_selectedCategory);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
      children: [
        Row(
          children: [
            for (var i = 0; i < _categories.length; i++) ...[
              Expanded(
                child: _CountCard(
                  cardKey: ValueKey(
                    'parcel-status-count-${_categories[i].name}',
                  ),
                  category: _categories[i],
                  count: page.counts.forCategory(_categories[i]),
                  selected: _selectedCategory == _categories[i],
                  onTap: () {
                    setState(() {
                      _selectedCategory = _categories[i];
                    });
                  },
                ),
              ),
              if (i != _categories.length - 1) SizedBox(width: 8.w),
            ],
          ],
        ),
        SizedBox(height: 16.h),
        if (items.isEmpty)
          _EmptyState(message: 'status_empty'.tr())
        else
          for (var i = 0; i < items.length; i++) ...[
            _StatusParcelCard(
              key: ValueKey('parcel-status-item-${items[i].id}'),
              item: items[i],
            ),
            if (i != items.length - 1) SizedBox(height: 12.h),
          ],
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.cardKey,
    required this.category,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final Key cardKey;
  final ParcelStatusCategory category;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryAccent(category);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: cardKey,
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected ? accent : const Color(0xFFE4EAF3),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: accent,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4.h),
              SizedBox(
                height: 30.h,
                child: Center(
                  child: Text(
                    _categoryLabelKey(category).tr(),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF49576A),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusParcelCard extends StatelessWidget {
  const _StatusParcelCard({super.key, required this.item});

  final ParcelStatusItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E7EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.isEmpty ? item.trackNo : item.name,
                      style: TextStyle(
                        color: const Color(0xFF161616),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      item.trackNo,
                      style: TextStyle(
                        color: const Color(0xFF9AA7B8),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.weight != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5FF),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Text(
                    '${item.weight} kg',
                    style: TextStyle(
                      color: AppTheme.brandBlueDark,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          _StepTracker(currentStep: item.step),
          if (item.order != null) ...[
            SizedBox(height: 14.h),
            Divider(height: 1, color: const Color(0xFFE8EEF6)),
            SizedBox(height: 12.h),
            _OrderSummary(order: item.order!),
          ],
        ],
      ),
    );
  }
}

class _StepTracker extends StatelessWidget {
  const _StepTracker({required this.currentStep});

  final int currentStep;

  static const List<String> _stepLabelKeys = [
    'status_step_arrived',
    'status_step_ready',
    'status_step_delivering',
    'status_step_success',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _stepLabelKeys.length; i++) ...[
          Expanded(
            child: _StepNode(
              stepNumber: i + 1,
              labelKey: _stepLabelKeys[i],
              active: (i + 1) <= currentStep,
              isFirst: i == 0,
              isLast: i == _stepLabelKeys.length - 1,
              connectorActive: (i + 1) < currentStep,
            ),
          ),
        ],
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.stepNumber,
    required this.labelKey,
    required this.active,
    required this.isFirst,
    required this.isLast,
    required this.connectorActive,
  });

  final int stepNumber;
  final String labelKey;
  final bool active;
  final bool isFirst;
  final bool isLast;
  final bool connectorActive;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppTheme.brandBlue;
    const inactiveColor = Color(0xFFD3DBE7);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 3.h,
                color: isFirst
                    ? Colors.transparent
                    : (active ? activeColor : inactiveColor),
              ),
            ),
            Container(
              width: 26.w,
              height: 26.w,
              decoration: BoxDecoration(
                color: active ? activeColor : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? activeColor : inactiveColor,
                  width: 1.6,
                ),
              ),
              alignment: Alignment.center,
              child: active
                  ? Icon(Icons.check, size: 15.sp, color: Colors.white)
                  : Text(
                      '$stepNumber',
                      style: TextStyle(
                        color: const Color(0xFF9AA7B8),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            Expanded(
              child: Container(
                height: 3.h,
                color: isLast
                    ? Colors.transparent
                    : (connectorActive ? activeColor : inactiveColor),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          labelKey.tr(),
          maxLines: 2,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? AppTheme.brandBlueDark : const Color(0xFF9AA7B8),
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});

  final ParcelStatusOrder order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                (order.type == 'forward'
                        ? 'status_order_forward'
                        : 'status_order_pickup')
                    .tr(),
                style: TextStyle(
                  color: const Color(0xFF6E7D92),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (order.amountLak != null)
              Text(
                formatLak(order.amountLak!),
                style: TextStyle(
                  color: AppTheme.brandBlueDark,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        if (order.paymentRef != null && order.paymentRef!.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Text(
            'status_order_ref'.tr(args: [order.paymentRef!]),
            style: TextStyle(
              color: const Color(0xFF9AA7B8),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E7EF)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: const Color(0xFFA2AFBF),
            size: 24.sp,
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF768499),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _categoryLabelKey(ParcelStatusCategory category) {
  switch (category) {
    case ParcelStatusCategory.inProgress:
      return 'status_tab_in_progress';
    case ParcelStatusCategory.selfPickup:
      return 'status_tab_self_pickup';
    case ParcelStatusCategory.forwarded:
      return 'status_tab_forwarded';
  }
}

Color _categoryAccent(ParcelStatusCategory category) {
  switch (category) {
    case ParcelStatusCategory.inProgress:
      return AppTheme.brandBlueDark;
    case ParcelStatusCategory.selfPickup:
      return const Color(0xFF2DA85B);
    case ParcelStatusCategory.forwarded:
      return AppTheme.brandBlue;
  }
}
