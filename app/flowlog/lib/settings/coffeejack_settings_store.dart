import 'dart:convert';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';

/// Default lever turns wound back before filling the boiler.
///
/// Lower than the old 8 so more water remains for the pull; use the live
/// yield warning (brew defaults) to time the stop instead of a long rewind.
const int kDefaultCoffeejackRewindTurns = 5;

/// Default slow turns used for pre-infusion.
const int kDefaultCoffeejackPreinfusionTurns = 8;

/// Minimum and maximum turn counts for Coffeejack sliders.
const int kCoffeejackMinTurns = 1;
const int kCoffeejackMaxTurns = 20;

/// User preferences for Coffeejack lever workflow.
class CoffeejackSettings {
  const CoffeejackSettings({
    this.rewindTurnsBeforeFill = kDefaultCoffeejackRewindTurns,
    this.slowPreinfusionTurns = kDefaultCoffeejackPreinfusionTurns,
  });

  final int rewindTurnsBeforeFill;
  final int slowPreinfusionTurns;

  CoffeejackSettings copyWith({
    int? rewindTurnsBeforeFill,
    int? slowPreinfusionTurns,
  }) {
    return CoffeejackSettings(
      rewindTurnsBeforeFill:
          rewindTurnsBeforeFill ?? this.rewindTurnsBeforeFill,
      slowPreinfusionTurns:
          slowPreinfusionTurns ?? this.slowPreinfusionTurns,
    );
  }
}

/// File-backed persistence for Coffeejack lever settings.
class CoffeejackSettingsStore {
  CoffeejackSettingsStore({String? settingsPath})
      : _settingsPathOverride = settingsPath;

  final String? _settingsPathOverride;

  Future<String> _resolveSettingsPath() async {
    return _settingsPathOverride ??
        FlowlogStorage.shared.filePath('flowlog_coffeejack_settings.json');
  }

  Future<CoffeejackSettings> load() async {
    final file = File(await _resolveSettingsPath());
    if (!file.existsSync()) {
      return const CoffeejackSettings();
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const CoffeejackSettings();
      }
      return CoffeejackSettings(
        rewindTurnsBeforeFill:
            (decoded['rewindTurnsBeforeFill'] as num?)?.toInt() ??
                kDefaultCoffeejackRewindTurns,
        slowPreinfusionTurns:
            (decoded['slowPreinfusionTurns'] as num?)?.toInt() ??
                kDefaultCoffeejackPreinfusionTurns,
      );
    } catch (_) {
      return const CoffeejackSettings();
    }
  }

  Future<void> save(CoffeejackSettings settings) async {
    final file = File(await _resolveSettingsPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'rewindTurnsBeforeFill': settings.rewindTurnsBeforeFill,
        'slowPreinfusionTurns': settings.slowPreinfusionTurns,
      }),
    );
  }
}