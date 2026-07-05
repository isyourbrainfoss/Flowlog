import 'package:meta/meta.dart';

/// Coffee processing methods for bean inventory.
const List<String> kBeanProcessMethods = [
  'Washed',
  'Natural',
  'Anaerobic natural',
];

/// Coffee bean inventory entry.
@immutable
class Bean {
  const Bean({
    required this.id,
    required this.name,
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
      origin: json['origin'] as String?,
      roastLevel: json['roastLevel'] as String?,
      roastDate: json['roastDate'] == null
          ? null
          : DateTime.parse(json['roastDate'] as String).toUtc(),
      process: json['process'] as String?,
      variety: json['variety'] as String?,
      stockG: (json['stockG'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
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
      'Bean(id: $id, name: $name, origin: $origin, roastLevel: $roastLevel, '
      'roastDate: $roastDate, process: $process, variety: $variety, '
      'stockG: $stockG, notes: $notes)';
}