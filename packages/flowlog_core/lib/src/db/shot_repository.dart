import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../models/flavour_intensities.dart';
import '../models/shot.dart' as models;
import '../models/bean.dart' show repairMojibake;
import '../models/shot_annotation.dart' as models;
import '../models/shot_sample.dart' as models;
import 'flowlog_database.dart';
import 'shot_list_filters.dart';
import 'type_converters.dart';

/// A recorded local (or synced) shot deletion used to prevent resurrection.
@immutable
class DeletedShotTombstone {
  const DeletedShotTombstone({
    required this.shotId,
    required this.deletedAt,
  });

  final String shotId;
  final DateTime deletedAt;

  factory DeletedShotTombstone.fromJson(Map<String, dynamic> json) {
    return DeletedShotTombstone(
      shotId: json['shotId'] as String? ?? json['id'] as String,
      deletedAt: DateTime.parse(json['deletedAt'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'shotId': shotId,
        'deletedAt': deletedAt.toUtc().toIso8601String(),
      };
}

/// Persists and loads [models.Shot] records with optional samples.
class ShotRepository {
  ShotRepository(this._db);

  final FlowlogDatabase _db;

  /// Inserts a shot and its samples in a single transaction.
  Future<void> insertShot(models.Shot shot) async {
    await _db.transaction(() async {
      await _db.into(_db.shots).insertOnConflictUpdate(_shotToCompanion(shot));

      await (_db.delete(_db.shotSamples)
            ..where((row) => row.shotId.equals(shot.id)))
          .go();

      await (_db.delete(_db.shotAnnotations)
            ..where((row) => row.shotId.equals(shot.id)))
          .go();

      await (_db.delete(_db.shotTargetSamples)
            ..where((row) => row.shotId.equals(shot.id)))
          .go();

      if (shot.samples.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(
            _db.shotSamples,
            shot.samples
                .map((sample) => _sampleToCompanion(shot.id, sample))
                .toList(),
          );
        });
      }

      if (shot.annotations.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(
            _db.shotAnnotations,
            shot.annotations
                .map((annotation) => _annotationToCompanion(shot.id, annotation))
                .toList(),
          );
        });
      }

      if (shot.targetPressureSamples.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(
            _db.shotTargetSamples,
            shot.targetPressureSamples
                .map((sample) => _targetSampleToCompanion(shot.id, sample))
                .toList(),
          );
        });
      }
    });
  }

  /// Returns shot metadata without samples.
  Future<models.Shot?> getShotById(String id) async {
    final row = await (_db.select(_db.shots)
          ..where((shot) => shot.id.equals(id)))
        .getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _shotFromRow(row, samples: const [], annotations: const [], targetPressureSamples: const []);
  }

  /// Max points per shot for history list sparklines (keeps list loads light).
  static const int kHistorySparklineMaxSamples = 48;

  /// Returns shots ordered by [models.Shot.startedAt] descending.
  ///
  /// When [includeSamples] is true, each shot includes samples ordered by
  /// elapsed time. Prefer [sparklineOnly] for history lists: one batched sample
  /// query, no annotations/targets, downsampled for sparklines (avoids UI hangs).
  ///
  /// Optional [filters] narrow results by bean, date, taste, and peak pressure.
  Future<List<models.Shot>> listShots({
    bool includeSamples = false,
    bool sparklineOnly = false,
    ShotListFilters filters = ShotListFilters.empty,
  }) async {
    final query = _db.select(_db.shots);
    await _applyShotListFilters(query, filters);
    query.orderBy([(shot) => OrderingTerm.desc(shot.startedAt)]);

    final rows = await query.get();

    if (!includeSamples && !sparklineOnly) {
      return rows
          .map((row) => _shotFromRow(row, samples: const [], annotations: const [], targetPressureSamples: const []))
          .toList();
    }

    if (rows.isEmpty) {
      return const [];
    }

    if (sparklineOnly) {
      final byShot = await _loadSparklineSamples(rows.map((r) => r.id).toList());
      return [
        for (final row in rows)
          _shotFromRow(
            row,
            samples: _downsampleSamples(
              byShot[row.id] ?? const [],
              kHistorySparklineMaxSamples,
            ),
            annotations: const [],
            targetPressureSamples: const [],
          ),
      ];
    }

    // Full includeSamples (sync/export): batch samples; load
    // annotations/targets only when needed (detail uses getShotWithSamples).
    if (includeSamples) {
      final ids = rows.map((r) => r.id).toList();
      final allSampleRows = await (_db.select(_db.shotSamples)
            ..where((sample) => sample.shotId.isIn(ids))
            ..orderBy([
              (sample) => OrderingTerm.asc(sample.shotId),
              (sample) => OrderingTerm.asc(sample.elapsedMs),
            ]))
          .get();

      final byShot = <String, List<models.ShotSample>>{};
      for (final sampleRow in allSampleRows) {
        final list = byShot.putIfAbsent(sampleRow.shotId, () => []);
        list.add(_sampleFromRow(sampleRow));
      }

      // Full includeSamples (sync/export): still batch samples; load
      // annotations/targets only when needed (detail uses getShotWithSamples).
      final shots = <models.Shot>[];
      for (final row in rows) {
        final annotationRows = await (_db.select(_db.shotAnnotations)
              ..where((annotation) => annotation.shotId.equals(row.id))
              ..orderBy([
                (annotation) => OrderingTerm.asc(annotation.elapsedMs),
                (annotation) => OrderingTerm.asc(annotation.id),
              ]))
            .get();

        final targetSampleRows = await (_db.select(_db.shotTargetSamples)
              ..where((sample) => sample.shotId.equals(row.id))
              ..orderBy([(sample) => OrderingTerm.asc(sample.elapsedMs)]))
            .get();

        shots.add(
          _shotFromRow(
            row,
            samples: byShot[row.id] ?? const [],
            annotations: annotationRows.map(_annotationFromRow).toList(),
            targetPressureSamples:
                targetSampleRows.map(_targetSampleFromRow).toList(),
          ),
        );
      }
      return shots;
    }

    return const [];
  }

  /// Loads at most [kHistorySparklineMaxSamples] points per shot in SQL so
  /// History does not materialize every sample row into Dart.
  Future<Map<String, List<models.ShotSample>>> _loadSparklineSamples(
    List<String> ids,
  ) async {
    if (ids.isEmpty) {
      return const {};
    }

    final placeholders = List.filled(ids.length, '?').join(', ');
    final maxPoints = kHistorySparklineMaxSamples;
    final inner = maxPoints - 1;
    final queryRows = await _db.customSelect(
      '''
      SELECT shot_id, elapsed_ms, pressure_bar, weight_g, flow_gs, temp_c
      FROM (
        SELECT shot_id, elapsed_ms, pressure_bar, weight_g, flow_gs, temp_c,
               ROW_NUMBER() OVER (PARTITION BY shot_id ORDER BY elapsed_ms) AS rn,
               COUNT(*) OVER (PARTITION BY shot_id) AS cnt
        FROM shot_samples
        WHERE shot_id IN ($placeholders)
      )
      WHERE cnt <= ?
         OR rn = 1
         OR rn = cnt
         OR ((rn - 1) % MAX(1, (cnt - 1) / ?)) = 0
      ORDER BY shot_id, elapsed_ms
      ''',
      variables: [
        for (final id in ids) Variable.withString(id),
        Variable.withInt(maxPoints),
        Variable.withInt(inner),
      ],
      readsFrom: {_db.shotSamples},
    ).get();

    final byShot = <String, List<models.ShotSample>>{};
    for (final row in queryRows) {
      final shotId = row.read<String>('shot_id');
      byShot.putIfAbsent(shotId, () => []).add(
            models.ShotSample(
              elapsedMs: row.read<int>('elapsed_ms'),
              pressureBar: row.readNullable<double>('pressure_bar'),
              weightG: row.readNullable<double>('weight_g'),
              flowGs: row.readNullable<double>('flow_gs'),
              tempC: row.readNullable<double>('temp_c'),
            ),
          );
    }
    return byShot;
  }

  /// Evenly spaced sample subset for sparklines (always keeps first/last).
  static List<models.ShotSample> _downsampleSamples(
    List<models.ShotSample> samples,
    int maxPoints,
  ) {
    if (samples.length <= maxPoints || maxPoints < 3) {
      return samples;
    }
    final result = <models.ShotSample>[samples.first];
    final inner = maxPoints - 2;
    final lastIndex = samples.length - 1;
    for (var i = 1; i <= inner; i++) {
      final index = ((i * lastIndex) / (inner + 1)).round().clamp(1, lastIndex - 1);
      final sample = samples[index];
      if (result.last.elapsedMs != sample.elapsedMs) {
        result.add(sample);
      }
    }
    if (result.last.elapsedMs != samples.last.elapsedMs) {
      result.add(samples.last);
    }
    return result;
  }

  Future<void> _applyShotListFilters(
    SimpleSelectStatement<$ShotsTable, ShotRow> query,
    ShotListFilters filters,
  ) async {
    final beanQuery = filters.beanQuery.trim();
    if (beanQuery.isNotEmpty) {
      final normalized = beanQuery.toLowerCase();
      final beanIds = await (_db.select(_db.beans)
            ..where(
              (bean) =>
                  bean.name.lower().like('%$normalized%') |
                  bean.id.lower().like('%$normalized%'),
            ))
          .map((row) => row.id)
          .get();

      query.where((shot) {
        final idMatch = shot.beanId.lower().like('%$normalized%');
        if (beanIds.isEmpty) {
          return idMatch;
        }
        return idMatch | shot.beanId.isIn(beanIds);
      });
    }

    if (filters.startedOnOrAfter != null) {
      final afterIso =
          const UtcIso8601Converter().toSql(filters.startedOnOrAfter!);
      query.where((shot) => shot.startedAt.isBiggerOrEqualValue(afterIso));
    }

    if (filters.startedOnOrBefore != null) {
      final beforeIso =
          const UtcIso8601Converter().toSql(filters.startedOnOrBefore!);
      query.where((shot) => shot.startedAt.isSmallerOrEqualValue(beforeIso));
    }

    if (filters.minTasteScore != null) {
      query.where(
        (shot) =>
            shot.tasteScore.isBiggerOrEqualValue(filters.minTasteScore!),
      );
    }

    if (filters.minPeakPressureBar != null ||
        filters.maxPeakPressureBar != null) {
      final shotIds = await _shotIdsWithPeakPressureRange(
        minBar: filters.minPeakPressureBar,
        maxBar: filters.maxPeakPressureBar,
      );
      if (shotIds.isEmpty) {
        query.where((shot) => const Constant(false));
      } else {
        query.where((shot) => shot.id.isIn(shotIds));
      }
    }

    if (filters.minDurationMs != null || filters.maxDurationMs != null) {
      final shotIds = await _shotIdsInDurationRange(
        minMs: filters.minDurationMs,
        maxMs: filters.maxDurationMs,
      );
      if (shotIds.isEmpty) {
        query.where((shot) => const Constant(false));
      } else {
        query.where((shot) => shot.id.isIn(shotIds));
      }
    }

    if (filters.minGrindSetting != null) {
      query.where(
        (shot) => shot.grindSetting
            .isBiggerOrEqualValue(filters.minGrindSetting!),
      );
    }
    if (filters.maxGrindSetting != null) {
      query.where(
        (shot) => shot.grindSetting
            .isSmallerOrEqualValue(filters.maxGrindSetting!),
      );
    }

    if (filters.tagIds.isNotEmpty) {
      final shotIds = await _shotIdsWithAnyTag(filters.tagIds);
      if (shotIds.isEmpty) {
        query.where((shot) => const Constant(false));
      } else {
        query.where((shot) => shot.id.isIn(shotIds));
      }
    }
  }

  // Note: the target samples loading for filtered list is handled in listShots when includeSamples.

  Future<List<String>> _shotIdsWithAnyTag(Set<String> tagIds) async {
    final rows = await (_db.select(_db.shotTags)
          ..where((row) => row.tagId.isIn(tagIds)))
        .map((row) => row.shotId)
        .get();

    return rows.toSet().toList();
  }

  Future<List<String>> _shotIdsWithPeakPressureRange({
    double? minBar,
    double? maxBar,
  }) async {
    final clauses = <String>[];
    final variables = <Variable<Object>>[];
    if (minBar != null) {
      clauses.add('MAX(pressure_bar) >= ?');
      variables.add(Variable.withReal(minBar));
    }
    if (maxBar != null) {
      clauses.add('MAX(pressure_bar) <= ?');
      variables.add(Variable.withReal(maxBar));
    }
    if (clauses.isEmpty) {
      return const [];
    }

    final rows = await _db.customSelect(
      '''
      SELECT shot_id
      FROM shot_samples
      GROUP BY shot_id
      HAVING ${clauses.join(' AND ')}
      ''',
      variables: variables,
      readsFrom: {_db.shotSamples},
    ).get();

    return rows.map((row) => row.read<String>('shot_id')).toList();
  }

  /// Brews whose [Shot.endedAt] − [Shot.startedAt] falls in the given range.
  Future<List<String>> _shotIdsInDurationRange({
    int? minMs,
    int? maxMs,
  }) async {
    final clauses = <String>[
      'ended_at IS NOT NULL',
    ];
    final variables = <Variable<Object>>[];
    // ISO-8601 timestamps compare lexicographically when stored consistently.
    // Duration via unix epoch seconds (SQLite strftime).
    if (minMs != null) {
      clauses.add(
        "(CAST(strftime('%s', ended_at) AS INTEGER) - "
        "CAST(strftime('%s', started_at) AS INTEGER)) * 1000 >= ?",
      );
      variables.add(Variable.withInt(minMs));
    }
    if (maxMs != null) {
      clauses.add(
        "(CAST(strftime('%s', ended_at) AS INTEGER) - "
        "CAST(strftime('%s', started_at) AS INTEGER)) * 1000 <= ?",
      );
      variables.add(Variable.withInt(maxMs));
    }

    final rows = await _db.customSelect(
      '''
      SELECT id
      FROM shots
      WHERE ${clauses.join(' AND ')}
      ''',
      variables: variables,
      readsFrom: {_db.shots},
    ).get();

    return rows.map((row) => row.read<String>('id')).toList();
  }

  /// Returns the grind setting from the most recently saved shot, if any.
  Future<double?> lastGrindSetting() async {
    final row = await (_db.select(_db.shots)
          ..where((shot) => shot.grindSetting.isNotNull())
          ..orderBy([(shot) => OrderingTerm.desc(shot.startedAt)])
          ..limit(1))
        .getSingleOrNull();

    return row?.grindSetting;
  }

  /// Returns the top shots by target gamification score (highest first).
  /// Only includes shots that have a non-null targetScore.
  /// Useful for high-score leaderboards.
  Future<List<models.Shot>> topTargetScores({int limit = 10}) async {
    final query = _db.select(_db.shots)
      ..where((shot) => shot.targetScore.isNotNull())
      ..orderBy([
        (shot) => OrderingTerm.desc(shot.targetScore),
        (shot) => OrderingTerm.desc(shot.startedAt),
      ])
      ..limit(limit);
    final rows = await query.get();
    return rows
        .map((row) => _shotFromRow(row, samples: const [], annotations: const [], targetPressureSamples: const []))
        .toList();
  }

  /// Deletes a shot and its related samples, annotations, and tag links.
  ///
  /// Records a tombstone so Nextcloud sync will not re-import the shot and
  /// other devices can drop it when they pull the backup.
  Future<void> deleteShot(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.shotSamples)
            ..where((row) => row.shotId.equals(id)))
          .go();
      await (_db.delete(_db.shotAnnotations)
            ..where((row) => row.shotId.equals(id)))
          .go();
      await (_db.delete(_db.shotTags)..where((row) => row.shotId.equals(id)))
          .go();
      await (_db.delete(_db.shotTargetSamples)
            ..where((row) => row.shotId.equals(id)))
          .go();
      await (_db.delete(_db.shots)..where((shot) => shot.id.equals(id))).go();
      await _db.into(_db.deletedShots).insertOnConflictUpdate(
            DeletedShotsCompanion.insert(
              shotId: id,
              deletedAt: DateTime.now().toUtc(),
            ),
          );
    });
  }

  /// Whether [id] is in the local deletion tombstone list.
  Future<bool> isShotDeleted(String id) async {
    final row = await (_db.select(_db.deletedShots)
          ..where((t) => t.shotId.equals(id)))
        .getSingleOrNull();
    return row != null;
  }

  /// All known deleted shot ids (for sync export).
  Future<List<DeletedShotTombstone>> listDeletedShots() async {
    final rows = await _db.select(_db.deletedShots).get();
    return [
      for (final row in rows)
        DeletedShotTombstone(shotId: row.shotId, deletedAt: row.deletedAt),
    ];
  }

  /// Records a tombstone without requiring the shot to still exist.
  Future<void> recordShotDeleted(
    String id, {
    DateTime? deletedAt,
  }) async {
    await _db.into(_db.deletedShots).insertOnConflictUpdate(
          DeletedShotsCompanion.insert(
            shotId: id,
            deletedAt: deletedAt ?? DateTime.now().toUtc(),
          ),
        );
  }

  /// Drops tombstones older than [maxAge] (default 180 days).
  Future<int> pruneDeletedShots({
    Duration maxAge = const Duration(days: 180),
  }) async {
    final cutoffIso =
        const UtcIso8601Converter().toSql(DateTime.now().toUtc().subtract(maxAge));
    // ISO-8601 UTC strings compare lexicographically by time.
    final countRow = await _db.customSelect(
      'SELECT COUNT(*) AS n FROM deleted_shots WHERE deleted_at < ?',
      variables: [Variable.withString(cutoffIso)],
      readsFrom: {_db.deletedShots},
    ).getSingle();
    final n = countRow.read<int>('n');
    if (n > 0) {
      await _db.customStatement(
        'DELETE FROM deleted_shots WHERE deleted_at < ?',
        [cutoffIso],
      );
    }
    return n;
  }

  /// Returns a shot with its samples ordered by elapsed time.
  Future<models.Shot?> getShotWithSamples(String id) async {
    final row = await (_db.select(_db.shots)
          ..where((shot) => shot.id.equals(id)))
        .getSingleOrNull();

    if (row == null) {
      return null;
    }

    final sampleRows = await (_db.select(_db.shotSamples)
          ..where((sample) => sample.shotId.equals(id))
          ..orderBy([(sample) => OrderingTerm.asc(sample.elapsedMs)]))
        .get();

    final annotationRows = await (_db.select(_db.shotAnnotations)
          ..where((annotation) => annotation.shotId.equals(id))
          ..orderBy([
            (annotation) => OrderingTerm.asc(annotation.elapsedMs),
            (annotation) => OrderingTerm.asc(annotation.id),
          ]))
        .get();

    final targetSampleRows = await (_db.select(_db.shotTargetSamples)
          ..where((sample) => sample.shotId.equals(id))
          ..orderBy([(sample) => OrderingTerm.asc(sample.elapsedMs)]))
        .get();

    return _shotFromRow(
      row,
      samples: sampleRows.map(_sampleFromRow).toList(),
      annotations: annotationRows.map(_annotationFromRow).toList(),
      targetPressureSamples: targetSampleRows.map(_targetSampleFromRow).toList(),
    );
  }

  ShotsCompanion _shotToCompanion(models.Shot shot) {
    return ShotsCompanion.insert(
      id: shot.id,
      startedAt: shot.startedAt,
      endedAt: Value(shot.endedAt),
      doseG: Value(shot.doseG),
      yieldG: Value(shot.yieldG),
      grindSetting: Value(shot.grindSetting),
      beanId: Value(shot.beanId),
      waterTempC: Value(shot.waterTempC),
      notes: Value(shot.notes),
      location: Value(shot.location),
      latitude: Value(shot.latitude),
      longitude: Value(shot.longitude),
      tasteScore: Value(shot.tasteScore),
      flavourTags: Value(jsonEncode(shot.flavourTags)),
      flavourIntensities: Value(encodeFlavourIntensities(shot.flavourIntensities)),
      coffeejackRewindTurns: Value(shot.coffeejackRewindTurns),
      coffeejackPreinfusionTurns: Value(shot.coffeejackPreinfusionTurns),
      grinder: Value(shot.grinder),
      showerScreen: Value(shot.showerScreen),
      basket: Value(shot.basket),
      scale: Value(shot.scale),
      brewer: Value(shot.brewer),
      lastModifiedAt: Value(shot.lastModifiedAt),
      autoStartPressureBar: Value(shot.autoStartPressureBar),
      targetClosenessPercent: Value(shot.targetClosenessPercent),
      targetMaxStreakSeconds: Value(shot.targetMaxStreakSeconds),
      targetScore: Value(shot.targetScore),
    );
  }

  ShotSamplesCompanion _sampleToCompanion(
    String shotId,
    models.ShotSample sample,
  ) {
    return ShotSamplesCompanion.insert(
      shotId: shotId,
      elapsedMs: sample.elapsedMs,
      pressureBar: Value(sample.pressureBar),
      weightG: Value(sample.weightG),
      flowGs: Value(sample.flowGs),
      tempC: Value(sample.tempC),
    );
  }

  ShotTargetSamplesCompanion _targetSampleToCompanion(
    String shotId,
    models.ShotSample sample,
  ) {
    return ShotTargetSamplesCompanion.insert(
      shotId: shotId,
      elapsedMs: sample.elapsedMs,
      pressureBar: Value(sample.pressureBar),
    );
  }

  ShotAnnotationsCompanion _annotationToCompanion(
    String shotId,
    models.ShotAnnotation annotation,
  ) {
    return ShotAnnotationsCompanion.insert(
      shotId: shotId,
      elapsedMs: annotation.elapsedMs,
      label: annotation.label,
      type: _annotationTypeToSql(annotation.type),
    );
  }

  models.Shot _shotFromRow(
    ShotRow row, {
    required List<models.ShotSample> samples,
    required List<models.ShotAnnotation> annotations,
    List<models.ShotSample> targetPressureSamples = const [],
  }) {
    return models.Shot(
      id: row.id,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      doseG: row.doseG,
      yieldG: row.yieldG,
      grindSetting: row.grindSetting,
      beanId: row.beanId,
      waterTempC: row.waterTempC,
      notes: repairMojibake(row.notes),
      location: row.location,
      latitude: row.latitude,
      longitude: row.longitude,
      tasteScore: row.tasteScore,
      flavourTags: _decodeFlavourTags(row.flavourTags),
      flavourIntensities: decodeFlavourIntensities(row.flavourIntensities),
      coffeejackRewindTurns: row.coffeejackRewindTurns,
      coffeejackPreinfusionTurns: row.coffeejackPreinfusionTurns,
      grinder: row.grinder,
      showerScreen: row.showerScreen,
      basket: row.basket,
      scale: row.scale,
      brewer: row.brewer,
      lastModifiedAt: row.lastModifiedAt,
      autoStartPressureBar: row.autoStartPressureBar,
      targetClosenessPercent: row.targetClosenessPercent,
      targetMaxStreakSeconds: row.targetMaxStreakSeconds,
      targetScore: row.targetScore,
      samples: samples,
      annotations: annotations,
      targetPressureSamples: targetPressureSamples,
    );
  }

  models.ShotAnnotation _annotationFromRow(ShotAnnotationRow row) {
    return models.ShotAnnotation(
      elapsedMs: row.elapsedMs,
      label: row.label,
      type: _annotationTypeFromSql(row.type),
    );
  }

  models.ShotSample _sampleFromRow(ShotSampleRow row) {
    return models.ShotSample(
      elapsedMs: row.elapsedMs,
      pressureBar: row.pressureBar,
      weightG: row.weightG,
      flowGs: row.flowGs,
      tempC: row.tempC,
    );
  }

  models.ShotSample _targetSampleFromRow(ShotTargetSampleRow row) {
    return models.ShotSample(
      elapsedMs: row.elapsedMs,
      pressureBar: row.pressureBar,
    );
  }

  List<String> _decodeFlavourTags(String jsonText) {
    if (jsonText.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(jsonText);
    if (decoded is! List) {
      return const [];
    }

    return decoded.map((value) => value as String).toList();
  }

  String _annotationTypeToSql(models.ShotAnnotationType type) {
    return switch (type) {
      models.ShotAnnotationType.channel => 'channel',
      models.ShotAnnotationType.note => 'note',
    };
  }

  models.ShotAnnotationType _annotationTypeFromSql(String value) {
    return switch (value) {
      'channel' => models.ShotAnnotationType.channel,
      'note' => models.ShotAnnotationType.note,
      _ => throw ArgumentError.value(value, 'type', 'Unknown annotation type'),
    };
  }
}