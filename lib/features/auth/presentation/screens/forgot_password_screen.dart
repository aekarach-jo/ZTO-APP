import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/language_toggle_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/app_brand_logo.dart';
import '../../application/auth_provider.dart';
import 'forgot_password_otp_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  static const String routePath = '/forgot-password';

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isRoutingToOtp = false;

  static final RegExp _laosForgotPasswordPhoneRegex = RegExp(
    r'^(?:20|30)[0-9]{8}$',
  );

  String _normalizeLaosPhone(String input) {
    var digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return '';
    }

    if (digitsOnly.startsWith('856')) {
      digitsOnly = digitsOnly.substring(3);
    }
    if (digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.substring(1);
    }

    return '+856$digitsOnly';
  }

  String _sanitizeLocalMobile(String input) {
    var digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.startsWith('856')) {
      digitsOnly = digitsOnly.substring(3);
    }
    if (digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.substring(1);
    }
    return digitsOnly;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (_isRoutingToOtp) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final phoneNumber = _normalizeLaosPhone(_phoneController.text.trim());
    final success = await ref
        .read(authProvider.notifier)
        .requestForgotPasswordOtp(phoneNumber: phoneNumber);

    if (!mounted) {
      return;
    }

    final message = ref.read(authProvider).message;
    if (message != null) {
      _showSnackBar(message);
    }

    if (success) {
      _isRoutingToOtp = true;
      context.go(
        ForgotPasswordOtpScreen.routePath,
        extra: ForgotPasswordOtpArgs(phoneNumber: phoneNumber),
      );
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
                          onPressed: () => context.pop(),
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
                            'forgot_password_title'.tr(),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: 30.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'forgot_password_subtitle'.tr(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF7A869A),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          SizedBox(height: 22.h),
                          CustomTextField(
                            label: 'phone_number'.tr(),
                            hintText: 'phone_local_hint'.tr(),
                            prefixText: '+856 ',
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9 ]'),
                              ),
                              LengthLimitingTextInputFormatter(13),
                            ],
                            controller: _phoneController,
                            validator: (value) {
                              final local = _sanitizeLocalMobile(
                                value?.trim() ?? '',
                              );
                              if (local.isEmpty) {
                                return 'required_field'.tr();
                              }
                              if (!_laosForgotPasswordPhoneRegex.hasMatch(
                                local,
                              )) {
                                return 'invalid_phone_number'.tr();
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 24.h),
                          PrimaryButton(
                            label: 'send_otp'.tr(),
                            onPressed: authState.isLoading || _isRoutingToOtp
                                ? null
                                : _handleSendOtp,
                            isLoading: authState.isLoading,
                          ),
                          SizedBox(height: 10.h),
                          Align(
                            child: TextButton(
                              onPressed: authState.isLoading
                                  ? null
                                  : () => context.pop(),
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
