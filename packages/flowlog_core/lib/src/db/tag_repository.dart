import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../models/tag.dart' as models;
import 'flowlog_database.dart';

/// Tag with the number of shots linked via [ShotTags].
@immutable
class TagWithShotCount {
  const TagWithShotCount({
    required this.tag,
    required this.shotCount,
  });

  final models.Tag tag;
  final int shotCount;
}

/// Persists and loads [models.Tag] records and shot associations.
class TagRepository {
  TagRepository(this._db);

  final FlowlogDatabase _db;

  /// Inserts or replaces a tag.
  Future<void> upsertTag(models.Tag tag) async {
    await _db.into(_db.tags).insertOnConflictUpdate(_tagToCompanion(tag));
  }

  /// Updates an existing tag.
  Future<void> updateTag(models.Tag tag) async {
    await (_db.update(_db.tags)..where((row) => row.id.equals(tag.id)))
        .write(_tagToCompanion(tag));
  }

  /// Deletes a tag by id (linked shot_tags rows cascade).
  Future<void> deleteTag(String id) async {
    await (_db.delete(_db.tags)..where((row) => row.id.equals(id))).go();
  }

  /// Returns a tag by id.
  Future<models.Tag?> getTagById(String id) async {
    final row = await (_db.select(_db.tags)
          ..where((tag) => tag.id.equals(id)))
        .getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _tagFromRow(row);
  }

  /// Returns all tags ordered by name.
  Future<List<models.Tag>> listTags() async {
    final rows = await (_db.select(_db.tags)
          ..orderBy([(tag) => OrderingTerm.asc(tag.name)]))
        .get();

    return rows.map(_tagFromRow).toList();
  }

  /// Returns tags with linked shot counts.
  Future<List<TagWithShotCount>> listTagsWithShotCounts() async {
    final tags = await listTags();
    final counts = await _shotCountsByTagId();

    return [
      for (final tag in tags)
        TagWithShotCount(
          tag: tag,
          shotCount: counts[tag.id] ?? 0,
        ),
    ];
  }

  /// Counts shots linked to [tagId].
  Future<int> countShotsForTag(String tagId) async {
    final counts = await _shotCountsByTagId(tagIds: {tagId});
    return counts[tagId] ?? 0;
  }

  /// Returns tags assigned to [shotId].
  Future<List<models.Tag>> getTagsForShot(String shotId) async {
    final rows = await (_db.select(_db.shotTags).join([
      innerJoin(
        _db.tags,
        _db.tags.id.equalsExp(_db.shotTags.tagId),
      ),
    ])
          ..where(_db.shotTags.shotId.equals(shotId))
          ..orderBy([OrderingTerm.asc(_db.tags.name)]))
        .get();

    return rows.map((row) => _tagFromRow(row.readTable(_db.tags))).toList();
  }

  /// Returns every shot-tag association in the database.
  Future<List<models.ShotTagLink>> listAllShotTagLinks() async {
    final rows = await _db.select(_db.shotTags).get();
    return [
      for (final row in rows)
        models.ShotTagLink(shotId: row.shotId, tagId: row.tagId),
    ];
  }

  /// Replaces all tags linked to [shotId].
  Future<void> setTagsForShot(String shotId, List<String> tagIds) async {
    await _db.transaction(() async {
      await (_db.delete(_db.shotTags)
            ..where((row) => row.shotId.equals(shotId)))
          .go();

      if (tagIds.isEmpty) {
        return;
      }

      await _db.batch((batch) {
        batch.insertAll(
          _db.shotTags,
          tagIds
              .map(
                (tagId) => ShotTagsCompanion.insert(
                  shotId: shotId,
                  tagId: tagId,
                ),
              )
              .toList(),
        );
      });
    });
  }

  Future<Map<String, int>> _shotCountsByTagId({Set<String>? tagIds}) async {
    final shotCount = _db.shotTags.shotId.count();
    final query = _db.selectOnly(_db.shotTags)
      ..addColumns([_db.shotTags.tagId, shotCount]);

    if (tagIds != null && tagIds.isNotEmpty) {
      query.where(_db.shotTags.tagId.isIn(tagIds));
    }

    query.groupBy([_db.shotTags.tagId]);

    final rows = await query.get();
    return {
      for (final row in rows)
        row.read<String>(_db.shotTags.tagId)!: row.read<int>(shotCount) ?? 0,
    };
  }

  TagsCompanion _tagToCompanion(models.Tag tag) {
    return TagsCompanion.insert(
      id: tag.id,
      name: tag.name,
    );
  }

  models.Tag _tagFromRow(TagRow row) {
    return models.Tag(
      id: row.id,
      name: row.name,
    );
  }
}