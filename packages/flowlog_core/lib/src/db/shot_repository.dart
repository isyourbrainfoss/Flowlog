import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/shot.dart' as models;
import '../models/shot_sample.dart' as models;
import 'flowlog_database.dart';
import 'shot_list_filters.dart';
import 'type_converters.dart';

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

    return _shotFromRow(row, samples: const []);
  }

  /// Returns shots ordered by [models.Shot.startedAt] descending.
  ///
  /// When [includeSamples] is true, each shot includes samples ordered by
  /// elapsed time (useful for history sparklines).
  ///
  /// Optional [filters] narrow results by bean, date, taste, and peak pressure.
  Future<List<models.Shot>> listShots({
    bool includeSamples = false,
    ShotListFilters filters = ShotListFilters.empty,
  }) async {
    final query = _db.select(_db.shots);
    await _applyShotListFilters(query, filters);
    query.orderBy([(shot) => OrderingTerm.desc(shot.startedAt)]);

    final rows = await query.get();

    if (!includeSamples) {
      return rows
          .map((row) => _shotFromRow(row, samples: const []))
          .toList();
    }

    final shots = <models.Shot>[];
    for (final row in rows) {
      final sampleRows = await (_db.select(_db.shotSamples)
            ..where((sample) => sample.shotId.equals(row.id))
            ..orderBy([(sample) => OrderingTerm.asc(sample.elapsedMs)]))
          .get();

      shots.add(
        _shotFromRow(
          row,
          samples: sampleRows.map(_sampleFromRow).toList(),
        ),
      );
    }
    return shots;
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

    if (filters.minPeakPressureBar != null) {
      final shotIds =
          await _shotIdsWithMinPeakPressure(filters.minPeakPressureBar!);
      if (shotIds.isEmpty) {
        query.where((shot) => const Constant(false));
      } else {
        query.where((shot) => shot.id.isIn(shotIds));
      }
    }
  }

  Future<List<String>> _shotIdsWithMinPeakPressure(double minBar) async {
    final rows = await _db.customSelect(
      '''
      SELECT shot_id
      FROM shot_samples
      GROUP BY shot_id
      HAVING MAX(pressure_bar) >= ?
      ''',
      variables: [Variable.withReal(minBar)],
      readsFrom: {_db.shotSamples},
    ).get();

    return rows.map((row) => row.read<String>('shot_id')).toList();
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

    return _shotFromRow(
      row,
      samples: sampleRows.map(_sampleFromRow).toList(),
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
      tasteScore: Value(shot.tasteScore),
      flavourTags: Value(jsonEncode(shot.flavourTags)),
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

  models.Shot _shotFromRow(
    ShotRow row, {
    required List<models.ShotSample> samples,
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
      notes: row.notes,
      tasteScore: row.tasteScore,
      flavourTags: _decodeFlavourTags(row.flavourTags),
      samples: samples,
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
}