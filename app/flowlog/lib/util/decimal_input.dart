/// Shared locale-tolerant decimal parsing and formatting (see flowlog_core).
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:flowlog_core/flowlog_core.dart';

export 'package:flowlog_core/flowlog_core.dart'
    show decimalSeparatorForLocale, formatDecimal, parseDecimal;

/// Overrides the device decimal separator (tests).
String? debugDecimalSeparatorOverride;

/// Decimal separator of the device locale: `,` for e.g. Norwegian.
String deviceDecimalSeparator() {
  final override = debugDecimalSeparatorOverride;
  if (override != null) return override;
  return decimalSeparatorForLocale(
    PlatformDispatcher.instance.locale.toString(),
  );
}

/// Formats [value] for a number text field in the device's decimal style, so
/// a dose typed as `18,5` is shown back as `18,5` (not `18.5`).
String formatDecimalInput(num? value, {int? fractionDigits}) {
  return formatDecimal(
    value,
    decimalSeparator: deviceDecimalSeparator(),
    fractionDigits: fractionDigits,
  );
}
