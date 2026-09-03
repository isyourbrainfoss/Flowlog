import 'package:meta/meta.dart';

import '../models/bean.dart' show repairMojibake;
import '../models/shot.dart';
import '../models/tag.dart';
import '../db/bean_repository.dart';
import '../db/flowlog_database.dart';
import '../db/profile_repository.dart';
import '../db/shot_repository.dart';
import '../db/tag_repository.dart';
import 'sync_blob.dart';
import 'sync_config.dart';

/// Counts of records merged from an imported [SyncPayload].
@immutable
class SyncMergeResult {
  const SyncMergeResult({
    required this.beansMerged,
    required this.profilesMerged,
    required this.shotsMerged,
    this.tagsMerged = 0,
    this.shotTagLinksMerged = 0,
  });

  final int beansMerged;
  final int profilesMerged;
  final int shotsMerged;
  final int tagsMerged;
  final int shotTagLinksMerged;

  int get totalMerged =>
      beansMerged + profilesMerged + shotsMerged + tagsMerged;

  @override
  String toString() =>
      'SyncMergeResult(beans: $beansMerged, profiles: $profilesMerged, '
      'shots: $shotsMerged, tags: $tagsMerged, shotTagLinks: '
      '$shotTagLinksMerged)';
}

/// Upserts all records in [payload] into [database] (ID-based merge).
///
/// Existing rows with the same id are replaced; new ids are inserted.
Future<SyncMergeResult> mergeSyncPayload({
  required FlowlogDatabase database,
  required SyncPayload payload,
}) async {
  final beanRepository = BeanRepository(database);
  final profileRepository = ProfileRepository(database);
  final shotRepository = ShotRepository(database);
  final tagRepository = TagRepository(database);

  for (final bean in payload.beans) {
    await beanRepository.upsertBean(bean);
  }
  for (final profile in payload.profiles) {
    await profileRepository.insertProfile(profile);
  }
  for (final shot in payload.shots) {
    await shotRepository.insertShot(shot);
  }
  for (final tag in payload.tags) {
    await tagRepository.upsertTag(tag);
  }

  final linksByShotId = _groupShotTagLinks(payload.shotTagLinks);
  for (final entry in linksByShotId.entries) {
    await tagRepository.setTagsForShot(entry.key, entry.value);
  }

  return SyncMergeResult(
    beansMerged: payload.beans.length,
    profilesMerged: payload.profiles.length,
    shotsMerged: payload.shots.length,
    tagsMerged: payload.tags.length,
    shotTagLinksMerged: payload.shotTagLinks.length,
  );
}

/// Merges [payload] into [database], applying remote rows selectively.
///
/// Records that do not exist locally are always inserted. Existing records are
/// replaced only when [remoteExportedAt] is after the local record's activity
/// time (or [remoteExportedAt] when no local timestamp exists).
///
/// Shots with the same id are merged field-by-field so metadata from one device
/// is not wiped when another device uploads a newer export with only samples.
Future<SyncMergeResult> mergeSyncPayloadFromRemote({
  required FlowlogDatabase database,
  required SyncPayload payload,
  required DateTime remoteExportedAt,
}) async {
  final beanRepository = BeanRepository(database);
  final profileRepository = ProfileRepository(database);
  final shotRepository = ShotRepository(database);
  final tagRepository = TagRepository(database);

  var beansMerged = 0;
  var profilesMerged = 0;
  var shotsMerged = 0;
  var tagsMerged = 0;
  var shotTagLinksMerged = 0;

  for (final bean in payload.beans) {
    final local = await beanRepository.getBeanById(bean.id);
    final remote = bean.repaired();
    if (local == null) {
      await beanRepository.upsertBean(remote);
      beansMerged++;
      continue;
    }
    // Prefer the cleaner free-text fields so remote multi-layer mojibake
    // cannot overwrite a fixed local name (or vice versa).
    final merged = local.copyWith(
      name: _preferCleanerText(local.name, remote.name) ?? local.name,
      brand: _preferCleanerText(local.brand, remote.brand),
      origin: _preferCleanerText(local.origin, remote.origin),
      variety: _preferCleanerText(local.variety, remote.variety),
      notes: _mergeBeanNotes(local.notes, remote.notes),
      roastLevel: remote.roastLevel ?? local.roastLevel,
      roastDate: remote.roastDate ?? local.roastDate,
      process: remote.process ?? local.process,
      stockG: remote.stockG ?? local.stockG,
      empty: local.empty || remote.empty,
    );
    if (merged != local) {
      await beanRepository.upsertBean(merged);
      beansMerged++;
    }
  }

  for (final profile in payload.profiles) {
    final local = await profileRepository.getProfileById(profile.id);
    if (local == null || remoteExportedAt.isAfter(local.createdAt)) {
      await profileRepository.insertProfile(profile);
      profilesMerged++;
    }
  }

  for (final tag in payload.tags) {
    final local = await tagRepository.getTagById(tag.id);
    if (local == null || local.name != tag.name) {
      await tagRepository.upsertTag(tag);
      tagsMerged++;
    }
  }

  // Apply remote deletion tombstones first so we never re-import a shot that
  // another device intentionally removed.
  for (final tombstone in payload.deletedShots) {
    final stillThere = await shotRepository.getShotWithSamples(
      tombstone.shotId,
    );
    if (stillThere != null) {
      await shotRepository.deleteShot(tombstone.shotId);
      // deleteShot records a tombstone with "now"; keep the earlier remote time.
      await shotRepository.recordShotDeleted(
        tombstone.shotId,
        deletedAt: tombstone.deletedAt,
      );
      shotsMerged++;
    } else {
      await shotRepository.recordShotDeleted(
        tombstone.shotId,
        deletedAt: tombstone.deletedAt,
      );
    }
  }

  final localDeletedIds = {
    for (final t in await shotRepository.listDeletedShots()) t.shotId,
  };

  final remoteLinksByShotId = _groupShotTagLinks(payload.shotTagLinks);

  for (final remoteShot in payload.shots) {
    // Skip shots we (or a peer) have deleted — otherwise Nextcloud re-adds them.
    if (localDeletedIds.contains(remoteShot.id)) {
      continue;
    }

    final local = await shotRepository.getShotWithSamples(remoteShot.id);
    if (!_shouldMergeShot(
      local: local,
      remote: remoteShot,
      remoteExportedAt: remoteExportedAt,
    )) {
      continue;
    }

    final merged = mergeShotRecords(
      local: local,
      remote: remoteShot,
      remoteExportedAt: remoteExportedAt,
    );
    await shotRepository.insertShot(merged);
    shotsMerged++;

    final remoteTagIds = remoteLinksByShotId[remoteShot.id];
    if (remoteTagIds != null) {
      final localTagIds = local == null
          ? const <String>[]
          : (await tagRepository.getTagsForShot(
              remoteShot.id,
            )).map((tag) => tag.id).toList();
      if (local == null ||
          remoteExportedAt.isAfter(_shotActivityAt(local)!) ||
          localTagIds.isEmpty) {
        await tagRepository.setTagsForShot(remoteShot.id, remoteTagIds);
        shotTagLinksMerged += remoteTagIds.length;
      }
    }
  }

  return SyncMergeResult(
    beansMerged: beansMerged,
    profilesMerged: profilesMerged,
    shotsMerged: shotsMerged,
    tagsMerged: tagsMerged,
    shotTagLinksMerged: shotTagLinksMerged,
  );
}

/// Whether [remote] should be merged into the local store for [local].
@visibleForTesting
bool shouldMergeShot({
  required Shot? local,
  required Shot remote,
  required DateTime remoteExportedAt,
}) {
  return _shouldMergeShot(
    local: local,
    remote: remote,
    remoteExportedAt: remoteExportedAt,
  );
}

bool _shouldMergeShot({
  required Shot? local,
  required Shot remote,
  required DateTime remoteExportedAt,
}) {
  if (local == null) {
    return true;
  }

  final localActivity = _shotActivityAt(local);
  if (localActivity != null && remoteExportedAt.isAfter(localActivity)) {
    // Remote snapshot is newer than our local activity (creation or last edit time).
    // Accept it (it may come from another device after our last change).
    return true;
  }

  return _shotCompleteness(remote) > _shotCompleteness(local);
}

/// Combines [local] and [remote] so metadata and samples from both are kept.
/// Bases the result on [local] (if present) so that local post-brew edits to
/// metadata (notes, taste, dose, etc.) are preserved and not overwritten by
/// an older remote export of the same shot. Missing fields on local are filled
/// from remote. Samples/annotations prefer the longer set.
@visibleForTesting
Shot mergeShotRecords({
  required Shot? local,
  required Shot remote,
  required DateTime remoteExportedAt,
}) {
  if (local == null) {
    return remote;
  }

  // Per-shot lastModifiedAt, not blob exportedAt. A device that is open and
  // re-exports the whole DB after a peer edited one shot used to look "newer"
  // and roll bean/notes back to the stale copy.
  final localWinsMeta = _isNewerRecord(
    local.lastModifiedAt,
    remote.lastModifiedAt,
  );

  T? pickMeta<T>(T? localValue, T? remoteValue) {
    if (localWinsMeta) {
      return localValue;
    }
    return remoteValue ?? localValue;
  }

  return local.copyWith(
    startedAt: local.startedAt,
    endedAt: local.endedAt ?? remote.endedAt,
    doseG: pickMeta(local.doseG, remote.doseG),
    yieldG: pickMeta(local.yieldG, remote.yieldG),
    grindSetting: pickMeta(local.grindSetting, remote.grindSetting),
    beanId: pickMeta(local.beanId, remote.beanId),
    waterTempC: pickMeta(local.waterTempC, remote.waterTempC),
    notes: pickMeta(local.notes, remote.notes),
    location: pickMeta(local.location, remote.location),
    latitude: pickMeta(local.latitude, remote.latitude),
    longitude: pickMeta(local.longitude, remote.longitude),
    tasteScore: pickMeta(local.tasteScore, remote.tasteScore),
    coffeejackRewindTurns: pickMeta(
      local.coffeejackRewindTurns,
      remote.coffeejackRewindTurns,
    ),
    coffeejackPreinfusionTurns: pickMeta(
      local.coffeejackPreinfusionTurns,
      remote.coffeejackPreinfusionTurns,
    ),
    grinder: pickMeta(local.grinder, remote.grinder),
    showerScreen: pickMeta(local.showerScreen, remote.showerScreen),
    basket: pickMeta(local.basket, remote.basket),
    scale: pickMeta(local.scale, remote.scale),
    brewer: pickMeta(local.brewer, remote.brewer),
    lastModifiedAt: _laterTimestamp(
      local.lastModifiedAt,
      remote.lastModifiedAt,
    ),
    flavourTags: localWinsMeta
        ? local.flavourTags
        : (remote.flavourTags.isNotEmpty
              ? remote.flavourTags
              : local.flavourTags),
    flavourIntensities: localWinsMeta
        ? local.flavourIntensities
        : (remote.flavourIntensities.isNotEmpty
              ? remote.flavourIntensities
              : local.flavourIntensities),
    samples: local.samples.length >= remote.samples.length
        ? local.samples
        : remote.samples,
    annotations: local.annotations.isNotEmpty
        ? local.annotations
        : remote.annotations,
  );
}

int _shotCompleteness(Shot shot) {
  var score = 0;
  if (shot.doseG != null) {
    score++;
  }
  if (shot.yieldG != null) {
    score++;
  }
  if (shot.grindSetting != null) {
    score++;
  }
  if (shot.beanId != null) {
    score++;
  }
  if (shot.waterTempC != null) {
    score++;
  }
  if (shot.tasteScore != null) {
    score++;
  }
  if (shot.coffeejackRewindTurns != null) {
    score++;
  }
  if (shot.coffeejackPreinfusionTurns != null) {
    score++;
  }
  if (shot.grinder?.trim().isNotEmpty ?? false) {
    score++;
  }
  if (shot.showerScreen?.trim().isNotEmpty ?? false) {
    score++;
  }
  if (shot.basket?.trim().isNotEmpty ?? false) {
    score++;
  }
  if (shot.scale?.trim().isNotEmpty ?? false) {
    score++;
  }
  if (shot.brewer?.trim().isNotEmpty ?? false) {
    score++;
  }
  if (shot.notes?.trim().isNotEmpty ?? false) {
    score += 2;
  }
  if (shot.flavourTags.isNotEmpty) {
    score++;
  }
  if (shot.flavourIntensities.isNotEmpty) {
    score++;
  }
  if (shot.location?.trim().isNotEmpty ?? false) {
    score++;
  }
  score += shot.annotations.length;
  return score;
}

String? _mergeText(String? primary, String? secondary) {
  final a = primary?.trim();
  final b = secondary?.trim();
  if (a != null && a.isNotEmpty) {
    return a;
  }
  if (b != null && b.isNotEmpty) {
    return b;
  }
  return null;
}

/// Prefer the string with fewer mojibake markers; ties keep [local].
String? _preferCleanerText(String? local, String? remote) {
  final l = repairMojibake(local?.trim());
  final r = repairMojibake(remote?.trim());
  final lEmpty = l == null || l.isEmpty;
  final rEmpty = r == null || r.isEmpty;
  if (lEmpty && rEmpty) return null;
  if (lEmpty) return r;
  if (rEmpty) return l;
  final lBad = RegExp(r'[\u00c3\u00c2\uFFFDÃÂ]').allMatches(l!).length;
  final rBad = RegExp(r'[\u00c3\u00c2\uFFFDÃÂ]').allMatches(r!).length;
  if (rBad < lBad) return r;
  if (lBad < rBad) return l;
  // Same cleanliness: prefer shorter (less double-encoded growth).
  if (r!.length < l!.length) return r;
  return l;
}

/// For bean notes, prefer the version that is non-empty and does not contain
/// mojibake markers (Ã or replacement chars). This prevents corrupted remote
/// versions from overwriting local manual fixes.
/// Explicitly cleared local notes (empty) are respected and will not be
/// overwritten by (even repaired) remote notes. This stops bad data from
/// reappearing after the user removes notes.
String? _mergeBeanNotes(String? local, String? remote) {
  final l = repairMojibake(local?.trim());
  final r = repairMojibake(remote?.trim());

  final lEmpty = l == null || l.isEmpty;
  final rEmpty = r == null || r.isEmpty;

  final lHasBad = !lEmpty && (l!.contains('Ã') || l.contains('\uFFFD'));
  final rHasBad = !rEmpty && (r!.contains('Ã') || r.contains('\uFFFD'));

  if (lEmpty) {
    // Respect local clear: do not pull remote notes (prevents reappearance of
    // corrupted remote data after user removes notes).
    if (rHasBad || rEmpty) {
      return null;
    }
    // Only adopt remote if it is clean. (Rare case; user cleared locally.)
    return r;
  }

  if (rEmpty) {
    return l;
  }

  if (lHasBad && !rHasBad) {
    return r;
  }
  if (!lHasBad) {
    return l;
  }
  // Both bad or ambiguous: prefer the longer/cleaner one after repair
  return (r!.length >= l!.length) ? r : l;
}

Map<String, List<String>> _groupShotTagLinks(List<ShotTagLink> links) {
  final grouped = <String, List<String>>{};
  for (final link in links) {
    grouped.putIfAbsent(link.shotId, () => []).add(link.tagId);
  }
  return grouped;
}

bool _isNewerRecord(DateTime? candidate, DateTime? other) {
  if (candidate == null) {
    return false;
  }
  if (other == null) {
    return true;
  }
  return candidate.isAfter(other);
}

DateTime? _laterTimestamp(DateTime? a, DateTime? b) {
  if (a == null) {
    return b;
  }
  if (b == null) {
    return a;
  }
  return a.isAfter(b) ? a : b;
}

DateTime? _shotActivityAt(Shot? shot) {
  if (shot == null) {
    return null;
  }
  var latest = shot.startedAt;
  final endedAt = shot.endedAt;
  if (endedAt != null && endedAt.isAfter(latest)) {
    latest = endedAt;
  }
  final mod = shot.lastModifiedAt;
  if (mod != null && mod.isAfter(latest)) {
    latest = mod;
  }
  return latest;
}

/// Builds a full local backup payload from [database].
Future<SyncPayload> buildSyncPayloadFromDatabase(
  FlowlogDatabase database, {
  SyncConfig config = const SyncConfig(),
  DateTime? exportedAt,
}) async {
  final shotRepository = ShotRepository(database);
  final profileRepository = ProfileRepository(database);
  final beanRepository = BeanRepository(database);
  final tagRepository = TagRepository(database);

  final shots = await shotRepository.listShots(includeSamples: true);
  final profiles = await profileRepository.listProfiles(includeSamples: true);
  final beans = await beanRepository.listBeans();
  final tags = await tagRepository.listTags();
  final shotTagLinks = await tagRepository.listAllShotTagLinks();
  await shotRepository.pruneDeletedShots();
  final deleted = await shotRepository.listDeletedShots();

  return SyncPayload(
    version: syncPayloadVersion,
    exportedAt: exportedAt ?? DateTime.now().toUtc(),
    config: config,
    shots: shots,
    profiles: profiles,
    beans: beans,
    tags: tags,
    shotTagLinks: shotTagLinks,
    deletedShots: [
      for (final t in deleted)
        DeletedShotRef(shotId: t.shotId, deletedAt: t.deletedAt),
    ],
  );
}
