import 'package:meta/meta.dart';

import '../db/flowlog_database.dart';
import 'sync_backup.dart';
import 'sync_config.dart';
import 'sync_merge.dart';
import 'webdav_client.dart';

/// Remote WebDAV path for the Flowlog sync backup file.
const kNextcloudRemoteFile = 'Flowlog/flowlog-sync.flowlog';

/// Remote WebDAV folder created on first sync.
const kNextcloudCollection = 'Flowlog';

/// Outcome of a Nextcloud WebDAV sync pass.
@immutable
class NextcloudSyncResult {
  const NextcloudSyncResult({
    required this.success,
    this.message = '',
    this.uploaded = false,
    this.mergedRemote = false,
    this.mergeResult,
    this.remoteExportedAt,
    this.localExportedAt,
    this.error,
    this.shotsSynced = 0,
    this.profilesSynced = 0,
    this.beansSynced = 0,
  });

  final bool success;
  final String message;
  final bool uploaded;
  final bool mergedRemote;
  final SyncMergeResult? mergeResult;
  final DateTime? remoteExportedAt;
  final DateTime? localExportedAt;
  final String? error;
  final int shotsSynced;
  final int profilesSynced;
  final int beansSynced;
}

/// Syncs the local database with a Nextcloud WebDAV backup file.
Future<NextcloudSyncResult> nextcloudSync({
  required WebDavCredentials credentials,
  required FlowlogDatabase database,
  WebDavTransport? client,
}) async {
  final transport = client ?? WebDavClient(credentials);
  const syncConfig = SyncConfig(accountEnabled: true);

  try {
    await transport.ensureCollection(kNextcloudCollection);

    final remoteContent = await transport.getText(kNextcloudRemoteFile);
    DateTime? remoteExportedAt;
    SyncMergeResult? mergeResult;
    var mergedRemote = false;

    if (remoteContent != null) {
      final remotePayload = parseSyncBackup(remoteContent);
      remoteExportedAt = remotePayload.exportedAt;

      mergeResult = await mergeSyncPayloadFromRemote(
        database: database,
        payload: remotePayload,
        remoteExportedAt: remotePayload.exportedAt,
      );
      mergedRemote = mergeResult.totalMerged > 0;
    }

    final uploadPayload = await buildSyncPayloadFromDatabase(
      database,
      config: syncConfig,
    );
    final localExportedAt = uploadPayload.exportedAt;

    await transport.putText(
      kNextcloudRemoteFile,
      encodeSyncBackup(uploadPayload),
    );

    final merge = mergeResult;
    final message = mergedRemote
        ? 'Merged ${merge?.shotsMerged ?? 0} shots from Nextcloud and uploaded'
        : remoteExportedAt == null
            ? 'Uploaded local backup to Nextcloud'
            : 'Uploaded newer local backup to Nextcloud';

    return NextcloudSyncResult(
      success: true,
      message: message,
      uploaded: true,
      mergedRemote: mergedRemote,
      mergeResult: mergeResult,
      remoteExportedAt: remoteExportedAt,
      localExportedAt: localExportedAt,
      shotsSynced: uploadPayload.shots.length,
      profilesSynced: uploadPayload.profiles.length,
      beansSynced: uploadPayload.beans.length,
    );
  } on WebDavException catch (error) {
    return NextcloudSyncResult(
      success: false,
      message: error.toString(),
      error: error.toString(),
    );
  } catch (error) {
    return NextcloudSyncResult(
      success: false,
      message: error.toString(),
      error: error.toString(),
    );
  }
}

