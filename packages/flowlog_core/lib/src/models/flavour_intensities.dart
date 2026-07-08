import 'dart:convert';

/// Default intensity when a flavour tag is selected without an explicit rating.
const int kDefaultFlavourIntensity = 5;

/// Minimum per-flavour intensity (1 = barely there).
const int kMinFlavourIntensity = 1;

/// Maximum per-flavour intensity.
const int kMaxFlavourIntensity = 10;

/// Clamps [value] to the valid per-flavour intensity range.
int clampFlavourIntensity(int value) {
  return value.clamp(kMinFlavourIntensity, kMaxFlavourIntensity);
}

/// Decodes a JSON object of tag → intensity from SQLite or JSON export.
Map<String, int> decodeFlavourIntensities(String? jsonText) {
  if (jsonText == null || jsonText.isEmpty || jsonText == '{}') {
    return const {};
  }

  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    return const {};
  }

  final result = <String, int>{};
  for (final entry in decoded.entries) {
    final tag = entry.key;
    final value = entry.value;
    if (tag is! String || value is! num) {
      continue;
    }
    result[tag] = clampFlavourIntensity(value.round());
  }
  return result;
}

/// Encodes [intensities] as a compact JSON object for persistence.
String encodeFlavourIntensities(Map<String, int> intensities) {
  if (intensities.isEmpty) {
    return '{}';
  }

  final sortedKeys = intensities.keys.toList()..sort();
  final normalized = {
    for (final tag in sortedKeys) tag: clampFlavourIntensity(intensities[tag]!),
  };
  return jsonEncode(normalized);
}

/// Parses `chocolate:7;nutty:5` from CSV metadata.
Map<String, int> parseFlavourIntensitiesCsv(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const {};
  }

  final result = <String, int>{};
  for (final part in raw.split(';')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final separator = trimmed.lastIndexOf(':');
    if (separator <= 0 || separator >= trimmed.length - 1) {
      continue;
    }
    final tag = trimmed.substring(0, separator).trim().toLowerCase();
    final value = int.tryParse(trimmed.substring(separator + 1).trim());
    if (tag.isEmpty || value == null) {
      continue;
    }
    result[tag] = clampFlavourIntensity(value);
  }
  return result;
}

/// Serializes [intensities] for CSV export.
String formatFlavourIntensitiesCsv(Map<String, int> intensities) {
  if (intensities.isEmpty) {
    return '';
  }
  final tags = intensities.keys.toList()..sort();
  return tags
      .map((tag) => '$tag:${clampFlavourIntensity(intensities[tag]!)}')
      .join(';');
}

/// Keeps only selected tags and fills missing values with [kDefaultFlavourIntensity].
Map<String, int> normalizeFlavourIntensities({
  required Iterable<String> selectedTags,
  Map<String, int>? intensities,
}) {
  final source = intensities ?? const {};
  final result = <String, int>{};
  for (final tag in selectedTags) {
    result[tag] = clampFlavourIntensity(
      source[tag] ?? kDefaultFlavourIntensity,
    );
  }
  return result;
}

/// Resolved intensity for [tag] when present in [tags].
int? flavourIntensityForTag({
  required String tag,
  required List<String> tags,
  Map<String, int>? intensities,
}) {
  if (!tags.contains(tag)) {
    return null;
  }
  return clampFlavourIntensity(
    intensities?[tag] ?? kDefaultFlavourIntensity,
  );
}

/// Sorted flavour tags for display.
List<String> sortedFlavourTags(Iterable<String> tags) {
  return tags.toList()..sort();
}

/// Human-readable intensities, e.g. `chocolate 7, nutty 5`.
String formatFlavourProfileSummary({
  required List<String> tags,
  Map<String, int>? intensities,
}) {
  if (tags.isEmpty) {
    return '—';
  }
  return sortedFlavourTags(tags)
      .map(
        (tag) =>
            '$tag ${flavourIntensityForTag(tag: tag, tags: tags, intensities: intensities)}',
      )
      .join(', ');
}