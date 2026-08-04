import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/network/media_upload_repository.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../data/profile_repository.dart';

/// Destructive-action red, matching the clear-all dialog on notifications.
const Color _dangerRed = Color(0xFFD64545);

/// Edits the signed-in user's name, email and avatar via `PATCH /users/me`.
/// The avatar is uploaded to `POST /chat/upload` first, then its returned URL
/// is sent as `profileImage`.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  static const String routePath = '/profile/edit';

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _initialised = false;
  bool _saving = false;
  bool _deleting = false;

  /// Newly picked local avatar (not yet uploaded). Null until the user picks.
  File? _pickedImage;

  /// Existing avatar URL/path from the server (shown until a new one is picked).
  String _currentImage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile profile) {
    if (_initialised) {
      return;
    }
    _initialised = true;
    _nameController.text = profile.displayName;
    _emailController.text = profile.email;
    _currentImage = profile.profileImage;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        title: Text('profile_edit_title'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
      ),
      body: profileAsync.when(
        data: (profile) {
          _hydrate(profile);
          return _buildForm();
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'profile_load_error'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp),
                ),
                SizedBox(height: 8.h),
                TextButton(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  child: Text('common_retry'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
        children: [
          Center(child: _AvatarPicker(
            pickedImage: _pickedImage,
            currentImageUrl:
                _currentImage.isEmpty ? '' : AppEnv.resolveMediaUrl(_currentImage),
            onTap: _saving ? null : _pickImage,
          )),
          SizedBox(height: 28.h),
          _FieldLabel('profile_edit_display_name'.tr()),
          SizedBox(height: 6.h),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration('profile_edit_display_name'.tr()),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'profile_edit_name_required'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 18.h),
          _FieldLabel('profile_edit_email'.tr()),
          SizedBox(height: 6.h),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration('profile_edit_email'.tr()),
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) {
                return null; // email is optional
              }
              final emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegExp.hasMatch(text)) {
                return 'profile_edit_invalid_email'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton(
              key: const ValueKey('edit-profile-save-button'),
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlueDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                textStyle: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
              ),
              child: _saving
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('profile_edit_save'.tr()),
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: OutlinedButton(
              key: const ValueKey('edit-profile-delete-account-button'),
              onPressed: _saving || _deleting ? null : _confirmDeleteAccount,
              style: OutlinedButton.styleFrom(
                foregroundColor: _dangerRed,
                side: const BorderSide(color: _dangerRed),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                textStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
              ),
              child: _deleting
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _dangerRed,
                      ),
                    )
                  : Text('profile_delete_account'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: Color(0xFFE2E8F1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: Color(0xFFE2E8F1)),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _pickedImage = File(picked.path));
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[EditProfile] pickImage failed error=$error');
      }
      _showSnack('contact_image_pick_failed'.tr());
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      // Upload the new avatar first (if any) so PATCH receives its URL.
      String? profileImage;
      if (_pickedImage != null) {
        profileImage =
            await ref.read(mediaUploadRepositoryProvider).uploadImage(_pickedImage!);
      }

      await ref.read(profileRepositoryProvider).updateProfile(
            displayName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            profileImage: profileImage,
          );

      ref.invalidate(userProfileProvider);

      if (!mounted) {
        return;
      }
      _showSnack('profile_edit_saved'.tr());
      Navigator.of(context).pop();
    } on MediaUploadException catch (error) {
      _showSnack(error.message);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[EditProfile] save failed error=$error');
      }
      _showSnack('profile_edit_save_failed'.tr());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('delete-account-confirm-dialog'),
        title: Text('profile_delete_account_confirm_title'.tr()),
        content: Text('profile_delete_account_confirm_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('common_cancel'.tr()),
          ),
          TextButton(
            key: const ValueKey('delete-account-confirm-action'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'profile_delete_account_confirm_action'.tr(),
              style: const TextStyle(color: _dangerRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || _deleting) {
      return;
    }
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() => _deleting = true);
    try {
      await ref.read(profileRepositoryProvider).deleteAccount();

      // The account is gone, so `POST /auth/logout` would only fail on a token
      // the backend no longer honours — and AuthRepository.logout() clears the
      // storages *after* that call, which would leave the session behind. Drop
      // the credentials here instead.
      await ref.read(tokenStorageProvider).clear();
      await ref.read(currentUserStorageProvider).clear();
      ref.invalidate(authTokensProvider);
      ref.invalidate(currentUserPhoneProvider);

      if (!mounted) {
        return;
      }
      _showSnack('profile_delete_account_success'.tr());
      context.go(LoginScreen.routePath);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[EditProfile] deleteAccount failed error=$error');
      }
      _showSnack('profile_delete_account_failed'.tr());
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.pickedImage,
    required this.currentImageUrl,
    required this.onTap,
  });

  final File? pickedImage;
  final String currentImageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              // ClipOval keeps the photo edge-to-edge; a bordered circle
              // Container insets the child and shows a white ring instead.
              ClipOval(
                child: Container(
                  width: 110.w,
                  height: 110.w,
                  color: const Color(0xFFE7F2FF),
                  child: _buildImage(),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.brandBlueDark,
                  ),
                  child: Icon(Icons.camera_alt, color: Colors.white, size: 16.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'profile_edit_change_photo'.tr(),
            style: TextStyle(
              color: AppTheme.brandBlueDark,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (pickedImage != null) {
      return Image.file(pickedImage!, fit: BoxFit.cover);
    }
    if (currentImageUrl.isNotEmpty) {
      return Image.network(
        currentImageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return const Icon(Icons.person, size: 56, color: Color(0xFF8A99AD));
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: const Color(0xFF6E7D92),
        fontSize: 13.sp,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
