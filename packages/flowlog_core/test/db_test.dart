import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('schema', () {
    test('schema version is 1', () async {
      final db = FlowlogDatabase.inMemory();
      addTearDown(db.close);

      expect(db.schemaVersion, 1);
    });

    test('creates shots and shot_samples tables', () async {
      final db = FlowlogDatabase.inMemory();
      addTearDown(db.close);

      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
            readsFrom: {},
          )
          .map((row) => row.read<String>('name'))
          .get();

      expect(tables, containsAll(['shots', 'shot_samples']));
    });
  });

  group('ShotRepository', () {
    late FlowlogDatabase db;
    late ShotRepository repository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('inserts and reads shot with samples from fixture', () async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');

      await repository.insertShot(shot);

      final withoutSamples = await repository.getShotById(shot.id);
      expect(withoutSamples, isNotNull);
      expect(withoutSamples!.samples, isEmpty);
      expect(withoutSamples.id, shot.id);
      expect(withoutSamples.doseG, shot.doseG);
      expect(withoutSamples.flavourTags, shot.flavourTags);

      final withSamples = await repository.getShotWithSamples(shot.id);
      expect(withSamples, shot);
    });

    test('getShotById returns null for unknown id', () async {
      expect(await repository.getShotById('missing'), isNull);
    });

    test('re-insert replaces samples for the same shot id', () async {
      final original = Shot(
        id: 'shot-replace',
        startedAt: DateTime.utc(2026, 6, 29, 10, 0),
        samples: const [
          ShotSample(elapsedMs: 0, pressureBar: 1.0),
        ],
      );

      await repository.insertShot(original);

      final updated = original.copyWith(
        samples: const [
          ShotSample(elapsedMs: 0, pressureBar: 2.0),
          ShotSample(elapsedMs: 1000, pressureBar: 8.0),
        ],
      );

      await repository.insertShot(updated);

      final loaded = await repository.getShotWithSamples('shot-replace');
      expect(loaded, updated);
    });
  });

  group('migration', () {
    test('opening an existing v1 database preserves data', () async {
      final tempDir = await Directory.systemTemp.createTemp('flowlog_db_test_');
      final dbPath = '${tempDir.path}/flowlog.db';

      try {
        final writer = FlowlogDatabase.openFile(dbPath);
        final writerRepo = ShotRepository(writer);
        final shot = _loadFixtureShot('shots/minimal_shot.json');

        await writerRepo.insertShot(shot);
        expect(writer.schemaVersion, 1);
        await writer.close();

        final reader = FlowlogDatabase.openFile(dbPath);
        final readerRepo = ShotRepository(reader);

        expect(reader.schemaVersion, 1);
        expect(await readerRepo.getShotWithSamples(shot.id), shot);

        await reader.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('v1 schema supports basic CRUD after reopen', () async {
      final tempDir = await Directory.systemTemp.createTemp('flowlog_db_crud_');
      final dbPath = '${tempDir.path}/flowlog.db';

      try {
        final firstOpen = FlowlogDatabase.openFile(dbPath);
        final firstRepo = ShotRepository(firstOpen);
        final shot = Shot(
          id: 'legacy-shot',
          startedAt: DateTime.utc(2026, 1, 1),
        );

        await firstRepo.insertShot(shot);
        await firstOpen.close();

        final secondOpen = FlowlogDatabase.openFile(dbPath);
        final secondRepo = ShotRepository(secondOpen);

        final loaded = await secondRepo.getShotById('legacy-shot');
        expect(loaded, isNotNull);
        expect(loaded!.startedAt, DateTime.utc(2026, 1, 1));

        await secondOpen.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}

Shot _loadFixtureShot(String relativePath) {
  final fixturePath = _fixturePath(relativePath);
  final json =
      jsonDecode(File(fixturePath).readAsStringSync()) as Map<String, dynamic>;
  return Shot.fromJson(json);
}

String _fixturePath(String relativePath) {
  final candidates = [
    '../../fixtures/$relativePath',
    '../../../fixtures/$relativePath',
  ];

  for (final candidate in candidates) {
    final file = File(candidate);
    if (file.existsSync()) return file.path;
  }

  throw StateError('Fixture not found: $relativePath');
}