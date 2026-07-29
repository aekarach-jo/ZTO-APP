import 'package:flutter/services.dart';

/// Every Lao mobile number this app accepts starts with these digits, so the
/// field shows them as a fixed prefix instead of asking anyone to type them.
const String laoMobilePrefix = '+85620';

/// Digits left for the user once [laoMobilePrefix] is taken out.
const int laoSubscriberDigits = 8;

/// Keeps a phone field down to the subscriber digits that follow the
/// `+856 20` prefix rendered next to it.
///
/// Typing is left alone; the trimming only kicks in for input longer than a
/// subscriber number, which in practice means a paste. People paste their
/// number in every shape it appears on a bill or in a chat — `2099887766`,
/// `02099887766`, `856 20 99 88 77 66` — so drop the parts the prefix already
/// covers rather than rejecting the paste and making them retype it.
class LaoSubscriberNumberFormatter extends TextInputFormatter {
  const LaoSubscriberNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > laoSubscriberDigits) {
      if (digits.startsWith('856')) {
        digits = digits.substring(3);
      }
      if (digits.startsWith('0')) {
        digits = digits.substring(1);
      }
      if (digits.startsWith('20')) {
        digits = digits.substring(2);
      }
    }
    if (digits.length > laoSubscriberDigits) {
      digits = digits.substring(0, laoSubscriberDigits);
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
