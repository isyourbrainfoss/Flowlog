import 'dart:convert';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flutter/material.dart';

/// User appearance preference: coffee dark, café light, or follow system.
class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = ThemeMode.dark,
    this.colorblindCharts = false,
  });

  final ThemeMode themeMode;

  /// When true, charts use [FlowlogChartPalette.colorblindSafe].
  final bool colorblindCharts;

  /// True only when [themeMode] is explicitly dark (not when following system).
  bool get isDark => themeMode == ThemeMode.dark;

  bool get isSystem => themeMode == ThemeMode.system;

  AppearanceSettings copyWith({
    ThemeMode? themeMode,
    bool? colorblindCharts,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      colorblindCharts: colorblindCharts ?? this.colorblindCharts,
    );
  }
}

/// File-backed persistence for light/dark theme and chart palette preference.
class AppearanceSettingsStore {
  AppearanceSettingsStore({String? settingsPath})
      : _settingsPathOverride = settingsPath;

  final String? _settingsPathOverride;

  Future<String> _resolveSettingsPath() async {
    return _settingsPathOverride ??
        FlowlogStorage.shared.filePath('flowlog_appearance.json');
  }

  Future<AppearanceSettings> load() async {
    final file = File(await _resolveSettingsPath());
    if (!file.existsSync()) {
      return const AppearanceSettings();
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const AppearanceSettings();
      }
      final mode = decoded['themeMode'] as String?;
      return AppearanceSettings(
        themeMode: _themeModeFromString(mode) ?? ThemeMode.dark,
        colorblindCharts: decoded['colorblindCharts'] as bool? ?? false,
      );
    } catch (_) {
      return const AppearanceSettings();
    }
  }

  Future<void> save(AppearanceSettings settings) async {
    final file = File(await _resolveSettingsPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'themeMode': _themeModeToString(settings.themeMode),
        'colorblindCharts': settings.colorblindCharts,
      }),
    );
  }

  static ThemeMode? _themeModeFromString(String? value) {
    return switch (value) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => null,
    };
  }

  static String _themeModeToString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };
  }
}
