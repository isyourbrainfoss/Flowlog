import 'dart:io';

import 'package:flowlog/settings/appearance_settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppearanceSettingsStore', () {
    late Directory tempDir;
    late AppearanceSettingsStore store;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('appearance_settings_test');
      store = AppearanceSettingsStore(
        settingsPath: '${tempDir.path}/appearance.json',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('defaults to dark when file is missing', () async {
      final settings = await store.load();
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.isDark, isTrue);
    });

    test('persists light mode preference', () async {
      await store.save(const AppearanceSettings(themeMode: ThemeMode.light));
      final loaded = await store.load();
      expect(loaded.themeMode, ThemeMode.light);
      expect(loaded.isDark, isFalse);
    });
  });
}