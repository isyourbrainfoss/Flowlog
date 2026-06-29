import 'package:drift/drift.dart';

import '../models/saved_profile.dart' as models;
import '../models/shot_sample.dart' as models;
import 'flowlog_database.dart';

/// Persists and loads [models.SavedProfile] records with pressure samples.
class ProfileRepository {
  ProfileRepository(this._db);

  final FlowlogDatabase _db;

  /// Inserts or replaces a profile and its pressure samples.
  Future<void> insertProfile(models.SavedProfile profile) async {
    await _db.transaction(() async {
      await _db
          .into(_db.savedProfiles)
          .insertOnConflictUpdate(_profileToCompanion(profile));

      await (_db.delete(_db.savedProfileSamples)
            ..where((row) => row.profileId.equals(profile.id)))
          .go();

      if (profile.pressureSamples.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(
            _db.savedProfileSamples,
            profile.pressureSamples
                .map((sample) => _sampleToCompanion(profile.id, sample))
                .toList(),
          );
        });
      }
    });
  }

  /// Returns profile metadata without samples.
  Future<models.SavedProfile?> getProfileById(String id) async {
    final row = await (_db.select(_db.savedProfiles)
          ..where((profile) => profile.id.equals(id)))
        .getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _profileFromRow(row, samples: const []);
  }

  /// Returns profiles ordered by [models.SavedProfile.createdAt] descending.
  Future<List<models.SavedProfile>> listProfiles({
    bool includeSamples = false,
  }) async {
    final rows = await (_db.select(_db.savedProfiles)
          ..orderBy([(profile) => OrderingTerm.desc(profile.createdAt)]))
        .get();

    if (!includeSamples) {
      return rows
          .map((row) => _profileFromRow(row, samples: const []))
          .toList();
    }

    final profiles = <models.SavedProfile>[];
    for (final row in rows) {
      final sampleRows = await (_db.select(_db.savedProfileSamples)
            ..where((sample) => sample.profileId.equals(row.id))
            ..orderBy([(sample) => OrderingTerm.asc(sample.elapsedMs)]))
          .get();

      profiles.add(
        _profileFromRow(
          row,
          samples: sampleRows.map(_sampleFromRow).toList(),
        ),
      );
    }
    return profiles;
  }

  /// Returns a profile with pressure samples ordered by elapsed time.
  Future<models.SavedProfile?> getProfileWithSamples(String id) async {
    final row = await (_db.select(_db.savedProfiles)
          ..where((profile) => profile.id.equals(id)))
        .getSingleOrNull();

    if (row == null) {
      return null;
    }

    final sampleRows = await (_db.select(_db.savedProfileSamples)
          ..where((sample) => sample.profileId.equals(id))
          ..orderBy([(sample) => OrderingTerm.asc(sample.elapsedMs)]))
        .get();

    return _profileFromRow(
      row,
      samples: sampleRows.map(_sampleFromRow).toList(),
    );
  }

  /// Deletes a profile by id (samples cascade).
  Future<void> deleteProfile(String id) async {
    await (_db.delete(_db.savedProfiles)
          ..where((profile) => profile.id.equals(id)))
        .go();
  }

  SavedProfilesCompanion _profileToCompanion(models.SavedProfile profile) {
    return SavedProfilesCompanion.insert(
      id: profile.id,
      name: profile.name,
      createdAt: profile.createdAt,
      sourceShotId: Value(profile.sourceShotId),
      doseG: Value(profile.doseG),
      yieldG: Value(profile.yieldG),
      grindSetting: Value(profile.grindSetting),
      beanId: Value(profile.beanId),
      waterTempC: Value(profile.waterTempC),
    );
  }

  SavedProfileSamplesCompanion _sampleToCompanion(
    String profileId,
    models.ShotSample sample,
  ) {
    return SavedProfileSamplesCompanion.insert(
      profileId: profileId,
      elapsedMs: sample.elapsedMs,
      pressureBar: sample.pressureBar ?? 0,
    );
  }

  models.SavedProfile _profileFromRow(
    SavedProfileRow row, {
    required List<models.ShotSample> samples,
  }) {
    return models.SavedProfile(
      id: row.id,
      name: row.name,
      createdAt: row.createdAt,
      sourceShotId: row.sourceShotId,
      doseG: row.doseG,
      yieldG: row.yieldG,
      grindSetting: row.grindSetting,
      beanId: row.beanId,
      waterTempC: row.waterTempC,
      pressureSamples: samples,
    );
  }

  models.ShotSample _sampleFromRow(SavedProfileSampleRow row) {
    return models.ShotSample(
      elapsedMs: row.elapsedMs,
      pressureBar: row.pressureBar,
    );
  }
}