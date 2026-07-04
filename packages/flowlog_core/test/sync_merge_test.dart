import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('mergeSyncPayload', () {
    late FlowlogDatabase db;

    setUp(() {
      db = FlowlogDatabase.inMemory();
    });

    tearDown(() async {
      await db.close();
    });

    test('merges shots, profiles, and beans by id', () async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final profile = SavedProfile.fromShot(
        shot,
        id: 'profile-merge-test',
        createdAt: DateTime.utc(2026, 6, 29, 12),
      );
      const bean = Bean(
        id: 'bean-merge-test',
        name: 'House Blend',
        roastDate: null,
        roastLevel: 'medium',
      );

      final payload = SyncPayload(
        version: syncPayloadVersion,
        exportedAt: DateTime.utc(2026, 7, 4),
        config: const SyncConfig(),
        shots: [shot],
        profiles: [profile],
        beans: [bean],
      );

      final result = await mergeSyncPayload(database: db, payload: payload);

      expect(result.shotsMerged, 1);
      expect(result.profilesMerged, 1);
      expect(result.beansMerged, 1);

      final shotRepository = ShotRepository(db);
      final profileRepository = ProfileRepository(db);
      final beanRepository = BeanRepository(db);

      expect(await shotRepository.getShotWithSamples(shot.id), shot);
      expect(
        await profileRepository.getProfileWithSamples(profile.id),
        profile,
      );
      expect(await beanRepository.getBeanById(bean.id), bean);
    });

    test('updates existing records on re-import', () async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final updatedShot = shot.copyWith(notes: 'Updated notes');

      await mergeSyncPayload(
        database: db,
        payload: SyncPayload(
          version: syncPayloadVersion,
          exportedAt: DateTime.utc(2026, 7, 4),
          config: const SyncConfig(),
          shots: [shot],
          profiles: const [],
          beans: const [],
        ),
      );

      await mergeSyncPayload(
        database: db,
        payload: SyncPayload(
          version: syncPayloadVersion,
          exportedAt: DateTime.utc(2026, 7, 5),
          config: const SyncConfig(),
          shots: [updatedShot],
          profiles: const [],
          beans: const [],
        ),
      );

      final stored = await ShotRepository(db).getShotById(shot.id);
      expect(stored?.notes, 'Updated notes');
    });
  });

  group('buildSyncPayloadFromDatabase / parseSyncBackup', () {
    late FlowlogDatabase db;

    setUp(() async {
      db = FlowlogDatabase.inMemory();
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await ShotRepository(db).insertShot(shot);
      await BeanRepository(db).upsertBean(
        const Bean(id: 'bean-export', name: 'Export Bean'),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('round-trips through plain JSON backup', () async {
      final payload = await buildSyncPayloadFromDatabase(db);
      final wire = encodeSyncBackup(payload);
      final restored = parseSyncBackup(wire);

      expect(restored.version, syncPayloadVersion);
      expect(restored.shots.length, 1);
      expect(restored.beans.length, 1);
      expect(restored.beans.first.name, 'Export Bean');
    });

    test('imports v1 payloads without beans', () {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final wire = jsonEncode({
        'version': 1,
        'exportedAt': DateTime.utc(2026, 6, 1).toIso8601String(),
        'config': const SyncConfig().toJson(),
        'shots': [shot.toJson()],
        'profiles': <dynamic>[],
      });

      final payload = parseSyncBackup(wire);
      expect(payload.version, 1);
      expect(payload.beans, isEmpty);
      expect(payload.shots, [shot]);
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