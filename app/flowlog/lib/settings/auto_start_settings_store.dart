import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/live/auto_start.dart';

/// File-backed persistence for pressure-triggered auto-start preferences.
class AutoStartSettingsStore {
  AutoStartSettingsStore({String? settingsPath})
      : _settingsPath = settingsPath ?? _defaultSettingsPath;

  static String get _defaultSettingsPath =>
      '${Directory.systemTemp.path}/flowlog_auto_start_settings.json';

  final String _settingsPath;

  Future<AutoStartSettings> load() async {
    final file = File(_settingsPath);
    if (!file.existsSync()) {
      return const AutoStartSettings();
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const AutoStartSettings();
      }
      return AutoStartSettings(
        enabled: decoded['enabled'] as bool? ?? true,
        startThresholdBar:
            (decoded['startThresholdBar'] as num?)?.toDouble() ??
                kDefaultAutoStartPressureBar,
      );
    } catch (_) {
      return const AutoStartSettings();
    }
  }

  Future<void> save(AutoStartSettings settings) async {
    final file = File(_settingsPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'enabled': settings.enabled,
        'startThresholdBar': settings.startThresholdBar,
      }),
    );
  }
}