import 'dart:io';

import 'package:flowlog/settings/coffeejack_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoffeejackSettingsStore', () {
    late Directory tempDir;
    late CoffeejackSettingsStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('coffeejack_store_');
      store = CoffeejackSettingsStore(
        settingsPath: '${tempDir.path}/coffeejack.json',
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('load returns defaults when file is missing', () async {
      final settings = await store.load();
      expect(settings.rewindTurnsBeforeFill, kDefaultCoffeejackRewindTurns);
      expect(settings.slowPreinfusionTurns, kDefaultCoffeejackPreinfusionTurns);
    });

    test('save and load round-trip', () async {
      await store.save(
        const CoffeejackSettings(
          rewindTurnsBeforeFill: 10,
          slowPreinfusionTurns: 6,
        ),
      );
      final settings = await store.load();
      expect(settings.rewindTurnsBeforeFill, 10);
      expect(settings.slowPreinfusionTurns, 6);
    });
  });
}