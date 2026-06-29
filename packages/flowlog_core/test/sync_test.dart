import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('SyncConfig', () {
    test('account is disabled by default', () {
      const config = SyncConfig();
      expect(config.accountEnabled, isFalse);
    });

    test('toJson/fromJson round-trip', () {
      const config = SyncConfig(accountEnabled: true);
      expect(SyncConfig.fromJson(config.toJson()), config);
    });
  });

  group('EncryptedSyncBlob', () {
    test('encrypt/decrypt round-trip preserves plaintext', () {
      const plaintext = '{"hello":"sync"}';
      final blob = encryptSyncPayload(plaintext);
      expect(decryptSyncPayload(blob), plaintext);
    });

    test('rejects checksum mismatch', () {
      final blob = encryptSyncPayload('{"tamper":true}');
      final tampered = EncryptedSyncBlob(
        version: blob.version,
        checksum: '00000000',
        data: blob.data,
      );

      expect(
        () => decryptSyncPayload(tampered),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unsupported version', () {
      final blob = encryptSyncPayload('{}');
      final unsupported = EncryptedSyncBlob(
        version: 99,
        checksum: blob.checksum,
        data: blob.data,
      );

      expect(
        () => decryptSyncPayload(unsupported),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('exportSyncBlob / importSyncBlob', () {
    test('round-trips shots and profiles from fixtures', () {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final profile = SavedProfile.fromShot(
        shot,
        id: 'profile-sync-test',
        createdAt: DateTime.utc(2026, 6, 29, 12),
      );
      final exportedAt = DateTime.utc(2026, 6, 29, 15, 30);

      final blob = exportSyncBlob(
        shots: [shot],
        profiles: [profile],
        exportedAt: exportedAt,
      );
      final payload = importSyncBlob(blob);

      expect(payload.version, syncBlobVersion);
      expect(payload.exportedAt, exportedAt);
      expect(payload.config.accountEnabled, isFalse);
      expect(payload.shots, [shot]);
      expect(payload.profiles, [profile]);
    });

    test('round-trips through EncryptedSyncBlob JSON transport', () {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final blob = exportSyncBlob(shots: [shot], profiles: const []);

      final wire = jsonEncode(blob.toJson());
      final restored = EncryptedSyncBlob.fromJson(
        jsonDecode(wire) as Map<String, dynamic>,
      );
      final payload = importSyncBlob(restored);

      expect(payload.shots, [shot]);
      expect(payload.profiles, isEmpty);
    });

    test('preserves explicit sync config', () {
      const config = SyncConfig(accountEnabled: true);
      final blob = exportSyncBlob(
        shots: const [],
        profiles: const [],
        config: config,
      );

      expect(importSyncBlob(blob).config, config);
    });

    test('rejects tampered ciphertext', () {
      final blob = exportSyncBlob(
        shots: [_loadFixtureShot('shots/minimal_shot.json')],
        profiles: const [],
      );
      final bytes = base64Decode(blob.data);
      bytes[0] = bytes[0] ^ 0xFF;
      final tampered = EncryptedSyncBlob(
        version: blob.version,
        checksum: blob.checksum,
        data: base64Encode(bytes),
      );

      expect(
        () => importSyncBlob(tampered),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

Shot _loadFixtureShot(String relativePath) {
  final json =
      jsonDecode(File(_fixturePath(relativePath)).readAsStringSync())
          as Map<String, dynamic>;
  return Shot.fromJson(json);
}

String _fixturePath(String relativePath) {
  final candidates = [
    '../../fixtures/$relativePath',
    '../../../fixtures/$relativePath',
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError('Fixture not found: $relativePath');
}