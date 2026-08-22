import 'dart:convert';

import 'package:meta/meta.dart';

/// Repairs UTF-8 mojibake in user-entered text (AI/clipboard/sync).
///
/// Typical corruption path (can repeat many times):
///   "ø" → UTF-8 bytes C3 B8 read as Latin-1 → "Ã¸" → re-encoded again…
/// after N rounds the string is thousands of `ÃÂ…` chars (see Flatpak DB
/// beans like "Oslo Mørkbrent" / "José Espinoza").
///
/// Strategy:
/// 1. Prefer repeated latin1→utf8 decoding while the string shrinks / gets
///    cleaner (this undoes multi-layer double-encoding losslessly).
/// 2. Only then apply phrase-level fixes for known Norwegian words.
/// 3. Never blindly strip every Ã/Â or map them all to ø (that turns
///    "MÃ¸rkbrent" into "M¸rkbrent" and destroys recoverable data).
String? repairMojibake(String? text) {
  if (text == null || text.isEmpty) return text;

  var current = text;

  // Phrase fixes first (cheap, safe) for cases where ø was destroyed to ¸.
  current = _applyPhraseFixes(current);

  if (!_looksLikeMojibake(current)) {
    return current;
  }

  // 1) Undo multi-layer "UTF-8 bytes as Latin-1" corruption.
  var best = current;
  var bestScore = _mojibakeScore(best);
  for (var i = 0; i < 16; i++) {
    try {
      final bytes = latin1.encode(current);
      final repaired = utf8.decode(bytes, allowMalformed: true);
      if (repaired == current) {
        break;
      }
      final score = _mojibakeScore(repaired);
      // Prefer fewer markers; on ties prefer shorter (layer peel) then more
      // legitimate high-bit letters.
      if (score < bestScore ||
          (score == bestScore && repaired.length < best.length) ||
          (score == bestScore &&
              repaired.length == best.length &&
              _countLettersAbove127(repaired) > _countLettersAbove127(best))) {
        best = repaired;
        bestScore = score;
      }
      current = repaired;
      if (!_looksLikeMojibake(current)) {
        break;
      }
    } on ArgumentError {
      // latin1.encode throws if any code unit > 255.
      break;
    } on Object {
      break;
    }
  }
  current = best;

  // 2) Replacement-char only gaps (clipboard dropped bytes).
  if (current.contains('\uFFFD')) {
    current = current.replaceAll('\uFFFD', '');
  }

  // 3) Phrase fixes again after peeling layers.
  current = _applyPhraseFixes(current);

  // 4) If still a long run of mojibake markers between letters, drop the run.
  current = current.replaceAll(
    RegExp(r'[\u00c3\u00c2ÃÂ]{4,}'),
    '',
  );

  // Collapse whitespace left by stripping.
  current = current.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return current;
}

String _applyPhraseFixes(String current) {
  return current
      .replaceAll(RegExp(r'M[\u00b8]rkbrent', caseSensitive: false), 'Mørkbrent')
      .replaceAll(
        RegExp(r'kaffeb[\u00b8]?nner', caseSensitive: false),
        'kaffebønner',
      );
}

bool _looksLikeMojibake(String s) {
  if (s.contains('\uFFFD')) return true;
  // Multi-layer growth leaves many U+00C3 (Ã) / U+00C2 (Â).
  final markers = _countMojibakeMarkers(s);
  if (markers >= 2) return true;
  // Single-layer classic: "Ã¸" "Ã©" etc.
  if (s.contains('Ã') || s.contains('Â')) return true;
  return false;
}

int _mojibakeScore(String s) {
  // Weighted: long marker runs are much worse than a single accented letter.
  final markers = _countMojibakeMarkers(s);
  final runBonus = RegExp(r'[\u00c3\u00c2ÃÂ]{3,}')
      .allMatches(s)
      .fold<int>(0, (sum, m) => sum + m.group(0)!.length);
  return markers * 2 + runBonus * 3 + (s.length > 80 ? s.length ~/ 10 : 0);
}

int _countMojibakeMarkers(String s) {
  return RegExp(r'[\u00c3\u00c2\uFFFDÃÂ]').allMatches(s).length;
}

/// Case-folds and strips diacritics for cross-platform bean search.
///
/// Android SQLite `LIKE` / `lower()` only fold ASCII, so "mørkbrent" never
/// matched "Mørkbrent". Dart search is Unicode-aware and also repairs
/// mojibake so a synced dirty name still matches what the UI shows.
String foldForSearch(String input) {
  final repaired = repairMojibake(input) ?? input;
  final buf = StringBuffer();
  for (final r in repaired.toLowerCase().runes) {
    if (r >= 0x300 && r <= 0x36F) {
      continue;
    }
    buf.write(_searchFoldMap[r] ?? String.fromCharCode(r));
  }
  return buf.toString();
}

const Map<int, String> _searchFoldMap = {
  0xE5: 'a', // å
  0xE4: 'a', // ä
  0xE1: 'a',
  0xE0: 'a',
  0xE6: 'ae', // æ
  0xE9: 'e',
  0xE8: 'e',
  0xEA: 'e',
  0xEB: 'e',
  0xED: 'i',
  0xEC: 'i',
  0xEF: 'i',
  0xF8: 'o', // ø
  0xF6: 'o', // ö
  0xF3: 'o',
  0xF2: 'o',
  0xFA: 'u',
  0xF9: 'u',
  0xFC: 'u',
  0xF1: 'n',
  0xE7: 'c',
};

/// True when [query] matches [bean] id, name, brand, origin, variety, or notes.
bool beanMatchesQuery(Bean bean, String query) {
  final q = foldForSearch(query).trim();
  if (q.isEmpty) {
    return true;
  }
  final cleaned = bean.repaired();
  final haystack = foldForSearch(
    [
      cleaned.id,
      cleaned.name,
      cleaned.brand,
      cleaned.origin,
      cleaned.variety,
      cleaned.process,
      cleaned.notes,
    ].whereType<String>().join(' '),
  );
  return haystack.contains(q);
}

int _countLettersAbove127(String s) {
  var n = 0;
  for (final r in s.runes) {
    if (r > 127 && r != 0xC2 && r != 0xC3 && r != 0xFFFD) {
      n++;
    }
  }
  return n;
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
      name: repairMojibake(json['name'] as String?) ?? '',
      brand: repairMojibake(json['brand'] as String?),
      origin: repairMojibake(json['origin'] as String?),
      roastLevel: json['roastLevel'] as String?,
      roastDate: json['roastDate'] == null
          ? null
          : DateTime.parse(json['roastDate'] as String).toUtc(),
      process: json['process'] as String?,
      variety: repairMojibake(json['variety'] as String?),
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

  /// Returns a copy with [repairMojibake] applied to all free-text fields.
  Bean repaired() {
    return Bean(
      id: id,
      name: repairMojibake(name) ?? name,
      brand: repairMojibake(brand),
      origin: repairMojibake(origin),
      roastLevel: roastLevel,
      roastDate: roastDate,
      process: process,
      variety: repairMojibake(variety),
      stockG: stockG,
      notes: repairMojibake(notes),
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
  String toString() => 'Bean(id: $id, name: $name, brand: $brand)';
}
