import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/language_toggle_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/auth_provider.dart';
import 'register_otp_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  static const String routePath = '/register';

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRoutingToOtp = false;

  static final RegExp _laosLocalPhoneRegex = RegExp(r'^20[0-9]{6,8}$');

  String _normalizeLaosPhone(String input) {
    var digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return '';
    }

    // Accept pasted full number while preserving local-input UX.
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
    _passwordController.dispose();
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
    final password = _passwordController.text.trim();

    final success = await ref.read(authProvider.notifier).requestRegisterOtp(
          phoneNumber: phoneNumber,
        );

    if (!mounted) {
      return;
    }

    final messageKey = ref.read(authProvider).message;
    if (messageKey != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageKey.tr())),
      );
    }

    if (success) {
      _isRoutingToOtp = true;
      context.go(
        RegisterOtpScreen.routePath,
        extra: RegisterOtpArgs(
          phoneNumber: phoneNumber,
          password: password,
        ),
      );
    }
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
                  colors: [Color(0xFFFFF3E8), Color(0xFFFFFFFF)],
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
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      ),
                      SizedBox(width: 4.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QUICKPICK',
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
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.8),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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
                      border: Border.all(color: const Color(0xFFFFE4CF)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'create_account'.tr(),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 30.sp,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'register_continue_subtitle'.tr(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                            LengthLimitingTextInputFormatter(11),
                          ],
                          controller: _phoneController,
                          validator: (value) {
                            final local = _sanitizeLocalMobile(value?.trim() ?? '');
                            if (local.isEmpty) {
                              return 'required_field'.tr();
                            }
                            if (!_laosLocalPhoneRegex.hasMatch(local)) {
                              return 'invalid_phone_number'.tr();
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 14.h),
                        CustomTextField(
                          label: 'password'.tr(),
                          controller: _passwordController,
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'required_field'.tr();
                            }
                            if (value.trim().length < 8) {
                              return 'password_too_short'.tr();
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 24.h),
                        PrimaryButton(
                          label: 'send_otp'.tr(),
                          onPressed: authState.isLoading || _isRoutingToOtp ? null : _handleSendOtp,
                          isLoading: authState.isLoading,
                        ),
                        SizedBox(height: 10.h),
                        Align(
                          child: TextButton(
                            onPressed: () => context.pop(),
                            child: Text('already_have_account'.tr()),
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

