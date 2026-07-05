import 'dart:io';

import 'package:flowlog/settings/brew_location_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrewLocationStore', () {
    late Directory tempDir;
    late String settingsPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('brew_location_store_');
      settingsPath = '${tempDir.path}/location.json';
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('load returns null when file is missing', () async {
      final store = BrewLocationStore(settingsPath: settingsPath);

      expect(await store.load(), isNull);
    });

    test('save and load round-trip', () async {
      final store = BrewLocationStore(settingsPath: settingsPath);

      await store.save('Home kitchen');
      expect(await store.load(), 'Home kitchen');
    });

    test('save null clears location', () async {
      final store = BrewLocationStore(settingsPath: settingsPath);

      await store.save('Office');
      await store.save(null);

      expect(await store.load(), isNull);
    });

    test('saveSettings persists auto GPS toggle', () async {
      final store = BrewLocationStore(settingsPath: settingsPath);

      await store.saveSettings(
        const BrewLocationSettings(
          currentLocation: 'Cafe',
          autoGpsEnabled: false,
        ),
      );

      final loaded = await store.loadSettings();
      expect(loaded.currentLocation, 'Cafe');
      expect(loaded.autoGpsEnabled, isFalse);
    });

    test('loadSettings defaults auto GPS to enabled', () async {
      final store = BrewLocationStore(settingsPath: settingsPath);

      expect((await store.loadSettings()).autoGpsEnabled, isTrue);
    });
  });
}