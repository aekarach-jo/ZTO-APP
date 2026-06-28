import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/language_toggle_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/auth_provider.dart';
import 'forgot_password_screen.dart';
import 'reset_password_screen.dart';

class ForgotPasswordOtpArgs {
  const ForgotPasswordOtpArgs({required this.phoneNumber});

  final String phoneNumber;
}

class ForgotPasswordOtpScreen extends ConsumerStatefulWidget {
  const ForgotPasswordOtpScreen({required this.args, super.key});

  static const String routePath = '/forgot-password/otp';

  final ForgotPasswordOtpArgs args;

  @override
  ConsumerState<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState
    extends ConsumerState<ForgotPasswordOtpScreen> {
  static const int _otpLength = 6;
  static const int _otpExpirySeconds = 300;

  Timer? _countdownTimer;
  int _remainingSeconds = _otpExpirySeconds;
  String _otp = '';
  final _otpInputController = TextEditingController();
  final _otpFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpInputController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  bool get _isExpired => _remainingSeconds <= 0;
  bool get _isOtpComplete => _otp.length == _otpLength;

  void _startCountdown() {
    _countdownTimer?.cancel();
    _remainingSeconds = _otpExpirySeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        setState(() => _remainingSeconds = 0);
        timer.cancel();
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  String _formatCountdown() {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _submitOtp() async {
    if (_isExpired) {
      _showSnackBar('otp_expired');
      return;
    }
    if (!_isOtpComplete) {
      _showSnackBar('invalid_otp_code');
      return;
    }

    final resetToken = await ref
        .read(authProvider.notifier)
        .verifyForgotPasswordOtp(
          phoneNumber: widget.args.phoneNumber,
          otp: _otp,
        );

    if (!mounted) {
      return;
    }

    final message = ref.read(authProvider).message;
    if (message != null) {
      _showSnackBar(message);
    }

    if (resetToken != null && resetToken.isNotEmpty) {
      context.go(
        ResetPasswordScreen.routePath,
        extra: ResetPasswordArgs(
          phoneNumber: widget.args.phoneNumber,
          resetToken: resetToken,
        ),
      );
    }
  }

  Future<void> _resendOtp() async {
    final success = await ref
        .read(authProvider.notifier)
        .requestForgotPasswordOtp(phoneNumber: widget.args.phoneNumber);

    if (!mounted) {
      return;
    }

    final message = ref.read(authProvider).message;
    if (message != null) {
      _showSnackBar(message);
    }

    if (success) {
      setState(() {
        _otp = '';
        _otpInputController.clear();
      });
      _startCountdown();
      setState(() {});
    }
  }

  String _maskPhoneNumber(String phoneNumber) {
    final hasPlus = phoneNumber.startsWith('+');
    final raw = hasPlus ? phoneNumber.substring(1) : phoneNumber;
    if (raw.length <= 6) {
      return hasPlus ? '+$raw' : raw;
    }
    final prefix = raw.substring(0, 3);
    final suffix = raw.substring(raw.length - 3);
    final masked = '*' * (raw.length - 6);
    return hasPlus ? '+$prefix$masked$suffix' : '$prefix$masked$suffix';
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
                  colors: [Color(0xFFFFF3E8), Color(0xFFFFFFFF)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const ValueKey('forgot-password-otp-back-button'),
                        onPressed: () =>
                            context.go(ForgotPasswordScreen.routePath),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
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
                          'verify_otp'.tr(),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontSize: 30.sp,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '${'phone_number'.tr()}: ${_maskPhoneNumber(widget.args.phoneNumber)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          _isExpired
                              ? 'otp_expired'.tr()
                              : 'otp_expires_in'.tr(args: [_formatCountdown()]),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _isExpired ? Colors.red : Colors.black54,
                              ),
                        ),
                        SizedBox(height: 20.h),
                        GestureDetector(
                          onTap: () => _otpFocusNode.requestFocus(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List<Widget>.generate(_otpLength, (
                              index,
                            ) {
                              final digit = index < _otp.length
                                  ? _otp[index]
                                  : '';
                              return Container(
                                key: ValueKey(
                                  'forgot-password-otp-digit-box-$index',
                                ),
                                width: 48.w,
                                height: 52.h,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFD8C9BA),
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  digit,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              );
                            }),
                          ),
                        ),
                        Opacity(
                          opacity: 0,
                          child: TextField(
                            key: const ValueKey(
                              'forgot-password-otp-hidden-input',
                            ),
                            controller: _otpInputController,
                            focusNode: _otpFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(_otpLength),
                            ],
                            onChanged: (value) {
                              setState(() => _otp = value);
                              if (value.length == _otpLength && !_isExpired) {
                                unawaited(_submitOtp());
                              }
                            },
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Align(
                          child: TextButton(
                            onPressed: authState.isLoading || !_isExpired
                                ? null
                                : _resendOtp,
                            child: Text('resend_otp'.tr()),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        PrimaryButton(
                          label: 'continue'.tr(),
                          onPressed: _isExpired || authState.isLoading
                              ? null
                              : _submitOtp,
                          isLoading: authState.isLoading,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
