import 'package:meta/meta.dart';

import '../models/shot.dart';
import '../db/bean_repository.dart';
import '../db/flowlog_database.dart';
import '../db/profile_repository.dart';
import '../db/shot_repository.dart';
import 'sync_blob.dart';
import 'sync_config.dart';

/// Counts of records merged from an imported [SyncPayload].
@immutable
class SyncMergeResult {
  const SyncMergeResult({
    required this.beansMerged,
    required this.profilesMerged,
    required this.shotsMerged,
  });

  final int beansMerged;
  final int profilesMerged;
  final int shotsMerged;

  int get totalMerged => beansMerged + profilesMerged + shotsMerged;

  @override
  String toString() =>
      'SyncMergeResult(beans: $beansMerged, profiles: $profilesMerged, '
      'shots: $shotsMerged)';
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

  for (final bean in payload.beans) {
    await beanRepository.upsertBean(bean);
  }
  for (final profile in payload.profiles) {
    await profileRepository.insertProfile(profile);
  }
  for (final shot in payload.shots) {
    await shotRepository.insertShot(shot);
  }

  return SyncMergeResult(
    beansMerged: payload.beans.length,
    profilesMerged: payload.profiles.length,
    shotsMerged: payload.shots.length,
  );
}

/// Merges [payload] into [database], applying remote rows selectively.
///
/// Records that do not exist locally are always inserted. Existing records are
/// replaced only when [remoteExportedAt] is after the local record's activity
/// time (or [remoteExportedAt] when no local timestamp exists).
Future<SyncMergeResult> mergeSyncPayloadFromRemote({
  required FlowlogDatabase database,
  required SyncPayload payload,
  required DateTime remoteExportedAt,
}) async {
  final beanRepository = BeanRepository(database);
  final profileRepository = ProfileRepository(database);
  final shotRepository = ShotRepository(database);

  var beansMerged = 0;
  var profilesMerged = 0;
  var shotsMerged = 0;

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

  for (final shot in payload.shots) {
    final local = await shotRepository.getShotById(shot.id);
    final localActivity = _shotActivityAt(local);
    if (local == null ||
        (localActivity != null && remoteExportedAt.isAfter(localActivity))) {
      await shotRepository.insertShot(shot);
      shotsMerged++;
    }
  }

  return SyncMergeResult(
    beansMerged: beansMerged,
    profilesMerged: profilesMerged,
    shotsMerged: shotsMerged,
  );
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

  final shots = await shotRepository.listShots(includeSamples: true);
  final profiles = await profileRepository.listProfiles(includeSamples: true);
  final beans = await beanRepository.listBeans();

  return SyncPayload(
    version: syncPayloadVersion,
    exportedAt: exportedAt ?? DateTime.now().toUtc(),
    config: config,
    shots: shots,
    profiles: profiles,
    beans: beans,
  );
}