import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/staff_parcel_repository.dart';

class StaffScanPayScreen extends ConsumerStatefulWidget {
  const StaffScanPayScreen({super.key});

  @override
  ConsumerState<StaffScanPayScreen> createState() => _StaffScanPayScreenState();
}

class _StaffScanPayScreenState extends ConsumerState<StaffScanPayScreen> {
  bool _isCameraGranted = false;
  bool _isScanningImage = false;
  String? _submittingParcelId;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readyItemsAsync = ref.watch(handoverReadyParcelsProvider);

    return Container(
      key: const ValueKey('staff-scan-pay-screen'),
      color: const Color(0xFFF1F3F7),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
        children: [
          Text(
            'scan_pay_title'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF111111),
              fontSize: 42.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'scan_pay_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF778394),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 14.h),
          _ScannerCard(
            isCameraGranted: _isCameraGranted,
            onRequestPermission: _requestCameraPermission,
            onScanImage: _scanFromImage,
            isScanningImage: _isScanningImage,
          ),
          SizedBox(height: 14.h),
          readyItemsAsync.when(
            data: (items) => _ReadyListCard(
              items: items,
              submittingParcelId: _submittingParcelId,
              onConfirm: _confirmHandover,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _LoadErrorCard(
              onRetry: () => ref.invalidate(handoverReadyParcelsProvider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestCameraPermission() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isCameraGranted = true;
    });
  }

  Future<void> _scanFromImage() async {
    setState(() {
      _isScanningImage = true;
    });

    try {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('action_not_implemented'.tr())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanningImage = false;
        });
      }
    }
  }

  Future<void> _confirmHandover(StaffParcelItem item) async {
    setState(() {
      _submittingParcelId = item.id;
    });

    try {
      await ref.read(staffParcelRepositoryProvider).confirmHandover(item.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('staff_scan_pay_handover_confirmed'.tr(args: [item.trackNo])),
        ),
      );
      ref.invalidate(handoverReadyParcelsProvider);
      ref.invalidate(staffParcelsProvider);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('staff_scan_pay_confirm_failed'.tr())));
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _submittingParcelId = null;
      });
    }
  }
}

class _ScannerCard extends StatelessWidget {
  const _ScannerCard({
    required this.isCameraGranted,
    required this.onRequestPermission,
    required this.onScanImage,
    required this.isScanningImage,
  });

  final bool isCameraGranted;
  final Future<void> Function() onRequestPermission;
  final Future<void> Function() onScanImage;
  final bool isScanningImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: const Color(0xFFE2E8F1)),
      ),
      child: Container(
        height: 362.h,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(28.r),
        ),
        child: Stack(
          children: [
            if (isCameraGranted)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28.r),
                  child: Container(
                    color: const Color(0xFF1E1E1E),
                    alignment: Alignment.center,
                    child: Text(
                      'action_not_implemented'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 14.h,
              left: 20.w,
              child: Text(
                'scan_pay_live_scanner'.tr(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Center(
              child: Container(
                width: 234.w,
                height: 255.h,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE9650E), width: 3),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: isCameraGranted
                    ? const SizedBox.shrink()
                    : Container(
                        margin: EdgeInsets.fromLTRB(12.w, 36.h, 12.w, 36.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 16.h,
                        ),
                        color: Colors.white,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                key: const ValueKey(
                                  'scan-pay-request-permission',
                                ),
                                onPressed: onRequestPermission,
                                child: Text(
                                  'scan_pay_camera_permission'.tr(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF1E1E1E),
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              TextButton(
                                key: const ValueKey('scan-pay-scan-image'),
                                onPressed: isScanningImage ? null : onScanImage,
                                child: Text(
                                  isScanningImage
                                      ? 'scan_pay_scanning_image'.tr()
                                      : 'scan_pay_scan_image'.tr(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF1E1E1E),
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              left: 28.w,
              right: 28.w,
              bottom: 86.h,
              child: Container(
                height: 3.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9650E).withValues(alpha: 0.85),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE9650E).withValues(alpha: 0.6),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyListCard extends StatelessWidget {
  const _ReadyListCard({
    required this.items,
    required this.submittingParcelId,
    required this.onConfirm,
  });

  final List<StaffParcelItem> items;
  final String? submittingParcelId;
  final ValueChanged<StaffParcelItem> onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: const Color(0xFFE2E8F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'scan_pay_ready_list'.tr(args: ['${items.length}']),
            style: TextStyle(
              color: const Color(0xFF8A98AB),
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (items.isEmpty) ...[
            SizedBox(height: 44.h),
            Center(
              child: Text('🛬', style: TextStyle(fontSize: 34.sp)),
            ),
            SizedBox(height: 8.h),
            Center(
              child: Text(
                'scan_pay_empty_message'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFC4CDDA),
                  fontSize: 21.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: 36.h),
          ] else ...[
            SizedBox(height: 12.h),
            for (var i = 0; i < items.length; i++) ...[
              _ReadyHandoverTile(
                item: items[i],
                isSubmitting: submittingParcelId == items[i].id,
                onConfirm: () => onConfirm(items[i]),
              ),
              if (i != items.length - 1) SizedBox(height: 8.h),
            ],
          ],
        ],
      ),
    );
  }
}

class _ReadyHandoverTile extends StatelessWidget {
  const _ReadyHandoverTile({
    required this.item,
    required this.isSubmitting,
    required this.onConfirm,
  });

  final StaffParcelItem item;
  final bool isSubmitting;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('scan-pay-item-${item.trackNo}'),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE2E8F1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: const BoxDecoration(
              color: Color(0xFFE9F3FF),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('📦', style: TextStyle(fontSize: 16.sp)),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF111111),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  item.trackNo,
                  style: TextStyle(
                    color: const Color(0xFF8A98AB),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.dateLabel,
            style: TextStyle(
              color: const Color(0xFF9EACBE),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
            ],
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5EE8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                isSubmitting ? 'common_loading'.tr() : 'staff_scan_pay_confirm_handover'.tr(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F1)),
      ),
      child: Column(
        children: [
          Text(
            'staff_scan_pay_load_error'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF6E7D92),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          TextButton(onPressed: onRetry, child: Text('common_retry'.tr())),
        ],
      ),
    );
  }
}
