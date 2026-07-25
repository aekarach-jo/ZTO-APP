import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../parcel_status/data/parcel_status_repository.dart';
import '../../../parcel_status/presentation/screens/parcel_status_screen.dart';
import '../../data/profile_repository.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(parcelStatusProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final loadingProfile = profileAsync.isLoading && profile == null;

    // Never show a fake name: use the real display name, fall back to the phone
    // number, and only show a neutral prompt when the account genuinely has no
    // name — instead of the old hard-coded "Somchai Rakdee" placeholder.
    final String? resolvedName =
        (profile != null && profile.displayName.isNotEmpty)
        ? profile.displayName
        : (profile != null && profile.phone.isNotEmpty ? profile.phone : null);
    final String nameText = loadingProfile
        ? '…'
        : (resolvedName ?? 'profile_name_placeholder'.tr());
    final String emailText = loadingProfile
        ? '…'
        : (profile?.email.isNotEmpty == true
              ? profile!.email
              : 'profile_email_placeholder'.tr());

    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(userProfileProvider);
        return ref.refresh(parcelStatusProvider.future);
      },
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
            // Overlay the edit button in the corner (Stack) so it does not add
            // vertical height to the header.
            child: Stack(
              children: [
                // Force full width so the avatar/name center across the whole
                // header — a non-positioned Stack child otherwise shrinks to its
                // widest child and pins top-start, breaking the centering.
                SizedBox(
                  width: double.infinity,
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
                        clipBehavior: Clip.antiAlias,
                        child: (profile != null && profile.hasProfileImage)
                            ? Image.network(
                                AppEnv.resolveMediaUrl(profile.profileImage),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.person, size: 56),
                              )
                            : const Icon(Icons.person, size: 56),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        nameText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        emailText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    key: const ValueKey('profile-edit-button'),
                    tooltip: 'profile_edit_title'.tr(),
                    onPressed: () => context.push(EditProfileScreen.routePath),
                    icon: const Icon(Icons.edit, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          statusAsync.when(
            // Show the spinner while refetching (e.g. after a branch switch)
            // instead of holding the previous branch's data on screen.
            skipLoadingOnRefresh: false,
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
  static const String loadError = 'profile_load_error';
  static const String retry = 'common_retry';
}
