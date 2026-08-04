import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'privacy_policy_sheet.dart';

/// Consent line shown under the sign-up / sign-in actions, with the policy name
/// itself as the only tappable part. Tapping opens the policy in a bottom sheet
/// without leaving the app.
class PrivacyPolicyConsentText extends StatefulWidget {
  const PrivacyPolicyConsentText({
    super.key,
    this.prefixKey = 'privacy_policy_read_prefix',
  });

  /// Translation key for the sentence preceding the link. Sign-up passes the
  /// consent wording; sign-in keeps the neutral "read our" default.
  final String prefixKey;

  @override
  State<PrivacyPolicyConsentText> createState() =>
      _PrivacyPolicyConsentTextState();
}

class _PrivacyPolicyConsentTextState extends State<PrivacyPolicyConsentText> {
  // A recognizer attached to a TextSpan is not disposed by the framework, so
  // the widget has to own it.
  late final TapGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = TapGestureRecognizer()
      ..onTap = () => showPrivacyPolicySheet(context);
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme.bodySmall;

    return Text.rich(
      TextSpan(
        style: textTheme?.copyWith(color: const Color(0xFF7A869A)),
        children: [
          TextSpan(text: '${widget.prefixKey.tr()} '),
          TextSpan(
            text: 'privacy_policy_title'.tr(),
            style: textTheme?.copyWith(
              color: const Color(0xFF0A4B98),
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
            recognizer: _recognizer,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
