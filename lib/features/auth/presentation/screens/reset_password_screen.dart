import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/language_toggle_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/app_brand_logo.dart';
import '../../application/auth_provider.dart';
import 'forgot_password_screen.dart';
import 'login_screen.dart';

class ResetPasswordArgs {
  const ResetPasswordArgs({
    required this.phoneNumber,
    required this.resetToken,
  });

  final String phoneNumber;
  final String resetToken;
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.args, super.key});

  static const String routePath = '/forgot-password/reset';

  final ResetPasswordArgs args;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .resetForgotPassword(
          phoneNumber: widget.args.phoneNumber,
          resetToken: widget.args.resetToken,
          newPassword: _newPasswordController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    final message = ref.read(authProvider).message;
    if (message != null) {
      _showSnackBar(message);
    }

    if (success) {
      context.go(LoginScreen.routePath);
    }
  }

  void _showSnackBar(String messageKeyOrText) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_messageText(messageKeyOrText))));
  }

  String _messageText(String messageKeyOrText) {
    return messageKeyOrText.contains('_')
        ? messageKeyOrText.tr()
        : messageKeyOrText;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFEAF5FF), Color(0xFFFFFFFF)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              context.go(ForgotPasswordScreen.routePath),
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                        ),
                        SizedBox(width: 4.w),
                        SizedBox(
                          width: 224.w,
                          child: AppBrandLogo(
                            width: double.infinity,
                            height: 42.h,
                            framed: true,
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 8.h,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const LanguageToggleButton(),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(color: const Color(0xFFD5E6FF)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12084E9A),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'reset_password_title'.tr(),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: 30.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'reset_password_subtitle'.tr(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF7A869A),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          SizedBox(height: 22.h),
                          CustomTextField(
                            label: 'new_password'.tr(),
                            controller: _newPasswordController,
                            obscureText: true,
                            validator: (value) {
                              final password = value?.trim() ?? '';
                              if (password.isEmpty) {
                                return 'required_field'.tr();
                              }
                              if (password.length < 8) {
                                return 'password_too_short'.tr();
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 14.h),
                          CustomTextField(
                            label: 'confirm_password'.tr(),
                            controller: _confirmPasswordController,
                            obscureText: true,
                            validator: (value) {
                              final confirmation = value?.trim() ?? '';
                              if (confirmation.isEmpty) {
                                return 'required_field'.tr();
                              }
                              if (confirmation !=
                                  _newPasswordController.text.trim()) {
                                return 'password_not_match'.tr();
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 24.h),
                          PrimaryButton(
                            label: 'reset_password'.tr(),
                            onPressed: authState.isLoading
                                ? null
                                : _handleResetPassword,
                            isLoading: authState.isLoading,
                          ),
                          SizedBox(height: 10.h),
                          Align(
                            child: TextButton(
                              onPressed: authState.isLoading
                                  ? null
                                  : () => context.go(LoginScreen.routePath),
                              child: Text('back_to_login'.tr()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
