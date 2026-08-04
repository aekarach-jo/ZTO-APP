import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/address_repository.dart';
import 'default_forwarding_address_screen.dart';

/// The customer's saved addresses (`/users/me/addresses`). The entry marked as
/// default is what the forward flow prefills the recipient step from, so this
/// screen exists mainly to pick which one that is.
class AddressBookScreen extends ConsumerStatefulWidget {
  const AddressBookScreen({super.key});

  static const String routePath = '/profile/addresses';

  @override
  ConsumerState<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends ConsumerState<AddressBookScreen> {
  /// Id of the entry a request is running for, so only its card shows a
  /// spinner instead of blocking the whole list.
  String? _busyAddressId;

  Future<void> _openForm({UserAddress? address}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DefaultForwardingAddressScreen(address: address),
      ),
    );
  }

  Future<void> _setDefault(UserAddress address) async {
    if (address.isDefault || _busyAddressId != null) {
      return;
    }
    setState(() => _busyAddressId = address.id);
    try {
      await ref.read(addressRepositoryProvider).setDefaultAddress(address.id);
      ref.invalidate(userAddressesProvider);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[AddressBook] setDefault failed error=$error');
      }
      _showSnack('profile_address_set_default_failed'.tr());
    } finally {
      if (mounted) {
        setState(() => _busyAddressId = null);
      }
    }
  }

  Future<void> _confirmDelete(UserAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('profile_address_delete_title'.tr()),
        content: Text('profile_address_delete_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('common_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'profile_address_delete_action'.tr(),
              style: const TextStyle(color: Color(0xFFD64545)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || _busyAddressId != null) {
      return;
    }

    setState(() => _busyAddressId = address.id);
    try {
      await ref.read(addressRepositoryProvider).deleteAddress(address.id);
      ref.invalidate(userAddressesProvider);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[AddressBook] delete failed error=$error');
      }
      _showSnack('profile_address_delete_failed'.tr());
    } finally {
      if (mounted) {
        setState(() => _busyAddressId = null);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(userAddressesProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        title: Text('profile_address_book_title'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('address-book-add-button'),
        onPressed: () => _openForm(),
        backgroundColor: AppTheme.brandBlueDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('profile_address_add'.tr()),
      ),
      body: addressesAsync.when(
        data: (addresses) {
          if (addresses.isEmpty) {
            return _CenteredMessage(
              message: 'profile_address_empty'.tr(),
              actionLabel: 'profile_address_add'.tr(),
              onAction: () => _openForm(),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(userAddressesProvider.future),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 96.h),
              itemCount: addresses.length,
              separatorBuilder: (_, _) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return _AddressCard(
                  key: ValueKey('address-card-${address.id}'),
                  address: address,
                  busy: _busyAddressId == address.id,
                  onEdit: () => _openForm(address: address),
                  onDelete: () => _confirmDelete(address),
                  onSetDefault: () => _setDefault(address),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _CenteredMessage(
          message: 'profile_address_load_error'.tr(),
          actionLabel: 'common_retry'.tr(),
          onAction: () => ref.invalidate(userAddressesProvider),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    super.key,
    required this.address,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final UserAddress address;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: address.isDefault
              ? AppTheme.brandBlueDark
              : const Color(0xFFE2E8F1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  address.label.isEmpty
                      ? 'profile_address_no_label'.tr()
                      : address.label,
                  style: TextStyle(
                    color: const Color(0xFF111111),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (address.isDefault)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.softBlue,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    'profile_address_default_badge'.tr(),
                    style: TextStyle(
                      color: AppTheme.brandBlueDark,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (address.phone.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              address.phone,
              style: TextStyle(
                color: const Color(0xFF6E7D92),
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          SizedBox(height: 6.h),
          Text(
            address.addressLine,
            style: TextStyle(
              color: const Color(0xFF44546A),
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              if (busy)
                SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                if (!address.isDefault)
                  TextButton(
                    onPressed: onSetDefault,
                    child: Text('profile_address_set_default'.tr()),
                  ),
                TextButton(
                  onPressed: onEdit,
                  child: Text('profile_address_edit'.tr()),
                ),
                TextButton(
                  onPressed: onDelete,
                  child: Text(
                    'profile_address_delete_action'.tr(),
                    style: const TextStyle(color: Color(0xFFD64545)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF6E7D92),
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
