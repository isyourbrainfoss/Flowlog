import 'dart:io';

import 'package:flowlog/sync/nextcloud_settings_store.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/foundation.dart';

typedef NextcloudSyncRunner = Future<NextcloudSyncResult> Function({
  required WebDavCredentials credentials,
  required FlowlogDatabase database,
});

/// Coordinates optional background Nextcloud sync for the Flowlog app.
class FlowlogSyncCoordinator {
  FlowlogSyncCoordinator._();

  static NextcloudSettingsStore _settingsStore = NextcloudSettingsStore();
  static NextcloudSyncRunner _syncRunner = nextcloudSync;
  static DateTime? _lastSyncAttempt;

  @visibleForTesting
  static void debugOverride({
    NextcloudSettingsStore? settingsStore,
    NextcloudSyncRunner? syncRunner,
  }) {
    if (settingsStore != null) {
      _settingsStore = settingsStore;
    }
    if (syncRunner != null) {
      _syncRunner = syncRunner;
    }
  }

  @visibleForTesting
  static void debugReset() {
    _settingsStore = NextcloudSettingsStore();
    _syncRunner = nextcloudSync;
    _lastSyncAttempt = null;
  }

  /// Runs sync when auto-sync is enabled and credentials are configured.
  static Future<NextcloudSyncResult?> syncIfEnabled({
    FlowlogDatabase? database,
    bool force = false,
  }) {
    return _runSync(
      database: database,
      requireEnabled: true,
      force: force,
    );
  }

  /// Runs sync on demand from settings UI (ignores the enabled toggle).
  static Future<NextcloudSyncResult?> syncNow({
    FlowlogDatabase? database,
  }) {
    return _runSync(
      database: database,
      requireEnabled: false,
      force: true,
    );
  }

  static Future<NextcloudSyncResult?> _runSync({
    FlowlogDatabase? database,
    required bool requireEnabled,
    required bool force,
  }) async {
    if (!force &&
        _lastSyncAttempt != null &&
        DateTime.now().difference(_lastSyncAttempt!) <
            const Duration(seconds: 30)) {
      return null;
    }

    final settings = await _settingsStore.loadSettings();
    if (requireEnabled && !settings.enabled) {
      return null;
    }

    final password = await _settingsStore.loadPassword();
    if (password == null || password.isEmpty) {
      return null;
    }

    final serverUrl = settings.serverUrl.trim();
    final username = settings.username.trim();
    if (serverUrl.isEmpty || username.isEmpty) {
      return null;
    }

    _lastSyncAttempt = DateTime.now();

    final resolvedDatabase = database ?? await _openDefaultDatabase();
    final ownsDatabase = database == null;

    try {
      final result = await _syncRunner(
        credentials: WebDavCredentials(
          serverUrl: serverUrl,
          username: username,
          password: password,
        ),
        database: resolvedDatabase,
      );

      final updated = settings.copyWith(
        lastSyncedAt: DateTime.now().toUtc(),
        lastSyncMessage: result.message.isNotEmpty
            ? result.message
            : (result.error ?? 'Sync finished'),
      );
      await _settingsStore.saveSettings(updated);

      return result;
    } catch (error) {
      final message = 'Sync failed: $error';
      final updated = settings.copyWith(lastSyncMessage: message);
      await _settingsStore.saveSettings(updated);

      return NextcloudSyncResult(success: false, message: message);
    } finally {
      if (ownsDatabase) {
        await resolvedDatabase.close();
      }
    }
  }

  static Future<FlowlogDatabase> _openDefaultDatabase() async {
    final dbPath = '${Directory.systemTemp.path}/flowlog.db';
    return FlowlogDatabase.openFile(dbPath);
  }
}