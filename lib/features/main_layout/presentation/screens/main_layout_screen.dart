import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/application/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../contact/presentation/screens/contact_screen.dart';
import '../../application/main_layout_navigation_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../notifications/data/notification_repository.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../send/presentation/screens/send_screen.dart';
import '../../../staff/presentation/screens/staff_receive_screen.dart';
import '../../../staff/presentation/screens/staff_scan_pay_screen.dart';
import '../../../../core/theme/app_theme.dart';

class MainLayoutScreen extends ConsumerStatefulWidget {
  const MainLayoutScreen({super.key});

  static const String routePath = '/main';

  @override
  ConsumerState<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends ConsumerState<MainLayoutScreen> {
  int _customerTabIndex = 0;
  int _staffTabIndex = 0;

  final List<Widget> _customerTabs = const [
    HomeScreen(),
    SendScreen(),
    NotificationsScreen(),
    ProfileScreen(),
    ContactScreen(),
  ];

  final List<Widget> _staffTabs = const [
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

  Future<void> _handleSwitchLanguage() async {
    final supportedLocales = context.supportedLocales;
    if (supportedLocales.isEmpty) {
      return;
    }

    final currentLocale = context.locale;
    final currentIndex = supportedLocales.indexWhere(
      (locale) =>
          locale.languageCode == currentLocale.languageCode &&
          locale.countryCode == currentLocale.countryCode,
    );
    final nextIndex = currentIndex == -1
        ? 0
        : (currentIndex + 1) % supportedLocales.length;
    await context.setLocale(supportedLocales[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
    final isCustomer = role == UserRole.customer;
    final requestedCustomerTab = ref.watch(customerTabJumpTargetProvider);
    final notificationBadgeCount = isCustomer
        ? ref.watch(notificationsProvider).maybeWhen(
            data: (items) => items.length,
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
            onSwitchRole: () => ref.read(authProvider.notifier).switchRole(),
            onSwitchLanguage: () => unawaited(_handleSwitchLanguage()),
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
        onTap: (index) => setState(() => _customerTabIndex = index),
        selectedItemColor: AppTheme.primaryOrange,
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
          BottomNavigationBarItem(
            icon: const Text('📦', style: TextStyle(fontSize: 20)),
            activeIcon: const Text('📦', style: TextStyle(fontSize: 20)),
            label: 'tab_parcel'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Text('🚚', style: TextStyle(fontSize: 20)),
            activeIcon: const Text('🚚', style: TextStyle(fontSize: 20)),
            label: 'tab_send_parcel'.tr(),
          ),
          BottomNavigationBarItem(
            icon: notificationBadgeCount > 0
                ? Badge(
                    label: Text(notificationBadgeCount.toString()),
                    child: const Text('🔔', style: TextStyle(fontSize: 20)),
                  )
                : const Text('🔔', style: TextStyle(fontSize: 20)),
            activeIcon: notificationBadgeCount > 0
                ? Badge(
                    label: Text(notificationBadgeCount.toString()),
                    child: const Text('🔔', style: TextStyle(fontSize: 20)),
                  )
                : const Text('🔔', style: TextStyle(fontSize: 20)),
            label: 'tab_notifications'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Text('👤', style: TextStyle(fontSize: 20)),
            activeIcon: const Text('👤', style: TextStyle(fontSize: 20)),
            label: 'tab_profile'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Text('💬', style: TextStyle(fontSize: 20)),
            activeIcon: const Text('💬', style: TextStyle(fontSize: 20)),
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
        selectedItemColor: AppTheme.primaryOrange,
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
          BottomNavigationBarItem(
            icon: const Text('📋', style: TextStyle(fontSize: 20)),
            activeIcon: const Text('📋', style: TextStyle(fontSize: 20)),
            label: 'tab_receive'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Text('🏪', style: TextStyle(fontSize: 20)),
            activeIcon: const Text('🏪', style: TextStyle(fontSize: 20)),
            label: 'tab_scan_pay'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Text('💬', style: TextStyle(fontSize: 20)),
            activeIcon: const Text('💬', style: TextStyle(fontSize: 20)),
            label: 'tab_customer_chat'.tr(),
          ),
        ],
      ),
    );
  }
}

class _MainTopBar extends StatelessWidget {
  const _MainTopBar({
    required this.isCustomer,
    required this.onSwitchRole,
    required this.onSwitchLanguage,
    required this.onLogout,
  });

  final bool isCustomer;
  final VoidCallback onSwitchRole;
  final VoidCallback onSwitchLanguage;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryOrange,
      padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 14.h),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'QUICKPICK',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22.sp,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  Text(
                    'brand_subtitle'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.85),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
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
                color: const Color(0xFF111111),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x30000000),
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
                  color: Colors.white,
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
                  if (action == _TopBarMenuAction.switchLanguage) {
                    onSwitchLanguage();
                    return;
                  }
                  onLogout();
                },
                itemBuilder: (context) => [
                  PopupMenuItem<_TopBarMenuAction>(
                    key: const ValueKey('topbar-menu-switch-role'),
                    value: _TopBarMenuAction.switchRole,
                    child: Text(
                      (isCustomer
                              ? 'switch_to_staff'.tr()
                              : 'switch_to_customer'.tr())
                          .toUpperCase(),
                    ),
                  ),
                  PopupMenuItem<_TopBarMenuAction>(
                    key: const ValueKey('topbar-menu-switch-language'),
                    value: _TopBarMenuAction.switchLanguage,
                    child: Text('switch_language'.tr().toUpperCase()),
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

enum _TopBarMenuAction { switchRole, switchLanguage, logout }

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
