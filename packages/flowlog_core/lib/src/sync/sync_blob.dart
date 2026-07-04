import 'dart:convert';

import 'package:meta/meta.dart';

import '../models/bean.dart';
import '../models/saved_profile.dart';
import '../models/shot.dart';
import 'encrypted_sync_blob.dart';
import 'sync_config.dart';

/// Current [SyncPayload] schema version (embedded in exported backups).
const syncPayloadVersion = 2;

/// Oldest [SyncPayload.version] this app can import.
const minSyncPayloadVersion = 1;

/// Decrypted sync export containing shot and profile data.
///
/// This payload is what future cloud sync would upload/download after real E2E
/// encryption replaces the current stub envelope in [EncryptedSyncBlob].
@immutable
class SyncPayload {
  const SyncPayload({
    required this.version,
    required this.exportedAt,
    required this.config,
    required this.shots,
    required this.profiles,
    this.beans = const [],
  });

  final int version;
  final DateTime exportedAt;
  final SyncConfig config;
  final List<Shot> shots;
  final List<SavedProfile> profiles;
  final List<Bean> beans;

  factory SyncPayload.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int;
    if (version < minSyncPayloadVersion || version > syncPayloadVersion) {
      throw FormatException('Unsupported sync payload version: $version');
    }

    return SyncPayload(
      version: version,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      config: SyncConfig.fromJson(
        json['config'] as Map<String, dynamic>? ?? const {},
      ),
      shots: (json['shots'] as List<dynamic>?)
              ?.map((entry) => Shot.fromJson(entry as Map<String, dynamic>))
              .toList() ??
          const [],
      profiles: (json['profiles'] as List<dynamic>?)
              ?.map(
                (entry) => SavedProfile.fromJson(entry as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      beans: version >= 2
          ? (json['beans'] as List<dynamic>?)
                  ?.map((entry) => Bean.fromJson(entry as Map<String, dynamic>))
                  .toList() ??
              const []
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'config': config.toJson(),
      'shots': shots.map((shot) => shot.toJson()).toList(),
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      if (version >= 2)
        'beans': beans.map((bean) => bean.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SyncPayload &&
            version == other.version &&
            exportedAt == other.exportedAt &&
            config == other.config &&
            _listEquals(shots, other.shots) &&
            _listEquals(profiles, other.profiles) &&
            _listEquals(beans, other.beans);
  }

  @override
  int get hashCode => Object.hash(
        version,
        exportedAt,
        config,
        Object.hashAll(shots),
        Object.hashAll(profiles),
        Object.hashAll(beans),
      );
}

/// Serializes [shots] and [profiles] to JSON and wraps them in a stub
/// encrypted [EncryptedSyncBlob].
///
/// **Stub only:** replace XOR + checksum with real E2E crypto before enabling
/// cloud upload.
EncryptedSyncBlob exportSyncBlob({
  required List<Shot> shots,
  required List<SavedProfile> profiles,
  List<Bean> beans = const [],
  SyncConfig config = const SyncConfig(),
  DateTime? exportedAt,
}) {
  final payload = SyncPayload(
    version: syncPayloadVersion,
    exportedAt: exportedAt ?? DateTime.now().toUtc(),
    config: config,
    shots: shots,
    profiles: profiles,
    beans: beans,
  );
  return encryptSyncPayload(jsonEncode(payload.toJson()));
}

/// Decrypts and validates [blob], returning the embedded [SyncPayload].
///
/// Throws [FormatException] when the blob is tampered or malformed.
SyncPayload importSyncBlob(EncryptedSyncBlob blob) {
  final plaintext = decryptSyncPayload(blob);
  final json = jsonDecode(plaintext);
  if (json is! Map<String, dynamic>) {
    throw const FormatException('Sync payload must be a JSON object');
  }
  return SyncPayload.fromJson(json);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}