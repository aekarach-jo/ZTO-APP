import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/staff_parcel_repository.dart';

class StaffReceiveScreen extends ConsumerStatefulWidget {
  const StaffReceiveScreen({super.key});

  @override
  ConsumerState<StaffReceiveScreen> createState() => _StaffReceiveScreenState();
}

class _StaffReceiveScreenState extends ConsumerState<StaffReceiveScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(staffParcelsProvider);
    final query = _searchController.text.trim().toLowerCase();

    return RefreshIndicator(
      onRefresh: () => ref.refresh(staffParcelsProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'receive_incoming_parcels'.tr(),
                  style: TextStyle(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
              Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE9D3),
                  border: Border.all(color: const Color(0xFFF3CCA5)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      color: const Color(0xFFE6852A),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'step_scan_box'.tr(),
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFF778394),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _SearchBar(
                  controller: _searchController,
                  hint: 'search_receive_parcel'.tr(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                height: 46.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flash_on,
                      color: const Color(0xFFFFD433),
                      size: 16.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'new_tag'.tr(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          itemsAsync.when(
            data: (items) {
              final filteredItems = items
                  .where((item) => item.matches(query))
                  .toList();
              if (filteredItems.isEmpty) {
                return const _EmptyState(message: 'no_receive_found');
              }
              return _StaffParcelCard(
                item: filteredItems.first,
                isSubmitting: _isSubmitting,
                onConfirm: () => _confirmInspected(filteredItems.first.id),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _EmptyState(
              message: 'staff_receive_load_error',
              actionLabel: 'common_retry',
              onAction: () => ref.invalidate(staffParcelsProvider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmInspected(String id) async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      await ref.read(staffParcelRepositoryProvider).markInspected(id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('staff_receive_marked_inspected'.tr())),
      );
      ref.invalidate(staffParcelsProvider);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('staff_receive_update_failed'.tr())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _StaffParcelCard extends StatelessWidget {
  const _StaffParcelCard({
    required this.item,
    required this.isSubmitting,
    required this.onConfirm,
  });

  final StaffParcelItem item;
  final bool isSubmitting;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final statusStyle = staffStatusStyleOf(item.status);

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
                label: statusStyle.statusKey.tr(),
                backgroundColor: statusStyle.backgroundColor,
                foregroundColor: statusStyle.foregroundColor,
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
                item.weightLabel,
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
                item.dateLabel,
                style: TextStyle(
                  color: const Color(0xFF95A2B3),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5EE8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
                textStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.sp,
                ),
              ),
              child: Text(
                isSubmitting ? '...' : 'action_confirm_inspected'.tr(),
              ),
            ),
          ),
        ],
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
  const _EmptyState({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            Icons.fact_check_outlined,
            color: const Color(0xFFA2AFBF),
            size: 24.sp,
          ),
          SizedBox(height: 8.h),
          Text(
            message.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF768499),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 8.h),
            TextButton(onPressed: onAction, child: Text(actionLabel!.tr())),
          ],
        ],
      ),
    );
  }
}
