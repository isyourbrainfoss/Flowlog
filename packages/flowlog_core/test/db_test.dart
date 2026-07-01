import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('schema', () {
    test('schema version is 6', () async {
      final db = FlowlogDatabase.inMemory();
      addTearDown(db.close);

      expect(db.schemaVersion, 6);
    });

    test(
      'creates shots, shot_samples, beans, tags, shot_tags, shot_annotations, and saved profile tables',
      () async {
      final db = FlowlogDatabase.inMemory();
      addTearDown(db.close);

      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
            readsFrom: {},
          )
          .map((row) => row.read<String>('name'))
          .get();

      expect(
        tables,
        containsAll([
          'shots',
          'shot_samples',
          'beans',
          'tags',
          'shot_tags',
          'shot_annotations',
          'saved_profiles',
          'saved_profile_samples',
        ]),
      );
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

    test('inserts and reads shot annotations', () async {
      final shot = Shot(
        id: 'shot-annotated',
        startedAt: DateTime.utc(2026, 6, 29, 10, 0),
        samples: const [
          ShotSample(elapsedMs: 0, pressureBar: 0),
          ShotSample(elapsedMs: 5000, pressureBar: 9),
        ],
        annotations: const [
          ShotAnnotation(
            elapsedMs: 1200,
            label: 'Channel 1',
            type: ShotAnnotationType.channel,
          ),
          ShotAnnotation(
            elapsedMs: 4200,
            label: 'First drops',
            type: ShotAnnotationType.note,
          ),
        ],
      );

      await repository.insertShot(shot);

      final loaded = await repository.getShotWithSamples('shot-annotated');
      expect(loaded, shot);
    });

    test('deleteShot removes shot, samples, and annotations', () async {
      final shot = Shot(
        id: 'shot-delete-me',
        startedAt: DateTime.utc(2026, 6, 29, 10, 0),
        samples: const [
          ShotSample(elapsedMs: 0, pressureBar: 1.0),
        ],
        annotations: const [
          ShotAnnotation(
            elapsedMs: 500,
            label: 'Channel 1',
            type: ShotAnnotationType.channel,
          ),
        ],
      );

      await repository.insertShot(shot);
      await repository.deleteShot(shot.id);

      expect(await repository.getShotById(shot.id), isNull);
      expect(await repository.getShotWithSamples(shot.id), isNull);
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

  group('TagRepository', () {
    late FlowlogDatabase db;
    late TagRepository tagRepository;
    late ShotRepository shotRepository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      tagRepository = TagRepository(db);
      shotRepository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('creates, reads, updates, and deletes tags', () async {
      const tag = Tag(id: 'tag-practice', name: 'Practice');

      await tagRepository.upsertTag(tag);
      expect(await tagRepository.getTagById(tag.id), tag);

      const updated = Tag(id: 'tag-practice', name: 'Competition');
      await tagRepository.updateTag(updated);
      expect(await tagRepository.getTagById(tag.id), updated);

      final listed = await tagRepository.listTags();
      expect(listed, [updated]);

      await tagRepository.deleteTag(tag.id);
      expect(await tagRepository.getTagById(tag.id), isNull);
      expect(await tagRepository.listTags(), isEmpty);
    });

    test('assigns tags to shots and counts linked shots', () async {
      const practice = Tag(id: 'tag-practice', name: 'Practice');
      const dialIn = Tag(id: 'tag-dial-in', name: 'Dial-in');
      await tagRepository.upsertTag(practice);
      await tagRepository.upsertTag(dialIn);

      final taggedShot = Shot(
        id: 'shot-tagged',
        startedAt: DateTime.utc(2026, 6, 29, 10),
      );
      final otherShot = Shot(
        id: 'shot-other',
        startedAt: DateTime.utc(2026, 6, 29, 11),
      );
      await shotRepository.insertShot(taggedShot);
      await shotRepository.insertShot(otherShot);

      await tagRepository.setTagsForShot(taggedShot.id, [practice.id, dialIn.id]);

      expect(
        (await tagRepository.getTagsForShot(taggedShot.id))
            .map((tag) => tag.id)
            .toList(),
        [dialIn.id, practice.id],
      );
      expect(await tagRepository.getTagsForShot(otherShot.id), isEmpty);
      expect(await tagRepository.countShotsForTag(practice.id), 1);

      final withCounts = await tagRepository.listTagsWithShotCounts();
      expect(withCounts.firstWhere((entry) => entry.tag.id == practice.id).shotCount, 1);
      expect(withCounts.firstWhere((entry) => entry.tag.id == dialIn.id).shotCount, 1);

      await tagRepository.setTagsForShot(taggedShot.id, [practice.id]);
      expect(await tagRepository.countShotsForTag(dialIn.id), 0);
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

    test('orders beans by recent shot use and ensures new names', () async {
      const olderBean = Bean(id: 'bean-old', name: 'Old Roast');
      const newerBean = Bean(id: 'bean-new', name: 'Test');
      await beanRepository.upsertBean(olderBean);
      await beanRepository.upsertBean(newerBean);

      await shotRepository.insertShot(
        Shot(
          id: 'shot-old',
          startedAt: DateTime.utc(2026, 6, 28, 10),
          beanId: olderBean.id,
        ),
      );
      await shotRepository.insertShot(
        Shot(
          id: 'shot-new',
          startedAt: DateTime.utc(2026, 6, 29, 10),
          beanId: newerBean.id,
        ),
      );

      final ordered = await beanRepository.listBeansByRecentUse();
      expect(ordered.map((bean) => bean.id).toList(), [
        newerBean.id,
        olderBean.id,
      ]);

      final created = await beanRepository.createBean(name: 'Fresh Bag');
      expect(created.name, 'Fresh Bag');
      expect(await beanRepository.getBeanById(created.id), created);

      final duplicate = await beanRepository.createBean(name: 'Test');
      expect(duplicate.id, isNot(newerBean.id));
      expect(duplicate.name, 'Test');

      final resolved = await beanRepository.resolveActiveBeanId(
        name: 'Test',
      );
      expect(resolved, newerBean.id);
    });

    test('createBean allows same name with different roast dates', () async {
      final first = await beanRepository.createBean(
        name: 'House Blend',
        roastDate: DateTime.utc(2026, 3, 1),
      );
      final second = await beanRepository.createBean(
        name: 'House Blend',
        roastDate: DateTime.utc(2026, 4, 15),
      );

      expect(first.id, isNot(second.id));
      expect((await beanRepository.listBeans()).where((b) => b.name == 'House Blend'), hasLength(2));
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
        expect(writer.schemaVersion, 6);
        await writer.close();

        final reader = FlowlogDatabase.openFile(dbPath);
        final readerRepo = ShotRepository(reader);

        expect(reader.schemaVersion, 6);
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

        expect(migrated.schemaVersion, 6);

        final tables = await migrated
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
              readsFrom: {},
            )
            .map((row) => row.read<String>('name'))
            .get();
        expect(
          tables,
          containsAll([
            'beans',
            'tags',
            'shot_tags',
            'shot_annotations',
            'saved_profiles',
            'saved_profile_samples',
          ]),
        );

        final beanColumns = await migrated
            .customSelect(
              'PRAGMA table_info(beans)',
              readsFrom: {},
            )
            .map((row) => row.read<String>('name'))
            .get();
        expect(beanColumns, contains('roast_date'));

        final shotRepo = ShotRepository(migrated);
        final loaded = await shotRepo.getShotById('legacy-shot');
        expect(loaded, isNotNull);
        expect(loaded!.startedAt, DateTime.utc(2026, 1, 1));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('migrates v2 database to v3 and adds tags tables', () async {
      final tempDir = await Directory.systemTemp.createTemp('flowlog_db_v2_');
      final dbPath = '${tempDir.path}/flowlog.db';

      try {
        final v2Db = sqlite3.open(dbPath);
        v2Db.execute('''
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
        v2Db.execute('''
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
        v2Db.execute('''
          CREATE TABLE beans (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            origin TEXT,
            roast_level TEXT,
            stock_g REAL,
            notes TEXT
          );
        ''');
        v2Db.execute(
          "INSERT INTO shots (id, started_at) VALUES ('legacy-shot', '2026-01-01T00:00:00.000Z');",
        );
        v2Db.execute('PRAGMA user_version = 2;');
        v2Db.dispose();

        final migrated = FlowlogDatabase.openFile(dbPath);
        addTearDown(migrated.close);

        expect(migrated.schemaVersion, 6);

        final tables = await migrated
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
              readsFrom: {},
            )
            .map((row) => row.read<String>('name'))
            .get();
        expect(
          tables,
          containsAll([
            'tags',
            'shot_tags',
            'shot_annotations',
            'saved_profiles',
            'saved_profile_samples',
          ]),
        );

        final shotRepo = ShotRepository(migrated);
        final loaded = await shotRepo.getShotById('legacy-shot');
        expect(loaded, isNotNull);
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