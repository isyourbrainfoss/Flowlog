import 'dart:convert';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog/sensors/sensor_kind.dart';

/// Serialized paired sensor entry for persistence across app restarts.
class PairedSensorRecord {
  const PairedSensorRecord({
    required this.id,
    required this.name,
    required this.kind,
    this.bleRemoteId,
  });

  final String id;
  final String name;
  final SensorKind kind;
  final String? bleRemoteId;

  factory PairedSensorRecord.fromJson(Map<String, dynamic> json) {
    return PairedSensorRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: _kindFromString(json['kind'] as String?) ?? SensorKind.pressensor,
      bleRemoteId: json['bleRemoteId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'kind': kind.name,
      if (bleRemoteId != null) 'bleRemoteId': bleRemoteId,
    };
  }
}

/// File-backed persistence for paired Pressensor and scale entries.
class PairedSensorsStore {
  PairedSensorsStore({String? settingsPath})
      : _settingsPathOverride = settingsPath;

  final String? _settingsPathOverride;

  Future<String> _resolveSettingsPath() async {
    return _settingsPathOverride ??
        FlowlogStorage.shared.filePath('flowlog_paired_sensors.json');
  }

  Future<List<PairedSensorRecord>> load() async {
    final file = File(await _resolveSettingsPath());
    if (!file.existsSync()) {
      return const [];
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const [];
      }
      final entries = decoded['devices'] as List<dynamic>?;
      if (entries == null) {
        return const [];
      }
      return [
        for (final entry in entries)
          if (entry is Map<String, dynamic>)
            PairedSensorRecord.fromJson(entry),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<PairedSensorRecord> devices) async {
    final file = File(await _resolveSettingsPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'devices': devices.map((device) => device.toJson()).toList(),
      }),
    );
  }
}

SensorKind? _kindFromString(String? value) {
  return switch (value) {
    'pressensor' => SensorKind.pressensor,
    'scale' => SensorKind.scale,
    _ => null,
  };
}