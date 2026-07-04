import 'dart:async';
import 'dart:io';

import 'package:flowlog/sync/flowlog_sync_coordinator.dart';
import 'package:flowlog/sync/nextcloud_settings_store.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Settings screen for Nextcloud WebDAV auto-sync.
class NextcloudSyncScreen extends StatefulWidget {
  const NextcloudSyncScreen({
    super.key,
    this.database,
    this.settingsStore,
  });

  final FlowlogDatabase? database;
  final NextcloudSettingsStore? settingsStore;

  @override
  State<NextcloudSyncScreen> createState() => _NextcloudSyncScreenState();
}

class _NextcloudSyncScreenState extends State<NextcloudSyncScreen> {
  late final NextcloudSettingsStore _store;
  late final TextEditingController _serverController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  FlowlogDatabase? _database;
  bool _ownsDatabase = false;
  bool _loading = true;
  bool _isBusy = false;
  bool _autoSyncEnabled = false;
  DateTime? _lastSyncedAt;
  String? _lastSyncMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _store = widget.settingsStore ?? NextcloudSettingsStore();
    _serverController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final settings = await _store.loadSettings();
    final password = await _store.loadPassword();

    if (!mounted) {
      return;
    }

    setState(() {
      _serverController.text = settings.serverUrl;
      _usernameController.text = settings.username;
      if (password != null) {
        _passwordController.text = password;
      }
      _autoSyncEnabled = settings.enabled;
      _lastSyncedAt = settings.lastSyncedAt;
      _lastSyncMessage = settings.lastSyncMessage;
      _loading = false;
    });
  }

  Future<FlowlogDatabase> _ensureDatabase() async {
    if (widget.database != null) {
      return widget.database!;
    }
    if (_database != null) {
      return _database!;
    }

    final dbPath = '${Directory.systemTemp.path}/flowlog.db';
    _database = FlowlogDatabase.openFile(dbPath);
    _ownsDatabase = true;
    return _database!;
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isBusy = true;
      _statusMessage = null;
    });

    String? message;
    try {
      final settings = NextcloudSettings(
        enabled: _autoSyncEnabled,
        serverUrl: _serverController.text.trim(),
        username: _usernameController.text.trim(),
        lastSyncedAt: _lastSyncedAt,
        lastSyncMessage: _lastSyncMessage,
      );
      await _store.saveSettings(settings);

      final password = _passwordController.text;
      if (password.isNotEmpty) {
        await _store.savePassword(password);
      }

      message = 'Settings saved';
    } catch (error) {
      message = 'Save failed: $error';
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          if (message != null) {
            _statusMessage = message;
          }
        });
      }
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _isBusy = true;
      _statusMessage = null;
    });

    try {
      await _saveSettingsInternal();

      final database = await _ensureDatabase();
      final result = await FlowlogSyncCoordinator.syncNow(database: database);
      final settings = await _store.loadSettings();

      if (!mounted) {
        return;
      }

      setState(() {
        _lastSyncedAt = settings.lastSyncedAt;
        _lastSyncMessage = settings.lastSyncMessage;
        _statusMessage = result == null
            ? 'Sync skipped — check server URL, username, and app password'
            : result.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Sync failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _saveSettingsInternal() async {
    final settings = NextcloudSettings(
      enabled: _autoSyncEnabled,
      serverUrl: _serverController.text.trim(),
      username: _usernameController.text.trim(),
      lastSyncedAt: _lastSyncedAt,
      lastSyncMessage: _lastSyncMessage,
    );
    await _store.saveSettings(settings);

    final password = _passwordController.text;
    if (password.isNotEmpty) {
      await _store.savePassword(password);
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    if (_ownsDatabase) {
      _database?.close();
    }
    super.dispose();
  }

  String _formatLastSyncedAt(DateTime? value) {
    if (value == null) {
      return 'Never';
    }

    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Sync shots, profiles, and beans with your Nextcloud instance '
          'over WebDAV. Use an app password from your Nextcloud security '
          'settings.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('nextcloud_server_field'),
          controller: _serverController,
          decoration: const InputDecoration(
            labelText: 'Server URL',
            hintText: 'https://cloud.example.com',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          enabled: !_isBusy,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('nextcloud_username_field'),
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
          enabled: !_isBusy,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('nextcloud_password_field'),
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'App password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          textInputAction: TextInputAction.done,
          enabled: !_isBusy,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-sync with Nextcloud'),
          subtitle: const Text('Sync after app launch and when shots are saved'),
          value: _autoSyncEnabled,
          onChanged: _isBusy
              ? null
              : (enabled) {
                  setState(() => _autoSyncEnabled = enabled);
                },
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last sync',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text('Time: ${_formatLastSyncedAt(_lastSyncedAt)}'),
                if (_lastSyncMessage != null) ...[
                  const SizedBox(height: 4),
                  Text('Status: $_lastSyncMessage'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('nextcloud_save_button'),
          onPressed: _isBusy ? null : () => unawaited(_saveSettings()),
          child: const Text('Save settings'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('nextcloud_sync_now_button'),
          onPressed: _isBusy ? null : () => unawaited(_syncNow()),
          child: const Text('Sync now'),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _statusMessage!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}