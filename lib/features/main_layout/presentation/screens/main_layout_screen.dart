import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/application/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../../core/network/network_providers.dart';
import '../../../branch/data/branch_repository.dart';
import '../../../contact/data/contact_repository.dart';
import '../../../contact/presentation/screens/contact_screen.dart';
import '../../application/main_layout_navigation_provider.dart';
import '../../../home/data/home_parcel_repository.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../notifications/data/notification_repository.dart';
import '../../../parcel_status/data/parcel_status_repository.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile/application/user_language_sync.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../send/application/send_forward_prefill_provider.dart';
import '../../../send/data/send_repository.dart';
import '../../../../shared/widgets/privacy_policy_sheet.dart';
import '../../../send/presentation/screens/send_screen.dart';
import '../../../staff/presentation/screens/staff_receive_screen.dart';
import '../../../staff/presentation/screens/staff_scan_pay_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_brand_logo.dart';

class MainLayoutScreen extends ConsumerStatefulWidget {
  const MainLayoutScreen({super.key});

  static const String routePath = '/main';

  @override
  ConsumerState<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends ConsumerState<MainLayoutScreen> {
  int _customerTabIndex = 0;
  int _staffTabIndex = 0;

  @override
  void initState() {
    super.initState();
    // First frame after sign-in: make sure the backend knows which language to
    // compose push notifications in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        reconcileUserLanguage(
          context,
          ProviderScope.containerOf(context, listen: false),
        ),
      );
    });
  }

  /// Index of the Send tab inside [_customerTabs].
  static const int _customerSendTabIndex = 1;

  List<Widget> get _customerTabs => [
    HomeScreen(),
    SendScreen(),
    NotificationsScreen(),
    ProfileScreen(),
    ContactScreen(),
  ];

  List<Widget> get _staffTabs => [
    StaffReceiveScreen(),
    StaffScanPayScreen(),
    _PlaceholderTab(titleKey: 'tab_customer_chat'),
  ];

  Future<void> _handleLogout() async {
    final success = await ref.read(authProvider.notifier).logout();
    if (!mounted) {
      return;
    }

    if (success) {
      context.go(LoginScreen.routePath);
      return;
    }

    final messageKey = ref.read(authProvider).message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text((messageKey ?? 'logout_failed').tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
    final isCustomer = role == UserRole.customer;
    final requestedCustomerTab = ref.watch(customerTabJumpTargetProvider);
    final notificationBadgeCount = isCustomer
        ? ref
              .watch(notificationsProvider)
              .maybeWhen(
                data: (items) => items.where((item) => item.isUnread).length,
                orElse: () => 0,
              )
        : 0;

    if (isCustomer && requestedCustomerTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _customerTabIndex = requestedCustomerTab;
        });
        ref.read(customerTabJumpTargetProvider.notifier).state = null;
      });
    }

    final currentIndex = isCustomer ? _customerTabIndex : _staffTabIndex;
    final tabs = isCustomer ? _customerTabs : _staffTabs;

    return Scaffold(
      body: Column(
        children: [
          _MainTopBar(
            isCustomer: isCustomer,
            currentLocale: context.locale,
            onSwitchRole: () => ref.read(authProvider.notifier).switchRole(),
            onLogout: () => unawaited(_handleLogout()),
          ),
          Expanded(
            child: IndexedStack(index: currentIndex, children: tabs),
          ),
        ],
      ),
      bottomNavigationBar: isCustomer
          ? _buildCustomerNavBar(notificationBadgeCount)
          : _buildStaffNavBar(),
    );
  }

  Widget _buildCustomerNavBar(int notificationBadgeCount) {
    return Material(
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        currentIndex: _customerTabIndex,
        onTap: (index) {
          // Tapping the Send tab while already on it means "start over", the
          // same way tapping a tab twice usually pops its stack.
          if (index == _customerTabIndex && index == _customerSendTabIndex) {
            ref.read(sendFlowResetSignalProvider.notifier).state++;
          }
          setState(() => _customerTabIndex = index);
        },
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: AppTheme.brandBlue,
        unselectedItemColor: const Color(0xFF778394),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        items: [
          _buildNavBarItem(
            icon: const Text('📦', style: TextStyle(fontSize: 20)),
            label: 'tab_parcel'.tr(),
          ),
          _buildNavBarItem(
            icon: const Text('🚚', style: TextStyle(fontSize: 20)),
            label: 'tab_send_parcel'.tr(),
          ),
          _buildNavBarItem(
            icon: notificationBadgeCount > 0
                ? Badge(
                    label: Text(notificationBadgeCount.toString()),
                    child: const Text('🔔', style: TextStyle(fontSize: 20)),
                  )
                : const Text('🔔', style: TextStyle(fontSize: 20)),
            label: 'tab_notifications'.tr(),
          ),
          _buildNavBarItem(
            icon: const Text('👤', style: TextStyle(fontSize: 20)),
            label: 'tab_profile'.tr(),
          ),
          _buildNavBarItem(
            icon: const Text('💬', style: TextStyle(fontSize: 20)),
            label: 'tab_contact'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffNavBar() {
    return Material(
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _staffTabIndex,
        onTap: (index) => setState(() => _staffTabIndex = index),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: AppTheme.brandBlue,
        unselectedItemColor: const Color(0xFF778394),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        items: [
          _buildNavBarItem(
            icon: const Text('📋', style: TextStyle(fontSize: 20)),
            label: 'tab_receive'.tr(),
          ),
          _buildNavBarItem(
            icon: const Text('🏪', style: TextStyle(fontSize: 20)),
            label: 'tab_scan_pay'.tr(),
          ),
          _buildNavBarItem(
            icon: const Text('💬', style: TextStyle(fontSize: 20)),
            label: 'tab_customer_chat'.tr(),
          ),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavBarItem({
    required Widget icon,
    required String label,
  }) {
    return BottomNavigationBarItem(
      icon: _BottomNavItemContent(icon: icon, label: label, isSelected: false),
      activeIcon: _BottomNavItemContent(
        icon: icon,
        label: label,
        isSelected: true,
      ),
      label: '',
      tooltip: label,
    );
  }
}

class _BottomNavItemContent extends StatelessWidget {
  const _BottomNavItemContent({
    required this.icon,
    required this.label,
    required this.isSelected,
  });

  final Widget icon;
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.brandBlue : const Color(0xFF778394);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        SizedBox(height: 3.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: color,
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MainTopBar extends ConsumerWidget {
  const _MainTopBar({
    required this.isCustomer,
    required this.currentLocale,
    required this.onSwitchRole,
    required this.onLogout,
  });

  final bool isCustomer;
  final Locale currentLocale;
  final VoidCallback onSwitchRole;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // โลโก้บน top bar เปลี่ยนตามสาขาที่เลือกไว้ (KD ใช้โลโก้ ZTO Savannakhet)
    final branchCode = ref.watch(selectedBranchCodeProvider).valueOrNull;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE9F5FF), Color(0xFFBFE0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 224.w,
                    child: AppBrandLogo(
                      width: double.infinity,
                      height: 42.h,
                      framed: true,
                      branchCode: branchCode,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 8.h,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Container(
              height: 34.h,
              width: 34.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A0A4B98),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: PopupMenuButton<_TopBarMenuAction>(
                key: const ValueKey('topbar-menu-button'),
                tooltip: 'topbar_menu'.tr(),
                padding: EdgeInsets.zero,
                iconSize: 18.sp,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.brandBlueDark,
                  size: 18.sp,
                ),
                color: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                onSelected: (action) {
                  if (action == _TopBarMenuAction.switchRole) {
                    onSwitchRole();
                    return;
                  }
                  if (action == _TopBarMenuAction.privacyPolicy) {
                    showPrivacyPolicySheet(context);
                    return;
                  }
                  onLogout();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<_TopBarMenuAction>(
                    key: ValueKey('topbar-menu-branch'),
                    enabled: false,
                    child: _BranchMenuItem(),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<_TopBarMenuAction>(
                    key: const ValueKey('topbar-menu-switch-language'),
                    enabled: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _LanguageFlagButton(
                          locale: Locale('en'),
                          flag: '🇬🇧',
                          tooltipKey: 'language_english',
                          selected: currentLocale.languageCode == 'en',
                        ),
                        _LanguageFlagButton(
                          locale: Locale('lo'),
                          flag: '🇱🇦',
                          tooltipKey: 'language_lao',
                          selected: currentLocale.languageCode == 'lo',
                        ),
                        _LanguageFlagButton(
                          locale: Locale('zh'),
                          flag: '🇨🇳',
                          tooltipKey: 'language_chinese',
                          selected: currentLocale.languageCode == 'zh',
                        ),
                      ],
                    ),
                  ),
                  // Play reviewers look for the policy link inside the signed-in
                  // app, not only on the auth screens.
                  PopupMenuItem<_TopBarMenuAction>(
                    key: const ValueKey('topbar-menu-privacy-policy'),
                    value: _TopBarMenuAction.privacyPolicy,
                    child: Text('privacy_policy_title'.tr()),
                  ),
                  PopupMenuItem<_TopBarMenuAction>(
                    key: const ValueKey('topbar-menu-logout'),
                    value: _TopBarMenuAction.logout,
                    child: Text(
                      'logout'.tr().toUpperCase(),
                      style: const TextStyle(color: Color(0xFFD32F2F)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageFlagButton extends StatelessWidget {
  const _LanguageFlagButton({
    required this.locale,
    required this.flag,
    required this.tooltipKey,
    required this.selected,
  });

  final Locale locale;
  final String flag;
  final String tooltipKey;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: ValueKey('topbar-language-${locale.languageCode}'),
      tooltip: tooltipKey.tr(),
      isSelected: selected,
      selectedIcon: Text(flag, style: const TextStyle(fontSize: 24)),
      onPressed: () {
        // Keep the backend language in step so pushes match the new UI language.
        final container = ProviderScope.containerOf(context, listen: false);
        unawaited(
          context.setLocale(locale).then(
            (_) => pushUserLanguage(container, locale.languageCode),
          ),
        );
        Navigator.of(context).pop();
      },
      icon: Text(flag, style: const TextStyle(fontSize: 24)),
    );
  }
}

/// First item in the top-bar dropdown: a toggle that switches the active
/// branch (e.g. CLS / KD). Selecting a branch calls `PATCH /users/me/branch`
/// and refreshes the chat so it can resolve a room id.
class _BranchMenuItem extends ConsumerWidget {
  const _BranchMenuItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    final currentId = ref.watch(currentBranchIdProvider).valueOrNull;
    final selectedCode = ref.watch(selectedBranchCodeProvider).valueOrNull;

    if (branches.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Text(
          'branch_loading'.tr(),
          style: TextStyle(
            color: const Color(0xFF6E7D92),
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < branches.length; i++) ...[
          if (i > 0) SizedBox(width: 8.w),
          Expanded(
            child: _BranchChip(
              branch: branches[i],
              // Prefer the locally selected code so the toggle reflects the
              // switch instantly; fall back to the server's branch id before
              // any manual selection has been made.
              selected: (selectedCode != null && selectedCode.isNotEmpty)
                  ? branches[i].code == selectedCode
                  : branches[i].id == currentId,
              onTap: () => _selectBranch(context, branches[i]),
            ),
          ),
        ],
      ],
    );
  }

  void _selectBranch(BuildContext context, Branch branch) {
    // Capture the app-level container and the messenger before the menu (and
    // this widget) closes.
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    unawaited(_applySelection(container, messenger, branch));
  }

  Future<void> _applySelection(
    ProviderContainer container,
    ScaffoldMessengerState messenger,
    Branch branch,
  ) async {
    final branchCodeStore = container.read(branchCodeStoreProvider);
    final previousCode = await branchCodeStore.read();

    // Point every subsequent request at the chosen branch FIRST. The
    // `x-branch-code` header is what NestJS routes on, so once it is set the
    // PATCH below and all data refetches hit the correct backend.
    if (branch.code.isNotEmpty) {
      await branchCodeStore.save(branch.code);
      container.invalidate(selectedBranchCodeProvider);
    }

    // The server now creates orders against the user's active branch
    // (`users.branchId`), not the header. If this PATCH fails the list would
    // show one branch's parcels while orders are created in another — which
    // surfaces as "parcel not found" — so roll the header back to the branch
    // the server still holds instead of leaving the two out of sync.
    try {
      await container.read(branchRepositoryProvider).selectBranch(branch.id);
    } catch (_) {
      // BranchRepository already logged the real cause (status/body).
      if (branch.code.isNotEmpty) {
        if (previousCode != null && previousCode.isNotEmpty) {
          await branchCodeStore.save(previousCode);
        } else {
          await branchCodeStore.clear();
        }
        container.invalidate(selectedBranchCodeProvider);
      }
      messenger.showSnackBar(
        SnackBar(content: Text('branch_switch_failed'.tr())),
      );
    }

    // Parcels/orders are a different set per branch, so drop every
    // branch-scoped cache and refetch for the newly selected branch instead of
    // showing the previous branch's data.
    container.invalidate(currentBranchIdProvider);
    container.invalidate(contactThreadProvider);
    container.invalidate(homeParcelsProvider);
    container.invalidate(parcelStatusProvider);
    container.invalidate(notificationsProvider);
    container.invalidate(sendParcelsProvider);
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({
    required this.branch,
    required this.selected,
    required this.onTap,
  });

  final Branch branch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: ValueKey('topbar-branch-${branch.code}'),
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor:
            selected ? AppTheme.brandBlue : const Color(0xFFEAF4FF),
        foregroundColor: selected ? Colors.white : AppTheme.brandBlueDark,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        minimumSize: Size(0, 36.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      child: Text(
        branch.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
      ),
    );
  }
}

enum _TopBarMenuAction { switchRole, privacyPolicy, logout }

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.titleKey});

  final String titleKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        titleKey.tr(),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
