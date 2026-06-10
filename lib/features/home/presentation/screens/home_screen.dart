import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/home_parcel_repository.dart';

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
    final query = _searchController.text.trim().toLowerCase();

    return ListView(
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
        _SearchBar(
          controller: _searchController,
          hint: 'search_parcel_or_item'.tr(),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: 14.h),
        parcelsAsync.when(
          data: (apiParcels) {
            final parcels = apiParcels.map(_ParcelItem.fromApi).toList(growable: false);
            final filteredParcels = parcels.where((item) => item.matches(query)).toList();

            if (filteredParcels.isEmpty) {
              return _EmptyState(message: 'no_parcel_found'.tr());
            }

            return Column(
              children: [
                for (var i = 0; i < filteredParcels.length; i++) ...[
                  _ParcelCard(
                    item: filteredParcels[i],
                    onDropAtPoint: () => _showNotImplementedSnack(context),
                    onCallPickup: () => _showNotImplementedSnack(context),
                  ),
                  if (i != filteredParcels.length - 1) SizedBox(height: 14.h),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _EmptyState(message: 'no_parcel_found'.tr()),
        ),
      ],
    );
  }

  void _showNotImplementedSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('action_not_implemented'.tr())),
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

class _ParcelCard extends StatelessWidget {
  const _ParcelCard({
    required this.item,
    required this.onDropAtPoint,
    required this.onCallPickup,
  });

  final _ParcelItem item;
  final VoidCallback onDropAtPoint;
  final VoidCallback onCallPickup;

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
                      item.title,
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF161616),
                      ),
                    ),
                    SizedBox(height: 4.h),
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
              const Icon(Icons.scale_outlined, size: 16, color: Color(0xFF96A3B5)),
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
          if (item.showActions) ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: onDropAtPoint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1CAB4D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        textStyle: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text('action_drop_at_service_point'.tr()),
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
                        backgroundColor: const Color(0xFFE9650E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        textStyle: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text('action_call_pickup'.tr()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
          Icon(Icons.inventory_2_outlined, color: const Color(0xFFA2AFBF), size: 24.sp),
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
    required this.title,
    required this.trackNo,
    required this.weight,
    required this.date,
    required this.statusKey,
    required this.statusBackgroundColor,
    required this.statusForegroundColor,
    this.showActions = false,
  });

  final String title;
  final String trackNo;
  final String weight;
  final String date;
  final String statusKey;
  final Color statusBackgroundColor;
  final Color statusForegroundColor;
  final bool showActions;

  factory _ParcelItem.fromApi(HomeParcel parcel) {
    final statusStyle = _statusStyle(parcel.status);
    return _ParcelItem(
      title: parcel.title,
      trackNo: parcel.trackingNo,
      weight: parcel.weightLabel,
      date: parcel.dateLabel,
      statusKey: statusStyle.statusKey,
      statusBackgroundColor: statusStyle.backgroundColor,
      statusForegroundColor: statusStyle.foregroundColor,
      showActions: statusStyle.showActions,
    );
  }

  bool matches(String query) {
    if (query.isEmpty) {
      return true;
    }
    return title.toLowerCase().contains(query) || trackNo.toLowerCase().contains(query);
  }

  static _ParcelStatusStyle _statusStyle(String status) {
    switch (status) {
      case 'ready':
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
      case 'arrived':
      case 'picked_up':
      case 'pending':
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
