import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/refresh/in_place_refresh.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/lak_currency.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/presentation/screens/order_history_screen.dart';
import '../../application/parcel_status_tab_provider.dart';
import '../../data/parcel_status_repository.dart';

class ParcelStatusScreen extends ConsumerStatefulWidget {
  const ParcelStatusScreen({super.key});

  static const String routePath = '/parcels/status';

  @override
  ConsumerState<ParcelStatusScreen> createState() => _ParcelStatusScreenState();
}

class _ParcelStatusScreenState extends ConsumerState<ParcelStatusScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('status_title'.tr())),
      body: SafeArea(
        child: RefreshIndicator(
          // Pull-to-refresh reloads whichever tab is on screen, so dragging on
          // the orders tab refetches the orders rather than the parcel page.
          onRefresh: () =>
              refreshParcelStatusTab(ref, ref.read(parcelStatusTabProvider)),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
            children: const [ParcelStatusSection()],
          ),
        ),
      ),
    );
  }
}

/// Shared status summary and parcel cards used by both the status route and
/// the profile tab. Keeping this in one widget ensures both surfaces render
/// the same API model and parcel name.
class ParcelStatusSection extends ConsumerStatefulWidget {
  const ParcelStatusSection({
    super.key,
    this.summaryKeyPrefix = 'parcel-status-count',
  });

  final String summaryKeyPrefix;

  @override
  ConsumerState<ParcelStatusSection> createState() =>
      _ParcelStatusSectionState();
}

class _ParcelStatusSectionState extends ConsumerState<ParcelStatusSection> {
  static const List<ParcelStatusTab> _parcelTabs = [
    ParcelStatusTab.inProgress,
    ParcelStatusTab.selfPickup,
    ParcelStatusTab.forwarded,
  ];

  /// Every tap refetches the tab it selects — including a tap on the tab that
  /// is already active — so the cards double as a refresh control.
  void _selectTab(ParcelStatusTab tab) {
    ref.read(parcelStatusTabProvider.notifier).state = tab;
    refreshParcelStatusTab(ref, tab);
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(parcelStatusTabProvider);
    final statusAsync = ref.watch(parcelStatusProvider);
    final page = statusAsync.valueOrNull;
    final inPlaceRefresh = ref.watch(isRefreshingInPlaceProvider);

    // Nothing to draw the cards from yet, or a reload that swaps in a different
    // data set (a branch switch): blank the whole section rather than leave the
    // previous branch's counts sitting there.
    if (page == null || (statusAsync.isLoading && !inPlaceRefresh)) {
      if (statusAsync.hasError && !statusAsync.isLoading) {
        return _SectionRetry(
          retryKey: const ValueKey('parcel-status-retry'),
          onRetry: () => ref.invalidate(parcelStatusProvider),
        );
      }
      return const _SectionLoader();
    }

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < _parcelTabs.length; i++) ...[
              Expanded(
                child: _CountCard(
                  cardKey: ValueKey(
                    '${widget.summaryKeyPrefix}-${_parcelTabs[i].name}',
                  ),
                  category: _parcelTabs[i].category!,
                  count: page.counts.forCategory(_parcelTabs[i].category!),
                  selected: tab == _parcelTabs[i],
                  onTap: () => _selectTab(_parcelTabs[i]),
                ),
              ),
              SizedBox(width: 8.w),
            ],
            // 4th card: opens the order history inline (no separate page).
            Expanded(
              child: _OrderHistoryCard(
                cardKey: ValueKey('${widget.summaryKeyPrefix}-orders'),
                selected: tab == ParcelStatusTab.orders,
                onTap: () => _selectTab(ParcelStatusTab.orders),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        ..._buildContent(tab, statusAsync, page),
      ],
    );
  }

  List<Widget> _buildContent(
    ParcelStatusTab tab,
    AsyncValue<ParcelStatusPage> statusAsync,
    ParcelStatusPage page,
  ) {
    if (tab == ParcelStatusTab.orders) {
      return _buildOrdersContent();
    }
    // A tab tap or pull-to-refresh is refetching the parcel page: swap only the
    // list for a spinner and leave the cards above it in place.
    if (statusAsync.isLoading) {
      return const [_SectionLoader()];
    }
    if (statusAsync.hasError) {
      return [
        _SectionRetry(
          retryKey: const ValueKey('parcel-status-retry'),
          onRetry: () => ref.invalidate(parcelStatusProvider),
        ),
      ];
    }

    final items = page.forCategory(tab.category!);
    if (items.isEmpty) {
      return [_EmptyState(message: 'status_empty'.tr())];
    }
    return [
      for (var i = 0; i < items.length; i++) ...[
        _StatusParcelCard(
          key: ValueKey('parcel-status-item-${items[i].id}'),
          item: items[i],
        ),
        if (i != items.length - 1) SizedBox(height: 12.h),
      ],
    ];
  }

  List<Widget> _buildOrdersContent() {
    final ordersAsync = ref.watch(ordersProvider);
    return ordersAsync.when(
      // Selecting this tab refetches the orders; show that as loading instead
      // of leaving the previous list on screen until the response lands.
      skipLoadingOnRefresh: false,
      data: (orders) {
        if (orders.isEmpty) {
          return [_EmptyState(message: 'order_history_empty'.tr())];
        }
        return [
          for (var i = 0; i < orders.length; i++) ...[
            OrderHistoryCard(
              key: ValueKey('profile-order-item-${orders[i].id}'),
              order: orders[i],
            ),
            if (i != orders.length - 1) SizedBox(height: 12.h),
          ],
        ];
      },
      loading: () => const [_SectionLoader()],
      error: (error, stackTrace) => [
        _SectionRetry(
          retryKey: const ValueKey('profile-orders-retry'),
          onRetry: () => ref.invalidate(ordersProvider),
        ),
      ],
    );
  }
}

class _SectionLoader extends StatelessWidget {
  const _SectionLoader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28.h),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SectionRetry extends StatelessWidget {
  const _SectionRetry({required this.retryKey, required this.onRetry});

  final Key retryKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 18.h),
      child: Center(
        child: TextButton(
          key: retryKey,
          onPressed: onRetry,
          child: Text('common_retry'.tr()),
        ),
      ),
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

/// The 4th summary card. Styled like [_CountCard] but shows an icon + label
/// and, when tapped, reveals the order history inline.
class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({
    required this.cardKey,
    required this.selected,
    required this.onTap,
  });

  final Key cardKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppTheme.brandBlueDark;

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
              Icon(Icons.receipt_long_outlined, color: accent, size: 22.sp),
              SizedBox(height: 4.h),
              SizedBox(
                height: 30.h,
                child: Center(
                  child: Text(
                    'order_history_title'.tr(),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
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
