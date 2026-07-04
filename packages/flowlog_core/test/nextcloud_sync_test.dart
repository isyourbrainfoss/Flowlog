import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('nextcloudSync', () {
    late FlowlogDatabase db;
    late FakeWebDavTransport transport;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      transport = FakeWebDavTransport();
    });

    tearDown(() async {
      await db.close();
    });

    test('uploads local payload when remote is missing', () async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await ShotRepository(db).insertShot(shot);

      final result = await nextcloudSync(
        credentials: _credentials,
        database: db,
        client: transport,
      );

      expect(result.success, isTrue);
      expect(result.uploaded, isTrue);
      expect(result.mergedRemote, isFalse);
      expect(result.mergeResult, isNull);
      expect(result.remoteExportedAt, isNull);
      expect(result.localExportedAt, isNotNull);
      expect(transport.collections, contains('Flowlog'));
      expect(transport.files[kNextcloudRemoteFile], isNotNull);

      final uploaded = parseSyncBackup(transport.files[kNextcloudRemoteFile]!);
      expect(uploaded.shots.length, 1);
      expect(uploaded.config.accountEnabled, isTrue);
    });

    test('merges newer remote payload before upload', () async {
      final localShot = _loadFixtureShot('shots/minimal_shot.json');
      await ShotRepository(db).insertShot(localShot);

      final localPayload = await buildSyncPayloadFromDatabase(
        db,
        config: const SyncConfig(accountEnabled: true),
        exportedAt: DateTime.utc(2026, 7, 1),
      );

      final remoteShot = localShot.copyWith(notes: 'Remote notes');
      final remotePayload = SyncPayload(
        version: syncPayloadVersion,
        exportedAt: DateTime.utc(2026, 7, 5),
        config: const SyncConfig(accountEnabled: true),
        shots: [remoteShot],
        profiles: const [],
        beans: const [],
      );
      transport.files[kNextcloudRemoteFile] = encodeSyncBackup(remotePayload);

      final result = await nextcloudSync(
        credentials: _credentials,
        database: db,
        client: transport,
      );

      expect(result.success, isTrue);
      expect(result.mergedRemote, isTrue);
      expect(result.uploaded, isTrue);
      expect(result.mergeResult?.shotsMerged, 1);
      expect(result.remoteExportedAt, remotePayload.exportedAt);

      final stored = await ShotRepository(db).getShotById(localShot.id);
      expect(stored?.notes, 'Remote notes');

      final uploaded = parseSyncBackup(transport.files[kNextcloudRemoteFile]!);
      expect(uploaded.shots.single.notes, 'Remote notes');
      expect(
        uploaded.exportedAt.isAfter(localPayload.exportedAt),
        isTrue,
      );
    });

    test('keeps local data when remote is older', () async {
      final localShot = _loadFixtureShot('shots/minimal_shot.json').copyWith(
        notes: 'Local notes',
      );
      await ShotRepository(db).insertShot(localShot);

      final remoteShot = localShot.copyWith(notes: 'Stale remote');
      final remotePayload = SyncPayload(
        version: syncPayloadVersion,
        exportedAt: DateTime.utc(2026, 6, 1),
        config: const SyncConfig(accountEnabled: true),
        shots: [remoteShot],
        profiles: const [],
        beans: const [],
      );
      transport.files[kNextcloudRemoteFile] = encodeSyncBackup(remotePayload);

      final result = await nextcloudSync(
        credentials: _credentials,
        database: db,
        client: transport,
      );

      expect(result.success, isTrue);
      expect(result.mergedRemote, isFalse);
      expect(result.mergeResult?.totalMerged, 0);
      expect(result.remoteExportedAt, remotePayload.exportedAt);

      final stored = await ShotRepository(db).getShotById(localShot.id);
      expect(stored?.notes, 'Local notes');

      final uploaded = parseSyncBackup(transport.files[kNextcloudRemoteFile]!);
      expect(uploaded.shots.single.notes, 'Local notes');
    });

    test('imports new remote shots even when remote export is older', () async {
      final localShot = _loadFixtureShot('shots/minimal_shot.json').copyWith(
        notes: 'Local notes',
      );
      await ShotRepository(db).insertShot(localShot);

      final remoteOnlyShot = localShot.copyWith(
        id: 'shot-from-other-device',
        notes: 'From phone',
      );
      final remotePayload = SyncPayload(
        version: syncPayloadVersion,
        exportedAt: DateTime.utc(2026, 6, 1),
        config: const SyncConfig(accountEnabled: true),
        shots: [localShot.copyWith(notes: 'Stale'), remoteOnlyShot],
        profiles: const [],
        beans: const [],
      );
      transport.files[kNextcloudRemoteFile] = encodeSyncBackup(remotePayload);

      final result = await nextcloudSync(
        credentials: _credentials,
        database: db,
        client: transport,
      );

      expect(result.success, isTrue);
      expect(result.mergedRemote, isTrue);
      expect(result.mergeResult?.shotsMerged, 1);

      final shots = await ShotRepository(db).listShots();
      expect(shots.length, 2);
      expect(
        shots.singleWhere((shot) => shot.id == localShot.id).notes,
        'Local notes',
      );
      expect(
        shots.singleWhere((shot) => shot.id == remoteOnlyShot.id).notes,
        'From phone',
      );
    });

    test('returns failure when transport errors', () async {
      transport.failWith = const WebDavException(500, 'server error');

      final result = await nextcloudSync(
        credentials: _credentials,
        database: db,
        client: transport,
      );

      expect(result.success, isFalse);
      expect(result.uploaded, isFalse);
      expect(result.error, contains('500'));
    });
  });
}

const _credentials = WebDavCredentials(
  serverUrl: 'https://cloud.example.com',
  username: 'alice',
  password: 'secret',
);

class FakeWebDavTransport implements WebDavTransport {
  final Set<String> collections = {};
  final Map<String, String> files = {};
  WebDavException? failWith;

  @override
  Future<void> ensureCollection(String relativePath) async {
    _throwIfNeeded();
    collections.add(relativePath);
  }

  @override
  Future<String?> getText(String relativePath) async {
    _throwIfNeeded();
    return files[relativePath];
  }

  @override
  Future<void> putText(String relativePath, String content) async {
    _throwIfNeeded();
    files[relativePath] = content;
  }

  void _throwIfNeeded() {
    if (failWith != null) {
      throw failWith!;
    }
  }
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