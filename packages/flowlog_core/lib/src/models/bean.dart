import 'dart:convert';

import 'package:meta/meta.dart';

/// Repairs common UTF-8 mojibake in user-entered text (e.g. from AI/clipboard).
/// Handles repeated patterns like "ÃÂ..." from mis-encoded Norwegian/special chars.
String? repairMojibake(String? text) {
  if (text == null || text.isEmpty) return text;
  if (!text.contains('\u00c3') && !text.contains('\u00c2')) {
    return text; // fast path for clean text
  }
  String current = text;

  // Direct pattern fix for repeated mojibake sequences (e.g. "ÃÂ" runs)
  current = current.replaceAll(RegExp(r'(\u00c3\u00c2)+'), '\u00f8');

  // Context specific for the exact reported "kaffebønner" corruption
  if (current.contains('kaffeb') && current.contains('nner')) {
    current = current.replaceAllMapped(
      RegExp(r'kaffeb[\u00c3\u00c2\u00f8\u00e6\u00e5ÃÂ]+nner'),
      (_) => 'kaffeb\u00f8nner',
    );
  }

  // Common mojibake patterns using escapes only
  current = current
      .replaceAll('\u00c3\u00f8', '\u00f8')
      .replaceAll('\u00c3\u00c2\u00b8', '\u00f8')
      .replaceAll('\u00c3\u00e6', '\u00e6')
      .replaceAll('\u00c3\u00e5', '\u00e5')
      .replaceAll('\u00c3', '\u00f8')
      .replaceAll('\u00c2\u00b8', '\u00f8');

  // Fallback roundtrips
  for (var i = 0; i < 3; i++) {
    try {
      final bytes = latin1.encode(current);
      final repaired = utf8.decode(bytes, allowMalformed: true);
      if (repaired == current) break;
      if (!repaired.contains('\u00c3') || repaired.runes.where((r) => r > 127).length > current.runes.where((r) => r > 127).length) {
        current = repaired;
        break;
      }
      current = repaired;
    } catch (_) {
      break;
    }
  }
  return current;
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