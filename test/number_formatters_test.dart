import 'package:bagoo_scanner_mobile/widgets/number_formatters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String apply(List<TextInputFormatter> formatters, String from, String to) {
  TextEditingValue at(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  var value = at(from);
  for (final formatter in formatters) {
    value = formatter.formatEditUpdate(value, at(to));
  }
  return value.text;
}

void main() {
  test('weights and sizes keep digits and one point only', () {
    final decimal = decimalFormatters();
    expect(apply(decimal, '', '12.5'), '12.5');
    expect(apply(decimal, '', '0.001'), '0.001');
    expect(apply(decimal, '12', '12x'), '12');
    expect(apply(decimal, '1.2', '1.2.'), '1.2');
    expect(apply(decimal, '1.25', '1.2500'), '1.25');
    expect(apply(decimal, '', '-3'), '');
    expect(apply(decimal, '', 'xf'), '');
  });

  test('parcel counts keep whole numbers only', () {
    expect(apply(wholeNumberFormatters, '', '40'), '40');
    expect(apply(wholeNumberFormatters, '4', '4o'), '4');
    expect(apply(wholeNumberFormatters, '4', '4.5'), '4');
    expect(apply(wholeNumberFormatters, '123456', '1234567'), '123456');
  });
}
