import 'dart:convert';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';

/// Default dose in grams applied when a brew is auto-saved.
const double kDefaultBrewDoseG = 18.0;

/// Default grind setting when no previous brew exists.
const double kDefaultBrewGrindSetting = 4.2;

/// Default target beverage weight in the cup (g).
const double kDefaultTargetYieldG = 36.0;

/// Default weight at which to alert before the target (g).
///
/// Lets you wind the lever back early and coast to [kDefaultTargetYieldG].
const double kDefaultYieldWarnAtG = 32.0;

/// Dose slider bounds for brew defaults and metadata.
const double kBrewDoseMinG = 14.0;
const double kBrewDoseMaxG = 24.0;

/// Target yield slider bounds.
const double kBrewYieldMinG = 15.0;
const double kBrewYieldMaxG = 60.0;

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
    this.targetYieldG = kDefaultTargetYieldG,
    this.yieldWarnAtG = kDefaultYieldWarnAtG,
    this.yieldAlertEnabled = true,
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

  /// Desired beverage weight in cup (g) for the live fill bar and finish target.
  final double targetYieldG;

  /// Weight (g) at which to alert during the pull so you can wind back early.
  final double yieldWarnAtG;

  /// Play sound + show banner when live weight reaches [yieldWarnAtG].
  final bool yieldAlertEnabled;

  /// Effective warn weight: never above target, never below a small floor.
  double get effectiveYieldWarnAtG {
    final target = targetYieldG.clamp(kBrewYieldMinG, kBrewYieldMaxG);
    final warn = yieldWarnAtG.clamp(kBrewYieldMinG, kBrewYieldMaxG);
    if (warn >= target) {
      return (target - 2).clamp(kBrewYieldMinG, target);
    }
    return warn;
  }

  BrewDefaultsSettings copyWith({
    double? defaultDoseG,
    double? defaultGrindSetting,
    bool? useDefaultDose,
    bool? useDefaultGrind,
    bool? useDefaultCoffeejack,
    bool? useDefaultTargetBrew,
    double? targetYieldG,
    double? yieldWarnAtG,
    bool? yieldAlertEnabled,
  }) {
    return BrewDefaultsSettings(
      defaultDoseG: defaultDoseG ?? this.defaultDoseG,
      defaultGrindSetting: defaultGrindSetting ?? this.defaultGrindSetting,
      useDefaultDose: useDefaultDose ?? this.useDefaultDose,
      useDefaultGrind: useDefaultGrind ?? this.useDefaultGrind,
      useDefaultCoffeejack: useDefaultCoffeejack ?? this.useDefaultCoffeejack,
      useDefaultTargetBrew: useDefaultTargetBrew ?? this.useDefaultTargetBrew,
      targetYieldG: targetYieldG ?? this.targetYieldG,
      yieldWarnAtG: yieldWarnAtG ?? this.yieldWarnAtG,
      yieldAlertEnabled: yieldAlertEnabled ?? this.yieldAlertEnabled,
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
        targetYieldG:
            (decoded['targetYieldG'] as num?)?.toDouble() ?? kDefaultTargetYieldG,
        yieldWarnAtG:
            (decoded['yieldWarnAtG'] as num?)?.toDouble() ?? kDefaultYieldWarnAtG,
        yieldAlertEnabled: decoded['yieldAlertEnabled'] as bool? ?? true,
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
        'targetYieldG': settings.targetYieldG,
        'yieldWarnAtG': settings.yieldWarnAtG,
        'yieldAlertEnabled': settings.yieldAlertEnabled,
      }),
    );
  }
}