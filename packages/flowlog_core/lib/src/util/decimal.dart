/// Locale-tolerant decimal parsing for user-typed or imported numbers.
///
/// Many locales (e.g. Norwegian, German) use a comma as the decimal
/// separator and their numeric keyboards emit `,` instead of `.`. Plain
/// [double.tryParse] rejects `18,5`.
library;

/// Parses [input] as a decimal, accepting either `.` or `,` as separator.
/// Returns null for empty or invalid input.
///
/// Thousands grouping is accepted when it is unambiguous:
/// * both separators present (`1.234,5`, `1,234.5`): the last one is the
///   decimal separator and the other must group digits in threes;
/// * the same separator repeated in valid groups of three (`1.234.567`,
///   `1,234,567`).
///
/// A single separator is always a decimal separator, so `1,000` is `1.0`
/// (as a comma-locale keyboard means it) and `18,5` is `18.5`. Spaces,
/// no-break spaces and narrow no-break spaces are ignored (`1 234,5`).
double? parseDecimal(String input) {
  final trimmed = input.trim().replaceAll(_groupingSpaces, '');
  if (trimmed.isEmpty) return null;

  final grouped = _groupedNumber.firstMatch(trimmed);
  if (grouped != null) {
    final sign = grouped.group(1) ?? '';
    final integer = grouped.group(2)!;
    final groupSep = grouped.group(3)!;
    final fraction = grouped.group(4);
    final groupCount = groupSep.allMatches(integer).length;
    final hasOtherDecimal = fraction != null && fraction[0] != groupSep;
    if (hasOtherDecimal || (fraction == null && groupCount >= 2)) {
      final digits = integer.replaceAll(groupSep, '');
      final decimals = fraction == null ? '' : '.${fraction.substring(1)}';
      return double.tryParse('$sign$digits$decimals');
    }
  }

  return double.tryParse(trimmed.replaceAll(',', '.'));
}

final RegExp _groupingSpaces = RegExp('[ \u00A0\u202F]');

/// `[sign] d{1,3} (sep ddd)+ [(.|,) d+]` — the fraction separator is
/// checked against the grouping one in code.
final RegExp _groupedNumber = RegExp(
  r'^([+-]?)(\d{1,3}(?:([.,])\d{3})(?:\3\d{3})*)([.,]\d+)?$',
);

/// Languages whose number format uses `,` as the decimal separator (CLDR).
const Set<String> _commaDecimalLanguages = {
  'af',
  'az',
  'be',
  'bg',
  'bs',
  'ca',
  'cs',
  'da',
  'de',
  'el',
  'es',
  'et',
  'eu',
  'fi',
  'fo',
  'fr',
  'gl',
  'hr',
  'hu',
  'hy',
  'id',
  'is',
  'it',
  'ka',
  'kk',
  'ky',
  'lt',
  'lv',
  'mk',
  'mn',
  'nb',
  'nl',
  'nn',
  'no',
  'pl',
  'pt',
  'ro',
  'ru',
  'se',
  'sk',
  'sl',
  'sq',
  'sr',
  'sv',
  'tr',
  'uk',
  'uz',
  'vi',
};

/// Regions that use `.` even though their language usually uses `,`.
const Set<String> _dotDecimalLocales = {
  'de_CH',
  'de_LI',
  'it_CH',
  'es_MX',
  'es_US',
  'es_PR',
  'es_419',
};

/// Decimal separator (`,` or `.`) for a locale such as `nb`, `nb_NO`,
/// `de-CH` or a POSIX `LANG` value like `nb_NO.UTF-8`.
String decimalSeparatorForLocale(String? locale) {
  if (locale == null || locale.trim().isEmpty) return '.';
  final normalized = locale
      .trim()
      .split('.')
      .first
      .split('@')
      .first
      .replaceAll('-', '_');
  final parts = normalized.split('_');
  final language = parts.first.toLowerCase();
  final region = parts.length > 1 ? parts.last.toUpperCase() : null;
  if (region != null && _dotDecimalLocales.contains('${language}_$region')) {
    return '.';
  }
  return _commaDecimalLanguages.contains(language) ? ',' : '.';
}

/// Formats [value] for an editable number field so it reads back the way
/// the user typed it: whole numbers without `.0`, and [decimalSeparator]
/// (e.g. `,` for Norwegian) instead of `.`. [fractionDigits] fixes the
/// number of decimals. Returns an empty string for null.
///
/// Without [fractionDigits] the value is rounded to
/// [kFormatDecimalMaxFractionDigits] decimals and trailing zeros are
/// trimmed, so float leftovers (`0.1 + 0.2`) read `0.3`. Output is always
/// plain positional notation (never `1e-7` / `1e+21`), and very large
/// values do not overflow. Non-finite values return an empty string.
///
/// Round-trips with [parseDecimal].
String formatDecimal(
  num? value, {
  String decimalSeparator = '.',
  int? fractionDigits,
}) {
  if (value == null) return '';
  if (value is double && !value.isFinite) return '';
  final digits = fractionDigits ?? kFormatDecimalMaxFractionDigits;
  var text = _toPlainFixed(value, digits);
  if (fractionDigits == null && text.contains('.')) {
    text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  if (RegExp(r'^-0(\.0*)?$').hasMatch(text)) {
    text = text.substring(1);
  }
  return decimalSeparator == '.'
      ? text
      : text.replaceAll('.', decimalSeparator);
}

/// Maximum decimals [formatDecimal] keeps when no fixed precision is given.
const int kFormatDecimalMaxFractionDigits = 10;

/// [num.toStringAsFixed] without its exponent form for |value| >= 1e21.
String _toPlainFixed(num value, int fractionDigits) {
  if (value is int) {
    return fractionDigits > 0
        ? '$value.${'0' * fractionDigits}'
        : value.toString();
  }
  final v = value.toDouble();
  if (v.abs() < 1e21) {
    return v.toStringAsFixed(fractionDigits);
  }
  // Doubles this large are integers; BigInt prints them exactly.
  final whole = BigInt.from(v).toString();
  return fractionDigits > 0 ? '$whole.${'0' * fractionDigits}' : whole;
}
