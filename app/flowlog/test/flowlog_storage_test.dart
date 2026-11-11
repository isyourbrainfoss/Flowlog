import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlowlogStorage', () {
    late Directory rootDir;
    late FlowlogStorage storage;

    setUp(() async {
      rootDir = await Directory.systemTemp.createTemp('flowlog_storage_test_');
      storage = FlowlogStorage(
        directoryProvider: () async => rootDir,
        migrateLegacy: false,
      );
      FlowlogStorage.overrideForTesting(storage);
    });

    tearDown(() async {
      FlowlogStorage.overrideForTesting(null);
      await FlowlogStorage.resetForTesting();
      if (rootDir.existsSync()) {
        await rootDir.delete(recursive: true);
      }
    });

    test('stores database under application support root', () async {
      final database = await storage.database();
      final path = await storage.databaseFilePath();

      expect(path, '${rootDir.path}/flowlog.db');
      expect(File(path).existsSync(), isTrue);

      await database.close();
      storage = FlowlogStorage(
        directoryProvider: () async => rootDir,
        migrateLegacy: false,
      );
      FlowlogStorage.overrideForTesting(storage);

      final reopened = await storage.database();
      expect(reopened, isNotNull);
    });

    test('migrates legacy temp database on first open', () async {
      final legacy = File('${Directory.systemTemp.path}/flowlog.db');
      final hadLegacy = legacy.existsSync();
      final previousBytes = hadLegacy ? await legacy.readAsBytes() : null;

      final migrationStorage = FlowlogStorage(
        directoryProvider: () async => rootDir,
        migrateLegacy: true,
      );
      FlowlogStorage.overrideForTesting(migrationStorage);

      try {
        if (!hadLegacy) {
          await legacy.parent.create(recursive: true);
          await legacy.writeAsBytes([0, 1, 2, 3]);
        }

        try {
          await migrationStorage.database();
        } catch (e) {
          if (hadLegacy ||
              e.toString().contains('not a database') == false) {
            rethrow;
          }
          // For the !hadLegacy garbage case we intentionally wrote non-sqlite
          // bytes to test "copy as-is". Opening will fail with sqlite error,
          // which is expected here; we still assert the file was migrated.
        }

        final migrated = File(await migrationStorage.databaseFilePath());
        expect(migrated.existsSync(), isTrue);
        if (!hadLegacy) {
          expect(await migrated.readAsBytes(), [0, 1, 2, 3]);
        }
      } finally {
        FlowlogStorage.overrideForTesting(storage);
        if (!hadLegacy && legacy.existsSync()) {
          await legacy.delete();
        } else if (hadLegacy && previousBytes != null) {
          await legacy.writeAsBytes(previousBytes);
        }
      }
    });

    test(
      'imports legacy Nextcloud files once, then removes them from temp',
      () async {
        final legacyDir = await Directory.systemTemp.createTemp(
          'flowlog_legacy_test_',
        );
        addTearDown(() async {
          if (legacyDir.existsSync()) {
            await legacyDir.delete(recursive: true);
          }
        });
        final legacyCreds = File(
          '${legacyDir.path}/flowlog_nextcloud_credentials.json',
        );
        final legacySettings = File(
          '${legacyDir.path}/flowlog_nextcloud_settings.json',
        );
        await legacyCreds.writeAsString('{"password":"secret"}');
        await legacySettings.writeAsString('{"enabled":true}');

        final migrating = FlowlogStorage(
          directoryProvider: () async => rootDir,
          legacyDirectory: legacyDir.path,
        );
        FlowlogStorage.overrideForTesting(migrating);
        await migrating.database();

        expect(
          await File(
            await migrating.filePath('flowlog_nextcloud_credentials.json'),
          ).readAsString(),
          '{"password":"secret"}',
        );
        expect(
          File(
            await migrating.filePath('flowlog_nextcloud_settings.json'),
          ).existsSync(),
          isTrue,
        );
        // Plaintext secret and account settings no longer linger in temp.
        expect(legacyCreds.existsSync(), isFalse);
        expect(legacySettings.existsSync(), isFalse);
      },
    );
  });
}
