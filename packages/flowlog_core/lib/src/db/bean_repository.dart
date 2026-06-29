import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../models/bean.dart' as models;
import 'flowlog_database.dart';

/// Bean with the number of shots linked via [models.Bean.id].
@immutable
class BeanWithShotCount {
  const BeanWithShotCount({
    required this.bean,
    required this.shotCount,
  });

  final models.Bean bean;
  final int shotCount;
}

/// Persists and loads [models.Bean] records.
class BeanRepository {
  BeanRepository(this._db);

  final FlowlogDatabase _db;

  /// Inserts or replaces a bean.
  Future<void> upsertBean(models.Bean bean) async {
    await _db.into(_db.beans).insertOnConflictUpdate(_beanToCompanion(bean));
  }

  /// Updates an existing bean.
  Future<void> updateBean(models.Bean bean) async {
    await (_db.update(_db.beans)..where((row) => row.id.equals(bean.id)))
        .write(_beanToCompanion(bean));
  }

  /// Deletes a bean by id.
  Future<void> deleteBean(String id) async {
    await (_db.delete(_db.beans)..where((row) => row.id.equals(id))).go();
  }

  /// Returns a bean by id.
  Future<models.Bean?> getBeanById(String id) async {
    final row = await (_db.select(_db.beans)
          ..where((bean) => bean.id.equals(id)))
        .getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _beanFromRow(row);
  }

  /// Returns all beans ordered by name.
  Future<List<models.Bean>> listBeans() async {
    final rows = await (_db.select(_db.beans)
          ..orderBy([(bean) => OrderingTerm.asc(bean.name)]))
        .get();

    return rows.map(_beanFromRow).toList();
  }

  /// Returns beans with linked shot counts.
  Future<List<BeanWithShotCount>> listBeansWithShotCounts() async {
    final beans = await listBeans();
    final counts = await _shotCountsByBeanId();

    return [
      for (final bean in beans)
        BeanWithShotCount(
          bean: bean,
          shotCount: counts[bean.id] ?? 0,
        ),
    ];
  }

  /// Counts shots linked to [beanId].
  Future<int> countShotsForBean(String beanId) async {
    final counts = await _shotCountsByBeanId(beanIds: {beanId});
    return counts[beanId] ?? 0;
  }

  Future<Map<String, int>> _shotCountsByBeanId({Set<String>? beanIds}) async {
    final shotCount = _db.shots.id.count();
    final query = _db.selectOnly(_db.shots)
      ..addColumns([_db.shots.beanId, shotCount])
      ..where(_db.shots.beanId.isNotNull());

    if (beanIds != null && beanIds.isNotEmpty) {
      query.where(_db.shots.beanId.isIn(beanIds));
    }

    query.groupBy([_db.shots.beanId]);

    final rows = await query.get();
    return {
      for (final row in rows)
        row.read<String>(_db.shots.beanId)!: row.read<int>(shotCount) ?? 0,
    };
  }

  BeansCompanion _beanToCompanion(models.Bean bean) {
    return BeansCompanion.insert(
      id: bean.id,
      name: bean.name,
      origin: Value(bean.origin),
      roastLevel: Value(bean.roastLevel),
      stockG: Value(bean.stockG),
      notes: Value(bean.notes),
    );
  }

  models.Bean _beanFromRow(BeanRow row) {
    return models.Bean(
      id: row.id,
      name: row.name,
      origin: row.origin,
      roastLevel: row.roastLevel,
      stockG: row.stockG,
      notes: row.notes,
    );
  }
}