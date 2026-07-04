import 'dart:convert';

import 'sync_blob.dart';
import 'encrypted_sync_blob.dart';

/// Suggested file extension for plain JSON backups.
const flowlogBackupExtension = 'flowlog';

/// Encodes [payload] as a portable JSON backup string.
String encodeSyncBackup(SyncPayload payload) {
  return const JsonEncoder.withIndent('  ').convert(payload.toJson());
}

/// Parses a backup file or encrypted sync blob wire format.
///
/// Accepts either a plain [SyncPayload] JSON document or an
/// [EncryptedSyncBlob] envelope.
SyncPayload parseSyncBackup(String contents) {
  final decoded = jsonDecode(contents);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Backup must be a JSON object');
  }

  if (decoded.containsKey('data') && decoded.containsKey('checksum')) {
    return importSyncBlob(EncryptedSyncBlob.fromJson(decoded));
  }

  return SyncPayload.fromJson(decoded);
}