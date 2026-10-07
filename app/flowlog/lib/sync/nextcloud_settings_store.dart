import 'dart:convert';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// User-visible Nextcloud sync preferences (password stored separately).
@immutable
class NextcloudSettings {
  const NextcloudSettings({
    this.enabled = false,
    this.serverUrl = '',
    this.username = '',
    this.lastSyncedAt,
    this.lastSyncMessage,
  });

  final bool enabled;
  final String serverUrl;
  final String username;
  final DateTime? lastSyncedAt;
  final String? lastSyncMessage;

  NextcloudSettings copyWith({
    bool? enabled,
    String? serverUrl,
    String? username,
    DateTime? lastSyncedAt,
    String? lastSyncMessage,
    bool clearLastSyncedAt = false,
    bool clearLastSyncMessage = false,
  }) {
    return NextcloudSettings(
      enabled: enabled ?? this.enabled,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      lastSyncedAt:
          clearLastSyncedAt ? null : (lastSyncedAt ?? this.lastSyncedAt),
      lastSyncMessage: clearLastSyncMessage
          ? null
          : (lastSyncMessage ?? this.lastSyncMessage),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'serverUrl': serverUrl,
      'username': username,
      if (lastSyncedAt != null)
        'lastSyncedAt': lastSyncedAt!.toUtc().toIso8601String(),
      if (lastSyncMessage != null) 'lastSyncMessage': lastSyncMessage,
    };
  }

  factory NextcloudSettings.fromJson(Map<String, dynamic> json) {
    final lastSyncedRaw = json['lastSyncedAt'];
    DateTime? lastSyncedAt;
    if (lastSyncedRaw is String && lastSyncedRaw.isNotEmpty) {
      lastSyncedAt = DateTime.tryParse(lastSyncedRaw)?.toUtc();
    }

    return NextcloudSettings(
      enabled: json['enabled'] as bool? ?? false,
      serverUrl: json['serverUrl'] as String? ?? '',
      username: json['username'] as String? ?? '',
      lastSyncedAt: lastSyncedAt,
      lastSyncMessage: json['lastSyncMessage'] as String?,
    );
  }
}

/// Persistence for Nextcloud settings (JSON) and app password (secure storage).

/// Non-secret preferences stay in [flowlog_nextcloud_settings.json]. The app
/// password / token is stored via [FlutterSecureStorage] (Android Keystore /
/// platform credential store). A legacy plaintext credentials JSON file is
/// migrated once, then deleted.
class NextcloudSettingsStore {
  NextcloudSettingsStore({
    String? settingsPath,
    String? credentialsPath,
    FlutterSecureStorage? secureStorage,
  })  : _settingsPathOverride = settingsPath,
        _credentialsPathOverride = credentialsPath,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _passwordKey = 'flowlog_nextcloud_app_password';

  final String? _settingsPathOverride;
  final String? _credentialsPathOverride;
  final FlutterSecureStorage _secureStorage;

  Future<String> _resolveSettingsPath() async {
    return _settingsPathOverride ??
        FlowlogStorage.shared.filePath('flowlog_nextcloud_settings.json');
  }

  Future<String> _resolveCredentialsPath() async {
    return _credentialsPathOverride ??
        FlowlogStorage.shared.filePath('flowlog_nextcloud_credentials.json');
  }

  Future<NextcloudSettings> loadSettings() async {
    final file = File(await _resolveSettingsPath());
    if (!file.existsSync()) {
      return const NextcloudSettings();
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const NextcloudSettings();
      }
      return NextcloudSettings.fromJson(decoded);
    } catch (_) {
      return const NextcloudSettings();
    }
  }

  Future<void> saveSettings(NextcloudSettings settings) async {
    final file = File(await _resolveSettingsPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }

  Future<String?> loadPassword() async {
    try {
      final fromSecure = await _secureStorage.read(key: _passwordKey);
      if (fromSecure != null && fromSecure.isNotEmpty) {
        await _deleteLegacyCredentialsFile();
        return fromSecure;
      }
    } on Object {
      // Fall through to legacy file / null (tests, unsupported platforms).
    }

    final legacy = await _loadLegacyPassword();
    if (legacy == null || legacy.isEmpty) {
      return null;
    }

    try {
      await _secureStorage.write(key: _passwordKey, value: legacy);
      await _deleteLegacyCredentialsFile();
    } on Object {
      // Keep legacy file readable if secure write fails.
    }
    return legacy;
  }

  Future<void> savePassword(String password) async {
    try {
      await _secureStorage.write(key: _passwordKey, value: password);
      await _deleteLegacyCredentialsFile();
      return;
    } on Object {
      // Fall back to file only when secure storage is unavailable (rare).
    }

    final file = File(await _resolveCredentialsPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'password': password,
      }),
    );
  }

  Future<void> clearAll() async {
    final settingsFile = File(await _resolveSettingsPath());
    if (settingsFile.existsSync()) {
      await settingsFile.delete();
    }

    try {
      await _secureStorage.delete(key: _passwordKey);
    } on Object {
      // ignore
    }
    await _deleteLegacyCredentialsFile();
  }

  Future<String?> _loadLegacyPassword() async {
    final file = File(await _resolveCredentialsPath());
    if (!file.existsSync()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final password = decoded['password'];
      if (password is! String || password.isEmpty) {
        return null;
      }
      return password;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteLegacyCredentialsFile() async {
    final file = File(await _resolveCredentialsPath());
    if (file.existsSync()) {
      try {
        await file.delete();
      } on Object {
        // ignore
      }
    }
  }
}
