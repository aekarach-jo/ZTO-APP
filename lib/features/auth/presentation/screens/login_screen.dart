import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/utils/lao_phone_input.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/language_toggle_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/app_brand_logo.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../../../main_layout/presentation/screens/main_layout_screen.dart';
import '../../application/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const String routePath = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  /// The field only holds what follows `+856 20`, which the prefix already
  /// shows: six to eight subscriber digits.
  static final RegExp _subscriberDigitsRegex = RegExp(r'^[0-9]{6,8}$');

  String _normalizeLaosPhone(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return '';
    }
    return '$laoMobilePrefix$digitsOnly';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    final phoneNumber = _normalizeLaosPhone(_phoneController.text.trim());
    final success = await notifier.login(
      phoneNumber: phoneNumber,
      password: _passwordController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      context.go(MainLayoutScreen.routePath);
    } else {
      final messageKey = ref.read(authProvider).message;
      if (messageKey != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageKey.tr())));
      }
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
                    SizedBox(height: 20.h),
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
                            'welcome_back'.tr(),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: 30.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'login_continue_subtitle'.tr(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF7A869A),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          SizedBox(height: 22.h),
                          CustomTextField(
                            label: 'phone_number'.tr(),
                            hintText: 'phone_subscriber_hint'.tr(),
                            prefixText: '+856 20 ',
                            keyboardType: TextInputType.phone,
                            inputFormatters: const [
                              LaoSubscriberNumberFormatter(),
                            ],
                            controller: _phoneController,
                            validator: (value) {
                              final digits = (value ?? '').trim();
                              if (digits.isEmpty) {
                                return 'required_field'.tr();
                              }
                              if (!_subscriberDigitsRegex.hasMatch(digits)) {
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
                              return null;
                            },
                          ),
                          SizedBox(height: 6.h),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: authState.isLoading
                                  ? null
                                  : () => context.push(
                                      ForgotPasswordScreen.routePath,
                                    ),
                              child: Text('forgot_password'.tr()),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          PrimaryButton(
                            label: 'login'.tr(),
                            onPressed: _handleLogin,
                            isLoading: authState.isLoading,
                          ),
                          SizedBox(height: 10.h),
                          Align(
                            child: TextButton(
                              onPressed: authState.isLoading
                                  ? null
                                  : () =>
                                        context.push(RegisterScreen.routePath),
                              child: Text('dont_have_account'.tr()),
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
