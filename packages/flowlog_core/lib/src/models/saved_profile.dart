import 'package:meta/meta.dart';

import 'shot.dart';
import 'shot_sample.dart';

/// A saved pressure profile and shot metadata for one-tap repeat pulls.
@immutable
class SavedProfile {
  const SavedProfile({
    required this.id,
    required this.name,
    required this.createdAt,
    this.sourceShotId,
    this.doseG,
    this.yieldG,
    this.grindSetting,
    this.beanId,
    this.waterTempC,
    this.pressureSamples = const [],
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String? sourceShotId;
  final double? doseG;
  final double? yieldG;
  final double? grindSetting;
  final String? beanId;
  final double? waterTempC;

  /// Pressure curve samples (elapsed ms + bar) captured from a reference shot.
  final List<ShotSample> pressureSamples;

  /// Builds a profile from [shot], keeping pressure samples for overlay.
  factory SavedProfile.fromShot(
    Shot shot, {
    required String id,
    String? name,
    DateTime? createdAt,
  }) {
    final pressureSamples = shot.samples
        .where((sample) => sample.pressureBar != null)
        .map(
          (sample) => ShotSample(
            elapsedMs: sample.elapsedMs,
            pressureBar: sample.pressureBar,
          ),
        )
        .toList();

    return SavedProfile(
      id: id,
      name: name ?? _defaultNameFromShot(shot),
      createdAt: createdAt ?? DateTime.now().toUtc(),
      sourceShotId: shot.id,
      doseG: shot.doseG,
      yieldG: shot.yieldG,
      grindSetting: shot.grindSetting,
      beanId: shot.beanId,
      waterTempC: shot.waterTempC,
      pressureSamples: pressureSamples,
    );
  }

  factory SavedProfile.fromJson(Map<String, dynamic> json) {
    return SavedProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sourceShotId: json['sourceShotId'] as String?,
      doseG: (json['doseG'] as num?)?.toDouble(),
      yieldG: (json['yieldG'] as num?)?.toDouble(),
      grindSetting: (json['grindSetting'] as num?)?.toDouble(),
      beanId: json['beanId'] as String?,
      waterTempC: (json['waterTempC'] as num?)?.toDouble(),
      pressureSamples: (json['pressureSamples'] as List<dynamic>?)
              ?.map((e) => ShotSample.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (sourceShotId != null) 'sourceShotId': sourceShotId,
      if (doseG != null) 'doseG': doseG,
      if (yieldG != null) 'yieldG': yieldG,
      if (grindSetting != null) 'grindSetting': grindSetting,
      if (beanId != null) 'beanId': beanId,
      if (waterTempC != null) 'waterTempC': waterTempC,
      if (pressureSamples.isNotEmpty)
        'pressureSamples':
            pressureSamples.map((sample) => sample.toJson()).toList(),
    };
  }

  SavedProfile copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    String? sourceShotId,
    double? doseG,
    double? yieldG,
    double? grindSetting,
    String? beanId,
    double? waterTempC,
    List<ShotSample>? pressureSamples,
  }) {
    return SavedProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sourceShotId: sourceShotId ?? this.sourceShotId,
      doseG: doseG ?? this.doseG,
      yieldG: yieldG ?? this.yieldG,
      grindSetting: grindSetting ?? this.grindSetting,
      beanId: beanId ?? this.beanId,
      waterTempC: waterTempC ?? this.waterTempC,
      pressureSamples: pressureSamples ?? this.pressureSamples,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SavedProfile &&
            id == other.id &&
            name == other.name &&
            createdAt == other.createdAt &&
            sourceShotId == other.sourceShotId &&
            doseG == other.doseG &&
            yieldG == other.yieldG &&
            grindSetting == other.grindSetting &&
            beanId == other.beanId &&
            waterTempC == other.waterTempC &&
            _listEquals(pressureSamples, other.pressureSamples);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        createdAt,
        sourceShotId,
        doseG,
        yieldG,
        grindSetting,
        beanId,
        waterTempC,
        Object.hashAll(pressureSamples),
      );

  @override
  String toString() =>
      'SavedProfile(id: $id, name: $name, samples: ${pressureSamples.length})';
}

String _defaultNameFromShot(Shot shot) {
  final local = shot.startedAt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return 'Repeat $month-$day $hour:$minute';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Generates a unique saved-profile id.
String generateProfileId() {
  return 'profile-${DateTime.now().toUtc().millisecondsSinceEpoch}';
}