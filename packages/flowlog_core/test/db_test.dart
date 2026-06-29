import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('schema', () {
    test('schema version is 2', () async {
      final db = FlowlogDatabase.inMemory();
      addTearDown(db.close);

      expect(db.schemaVersion, 2);
    });

    test('creates shots, shot_samples, and beans tables', () async {
      final db = FlowlogDatabase.inMemory();
      addTearDown(db.close);

      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
            readsFrom: {},
          )
          .map((row) => row.read<String>('name'))
          .get();

      expect(tables, containsAll(['shots', 'shot_samples', 'beans']));
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

  group('BeanRepository', () {
    late FlowlogDatabase db;
    late BeanRepository beanRepository;
    late ShotRepository shotRepository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      beanRepository = BeanRepository(db);
      shotRepository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('creates, reads, updates, and deletes beans', () async {
      const bean = Bean(
        id: 'bean-ethiopia',
        name: 'Ethiopia Yirgacheffe',
        origin: 'Ethiopia',
        roastLevel: 'light',
        stockG: 250,
        notes: 'Fruity',
      );

      await beanRepository.upsertBean(bean);
      expect(await beanRepository.getBeanById(bean.id), bean);

      final updated = bean.copyWith(stockG: 200, notes: 'Updated');
      await beanRepository.updateBean(updated);
      expect(await beanRepository.getBeanById(bean.id), updated);

      final listed = await beanRepository.listBeans();
      expect(listed, [updated]);

      await beanRepository.deleteBean(bean.id);
      expect(await beanRepository.getBeanById(bean.id), isNull);
      expect(await beanRepository.listBeans(), isEmpty);
    });

    test('counts shots linked by beanId', () async {
      const bean = Bean(id: 'bean-house', name: 'House Blend');
      await beanRepository.upsertBean(bean);

      final linkedShot = Shot(
        id: 'shot-linked',
        startedAt: DateTime.utc(2026, 6, 29, 10),
        beanId: bean.id,
      );
      final otherShot = Shot(
        id: 'shot-other',
        startedAt: DateTime.utc(2026, 6, 29, 11),
        beanId: 'bean-other',
      );

      await shotRepository.insertShot(linkedShot);
      await shotRepository.insertShot(otherShot);

      expect(await beanRepository.countShotsForBean(bean.id), 1);

      final withCounts = await beanRepository.listBeansWithShotCounts();
      expect(withCounts, hasLength(1));
      expect(withCounts.first.bean, bean);
      expect(withCounts.first.shotCount, 1);
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
        expect(writer.schemaVersion, 2);
        await writer.close();

        final reader = FlowlogDatabase.openFile(dbPath);
        final readerRepo = ShotRepository(reader);

        expect(reader.schemaVersion, 2);
        expect(await readerRepo.getShotWithSamples(shot.id), shot);

        await reader.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('migrates v1 database to v2 and adds beans table', () async {
      final tempDir = await Directory.systemTemp.createTemp('flowlog_db_v1_');
      final dbPath = '${tempDir.path}/flowlog.db';

      try {
        final v1Db = sqlite3.open(dbPath);
        v1Db.execute('''
          CREATE TABLE shots (
            id TEXT NOT NULL PRIMARY KEY,
            started_at TEXT NOT NULL,
            ended_at TEXT,
            dose_g REAL,
            yield_g REAL,
            grind_setting REAL,
            bean_id TEXT,
            water_temp_c REAL,
            notes TEXT,
            taste_score INTEGER,
            flavour_tags TEXT NOT NULL DEFAULT '[]'
          );
        ''');
        v1Db.execute('''
          CREATE TABLE shot_samples (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            shot_id TEXT NOT NULL REFERENCES shots(id) ON DELETE CASCADE,
            elapsed_ms INTEGER NOT NULL,
            pressure_bar REAL,
            weight_g REAL,
            flow_gs REAL,
            temp_c REAL
          );
        ''');
        v1Db.execute(
          "INSERT INTO shots (id, started_at) VALUES ('legacy-shot', '2026-01-01T00:00:00.000Z');",
        );
        v1Db.execute('PRAGMA user_version = 1;');
        v1Db.dispose();

        final migrated = FlowlogDatabase.openFile(dbPath);
        addTearDown(migrated.close);

        expect(migrated.schemaVersion, 2);

        final tables = await migrated
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
              readsFrom: {},
            )
            .map((row) => row.read<String>('name'))
            .get();
        expect(tables, contains('beans'));

        final shotRepo = ShotRepository(migrated);
        final loaded = await shotRepo.getShotById('legacy-shot');
        expect(loaded, isNotNull);
        expect(loaded!.startedAt, DateTime.utc(2026, 1, 1));
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