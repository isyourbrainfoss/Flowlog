import 'dart:convert';
import 'dart:io';

import 'package:flowlog/persistence/atomic_file.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('flowlog_atomic_');
  });

  tearDown(() async {
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  test(
    'overlapping writes of different lengths never corrupt the file',
    () async {
      final file = File('${dir.path}/settings.json');
      for (var i = 0; i < 50; i++) {
        await Future.wait([
          writeStringAtomically(file, jsonEncode({'v': 'x' * 400})),
          writeStringAtomically(file, jsonEncode({'v': i})),
        ]);
        // Last queued write wins, and the file is always valid JSON.
        expect(jsonDecode(await file.readAsString()), {'v': i});
      }
      expect(File('${file.path}.tmp').existsSync(), isFalse);
    },
  );

  test('a failed write does not block later writes to the same path', () async {
    final file = File('${dir.path}/settings.json');
    final blocker = Directory('${file.path}.tmp')..createSync();
    await expectLater(writeStringAtomically(file, 'a'), throwsA(anything));
    blocker.deleteSync();
    await writeStringAtomically(file, 'b');
    expect(await file.readAsString(), 'b');
  });

  test(
    'slider-style unawaited brew default saves keep the last value',
    () async {
      final store = BrewDefaultsSettingsStore(
        settingsPath: '${dir.path}/flowlog_brew_defaults.json',
      );
      final pending = <Future<void>>[];
      for (final bar in [9.0, 9.5, 10.0, 10.5, 11.0, 10.5, 10.0, 9.5]) {
        pending.add(
          store.save(
            BrewDefaultsSettings(pressureLimitBar: bar, targetYieldG: 36),
          ),
        );
      }
      await Future.wait(pending);
      final loaded = await store.load();
      expect(loaded.pressureLimitBar, 9.5);
      expect(loaded.targetYieldG, 36);
    },
  );
}
