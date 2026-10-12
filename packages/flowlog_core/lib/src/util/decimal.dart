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
