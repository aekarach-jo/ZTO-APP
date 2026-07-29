import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/refresh/in_place_refresh.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/home_parcel_repository.dart';
import '../../../main_layout/application/main_layout_navigation_provider.dart';
import '../../../parcel_claim/presentation/screens/parcel_claim_screen.dart';
import '../../../parcel_payment/presentation/screens/parcel_payment_screen.dart';
import '../../../parcel_status/data/parcel_status_repository.dart';
import '../../../send/application/send_forward_prefill_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parcelsAsync = ref.watch(homeParcelsProvider);
    final inPlaceRefresh = ref.watch(isRefreshingInPlaceProvider);
    final query = _searchController.text.trim().toLowerCase();

    return RefreshIndicator(
      onRefresh: () => runInPlaceRefresh(
        ref.read(inPlaceRefreshCountProvider.notifier),
        ref.refresh(homeParcelsProvider.future),
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
        children: [
          Text(
            'your_parcels'.tr(),
            style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111111),
            ),
          ),
          SizedBox(height: 12.h),
          _ClaimEntryCard(
            onTap: () => context.push(ParcelClaimScreen.routePath),
          ),
          SizedBox(height: 12.h),
          _SearchBar(
            controller: _searchController,
            hint: 'search_parcel_or_item'.tr(),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: 14.h),
          parcelsAsync.when(
            // Reloads of the same list — pull-to-refresh, an arriving push,
            // coming back to the app — keep the parcels on screen. Anything
            // else swaps in a different list (a branch switch), so show the
            // spinner instead of holding the previous branch's parcels.
            skipLoadingOnRefresh: inPlaceRefresh,
            data: (apiParcels) {
              final parcels = apiParcels
                  .map(_ParcelItem.fromApi)
                  .toList(growable: false);
              final filteredParcels = parcels
                  .where((item) => item.matches(query))
                  .toList();
              final groupedParcels = _ParcelGroup.group(filteredParcels);

              if (filteredParcels.isEmpty) {
                return _EmptyState(message: 'no_parcel_found'.tr());
              }

              return Column(
                children: [
                  for (
                    var groupIndex = 0;
                    groupIndex < groupedParcels.length;
                    groupIndex++
                  ) ...[
                    _DateSectionHeader(
                      label: groupedParcels[groupIndex].dateLabel,
                    ),
                    SizedBox(height: 10.h),
                    _ParcelGroupCard(
                      cardKey: ValueKey('home-parcel-group-card-$groupIndex'),
                      items: groupedParcels[groupIndex].items,
                      onPickup: (items) => _openPickupPayment(context, items),
                      onForward: _startForward,
                    ),
                    if (groupIndex != groupedParcels.length - 1)
                      SizedBox(height: 18.h),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                _EmptyState(message: 'no_parcel_found'.tr()),
          ),
        ],
      ),
    );
  }

  /// Forward reuses the Send flow: pre-select the parcel then jump to the
  /// Send tab, landing directly on the recipient-details step.
  void _startForward(List<_ParcelItem> items) {
    if (items.isEmpty) {
      return;
    }
    ref.read(sendForwardPrefillProvider.notifier).state = items.first.id;
    ref.read(customerTabJumpTargetProvider.notifier).state = 1;
  }

  Future<void> _openPickupPayment(
    BuildContext context,
    List<_ParcelItem> items,
  ) async {
    if (items.isEmpty) {
      return;
    }
    final result = await context.push(
      ParcelPaymentScreen.routePath,
      extra: ParcelPaymentArgs.pickup(
        parcels: [
          for (final item in items)
            PickupPaymentParcel(
              parcelId: item.id,
              title: item.title,
              amount: item.price ?? 0,
            ),
        ],
      ),
    );
    if (result == true && mounted) {
      ref.invalidate(homeParcelsProvider);
      ref.invalidate(parcelStatusProvider);
    }
  }
}

class _ClaimEntryCard extends StatelessWidget {
  const _ClaimEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('home-claim-entry-card'),
      borderRadius: BorderRadius.circular(20.r),
      onTap: onTap,
      child: Ink(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.brandBlueDark, AppTheme.brandBlueLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: const Icon(Icons.search, color: Colors.white),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'parcel_claim_entry_title'.tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'parcel_claim_entry_subtitle'.tr(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFFA2AFBF),
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(Icons.search, color: Color(0xFFA2AFBF)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 0.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFFE0E6EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFFE0E6EF)),
        ),
      ),
    );
  }
}

class _DateSectionHeader extends StatelessWidget {
  const _DateSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF49576A),
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(child: Container(height: 1, color: const Color(0xFFE0E6EF))),
      ],
    );
  }
}

class _ParcelGroupCard extends StatelessWidget {
  const _ParcelGroupCard({
    required this.cardKey,
    required this.items,
    required this.onPickup,
    required this.onForward,
  });

  final Key cardKey;
  final List<_ParcelItem> items;
  final ValueChanged<List<_ParcelItem>> onPickup;
  final ValueChanged<List<_ParcelItem>> onForward;

  @override
  Widget build(BuildContext context) {
    final isGrouped = items.length > 1;
    final showGroupActions = items.any((item) => item.showActions);

    return Container(
      key: cardKey,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E7EF)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _ParcelListItem(
              item: items[index],
              hideTitle: true,
              showActions: !isGrouped && items[index].showActions,
              onDropAtPoint: () => onPickup(<_ParcelItem>[items[index]]),
              onCallPickup: () => onForward(<_ParcelItem>[items[index]]),
            ),
            if (index != items.length - 1) ...[
              SizedBox(height: 14.h),
              Divider(height: 1, color: const Color(0xFFE8EEF6)),
              SizedBox(height: 14.h),
            ],
          ],
          if (isGrouped && showGroupActions) ...[
            SizedBox(height: 16.h),
            Divider(height: 1, color: const Color(0xFFE8EEF6)),
            SizedBox(height: 16.h),
            _ParcelActionRow(
              onDropAtPoint: () => onPickup(items),
              onCallPickup: () => onForward(items),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParcelListItem extends StatelessWidget {
  const _ParcelListItem({
    required this.item,
    required this.hideTitle,
    required this.showActions,
    required this.onDropAtPoint,
    required this.onCallPickup,
  });

  final _ParcelItem item;
  final bool hideTitle;
  final bool showActions;
  final VoidCallback onDropAtPoint;
  final VoidCallback onCallPickup;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hideTitle) ...[
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF161616),
                      ),
                    ),
                    SizedBox(height: 4.h),
                  ],
                  Text(
                    item.trackNo,
                    style: TextStyle(
                      color: const Color(0xFF9AA7B8),
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
            _StatusChip(
              label: item.statusKey.tr(),
              backgroundColor: item.statusBackgroundColor,
              foregroundColor: item.statusForegroundColor,
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            const Icon(
              Icons.scale_outlined,
              size: 16,
              color: Color(0xFF96A3B5),
            ),
            SizedBox(width: 4.w),
            Text(
              item.weight,
              style: TextStyle(
                color: const Color(0xFF95A2B3),
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 14.w),
            const Icon(Icons.access_time, size: 16, color: Color(0xFF96A3B5)),
            SizedBox(width: 4.w),
            Text(
              item.date,
              style: TextStyle(
                color: const Color(0xFF95A2B3),
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (showActions) ...[
          SizedBox(height: 16.h),
          _ParcelActionRow(
            onDropAtPoint: onDropAtPoint,
            onCallPickup: onCallPickup,
          ),
        ],
      ],
    );
  }
}

class _ParcelActionRow extends StatelessWidget {
  const _ParcelActionRow({
    required this.onDropAtPoint,
    required this.onCallPickup,
  });

  final VoidCallback onDropAtPoint;
  final VoidCallback onCallPickup;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50.h,
            child: ElevatedButton(
              onPressed: onDropAtPoint,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlueDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                textStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(context.tr('action_pickup')),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: SizedBox(
            height: 50.h,
            child: ElevatedButton(
              onPressed: onCallPickup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                textStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(context.tr('action_forward')),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 12.sp,
        ),
      ),
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

class _ParcelItem {
  const _ParcelItem({
    required this.id,
    required this.title,
    required this.trackNo,
    required this.weight,
    required this.date,
    required this.statusKey,
    required this.statusBackgroundColor,
    required this.statusForegroundColor,
    this.price,
    this.showActions = false,
  });

  final String id;
  final String title;
  final String trackNo;
  final String weight;
  final String date;
  final String statusKey;
  final Color statusBackgroundColor;
  final Color statusForegroundColor;
  final int? price;
  final bool showActions;

  factory _ParcelItem.fromApi(HomeParcel parcel) {
    final statusStyle = _statusStyle(parcel.status);
    return _ParcelItem(
      id: parcel.id,
      title: parcel.title,
      trackNo: parcel.trackingNo,
      weight: parcel.weightLabel,
      date: parcel.dateLabel,
      statusKey: statusStyle.statusKey,
      statusBackgroundColor: statusStyle.backgroundColor,
      statusForegroundColor: statusStyle.foregroundColor,
      price: parcel.price,
      showActions: statusStyle.showActions,
    );
  }

  bool matches(String query) {
    if (query.isEmpty) {
      return true;
    }
    return title.toLowerCase().contains(query) ||
        trackNo.toLowerCase().contains(query);
  }

  static _ParcelStatusStyle _statusStyle(String status) {
    switch (status) {
      case 'ready':
        return const _ParcelStatusStyle(
          statusKey: 'status_ready',
          backgroundColor: Color(0xFFDDF6E7),
          foregroundColor: Color(0xFF198754),
          showActions: true,
        );
      case 'ready_to_ship':
        return const _ParcelStatusStyle(
          statusKey: 'status_ready_to_ship',
          backgroundColor: Color(0xFFD8E9FF),
          foregroundColor: Color(0xFF2B6FC8),
          showActions: true,
        );
      case 'in_transit':
      case 'shipping_started':
        return const _ParcelStatusStyle(
          statusKey: 'status_shipping_started',
          backgroundColor: Color(0xFFEDF1F5),
          foregroundColor: Color(0xFF6F8196),
        );
      case 'wait_import':
        return const _ParcelStatusStyle(
          statusKey: 'status_wait_import',
          backgroundColor: Color(0xFFEDF1F5),
          foregroundColor: Color(0xFF6F8196),
        );
      case 'arrived':
      case 'picked_up':
      case 'pending':
        return const _ParcelStatusStyle(
          statusKey: 'status_pending',
          backgroundColor: Color(0xFFFDF0A6),
          foregroundColor: Color(0xFF8D7000),
        );
      case 'waiting_inspection':
      default:
        return const _ParcelStatusStyle(
          statusKey: 'status_waiting_inspection',
          backgroundColor: Color(0xFFFDF0A6),
          foregroundColor: Color(0xFF8D7000),
        );
    }
  }
}

class _ParcelStatusStyle {
  const _ParcelStatusStyle({
    required this.statusKey,
    required this.backgroundColor,
    required this.foregroundColor,
    this.showActions = false,
  });

  final String statusKey;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool showActions;
}

class _ParcelGroup {
  const _ParcelGroup({required this.dateLabel, required this.items});

  final String dateLabel;
  final List<_ParcelItem> items;

  static List<_ParcelGroup> group(List<_ParcelItem> items) {
    final grouped = <_ParcelGroup>[];

    for (final item in items) {
      if (grouped.isNotEmpty && grouped.last.dateLabel == item.date) {
        grouped.last.items.add(item);
        continue;
      }

      grouped.add(
        _ParcelGroup(dateLabel: item.date, items: <_ParcelItem>[item]),
      );
    }

    return grouped;
  }
}
