import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('SavedProfile', () {
    test('fromShot captures metadata and pressure samples', () {
      final shot = _loadFixtureShot('shots/minimal_shot.json');

      final profile = SavedProfile.fromShot(
        shot,
        id: 'profile-test',
        createdAt: DateTime.utc(2026, 6, 29, 12),
      );

      expect(profile.id, 'profile-test');
      expect(profile.sourceShotId, shot.id);
      expect(profile.doseG, shot.doseG);
      expect(profile.yieldG, shot.yieldG);
      expect(profile.grindSetting, shot.grindSetting);
      expect(profile.beanId, shot.beanId);
      expect(profile.waterTempC, shot.waterTempC);
      expect(profile.pressureSamples, isNotEmpty);
      expect(
        profile.pressureSamples.every((sample) => sample.pressureBar != null),
        isTrue,
      );
    });

    test('toJson/fromJson round-trip', () {
      final profile = SavedProfile(
        id: 'profile-1',
        name: 'Morning repeat',
        createdAt: DateTime.utc(2026, 6, 29, 8),
        sourceShotId: 'shot-1',
        doseG: 18,
        yieldG: 36,
        grindSetting: 14,
        beanId: 'bean-house',
        waterTempC: 93,
        pressureSamples: const [
          ShotSample(elapsedMs: 0, pressureBar: 0),
          ShotSample(elapsedMs: 5000, pressureBar: 9),
        ],
      );

      expect(SavedProfile.fromJson(profile.toJson()), profile);
    });
  });

  group('ProfileMetadata', () {
    test('maps profile fields for repeat prefill', () {
      final profile = SavedProfile(
        id: 'profile-1',
        name: 'Test',
        createdAt: DateTime.utc(2026, 6, 29),
        doseG: 18,
        yieldG: 36,
        grindSetting: 14,
        beanId: 'bean-house',
        waterTempC: 93,
      );

      final metadata = ProfileMetadata.fromProfile(profile);
      expect(metadata.doseG, 18);
      expect(metadata.yieldG, 36);
      expect(metadata.grindSetting, 14);
      expect(metadata.beanId, 'bean-house');
      expect(metadata.waterTempC, 93);
    });
  });

  group('ProfileRepository', () {
    late FlowlogDatabase db;
    late ProfileRepository repository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ProfileRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('inserts and reads profile with pressure samples', () async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final profile = SavedProfile.fromShot(
        shot,
        id: 'profile-fixture',
        createdAt: DateTime.utc(2026, 6, 29, 12),
      );

      await repository.insertProfile(profile);

      final withoutSamples = await repository.getProfileById(profile.id);
      expect(withoutSamples, isNotNull);
      expect(withoutSamples!.pressureSamples, isEmpty);

      final withSamples = await repository.getProfileWithSamples(profile.id);
      expect(withSamples, profile);
    });

    test('listProfiles returns newest first', () async {
      final older = SavedProfile(
        id: 'profile-old',
        name: 'Older',
        createdAt: DateTime.utc(2026, 6, 28),
        pressureSamples: const [
          ShotSample(elapsedMs: 0, pressureBar: 1),
        ],
      );
      final newer = SavedProfile(
        id: 'profile-new',
        name: 'Newer',
        createdAt: DateTime.utc(2026, 6, 29),
        pressureSamples: const [
          ShotSample(elapsedMs: 0, pressureBar: 2),
        ],
      );

      await repository.insertProfile(older);
      await repository.insertProfile(newer);

      final listed = await repository.listProfiles(includeSamples: true);
      expect(listed.map((profile) => profile.id).toList(), [
        'profile-new',
        'profile-old',
      ]);
    });

    test('deleteProfile removes profile and samples', () async {
      final profile = SavedProfile(
        id: 'profile-delete',
        name: 'Delete me',
        createdAt: DateTime.utc(2026, 6, 29),
        pressureSamples: const [
          ShotSample(elapsedMs: 1000, pressureBar: 8),
        ],
      );

      await repository.insertProfile(profile);
      await repository.deleteProfile(profile.id);

      expect(await repository.getProfileById(profile.id), isNull);
      expect(await repository.getProfileWithSamples(profile.id), isNull);
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