import 'package:flutter/services.dart';

/// Number fields accept numbers only, whatever keyboard or paste the worker uses.

/// Whole numbers such as parcel counts.
final List<TextInputFormatter> wholeNumberFormatters = [
  TextInputFormatter.withFunction(
    (oldValue, newValue) =>
        RegExp(r'^\d{0,6}$').hasMatch(newValue.text) ? newValue : oldValue,
  ),
];

/// Decimal readings such as weight in kg or size in cm: digits, one point, up to [places] decimals.
List<TextInputFormatter> decimalFormatters({int places = 3}) {
  final pattern = RegExp('^\\d{0,7}(\\.\\d{0,$places})?\$');
  return [
    TextInputFormatter.withFunction(
      (oldValue, newValue) =>
          pattern.hasMatch(newValue.text) ? newValue : oldValue,
    ),
  ];
}
