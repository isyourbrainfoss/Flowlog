import 'dart:convert';
import 'dart:isolate';

import 'sync_blob.dart';
import 'encrypted_sync_blob.dart';

/// Suggested file extension for plain JSON backups.
const flowlogBackupExtension = 'flowlog';

/// Encodes [payload] as a portable JSON backup string.
///
/// Uses compact JSON (no indent) so large shot histories stay cheap to encode.
/// Prefer [encodeSyncBackupAsync] from async UI/sync call sites.
String encodeSyncBackup(SyncPayload payload) {
  return jsonEncode(payload.toJson());
}

/// Encodes [payload] without blocking the UI isolate on [jsonEncode].
///
/// Yields before/after building the JSON map, then runs [jsonEncode] in an
/// [Isolate]. Compact JSON (no pretty-indent) keeps CPU and payload size down.
Future<String> encodeSyncBackupAsync(SyncPayload payload) async {
  await Future<void>.delayed(Duration.zero);
  final map = payload.toJson();
  await Future<void>.delayed(Duration.zero);
  return Isolate.run(() => jsonEncode(map));
}

/// Parses a backup file or encrypted sync blob wire format.
///
/// Accepts either a plain [SyncPayload] JSON document or an
/// [EncryptedSyncBlob] envelope.
SyncPayload parseSyncBackup(String contents) {
  final decoded = jsonDecode(contents);
  if (decoded is! Map) {
    throw const FormatException('Backup must be a JSON object');
  }

  final map = _deepStringKeyedMap(decoded);
  if (map.containsKey('data') && map.containsKey('checksum')) {
    return importSyncBlob(EncryptedSyncBlob.fromJson(map));
  }

  return SyncPayload.fromJson(map);
}

/// Parses [contents] with [jsonDecode] on a background isolate.
Future<SyncPayload> parseSyncBackupAsync(String contents) async {
  final decoded = await Isolate.run(() => jsonDecode(contents));
  if (decoded is! Map) {
    throw const FormatException('Backup must be a JSON object');
  }

  // Yield before walking a potentially large shot graph on this isolate.
  await Future<void>.delayed(Duration.zero);
  final map = _deepStringKeyedMap(decoded);
  if (map.containsKey('data') && map.containsKey('checksum')) {
    return importSyncBlob(EncryptedSyncBlob.fromJson(map));
  }
  return SyncPayload.fromJson(map);
}

Map<String, dynamic> _deepStringKeyedMap(Map<dynamic, dynamic> input) {
  final result = <String, dynamic>{};
  for (final entry in input.entries) {
    result[entry.key.toString()] = _deepJsonValue(entry.value);
  }
  return result;
}

dynamic _deepJsonValue(dynamic value) {
  if (value is Map) {
    return _deepStringKeyedMap(value);
  }
  if (value is List) {
    return [for (final item in value) _deepJsonValue(item)];
  }
  return value;
}
