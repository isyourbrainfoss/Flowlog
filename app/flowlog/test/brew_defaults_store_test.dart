import 'dart:io';

import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('grind formatting', () {
    test('snapGrindSetting rounds to one decimal', () {
      expect(snapGrindSetting(3.599999999), 3.6);
      expect(snapGrindSetting(4.2000001), 4.2);
    });

    test('formatGrindSetting avoids floating-point noise', () {
      expect(formatGrindSetting(3.599999999), '3.6');
      expect(formatGrindSetting(14), '14.0');
      expect(formatGrindSetting(null), '—');
    });
  });

  group('pressure limit', () {
    test('flat target spans at least 30 s and extends with the shot', () {
      final short = flatPressureTargetSamples(9);
      expect(short.first.pressureBar, 9);
      expect(short.last.elapsedMs, kFlatTargetMinDurationMs);
      expect(
        flatPressureTargetSamples(9, untilMs: 45000).last.elapsedMs,
        45000,
      );
    });

    test('round-trips and clears via the store', () async {
      final dir = await Directory.systemTemp.createTemp('flowlog_bd');
      addTearDown(() => dir.delete(recursive: true));
      final store = BrewDefaultsSettingsStore(
        settingsPath: '${dir.path}/bd.json',
      );
      expect((await store.load()).pressureLimitBar, isNull);
      await store.save(const BrewDefaultsSettings(pressureLimitBar: 8.5));
      final loaded = await store.load();
      expect(loaded.pressureLimitBar, 8.5);
      expect(
        loaded.copyWith(clearPressureLimit: true).pressureLimitBar,
        isNull,
      );
      expect(loaded.copyWith(targetYieldG: 40).pressureLimitBar, 8.5);
    });
  });
}
