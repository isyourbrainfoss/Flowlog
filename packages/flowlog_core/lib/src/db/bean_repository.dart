import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../models/bean.dart' as models;
import '../models/bean.dart' show repairMojibake;
import '../models/bean.dart' show repairMojibake;
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

  /// Returns beans with most recently used (in shots) first, then alphabetical.
  Future<List<models.Bean>> listBeansByRecentUse() async {
    final beans = await listBeans();
    if (beans.isEmpty) {
      return beans;
    }

    final recentIds = await _recentBeanIdsFromShots();
    beans.sort((a, b) {
      final aIndex = recentIds.indexOf(a.id);
      final bIndex = recentIds.indexOf(b.id);
      if (aIndex >= 0 && bIndex >= 0) {
        return aIndex.compareTo(bIndex);
      }
      if (aIndex >= 0) {
        return -1;
      }
      if (bIndex >= 0) {
        return 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return beans;
  }

  /// Creates a new bean entry (duplicate names are allowed).
  Future<models.Bean> createBean({
    required String name,
    String? brand,
    DateTime? roastDate,
    String? origin,
    String? roastLevel,
    String? process,
    String? variety,
    double? stockG,
    String? notes,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Bean name must not be empty');
    }

    final bean = models.Bean(
      id: 'bean-${DateTime.now().toUtc().millisecondsSinceEpoch}',
      name: trimmed,
      brand: brand,
      roastDate: roastDate,
      origin: origin,
      roastLevel: roastLevel,
      process: process,
      variety: variety,
      stockG: stockG,
      notes: notes,
    );
    await upsertBean(bean);
    return bean;
  }

  /// Resolves the active session bean id from a known id or display name.
  ///
  /// When only [name] is provided, returns the most recently used matching
  /// bean or creates a new entry if none exist.
  Future<String?> resolveActiveBeanId({
    String? beanId,
    String? name,
  }) async {
    if (beanId != null && beanId.trim().isNotEmpty) {
      final existing = await getBeanById(beanId.trim());
      if (existing != null) {
        return existing.id;
      }
    }

    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      return null;
    }

    final recent = await listBeansByRecentUse();
    for (final bean in recent) {
      if (bean.name.toLowerCase() == trimmedName.toLowerCase()) {
        return bean.id;
      }
    }

    return (await createBean(name: trimmedName)).id;
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

  Future<List<String>> _recentBeanIdsFromShots() async {
    final rows = await (_db.select(_db.shots)
          ..orderBy([(shot) => OrderingTerm.desc(shot.startedAt)]))
        .get();

    final seen = <String>{};
    final recent = <String>[];
    for (final row in rows) {
      final beanId = row.beanId;
      if (beanId == null || beanId.isEmpty || !seen.add(beanId)) {
        continue;
      }
      recent.add(beanId);
    }
    return recent;
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
      brand: Value(bean.brand),
      origin: Value(bean.origin),
      roastLevel: Value(bean.roastLevel),
      roastDate: Value(bean.roastDate),
      process: Value(bean.process),
      variety: Value(bean.variety),
      stockG: Value(bean.stockG),
      notes: Value(bean.notes),
    );
  }

  models.Bean _beanFromRow(BeanRow row) {
    return models.Bean(
      id: row.id,
      name: row.name,
      brand: row.brand,
      origin: row.origin,
      roastLevel: row.roastLevel,
      roastDate: row.roastDate,
      process: row.process,
      variety: row.variety,
      stockG: row.stockG,
      notes: repairMojibake(row.notes),
    );
  }
}