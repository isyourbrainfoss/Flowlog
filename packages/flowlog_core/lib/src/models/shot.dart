import 'dart:convert';

import 'package:meta/meta.dart';

import 'bean.dart' show repairMojibake;

import 'flavour_intensities.dart';
import 'shot_annotation.dart';
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
    this.location,
    this.latitude,
    this.longitude,
    this.tasteScore,
    this.flavourTags = const [],
    this.flavourIntensities = const {},
    this.coffeejackRewindTurns,
    this.coffeejackPreinfusionTurns,
    this.grinder,
    this.showerScreen,
    this.basket,
    this.scale,
    this.brewer,
    this.lastModifiedAt,
    this.autoStartPressureBar,
    this.samples = const [],
    this.annotations = const [],
    this.targetClosenessPercent,
    this.targetMaxStreakSeconds,
    this.targetScore,
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
  final String? location;
  final double? latitude;
  final double? longitude;
  final int? tasteScore;
  final List<String> flavourTags;
  final Map<String, int> flavourIntensities;
  final int? coffeejackRewindTurns;
  final int? coffeejackPreinfusionTurns;
  final String? grinder;
  final String? showerScreen;
  final String? basket;
  final String? scale;
  final String? brewer;
  final DateTime? lastModifiedAt;
  final double? autoStartPressureBar;
  final List<ShotSample> samples;
  final List<ShotAnnotation> annotations;

  /// Gamification fields for target curve closeness.
  final double? targetClosenessPercent;
  final int? targetMaxStreakSeconds;
  final double? targetScore;

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
      notes: repairMojibake(json['notes'] as String?),
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      tasteScore: json['tasteScore'] as int?,
      coffeejackRewindTurns: (json['coffeejackRewindTurns'] as num?)?.toInt(),
      coffeejackPreinfusionTurns:
          (json['coffeejackPreinfusionTurns'] as num?)?.toInt(),
      grinder: json['grinder'] as String?,
      showerScreen: json['showerScreen'] as String?,
      basket: json['basket'] as String?,
      scale: json['scale'] as String?,
      brewer: json['brewer'] as String?,
      lastModifiedAt: json['lastModifiedAt'] == null
          ? null
          : DateTime.parse(json['lastModifiedAt'] as String),
      autoStartPressureBar: (json['autoStartPressureBar'] as num?)?.toDouble(),
      targetClosenessPercent: (json['targetClosenessPercent'] as num?)?.toDouble(),
      targetMaxStreakSeconds: (json['targetMaxStreakSeconds'] as num?)?.toInt(),
      targetScore: (json['targetScore'] as num?)?.toDouble(),
      flavourTags: (json['flavourTags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      flavourIntensities: _flavourIntensitiesFromJson(json['flavourIntensities']),
      samples: (json['samples'] as List<dynamic>?)
              ?.map((e) => ShotSample.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      annotations: (json['annotations'] as List<dynamic>?)
              ?.map((e) => ShotAnnotation.fromJson(e as Map<String, dynamic>))
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
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (tasteScore != null) 'tasteScore': tasteScore,
      if (coffeejackRewindTurns != null)
        'coffeejackRewindTurns': coffeejackRewindTurns,
      if (coffeejackPreinfusionTurns != null)
        'coffeejackPreinfusionTurns': coffeejackPreinfusionTurns,
      if (grinder != null) 'grinder': grinder,
      if (showerScreen != null) 'showerScreen': showerScreen,
      if (basket != null) 'basket': basket,
      if (scale != null) 'scale': scale,
      if (brewer != null) 'brewer': brewer,
      if (lastModifiedAt != null)
        'lastModifiedAt': lastModifiedAt!.toUtc().toIso8601String(),
      if (autoStartPressureBar != null)
        'autoStartPressureBar': autoStartPressureBar,
      if (targetClosenessPercent != null)
        'targetClosenessPercent': targetClosenessPercent,
      if (targetMaxStreakSeconds != null)
        'targetMaxStreakSeconds': targetMaxStreakSeconds,
      if (targetScore != null) 'targetScore': targetScore,
      if (flavourTags.isNotEmpty) 'flavourTags': flavourTags,
      if (flavourIntensities.isNotEmpty)
        'flavourIntensities': flavourIntensities,
      if (samples.isNotEmpty)
        'samples': samples.map((s) => s.toJson()).toList(),
      if (annotations.isNotEmpty)
        'annotations': annotations.map((a) => a.toJson()).toList(),
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
    String? location,
    double? latitude,
    double? longitude,
    int? tasteScore,
    List<String>? flavourTags,
    Map<String, int>? flavourIntensities,
    int? coffeejackRewindTurns,
    int? coffeejackPreinfusionTurns,
    String? grinder,
    String? showerScreen,
    String? basket,
    String? scale,
    String? brewer,
    DateTime? lastModifiedAt,
    double? autoStartPressureBar,
    List<ShotSample>? samples,
    List<ShotAnnotation>? annotations,
    double? targetClosenessPercent,
    int? targetMaxStreakSeconds,
    double? targetScore,
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
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tasteScore: tasteScore ?? this.tasteScore,
      flavourTags: flavourTags ?? this.flavourTags,
      flavourIntensities: flavourIntensities ?? this.flavourIntensities,
      coffeejackRewindTurns:
          coffeejackRewindTurns ?? this.coffeejackRewindTurns,
      coffeejackPreinfusionTurns:
          coffeejackPreinfusionTurns ?? this.coffeejackPreinfusionTurns,
      grinder: grinder ?? this.grinder,
      showerScreen: showerScreen ?? this.showerScreen,
      basket: basket ?? this.basket,
      scale: scale ?? this.scale,
      brewer: brewer ?? this.brewer,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      autoStartPressureBar: autoStartPressureBar ?? this.autoStartPressureBar,
      samples: samples ?? this.samples,
      annotations: annotations ?? this.annotations,
      targetClosenessPercent: targetClosenessPercent ?? this.targetClosenessPercent,
      targetMaxStreakSeconds: targetMaxStreakSeconds ?? this.targetMaxStreakSeconds,
      targetScore: targetScore ?? this.targetScore,
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
            location == other.location &&
            latitude == other.latitude &&
            longitude == other.longitude &&
            tasteScore == other.tasteScore &&
            coffeejackRewindTurns == other.coffeejackRewindTurns &&
            coffeejackPreinfusionTurns == other.coffeejackPreinfusionTurns &&
            grinder == other.grinder &&
            showerScreen == other.showerScreen &&
            basket == other.basket &&
            scale == other.scale &&
            brewer == other.brewer &&
            lastModifiedAt == other.lastModifiedAt &&
            autoStartPressureBar == other.autoStartPressureBar &&
            targetClosenessPercent == other.targetClosenessPercent &&
            targetMaxStreakSeconds == other.targetMaxStreakSeconds &&
            targetScore == other.targetScore &&
            _listEquals(flavourTags, other.flavourTags) &&
            _mapEquals(flavourIntensities, other.flavourIntensities) &&
            _listEquals(samples, other.samples) &&
            _listEquals(annotations, other.annotations);
  }

  @override
  int get hashCode => Object.hash(
        id,
        startedAt,
        endedAt,
        doseG,
        yieldG,
        grindSetting,
        autoStartPressureBar,
        beanId,
        waterTempC,
        notes,
        location,
        latitude,
        longitude,
        tasteScore,
        coffeejackRewindTurns,
        coffeejackPreinfusionTurns,
        grinder,
        showerScreen,
        Object.hash(
          basket,
          scale,
          brewer,
          lastModifiedAt,
          targetClosenessPercent,
          targetMaxStreakSeconds,
          targetScore,
          Object.hashAll(flavourTags),
          Object.hashAll(flavourIntensities.entries),
          Object.hashAll(samples),
          Object.hashAll(annotations),
        ),
      );

  @override
  String toString() =>
      'Shot(id: $id, startedAt: $startedAt, endedAt: $endedAt, '
      'doseG: $doseG, yieldG: $yieldG, samples: ${samples.length})';
}

Map<String, int> _flavourIntensitiesFromJson(Object? raw) {
  if (raw is! Map) {
    return const {};
  }
  final result = <String, int>{};
  for (final entry in raw.entries) {
    final tag = entry.key;
    final value = entry.value;
    if (tag is! String || value is! num) {
      continue;
    }
    result[tag] = clampFlavourIntensity(value.round());
  }
  return result;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, int> a, Map<String, int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}