import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

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

/// File-backed persistence for Nextcloud settings and credentials.
class NextcloudSettingsStore {
  NextcloudSettingsStore({
    String? settingsPath,
    String? credentialsPath,
  })  : _settingsPath = settingsPath ?? _defaultSettingsPath,
        _credentialsPath = credentialsPath ?? _defaultCredentialsPath;

  static String get _defaultSettingsPath =>
      '${Directory.systemTemp.path}/flowlog_nextcloud_settings.json';

  static String get _defaultCredentialsPath =>
      '${Directory.systemTemp.path}/flowlog_nextcloud_credentials.json';

  final String _settingsPath;
  final String _credentialsPath;

  Future<NextcloudSettings> loadSettings() async {
    final file = File(_settingsPath);
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
    final file = File(_settingsPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }

  Future<String?> loadPassword() async {
    final file = File(_credentialsPath);
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

  Future<void> savePassword(String password) async {
    final file = File(_credentialsPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'password': password,
      }),
    );
  }

  Future<void> clearAll() async {
    final settingsFile = File(_settingsPath);
    if (settingsFile.existsSync()) {
      await settingsFile.delete();
    }

    final credentialsFile = File(_credentialsPath);
    if (credentialsFile.existsSync()) {
      await credentialsFile.delete();
    }
  }
}