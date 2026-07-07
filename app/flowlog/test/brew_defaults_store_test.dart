import 'dart:io';

import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrewDefaultsSettingsStore', () {
    late Directory tempDir;
    late BrewDefaultsSettingsStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('brew_defaults_store_');
      store = BrewDefaultsSettingsStore(
        settingsPath: '${tempDir.path}/brew_defaults.json',
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('load returns defaults when file is missing', () async {
      final settings = await store.load();
      expect(settings.defaultDoseG, kDefaultBrewDoseG);
      expect(settings.defaultGrindSetting, kDefaultBrewGrindSetting);
    });

    test('save and load round-trip', () async {
      await store.save(
        const BrewDefaultsSettings(defaultDoseG: 20, defaultGrindSetting: 5.5),
      );
      final settings = await store.load();
      expect(settings.defaultDoseG, 20);
      expect(settings.defaultGrindSetting, 5.5);
    });
  });
}