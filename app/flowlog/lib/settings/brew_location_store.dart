import 'dart:convert';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flutter/foundation.dart';

/// Brew location preferences: optional label and automatic GPS capture.
@immutable
class BrewLocationSettings {
  const BrewLocationSettings({
    this.currentLocation,
    this.autoGpsEnabled = true,
  });

  final String? currentLocation;
  final bool autoGpsEnabled;

  BrewLocationSettings copyWith({
    String? currentLocation,
    bool? autoGpsEnabled,
    bool clearCurrentLocation = false,
  }) {
    return BrewLocationSettings(
      currentLocation:
          clearCurrentLocation ? null : (currentLocation ?? this.currentLocation),
      autoGpsEnabled: autoGpsEnabled ?? this.autoGpsEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (currentLocation != null) 'currentLocation': currentLocation,
      'autoGpsEnabled': autoGpsEnabled,
    };
  }

  factory BrewLocationSettings.fromJson(Map<String, dynamic> json) {
    final location = json['currentLocation'];
    String? currentLocation;
    if (location is String) {
      final trimmed = location.trim();
      if (trimmed.isNotEmpty) {
        currentLocation = trimmed;
      }
    }

    return BrewLocationSettings(
      currentLocation: currentLocation,
      autoGpsEnabled: json['autoGpsEnabled'] as bool? ?? true,
    );
  }
}

/// File-backed persistence for brew location settings.
class BrewLocationStore {
  BrewLocationStore({String? settingsPath})
      : _settingsPathOverride = settingsPath;

  final String? _settingsPathOverride;

  Future<String> _resolveSettingsPath() async {
    return _settingsPathOverride ??
        FlowlogStorage.shared.filePath('flowlog_brew_location.json');
  }

  Future<BrewLocationSettings> loadSettings() async {
    final file = File(await _resolveSettingsPath());
    if (!file.existsSync()) {
      return const BrewLocationSettings();
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const BrewLocationSettings();
      }
      return BrewLocationSettings.fromJson(decoded);
    } catch (_) {
      return const BrewLocationSettings();
    }
  }

  /// Legacy helper for the current location label only.
  Future<String?> load() async {
    return (await loadSettings()).currentLocation;
  }

  Future<void> saveSettings(BrewLocationSettings settings) async {
    final file = File(await _resolveSettingsPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }

  Future<void> save(String? location) async {
    final current = await loadSettings();
    await saveSettings(
      current.copyWith(
        currentLocation: location,
        clearCurrentLocation: location == null || location.trim().isEmpty,
      ),
    );
  }
}