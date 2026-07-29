import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zto_app/shared/utils/lao_phone_input.dart';

void main() {
  const formatter = LaoSubscriberNumberFormatter();

  String format(String input, {String previous = ''}) {
    return formatter
        .formatEditUpdate(
          TextEditingValue(text: previous),
          TextEditingValue(
            text: input,
            selection: TextSelection.collapsed(offset: input.length),
          ),
        )
        .text;
  }

  test('leaves a subscriber number being typed alone', () {
    expect(format('9'), '9');
    expect(format('9123456'), '9123456');
    expect(format('91234567'), '91234567');
  });

  test('drops separators', () {
    expect(format('99 88 77 66'), '99887766');
  });

  test('drops a prefix the field already shows', () {
    expect(format('2099887766'), '99887766');
    expect(format('02099887766'), '99887766');
    expect(format('8562099887766'), '99887766');
    expect(format('+856 20 99 88 77 66'), '99887766');
  });

  test('caps input at the subscriber length', () {
    expect(format('123456789012').length, laoSubscriberDigits);
  });

  test('keeps the caret at the end of the digits', () {
    final value = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(
        text: '2099887766',
        selection: TextSelection.collapsed(offset: 10),
      ),
    );

    expect(value.selection.baseOffset, value.text.length);
  });
}
