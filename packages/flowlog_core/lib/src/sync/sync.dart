/// Stub module for future end-to-end encrypted cloud sync.
///
/// Flowlog ships with local-only storage today. This module defines the
/// export/import envelope that a future sync service would exchange:
///
/// - [SyncConfig] keeps cloud account linkage **off by default**
/// - [exportSyncBlob] serializes shots and saved profiles to JSON, then wraps
///   the payload in a placeholder XOR + base64 + checksum envelope
/// - [importSyncBlob] reverses that process and validates integrity
///
/// The encryption here is intentionally weak — it exists so callers can wire
/// sync UX and transport without pulling in a crypto package. Replace
/// [EncryptedSyncBlob] with real E2E encryption before any data leaves the
/// device.
library;

export 'encrypted_sync_blob.dart';
export 'sync_blob.dart';
export 'sync_config.dart';