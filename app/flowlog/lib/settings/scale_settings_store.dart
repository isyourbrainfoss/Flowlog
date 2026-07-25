import 'dart:convert';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';

/// Defaults aligned with espresso-scale firmware `config.h`.
const double kDefaultScaleTargetYieldG = 36.0;
const double kDefaultScaleWarnAtG = 34.0;
const double kDefaultScalePressureMinBar = 5.0;
const double kDefaultScalePressureMaxBar = 10.0;

/// OLED / cue preferences pushed to the Flowlog DIY scale over BLE.
class ScaleDisplaySettings {
  const ScaleDisplaySettings({
    this.targetYieldG = kDefaultScaleTargetYieldG,
    this.warnAtG = kDefaultScaleWarnAtG,
    this.pressureMinBar = kDefaultScalePressureMinBar,
    this.pressureMaxBar = kDefaultScalePressureMaxBar,
  });

  final double targetYieldG;
  final double warnAtG;
  final double pressureMinBar;
  final double pressureMaxBar;

  ScaleDisplaySettings copyWith({
    double? targetYieldG,
    double? warnAtG,
    double? pressureMinBar,
    double? pressureMaxBar,
  }) {
    return ScaleDisplaySettings(
      targetYieldG: targetYieldG ?? this.targetYieldG,
      warnAtG: warnAtG ?? this.warnAtG,
      pressureMinBar: pressureMinBar ?? this.pressureMinBar,
      pressureMaxBar: pressureMaxBar ?? this.pressureMaxBar,
    );
  }

  Map<String, dynamic> toJson() => {
        'targetYieldG': targetYieldG,
        'warnAtG': warnAtG,
        'pressureMinBar': pressureMinBar,
        'pressureMaxBar': pressureMaxBar,
      };

  factory ScaleDisplaySettings.fromJson(Map<String, dynamic> json) {
    return ScaleDisplaySettings(
      targetYieldG: (json['targetYieldG'] as num?)?.toDouble() ??
          kDefaultScaleTargetYieldG,
      warnAtG: (json['warnAtG'] as num?)?.toDouble() ?? kDefaultScaleWarnAtG,
      pressureMinBar: (json['pressureMinBar'] as num?)?.toDouble() ??
          kDefaultScalePressureMinBar,
      pressureMaxBar: (json['pressureMaxBar'] as num?)?.toDouble() ??
          kDefaultScalePressureMaxBar,
    );
  }
}

/// File-backed scale display preferences.
class ScaleSettingsStore {
  ScaleSettingsStore({String? settingsPath, String? importHostPath})
      : _settingsPathOverride = settingsPath,
        _importHostPathOverride = importHostPath;

  final String? _settingsPathOverride;
  final String? _importHostPathOverride;

  Future<String> _resolvePath() async {
    return _settingsPathOverride ??
        FlowlogStorage.shared.filePath('flowlog_scale_settings.json');
  }

  Future<String> _resolveImportHostPath() async {
    return _importHostPathOverride ??
        FlowlogStorage.shared.filePath('flowlog_scale_import_host.txt');
  }

  Future<ScaleDisplaySettings> load() async {
    try {
      final file = File(await _resolvePath());
      if (!await file.exists()) {
        return const ScaleDisplaySettings();
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const ScaleDisplaySettings();
      }
      return ScaleDisplaySettings.fromJson(decoded);
    } on Object {
      return const ScaleDisplaySettings();
    }
  }

  Future<void> save(ScaleDisplaySettings settings) async {
    final file = File(await _resolvePath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }

  /// Last successful import host/IP (phones often cannot resolve mDNS).
  Future<String?> loadImportHost() async {
    try {
      final file = File(await _resolveImportHostPath());
      if (!await file.exists()) {
        return null;
      }
      final host = (await file.readAsString()).trim();
      return host.isEmpty ? null : host;
    } on Object {
      return null;
    }
  }

  Future<void> saveImportHost(String host) async {
    final trimmed = host.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final file = File(await _resolveImportHostPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(trimmed);
  }
}
