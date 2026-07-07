import 'dart:convert';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';

/// Persisted default target brew profile reference.
class TargetBrewSettings {
  const TargetBrewSettings({
    this.profileId,
    this.profileName,
  });

  final String? profileId;
  final String? profileName;

  bool get hasTarget => profileId != null && profileId!.isNotEmpty;

  TargetBrewSettings copyWith({
    String? profileId,
    String? profileName,
  }) {
    return TargetBrewSettings(
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
    );
  }
}

/// File-backed persistence for the default target brew curve.
class TargetBrewSettingsStore {
  TargetBrewSettingsStore({String? settingsPath})
      : _settingsPathOverride = settingsPath;

  final String? _settingsPathOverride;

  Future<String> _resolveSettingsPath() async {
    return _settingsPathOverride ??
        FlowlogStorage.shared.filePath('flowlog_target_brew.json');
  }

  Future<TargetBrewSettings> load() async {
    final file = File(await _resolveSettingsPath());
    if (!file.existsSync()) {
      return const TargetBrewSettings();
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const TargetBrewSettings();
      }
      return TargetBrewSettings(
        profileId: decoded['profileId'] as String?,
        profileName: decoded['profileName'] as String?,
      );
    } catch (_) {
      return const TargetBrewSettings();
    }
  }

  Future<void> save(TargetBrewSettings settings) async {
    final file = File(await _resolveSettingsPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        if (settings.profileId != null) 'profileId': settings.profileId,
        if (settings.profileName != null) 'profileName': settings.profileName,
      }),
    );
  }

  Future<void> clear() async {
    final file = File(await _resolveSettingsPath());
    if (file.existsSync()) {
      await file.delete();
    }
  }
}