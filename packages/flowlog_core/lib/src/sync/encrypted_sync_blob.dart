import 'dart:convert';

import 'package:meta/meta.dart';

/// Current encrypted sync blob format version.
const syncBlobVersion = 1;

/// Placeholder XOR key for the sync stub envelope.
///
/// **Not** a production secret — replace with per-user E2E keys before cloud
/// sync goes live.
const syncStubXorKey = 'flowlog-sync-stub-v1';

/// Wire format for an encrypted sync export.
///
/// This is a **stub** for future end-to-end cloud sync. The [data] field holds
/// base64-encoded bytes that were XOR-obfuscated with [syncStubXorKey] and
/// tagged with a simple checksum. It is not real cryptography.
@immutable
class EncryptedSyncBlob {
  const EncryptedSyncBlob({
    required this.version,
    required this.checksum,
    required this.data,
  });

  final int version;
  final String checksum;
  final String data;

  factory EncryptedSyncBlob.fromJson(Map<String, dynamic> json) {
    return EncryptedSyncBlob(
      version: json['version'] as int,
      checksum: json['checksum'] as String,
      data: json['data'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'checksum': checksum,
      'data': data,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EncryptedSyncBlob &&
            version == other.version &&
            checksum == other.checksum &&
            data == other.data;
  }

  @override
  int get hashCode => Object.hash(version, checksum, data);

  @override
  String toString() =>
      'EncryptedSyncBlob(version: $version, checksum: $checksum, '
      'dataLength: ${data.length})';
}

/// XOR-obfuscates [plaintext] with [key] (stub encryption only).
List<int> xorObfuscate(String plaintext, String key) {
  final bytes = utf8.encode(plaintext);
  final keyBytes = utf8.encode(key);
  return List<int>.generate(
    bytes.length,
    (index) => bytes[index] ^ keyBytes[index % keyBytes.length],
  );
}

/// Reverses [xorObfuscate].
String xorDeobfuscate(List<int> bytes, String key) {
  final keyBytes = utf8.encode(key);
  final plainBytes = List<int>.generate(
    bytes.length,
    (index) => bytes[index] ^ keyBytes[index % keyBytes.length],
  );
  return utf8.decode(plainBytes);
}

/// Simple rolling checksum used to detect tampering in the stub envelope.
String syncPayloadChecksum(String plaintext) {
  var sum = 0;
  for (final codeUnit in plaintext.codeUnits) {
    sum = (sum + codeUnit) & 0xFFFFFFFF;
  }
  return sum.toRadixString(16).padLeft(8, '0');
}

/// Wraps [plaintext] in a stub-encrypted [EncryptedSyncBlob].
EncryptedSyncBlob encryptSyncPayload(
  String plaintext, {
  int version = syncBlobVersion,
  String key = syncStubXorKey,
}) {
  final checksum = syncPayloadChecksum(plaintext);
  final data = base64Encode(xorObfuscate(plaintext, key));
  return EncryptedSyncBlob(
    version: version,
    checksum: checksum,
    data: data,
  );
}

/// Decrypts [blob] and verifies its checksum.
///
/// Throws [FormatException] when the version, checksum, or payload is invalid.
String decryptSyncPayload(
  EncryptedSyncBlob blob, {
  String key = syncStubXorKey,
}) {
  if (blob.version != syncBlobVersion) {
    throw FormatException('Unsupported sync blob version: ${blob.version}');
  }

  final bytes = base64Decode(blob.data);
  final plaintext = xorDeobfuscate(bytes, key);
  final checksum = syncPayloadChecksum(plaintext);
  if (checksum != blob.checksum) {
    throw const FormatException('Sync blob checksum mismatch');
  }

  return plaintext;
}