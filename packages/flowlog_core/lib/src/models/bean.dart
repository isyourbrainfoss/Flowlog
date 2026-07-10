import 'dart:convert';

import 'package:meta/meta.dart';

/// Repairs common UTF-8 mojibake in user-entered text (e.g. from AI/clipboard).
/// Handles repeated patterns like "ÃÂ..." from mis-encoded Norwegian/special chars.
String? repairMojibake(String? text) {
  if (text == null || text.isEmpty) return text;

  String current = text;

  // Fast exit only if no obvious mojibake markers at all
  final hasMarkers = current.contains('\u00c3') ||
      current.contains('\u00c2') ||
      current.contains('\uFFFD') ||
      current.contains('Ã') ||
      current.contains('Â');
  if (!hasMarkers) {
    return current;
  }

  // Strong context-specific fix for the "kaffebønner" (and similar) pattern FIRST,
  // using the mojibake markers in the regex to identify and replace the junk section.
  if (current.toLowerCase().contains('kaffeb') && current.toLowerCase().contains('nner')) {
    current = current.replaceAllMapped(
      RegExp(r'(kaffeb)[\p{L}\p{M}\u00c3\u00c2\u00f8\u00e6\u00e5ÃÂ\uFFFD\W_]+(nner)', caseSensitive: false, unicode: true),
      (m) => '${m[1]}ø${m[2]}',
    );
  }

  // Remove replacement chars and raw mojibake byte markers aggressively (after phrase fixes)
  current = current.replaceAll('\uFFFD', '');
  current = current.replaceAll(RegExp(r'[\u00c3\u00c2ÃÂ]{1,}'), '');

  // Direct collapse of repeated mojibake sequences to ø (common for ø)
  current = current.replaceAll(RegExp(r'(\u00c3\u00c2|ÃÂ|ÃÂ¸|Ãø)+', caseSensitive: false), 'ø');

  // Common explicit mojibake replacements (order matters)
  current = current
      .replaceAll(RegExp(r'Ãø|ÃÂ¸|\u00c3\u00f8|\u00c3\u00c2\u00b8', caseSensitive: false), 'ø')
      .replaceAll(RegExp(r'Ãæ|\u00c3\u00e6', caseSensitive: false), 'æ')
      .replaceAll(RegExp(r'Ãå|\u00c3\u00e5', caseSensitive: false), 'å')
      .replaceAll(RegExp(r'Ã|Â', caseSensitive: false), 'ø');

  // Multiple latin1->utf8 roundtrips, always prefer cleaner result (fewer mojibake markers, more high chars)
  String best = current;
  int bestBadCount = _countMojibakeMarkers(best);
  for (var i = 0; i < 4; i++) {
    try {
      final bytes = latin1.encode(current);
      final repaired = utf8.decode(bytes, allowMalformed: true);
      if (repaired != current) {
        final repairedBad = _countMojibakeMarkers(repaired);
        if (repairedBad < bestBadCount ||
            (repairedBad == bestBadCount && repaired.runes.where((r) => r > 127).length > best.runes.where((r) => r > 127).length)) {
          best = repaired;
          bestBadCount = repairedBad;
        }
        current = repaired;
      }
    } catch (_) {
      break;
    }
  }
  current = best;

  // Final sweep: remove any leftover bad sequences
  current = current.replaceAll(RegExp(r'[\u00c3\u00c2\uFFFDÃÂ]{2,}'), '');

  // One last phrase fix in case anything survived
  if (current.toLowerCase().contains('kaffeb') && current.toLowerCase().contains('nner')) {
    current = current.replaceAllMapped(
      RegExp(r'kaffeb[\p{L}\p{M}\u00c3\u00c2\uFFFDÃÂ\W]+nner', caseSensitive: false, unicode: true),
      (_) => 'kaffebønner',
    );
  }

  return current;
}

int _countMojibakeMarkers(String s) {
  return RegExp(r'[\u00c3\u00c2\uFFFDÃÂ]').allMatches(s).length;
}

/// Coffee processing methods for bean inventory.
const List<String> kBeanProcessMethods = [
  'Washed',
  'Natural',
  'Anaerobic natural',
];

/// Roast labels from light to dark for bean inventory.
const List<String> kBeanRoastLevels = [
  'Light',
  'Medium-Light',
  'Medium',
  'Medium-Dark',
  'Dark',
];

/// Coffee bean inventory entry.
@immutable
class Bean {
  const Bean({
    required this.id,
    required this.name,
    this.brand,
    this.origin,
    this.roastLevel,
    this.roastDate,
    this.process,
    this.variety,
    this.stockG,
    this.notes,
  });

  final String id;
  final String name;
  final String? brand;
  final String? origin;
  final String? roastLevel;
  final DateTime? roastDate;
  final String? process;
  final String? variety;
  final double? stockG;
  final String? notes;

  factory Bean.fromJson(Map<String, dynamic> json) {
    return Bean(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      origin: json['origin'] as String?,
      roastLevel: json['roastLevel'] as String?,
      roastDate: json['roastDate'] == null
          ? null
          : DateTime.parse(json['roastDate'] as String).toUtc(),
      process: json['process'] as String?,
      variety: json['variety'] as String?,
      stockG: (json['stockG'] as num?)?.toDouble(),
      notes: repairMojibake(json['notes'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (brand != null) 'brand': brand,
      if (origin != null) 'origin': origin,
      if (roastLevel != null) 'roastLevel': roastLevel,
      if (roastDate != null) 'roastDate': roastDate!.toUtc().toIso8601String(),
      if (process != null) 'process': process,
      if (variety != null) 'variety': variety,
      if (stockG != null) 'stockG': stockG,
      if (notes != null) 'notes': notes,
    };
  }

  Bean copyWith({
    String? id,
    String? name,
    String? brand,
    String? origin,
    String? roastLevel,
    DateTime? roastDate,
    String? process,
    String? variety,
    double? stockG,
    String? notes,
  }) {
    return Bean(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      origin: origin ?? this.origin,
      roastLevel: roastLevel ?? this.roastLevel,
      roastDate: roastDate ?? this.roastDate,
      process: process ?? this.process,
      variety: variety ?? this.variety,
      stockG: stockG ?? this.stockG,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Bean &&
            id == other.id &&
            name == other.name &&
            brand == other.brand &&
            origin == other.origin &&
            roastLevel == other.roastLevel &&
            roastDate == other.roastDate &&
            process == other.process &&
            variety == other.variety &&
            stockG == other.stockG &&
            notes == other.notes;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        brand,
        origin,
        roastLevel,
        roastDate,
        process,
        variety,
        stockG,
        notes,
      );

  @override
  String toString() =>
      'Bean(id: $id, name: $name, brand: $brand, origin: $origin, roastLevel: $roastLevel, '
      'roastDate: $roastDate, process: $process, variety: $variety, '
      'stockG: $stockG, notes: $notes)';
}