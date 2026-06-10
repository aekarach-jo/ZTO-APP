import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return ListView(
      padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 20.h),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _NotiTextKeys.title.tr(),
                style: TextStyle(
                  color: const Color(0xFF111111),
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3F8),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Text(
                _NotiTextKeys.countLabel.tr(
                  args: [
                    notificationsAsync.maybeWhen(
                      data: (items) => items.length.toString(),
                      orElse: () => '0',
                    ),
                  ],
                ),
                style: TextStyle(
                  color: const Color(0xFF78879B),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        notificationsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return const _StateCard(
                icon: Icons.notifications_off_outlined,
                message: _NotiTextKeys.empty,
              );
            }

            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _NotificationCard(item: items[i]),
                  if (i != items.length - 1) SizedBox(height: 14.h),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _StateCard(
            icon: Icons.error_outline,
            message: _NotiTextKeys.loadError,
            actionLabel: _NotiTextKeys.retry,
            onAction: () => ref.invalidate(notificationsProvider),
          ),
        ),
      ],
    );
  }
}


class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFF0C694)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: const Color(0xFFDCE8FA),
              borderRadius: BorderRadius.circular(16.r),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.notifications, color: const Color(0xFF2B6FC8), size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: const Color(0xFF111111),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  item.message,
                  style: TextStyle(
                    color: const Color(0xFF6E7D92),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  item.timeLabel,
                  style: TextStyle(
                    color: const Color(0xFF8E9CAF),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (item.isUnread)
            Container(
              margin: EdgeInsets.only(top: 2.h),
              width: 10.w,
              height: 10.w,
              decoration: const BoxDecoration(
                color: Color(0xFFE9650E),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 22.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF8E9CAF), size: 26.sp),
          SizedBox(height: 8.h),
          Text(
            message.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF6E7D92),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 10.h),
            TextButton(onPressed: onAction, child: Text(actionLabel!.tr())),
          ],
        ],
      ),
    );
  }
}

class _NotiTextKeys {
  static const String title = 'notifications_title';
  static const String countLabel = 'notifications_count_label';
  static const String empty = 'notifications_empty';
  static const String loadError = 'notifications_load_error';
  static const String retry = 'common_retry';
}
