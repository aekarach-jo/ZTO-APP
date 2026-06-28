import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../home/data/home_parcel_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _selectedSummaryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final parcelsAsync = ref.watch(homeParcelsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(homeParcelsProvider.future),
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
          parcelsAsync.when(
            data: (parcels) {
              final grouped = _GroupedParcels.from(parcels);
              final summaryItems = _buildSummaryItems(grouped);
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Row(
                      children: [
                        for (var i = 0; i < summaryItems.length; i++) ...[
                          Expanded(
                            child: _SummaryCard(
                              item: summaryItems[i],
                              cardKey: ValueKey('profile-summary-$i'),
                              selected: i == _selectedSummaryIndex,
                              onTap: () {
                                setState(() {
                                  _selectedSummaryIndex = i;
                                });
                              },
                            ),
                          ),
                          if (i != summaryItems.length - 1)
                            SizedBox(width: 8.w),
                        ],
                      ],
                    ),
                  ),
                  ..._buildSelectedSection(grouped),
                ],
              );
            },
            loading: () => Padding(
              padding: EdgeInsets.only(top: 18.h),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Padding(
              padding: EdgeInsets.all(16.w),
              child: _SimpleStateCard(
                message: _ProfileTextKeys.loadError,
                actionLabel: _ProfileTextKeys.retry,
                onAction: () => ref.invalidate(homeParcelsProvider),
              ),
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

  List<_ProfileSummaryItem> _buildSummaryItems(_GroupedParcels grouped) {
    return [
      _ProfileSummaryItem(
        titleKey: _ProfileTextKeys.summaryProcessing,
        value: grouped.processing.length.toString(),
        valueColor: AppTheme.brandBlueDark,
        icon: '📦',
        iconBackgroundColor: const Color(0xFFE7F2FF),
      ),
      _ProfileSummaryItem(
        titleKey: _ProfileTextKeys.summaryReceived,
        value: grouped.received.length.toString(),
        valueColor: const Color(0xFF2DA85B),
        icon: '🛬',
        iconBackgroundColor: const Color(0xFFE2F5E8),
      ),
      _ProfileSummaryItem(
        titleKey: _ProfileTextKeys.summaryAtHome,
        value: grouped.atHome.length.toString(),
        valueColor: AppTheme.brandBlue,
        icon: '🏡',
        iconBackgroundColor: const Color(0xFFE8F3FF),
      ),
      _ProfileSummaryItem(
        titleKey: _ProfileTextKeys.summaryCompleted,
        value: grouped.completed.length.toString(),
        valueColor: AppTheme.brandBlueLight,
        icon: '✅',
        iconBackgroundColor: const Color(0xFFE7F4FF),
      ),
    ];
  }

  List<Widget> _buildSelectedSection(_GroupedParcels grouped) {
    switch (_selectedSummaryIndex) {
      case 1:
        return _buildParcelSection(
          titleKey: _ProfileTextKeys.receivedHistoryTitle,
          items: grouped.received,
          emptyMessage: _ProfileTextKeys.receivedHistoryEmpty,
        );
      case 2:
        return _buildParcelSection(
          titleKey: _ProfileTextKeys.homeDeliveryHistoryTitle,
          items: grouped.atHome,
          emptyMessage: _ProfileTextKeys.homeDeliveryEmptyMessage,
        );
      case 3:
        return _buildParcelSection(
          titleKey: _ProfileTextKeys.completedHistoryTitle,
          items: grouped.completed,
          emptyMessage: _ProfileTextKeys.completedHistoryEmpty,
        );
      case 0:
      default:
        return _buildParcelSection(
          titleKey: _ProfileTextKeys.activeParcelsTitle,
          items: grouped.processing,
          emptyMessage: _ProfileTextKeys.activeParcelsEmpty,
        );
    }
  }

  List<Widget> _buildParcelSection({
    required String titleKey,
    required List<HomeParcel> items,
    required String emptyMessage,
  }) {
    return [
      SizedBox(height: 18.h),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Text(
          titleKey.tr(),
          style: TextStyle(
            color: const Color(0xFF8190A4),
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      SizedBox(height: 10.h),
      if (items.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: _SimpleStateCard(message: emptyMessage),
        )
      else
        for (var i = 0; i < items.length; i++) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: _ParcelCard(item: items[i]),
          ),
          if (i != items.length - 1) SizedBox(height: 10.h),
        ],
    ];
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.item,
    required this.cardKey,
    required this.selected,
    required this.onTap,
  });

  final _ProfileSummaryItem item;
  final Key cardKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: cardKey,
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected ? item.valueColor : const Color(0xFFE4EAF3),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: item.iconBackgroundColor,
                  borderRadius: BorderRadius.circular(13.r),
                ),
                alignment: Alignment.center,
                child: Text(item.icon, style: TextStyle(fontSize: 20.sp)),
              ),
              SizedBox(height: 8.h),
              SizedBox(
                height: 18.h,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.titleKey.tr(),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF111111),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                item.value,
                style: TextStyle(
                  color: item.valueColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParcelCard extends StatelessWidget {
  const _ParcelCard({required this.item});

  final HomeParcel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E8F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: const Color(0xFF111111),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Text(
                  item.weightLabel,
                  style: TextStyle(
                    color: AppTheme.brandBlueDark,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            item.trackingNo,
            style: TextStyle(
              color: const Color(0xFF8A99AD),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            item.dateLabel,
            style: TextStyle(
              color: const Color(0xFF8A98AB),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

class _ProfileSummaryItem {
  const _ProfileSummaryItem({
    required this.titleKey,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.iconBackgroundColor,
  });

  final String titleKey;
  final String value;
  final Color valueColor;
  final String icon;
  final Color iconBackgroundColor;
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

class _GroupedParcels {
  const _GroupedParcels({
    required this.processing,
    required this.received,
    required this.atHome,
    required this.completed,
  });

  final List<HomeParcel> processing;
  final List<HomeParcel> received;
  final List<HomeParcel> atHome;
  final List<HomeParcel> completed;

  factory _GroupedParcels.from(List<HomeParcel> items) {
    final processing = <HomeParcel>[];
    final received = <HomeParcel>[];
    final atHome = <HomeParcel>[];
    final completed = <HomeParcel>[];

    for (final item in items) {
      final status = item.status.toLowerCase();
      if (status == 'completed' || status == 'delivered') {
        completed.add(item);
      } else if (status == 'at_home') {
        atHome.add(item);
      } else if (status == 'arrived' ||
          status == 'picked_up' ||
          status == 'received') {
        received.add(item);
      } else {
        processing.add(item);
      }
    }

    return _GroupedParcels(
      processing: processing,
      received: received,
      atHome: atHome,
      completed: completed,
    );
  }
}

class _ProfileTextKeys {
  static const String userName = 'profile_user_name';
  static const String userEmail = 'profile_user_email';
  static const String summaryProcessing = 'profile_summary_processing';
  static const String summaryReceived = 'profile_summary_received';
  static const String summaryAtHome = 'profile_summary_at_home';
  static const String summaryCompleted = 'profile_summary_completed';
  static const String activeParcelsTitle = 'profile_active_parcels_title';
  static const String receivedHistoryTitle = 'profile_received_history_title';
  static const String homeDeliveryHistoryTitle =
      'profile_home_delivery_history_title';
  static const String completedHistoryTitle = 'profile_completed_history_title';
  static const String homeDeliveryEmptyMessage =
      'profile_home_delivery_empty_message';
  static const String currentLocationTitle = 'profile_current_location_title';
  static const String currentLocationLabel = 'profile_current_location_label';
  static const String pinMapAction = 'profile_pin_map_action';
  static const String currentAddressValue = 'profile_current_address_value';
  static const String saveButton = 'profile_save_button';
  static const String savedMessage = 'profile_saved_message';
  static const String loadError = 'profile_load_error';
  static const String retry = 'common_retry';
  static const String receivedHistoryEmpty = 'profile_received_history_empty';
  static const String completedHistoryEmpty = 'profile_completed_history_empty';
  static const String activeParcelsEmpty = 'profile_active_parcels_empty';
}
