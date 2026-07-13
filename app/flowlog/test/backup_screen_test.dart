import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/more/backup.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupScreen', () {
    late FlowlogDatabase db;
    late StubBackupActions actions;
    late Directory saveDirectory;

    setUp(() async {
      db = FlowlogDatabase.inMemory();
      saveDirectory = Directory.systemTemp.createTempSync('flowlog-backup-test');
      actions = StubBackupActions(saveDirectory: saveDirectory.path);

      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await ShotRepository(db).insertShot(shot);
      await BeanRepository(db).upsertBean(
        const Bean(id: 'bean-ui', name: 'UI Bean'),
      );
    });

    tearDown(() async {
      await db.close();
      if (saveDirectory.existsSync()) {
        saveDirectory.deleteSync(recursive: true);
      }
    });

    testWidgets('exports backup with local counts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BackupScreen(
            database: db,
            backupActions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 shots'), findsOneWidget);
      expect(find.text('1 beans'), findsOneWidget);

      await tester.tap(find.byKey(const Key('backup_export_button')));
      await tester.pump();
      for (var i = 0; i < 30 && actions.saveCalls == 0; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(actions.saveCalls, 1);
      expect(actions.lastSavedContent, isNotNull);
      final payload = parseSyncBackup(actions.lastSavedContent!);
      expect(payload.shots.length, 1);
      expect(payload.beans.length, 1);
    });

    testWidgets('imports and merges staged backup', (tester) async {
      final exportPayload = await buildSyncPayloadFromDatabase(db);
      final otherDb = FlowlogDatabase.inMemory();
      final otherShot = _loadFixtureShot('shots/minimal_shot.json').copyWith(
        id: 'shot-imported',
        notes: 'Imported',
      );
      await ShotRepository(otherDb).insertShot(otherShot);
      final importPayload = await buildSyncPayloadFromDatabase(otherDb);
      await otherDb.close();

      actions.stagePick(
        path: 'merge.flowlog',
        contents: encodeSyncBackup(importPayload),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BackupScreen(
            database: db,
            backupActions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('backup_import_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(actions.pickCalls, 1);
      expect(find.textContaining('Merged'), findsOneWidget);

      final shots = await ShotRepository(db).listShots();
      expect(shots.length, 2);
      expect(shots.any((shot) => shot.id == exportPayload.shots.first.id), isTrue);
      expect(shots.any((shot) => shot.id == 'shot-imported'), isTrue);
    });
  });
}

Shot _loadFixtureShot(String relativePath) {
  final json =
      jsonDecode(File(_fixturePath(relativePath)).readAsStringSync())
          as Map<String, dynamic>;
  return Shot.fromJson(json);
}

String _fixturePath(String relativePath) {
  final candidates = [
    '../../fixtures/$relativePath',
    '../../../fixtures/$relativePath',
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError('Fixture not found: $relativePath');
}