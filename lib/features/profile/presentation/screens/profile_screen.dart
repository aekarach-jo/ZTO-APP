import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../orders/presentation/screens/order_history_screen.dart';
import '../../../parcel_status/data/parcel_status_repository.dart';
import '../../../parcel_status/presentation/screens/parcel_status_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(parcelStatusProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(parcelStatusProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 20.h),
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 26.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.brandBlueDark, AppTheme.brandBlueLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40.r),
                bottomRight: Radius.circular(40.r),
              ),
            ),
            child: Column(
              children: [
                SizedBox(height: 12.h),
                Container(
                  width: 106.w,
                  height: 106.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    color: Colors.white,
                  ),
                  child: const Icon(Icons.person, size: 56),
                ),
                SizedBox(height: 12.h),
                Text(
                  _ProfileTextKeys.userName.tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _ProfileTextKeys.userEmail.tr(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          statusAsync.when(
            data: (page) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: ParcelStatusSection(
                page: page,
                summaryKeyPrefix: 'profile-summary',
              ),
            ),
            loading: () => Padding(
              padding: EdgeInsets.only(top: 18.h),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Padding(
              padding: EdgeInsets.all(16.w),
              child: _SimpleStateCard(
                message: _ProfileTextKeys.loadError,
                actionLabel: _ProfileTextKeys.retry,
                onAction: () => ref.invalidate(parcelStatusProvider),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: _OrderHistoryEntry(
              onTap: () => context.push(OrderHistoryScreen.routePath),
            ),
          ),
          SizedBox(height: 14.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: _LocationCard(
              onPinMap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('action_not_implemented'.tr())),
                );
              },
              onSave: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_ProfileTextKeys.savedMessage.tr())),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderHistoryEntry extends StatelessWidget {
  const _OrderHistoryEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('profile-order-history-entry'),
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: const Color(0xFFE2E8F1)),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F2FF),
                  borderRadius: BorderRadius.circular(13.r),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: AppTheme.brandBlueDark,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'order_history_title'.tr(),
                      style: TextStyle(
                        color: const Color(0xFF111111),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'order_history_subtitle'.tr(),
                      style: TextStyle(
                        color: const Color(0xFF8A99AD),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: const Color(0xFFB4C0D0),
                size: 22.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.onPinMap, required this.onSave});

  final VoidCallback onPinMap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFE2E8F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _ProfileTextKeys.currentLocationTitle.tr(),
            style: TextStyle(
              color: const Color(0xFF111111),
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  _ProfileTextKeys.currentLocationLabel.tr(),
                  style: TextStyle(
                    color: const Color(0xFF8A98AB),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('profile-pin-map-button'),
                onPressed: onPinMap,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  _ProfileTextKeys.pinMapAction.tr(),
                  style: TextStyle(
                    color: AppTheme.brandBlueDark,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Text(
              _ProfileTextKeys.currentAddressValue.tr(),
              style: TextStyle(
                color: const Color(0xFF111111),
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton(
              key: const ValueKey('profile-save-button'),
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlueDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                textStyle: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(_ProfileTextKeys.saveButton.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleStateCard extends StatelessWidget {
  const _SimpleStateCard({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E8F1)),
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

class _ProfileTextKeys {
  static const String userName = 'profile_user_name';
  static const String userEmail = 'profile_user_email';
  static const String currentLocationTitle = 'profile_current_location_title';
  static const String currentLocationLabel = 'profile_current_location_label';
  static const String pinMapAction = 'profile_pin_map_action';
  static const String currentAddressValue = 'profile_current_address_value';
  static const String saveButton = 'profile_save_button';
  static const String savedMessage = 'profile_saved_message';
  static const String loadError = 'profile_load_error';
  static const String retry = 'common_retry';
}
