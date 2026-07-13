import 'dart:convert';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';

/// Default dose in grams applied when a brew is auto-saved.
const double kDefaultBrewDoseG = 18.0;

/// Default grind setting when no previous brew exists.
const double kDefaultBrewGrindSetting = 4.2;

/// Dose slider bounds for brew defaults and metadata.
const double kBrewDoseMinG = 14.0;
const double kBrewDoseMaxG = 24.0;

/// Grind slider bounds for brew defaults and metadata.
const double kBrewGrindMin = 0.0;
const double kBrewGrindMax = 20.0;

/// Step size for grind adjustments in the metadata sheet.
const double kBrewGrindStep = 0.1;

/// Snaps [value] to one decimal place within grind bounds.
double snapGrindSetting(double value) {
  final snapped = (value * 10).round() / 10.0;
  return snapped.clamp(kBrewGrindMin, kBrewGrindMax);
}

/// Formats grind for display without floating-point noise.
String formatGrindSetting(double? value) {
  if (value == null) {
    return '—';
  }
  return snapGrindSetting(value).toStringAsFixed(1);
}

/// User preferences for metadata defaults on new brews.
class BrewDefaultsSettings {
  const BrewDefaultsSettings({
    this.defaultDoseG = kDefaultBrewDoseG,
    this.defaultGrindSetting = kDefaultBrewGrindSetting,
    this.useDefaultDose = true,
    this.useDefaultGrind = true,
    this.useDefaultCoffeejack = true,
    this.useDefaultTargetBrew = true,
  });

  final double defaultDoseG;
  final double defaultGrindSetting;

  /// Whether the default dose should be applied to new brews / metadata.
  final bool useDefaultDose;

  /// Whether the default grind should be applied to new brews / metadata.
  final bool useDefaultGrind;

  /// Whether the default Coffeejack turns should be applied.
  final bool useDefaultCoffeejack;

  /// Whether the default target brew curve should be shown/used.
  final bool useDefaultTargetBrew;

  BrewDefaultsSettings copyWith({
    double? defaultDoseG,
    double? defaultGrindSetting,
    bool? useDefaultDose,
    bool? useDefaultGrind,
    bool? useDefaultCoffeejack,
    bool? useDefaultTargetBrew,
  }) {
    return BrewDefaultsSettings(
      defaultDoseG: defaultDoseG ?? this.defaultDoseG,
      defaultGrindSetting: defaultGrindSetting ?? this.defaultGrindSetting,
      useDefaultDose: useDefaultDose ?? this.useDefaultDose,
      useDefaultGrind: useDefaultGrind ?? this.useDefaultGrind,
      useDefaultCoffeejack: useDefaultCoffeejack ?? this.useDefaultCoffeejack,
      useDefaultTargetBrew: useDefaultTargetBrew ?? this.useDefaultTargetBrew,
    );
  }
}

/// File-backed persistence for brew metadata defaults.
class BrewDefaultsSettingsStore {
  BrewDefaultsSettingsStore({String? settingsPath})
      : _settingsPathOverride = settingsPath;

  final String? _settingsPathOverride;

  Future<String> _resolveSettingsPath() async {
    return _settingsPathOverride ??
        FlowlogStorage.shared.filePath('flowlog_brew_defaults.json');
  }

  Future<BrewDefaultsSettings> load() async {
    final file = File(await _resolveSettingsPath());
    if (!file.existsSync()) {
      return const BrewDefaultsSettings();
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const BrewDefaultsSettings();
      }
      return BrewDefaultsSettings(
        defaultDoseG:
            (decoded['defaultDoseG'] as num?)?.toDouble() ?? kDefaultBrewDoseG,
        defaultGrindSetting: (decoded['defaultGrindSetting'] as num?)
                ?.toDouble() ??
            kDefaultBrewGrindSetting,
        useDefaultDose: decoded['useDefaultDose'] as bool? ?? true,
        useDefaultGrind: decoded['useDefaultGrind'] as bool? ?? true,
        useDefaultCoffeejack: decoded['useDefaultCoffeejack'] as bool? ?? true,
        useDefaultTargetBrew: decoded['useDefaultTargetBrew'] as bool? ?? true,
      );
    } catch (_) {
      return const BrewDefaultsSettings();
    }
  }

  Future<void> save(BrewDefaultsSettings settings) async {
    final file = File(await _resolveSettingsPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'defaultDoseG': settings.defaultDoseG,
        'defaultGrindSetting': settings.defaultGrindSetting,
        'useDefaultDose': settings.useDefaultDose,
        'useDefaultGrind': settings.useDefaultGrind,
        'useDefaultCoffeejack': settings.useDefaultCoffeejack,
        'useDefaultTargetBrew': settings.useDefaultTargetBrew,
      }),
    );
  }
}