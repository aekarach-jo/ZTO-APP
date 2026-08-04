import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../parcel_status/application/parcel_status_tab_provider.dart';
import '../../../parcel_status/presentation/screens/parcel_status_screen.dart';
import '../../data/profile_repository.dart';
import 'address_book_screen.dart';
import 'edit_profile_screen.dart';

enum _ProfileMenuAction { editProfile, addressBook }

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
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
      // Pull-to-refresh reloads the header plus whichever tab is on screen, so
      // dragging on the orders tab refetches the orders rather than the parcel
      // page it used to reload unconditionally.
      onRefresh: () {
        ref.invalidate(userProfileProvider);
        return refreshParcelStatusTab(ref, ref.read(parcelStatusTabProvider));
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
                      // ClipOval instead of a bordered Container: a border on a
                      // circle Container insets the child, leaving a white ring
                      // around the uploaded photo.
                      ClipOval(
                        child: SizedBox(
                          width: 106.w,
                          height: 106.w,
                          child: (profile != null && profile.hasProfileImage)
                              ? Image.network(
                                  AppEnv.resolveMediaUrl(profile.profileImage),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const ColoredBox(
                                        color: Colors.white,
                                        child: Icon(Icons.person, size: 56),
                                      ),
                                )
                              : const ColoredBox(
                                  color: Colors.white,
                                  child: Icon(Icons.person, size: 56),
                                ),
                        ),
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
                  child: PopupMenuButton<_ProfileMenuAction>(
                    key: const ValueKey('profile-menu-button'),
                    tooltip: 'profile_menu_tooltip'.tr(),
                    icon: const Icon(Icons.more_horiz, color: Colors.white),
                    onSelected: (action) {
                      switch (action) {
                        case _ProfileMenuAction.editProfile:
                          context.push(EditProfileScreen.routePath);
                        case _ProfileMenuAction.addressBook:
                          context.push(AddressBookScreen.routePath);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        key: const ValueKey('profile-menu-edit'),
                        value: _ProfileMenuAction.editProfile,
                        child: Text('profile_edit_title'.tr()),
                      ),
                      PopupMenuItem(
                        key: const ValueKey('profile-menu-address-book'),
                        value: _ProfileMenuAction.addressBook,
                        child: Text('profile_address_book_menu'.tr()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            // The section owns its own loading, error and retry states so the
            // summary cards can stay put while a tab reloads.
            child: const ParcelStatusSection(
              summaryKeyPrefix: 'profile-summary',
            ),
          ),
        ],
      ),
    );
  }
}
