import 'package:meta/meta.dart';

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
    if (local == null ||
        remoteExportedAt.isAfter(
          local.roastDate ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        )) {
      await beanRepository.upsertBean(bean);
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

  final remoteLinksByShotId = _groupShotTagLinks(payload.shotTagLinks);

  for (final remoteShot in payload.shots) {
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
          : (await tagRepository.getTagsForShot(remoteShot.id))
              .map((tag) => tag.id)
              .toList();
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
    return true;
  }

  return _shotCompleteness(remote) > _shotCompleteness(local);
}

/// Combines [local] and [remote] so metadata and samples from both are kept.
@visibleForTesting
Shot mergeShotRecords({
  required Shot? local,
  required Shot remote,
  required DateTime remoteExportedAt,
}) {
  if (local == null) {
    return remote;
  }

  final localActivity = _shotActivityAt(local)!;
  final remoteIsNewer = remoteExportedAt.isAfter(localActivity);
  final primary = remoteIsNewer ? remote : local;
  final secondary = remoteIsNewer ? local : remote;

  return primary.copyWith(
    startedAt: local.startedAt,
    endedAt: primary.endedAt ?? secondary.endedAt,
    doseG: primary.doseG ?? secondary.doseG,
    yieldG: primary.yieldG ?? secondary.yieldG,
    grindSetting: primary.grindSetting ?? secondary.grindSetting,
    beanId: primary.beanId ?? secondary.beanId,
    waterTempC: primary.waterTempC ?? secondary.waterTempC,
    notes: _mergeText(primary.notes, secondary.notes),
    location: primary.location ?? secondary.location,
    latitude: primary.latitude ?? secondary.latitude,
    longitude: primary.longitude ?? secondary.longitude,
    tasteScore: primary.tasteScore ?? secondary.tasteScore,
    coffeejackRewindTurns:
        primary.coffeejackRewindTurns ?? secondary.coffeejackRewindTurns,
    coffeejackPreinfusionTurns: primary.coffeejackPreinfusionTurns ??
        secondary.coffeejackPreinfusionTurns,
    flavourTags: primary.flavourTags.isNotEmpty
        ? primary.flavourTags
        : secondary.flavourTags,
    flavourIntensities: primary.flavourIntensities.isNotEmpty
        ? primary.flavourIntensities
        : secondary.flavourIntensities,
    samples: primary.samples.length >= secondary.samples.length
        ? primary.samples
        : secondary.samples,
    annotations: primary.annotations.isNotEmpty
        ? primary.annotations
        : secondary.annotations,
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

Map<String, List<String>> _groupShotTagLinks(List<ShotTagLink> links) {
  final grouped = <String, List<String>>{};
  for (final link in links) {
    grouped.putIfAbsent(link.shotId, () => []).add(link.tagId);
  }
  return grouped;
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

  return SyncPayload(
    version: syncPayloadVersion,
    exportedAt: exportedAt ?? DateTime.now().toUtc(),
    config: config,
    shots: shots,
    profiles: profiles,
    beans: beans,
    tags: tags,
    shotTagLinks: shotTagLinks,
  );
}