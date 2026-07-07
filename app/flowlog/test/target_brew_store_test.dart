import 'dart:io';

import 'package:flowlog/settings/target_brew_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TargetBrewSettingsStore', () {
    late Directory tempDir;
    late TargetBrewSettingsStore store;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flowlog_target_brew_test');
      store = TargetBrewSettingsStore(
        settingsPath: '${tempDir.path}/target_brew.json',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns empty settings when file is missing', () async {
      final settings = await store.load();
      expect(settings.hasTarget, isFalse);
    });

    test('persists and reloads profile reference', () async {
      await store.save(
        const TargetBrewSettings(
          profileId: 'profile-1',
          profileName: 'Morning 9-bar',
        ),
      );

      final loaded = await store.load();
      expect(loaded.profileId, 'profile-1');
      expect(loaded.profileName, 'Morning 9-bar');
      expect(loaded.hasTarget, isTrue);
    });

    test('clear removes persisted settings', () async {
      await store.save(
        const TargetBrewSettings(
          profileId: 'profile-1',
          profileName: 'Morning 9-bar',
        ),
      );
      await store.clear();

      final loaded = await store.load();
      expect(loaded.hasTarget, isFalse);
    });
  });
}