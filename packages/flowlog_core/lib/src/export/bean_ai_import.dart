import 'dart:convert';

import '../models/bean.dart';

/// Parsed bean fields from an external AI response (no persistence id).
class BeanAiDraft {
  const BeanAiDraft({
    required this.name,
    this.brand,
    this.origin,
    this.variety,
    this.process,
    this.roastLevel,
    this.roastDate,
    this.stockG,
    this.notes,
  });

  final String name;
  final String? brand;
  final String? origin;
  final String? variety;
  final String? process;
  final String? roastLevel;
  final DateTime? roastDate;
  final double? stockG;
  final String? notes;
}

/// User-facing prompt to copy into any AI chat together with a bag photo.
String buildBeanAiPrompt() {
  final processOptions = kBeanProcessMethods.map((m) => '"$m"').join(' | ');
  final roastOptions = kBeanRoastLevels.map((m) => '"$m"').join(' | ');

  return '''
Here is a picture of a bag of coffee beans. Please read the label and fill out all the information you can in this JSON format.

Output format (important):
Put your entire answer in one markdown code block so it can be copied with a single button. Use a ```json fence. Do not write any text, explanation, or extra code blocks before or after that block.

Include every field below in the JSON object. When information is missing or unclear, follow the rules for that field — do not guess.

Field rules when information is not available:
- name (required): use the main product or blend name on the bag. If no product name is visible, use the roaster name. Never use null.
- brand: roaster or brand name. Use null if not shown or if it is the same as name.
- origin: country, region, or farm printed on the label. Use null if not stated — do not infer from the name alone.
- variety: cultivar or variety (e.g. Yellow Catuai, Bourbon, Gesha). Use null if not stated.
- process: only use one of the allowed values if the label clearly states it. Use null if not stated or ambiguous.
- roastLevel: only use one of the allowed values if the label states light/medium/dark (or equivalent). Use null if not stated — do not estimate from bean color.
- roastDate: roast date printed on the bag as YYYY-MM-DD. Use null if no roast date is printed.
- stockG: bag weight in grams as a number (e.g. 250, 340, 1000). Use null if net weight is not visible.
- notes: tasting notes, altitude, lot number, or other label details. Use null if there is nothing extra to record. Put uncertain or partial details here instead of guessing in other fields.

{
  "name": "product or blend name (required)",
  "brand": "roaster or brand name, or null",
  "origin": "country, region, or farm, or null",
  "variety": "e.g. Yellow Catuai, Bourbon, Gesha, or null",
  "process": $processOptions,
  "roastLevel": $roastOptions,
  "roastDate": "YYYY-MM-DD or null",
  "stockG": "bag weight in grams as a number, or null",
  "notes": "extra label details, or null"
}

Example response (your answer should look like this — one copyable code block only):

```json
{
  "name": "Ethiopia Guji",
  "brand": "Onyx",
  "origin": "Ethiopia",
  "variety": null,
  "process": "Natural",
  "roastLevel": "Light",
  "roastDate": "2026-03-15",
  "stockG": 250,
  "notes": null
}
```
'''.trim();
}

/// Extracts and parses bean fields from an AI chat response.
BeanAiDraft parseBeanAiResponse(String text) {
  final json = _extractJsonObject(text);
  return _parseBeanAiDraft(json);
}

Map<String, dynamic> _extractJsonObject(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Response is empty');
  }

  final fenced = RegExp(
    r'```(?:json)?\s*([\s\S]*?)\s*```',
    caseSensitive: false,
  ).firstMatch(trimmed);
  final candidate = fenced?.group(1)?.trim() ?? trimmed;

  try {
    final decoded = jsonDecode(candidate);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } on FormatException {
    // Fall through to brace extraction.
  }

  final start = candidate.indexOf('{');
  final end = candidate.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('No JSON object found in response');
  }

  final slice = candidate.substring(start, end + 1);
  final decoded = jsonDecode(slice);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  throw const FormatException('Expected a JSON object');
}

BeanAiDraft _parseBeanAiDraft(Map<String, dynamic> json) {
  final name = _optionalString(json['name']);
  if (name == null || name.isEmpty) {
    throw const FormatException('name is required');
  }

  return BeanAiDraft(
    name: name,
    brand: _optionalString(json['brand']),
    origin: _optionalString(json['origin']),
    variety: _optionalString(json['variety']),
    process: _normalizeProcess(_optionalString(json['process'])),
    roastLevel: _normalizeRoastLevel(_optionalString(json['roastLevel'])),
    roastDate: _parseRoastDate(json['roastDate']),
    stockG: _parseStockG(json['stockG']),
    notes: _optionalString(json['notes']),
  );
}

String? _optionalString(Object? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.toString().trim();
  if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
    return null;
  }
  return repairMojibake(trimmed);
}

String? _normalizeRoastLevel(String? value) {
  if (value == null) {
    return null;
  }

  final direct = kBeanRoastLevels.firstWhere(
    (level) => level.toLowerCase() == value.toLowerCase(),
    orElse: () => '',
  );
  if (direct.isNotEmpty) {
    return direct;
  }

  final compact = value.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  for (final level in kBeanRoastLevels) {
    final levelCompact = level.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (levelCompact == compact) {
      return level;
    }
  }

  return null;
}

String? _normalizeProcess(String? value) {
  if (value == null) {
    return null;
  }

  final direct = kBeanProcessMethods.firstWhere(
    (method) => method.toLowerCase() == value.toLowerCase(),
    orElse: () => '',
  );
  if (direct.isNotEmpty) {
    return direct;
  }

  final compact = value.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  for (final method in kBeanProcessMethods) {
    final methodCompact =
        method.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (methodCompact == compact) {
      return method;
    }
  }

  return null;
}

DateTime? _parseRoastDate(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }

    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(trimmed);
    if (iso != null) {
      return DateTime.utc(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    try {
      return DateTime.parse(trimmed).toUtc();
    } on FormatException {
      throw FormatException('Invalid roastDate: $trimmed');
    }
  }

  throw FormatException('Invalid roastDate type: ${value.runtimeType}');
}

double? _parseStockG(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    final grams = value.toDouble();
    if (grams <= 0) {
      throw FormatException('stockG must be positive: $grams');
    }
    return grams;
  }

  if (value is String) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'null') {
      return null;
    }

    final numeric = trimmed.replaceAll(RegExp(r'[^0-9.]'), '');
    if (numeric.isEmpty) {
      throw FormatException('Invalid stockG: $value');
    }

    final grams = double.parse(numeric);
    if (grams <= 0) {
      throw FormatException('stockG must be positive: $grams');
    }
    return grams;
  }

  throw FormatException('Invalid stockG type: ${value.runtimeType}');
}