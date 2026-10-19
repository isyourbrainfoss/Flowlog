/// Locale-tolerant decimal parsing for user-typed or imported numbers.
///
/// Many locales (e.g. Norwegian, German) use a comma as the decimal
/// separator and their numeric keyboards emit `,` instead of `.`. Plain
/// [double.tryParse] rejects `18,5`.
library;

/// Parses [input] as a decimal, accepting either `.` or `,` as separator.
/// Returns null for empty or invalid input.
double? parseDecimal(String input) {
  final trimmed = input.trim().replaceAll(' ', '');
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed.replaceAll(',', '.'));
}

/// Languages whose number format uses `,` as the decimal separator (CLDR).
const Set<String> _commaDecimalLanguages = {
  'af', 'az', 'be', 'bg', 'bs', 'ca', 'cs', 'da', 'de', 'el', 'es', 'et',
  'eu', 'fi', 'fo', 'fr', 'gl', 'hr', 'hu', 'hy', 'id', 'is', 'it', 'ka',
  'kk', 'ky', 'lt', 'lv', 'mk', 'mn', 'nb', 'nl', 'nn', 'no', 'pl', 'pt',
  'ro', 'ru', 'se', 'sk', 'sl', 'sq', 'sr', 'sv', 'tr', 'uk', 'uz', 'vi',
};

/// Regions that use `.` even though their language usually uses `,`.
const Set<String> _dotDecimalLocales = {
  'de_CH', 'de_LI', 'it_CH', 'es_MX', 'es_US', 'es_PR', 'es_419',
};

/// Decimal separator (`,` or `.`) for a locale such as `nb`, `nb_NO`,
/// `de-CH` or a POSIX `LANG` value like `nb_NO.UTF-8`.
String decimalSeparatorForLocale(String? locale) {
  if (locale == null || locale.trim().isEmpty) return '.';
  final normalized = locale.trim().split('.').first.split('@').first
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
/// Round-trips with [parseDecimal].
String formatDecimal(
  num? value, {
  String decimalSeparator = '.',
  int? fractionDigits,
}) {
  if (value == null) return '';
  final String text;
  if (fractionDigits != null) {
    text = value.toStringAsFixed(fractionDigits);
  } else if (value is int || value == value.roundToDouble()) {
    text = value.round().toString();
  } else {
    text = value.toString();
  }
  return decimalSeparator == '.' ? text : text.replaceAll('.', decimalSeparator);
}
