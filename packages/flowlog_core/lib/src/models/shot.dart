import 'package:meta/meta.dart';

import 'shot_sample.dart';

/// A recorded espresso pull with metadata and optional inline samples.
@immutable
class Shot {
  const Shot({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.doseG,
    this.yieldG,
    this.grindSetting,
    this.beanId,
    this.waterTempC,
    this.notes,
    this.tasteScore,
    this.flavourTags = const [],
    this.samples = const [],
  }) : assert(
          tasteScore == null || (tasteScore >= 0 && tasteScore <= 10),
          'tasteScore must be between 0 and 10',
        );

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double? doseG;
  final double? yieldG;
  final double? grindSetting;
  final String? beanId;
  final double? waterTempC;
  final String? notes;
  final int? tasteScore;
  final List<String> flavourTags;
  final List<ShotSample> samples;

  factory Shot.fromJson(Map<String, dynamic> json) {
    return Shot(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      doseG: (json['doseG'] as num?)?.toDouble(),
      yieldG: (json['yieldG'] as num?)?.toDouble(),
      grindSetting: (json['grindSetting'] as num?)?.toDouble(),
      beanId: json['beanId'] as String?,
      waterTempC: (json['waterTempC'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      tasteScore: json['tasteScore'] as int?,
      flavourTags: (json['flavourTags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      samples: (json['samples'] as List<dynamic>?)
              ?.map((e) => ShotSample.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startedAt': startedAt.toUtc().toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
      if (doseG != null) 'doseG': doseG,
      if (yieldG != null) 'yieldG': yieldG,
      if (grindSetting != null) 'grindSetting': grindSetting,
      if (beanId != null) 'beanId': beanId,
      if (waterTempC != null) 'waterTempC': waterTempC,
      if (notes != null) 'notes': notes,
      if (tasteScore != null) 'tasteScore': tasteScore,
      if (flavourTags.isNotEmpty) 'flavourTags': flavourTags,
      if (samples.isNotEmpty)
        'samples': samples.map((s) => s.toJson()).toList(),
    };
  }

  Shot copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    double? doseG,
    double? yieldG,
    double? grindSetting,
    String? beanId,
    double? waterTempC,
    String? notes,
    int? tasteScore,
    List<String>? flavourTags,
    List<ShotSample>? samples,
  }) {
    return Shot(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      doseG: doseG ?? this.doseG,
      yieldG: yieldG ?? this.yieldG,
      grindSetting: grindSetting ?? this.grindSetting,
      beanId: beanId ?? this.beanId,
      waterTempC: waterTempC ?? this.waterTempC,
      notes: notes ?? this.notes,
      tasteScore: tasteScore ?? this.tasteScore,
      flavourTags: flavourTags ?? this.flavourTags,
      samples: samples ?? this.samples,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Shot &&
            id == other.id &&
            startedAt == other.startedAt &&
            endedAt == other.endedAt &&
            doseG == other.doseG &&
            yieldG == other.yieldG &&
            grindSetting == other.grindSetting &&
            beanId == other.beanId &&
            waterTempC == other.waterTempC &&
            notes == other.notes &&
            tasteScore == other.tasteScore &&
            _listEquals(flavourTags, other.flavourTags) &&
            _listEquals(samples, other.samples);
  }

  @override
  int get hashCode => Object.hash(
        id,
        startedAt,
        endedAt,
        doseG,
        yieldG,
        grindSetting,
        beanId,
        waterTempC,
        notes,
        tasteScore,
        Object.hashAll(flavourTags),
        Object.hashAll(samples),
      );

  @override
  String toString() =>
      'Shot(id: $id, startedAt: $startedAt, endedAt: $endedAt, '
      'doseG: $doseG, yieldG: $yieldG, samples: ${samples.length})';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}