import 'dart:async';

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog/sync/flowlog_sync_coordinator.dart';
import 'package:flowlog/sync/nextcloud_settings_store.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

typedef NextcloudLoginFlowStarter = Future<NextcloudLoginSession> Function(
  String serverUrl,
);

typedef NextcloudLoginFlowPoller = Future<NextcloudLoginPollResult> Function(
  NextcloudLoginSession session,
);

typedef NextcloudUrlLauncher = Future<bool> Function(Uri url);

/// Settings screen for Nextcloud WebDAV auto-sync.
class NextcloudSyncScreen extends StatefulWidget {
  const NextcloudSyncScreen({
    super.key,
    this.database,
    this.settingsStore,
    this.loginFlowStarter = startNextcloudLoginFlow,
    this.loginFlowPoller = pollNextcloudLoginFlow,
    this.urlLauncher = _defaultUrlLauncher,
  });

  final FlowlogDatabase? database;
  final NextcloudSettingsStore? settingsStore;
  final NextcloudLoginFlowStarter loginFlowStarter;
  final NextcloudLoginFlowPoller loginFlowPoller;
  final NextcloudUrlLauncher urlLauncher;

  @override
  State<NextcloudSyncScreen> createState() => _NextcloudSyncScreenState();
}

Future<bool> _defaultUrlLauncher(Uri url) {
  return launchUrl(url, mode: LaunchMode.externalApplication);
}

class _NextcloudSyncScreenState extends State<NextcloudSyncScreen> {
  late final NextcloudSettingsStore _store;
  late final TextEditingController _serverController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  FlowlogDatabase? _database;
  bool _loading = true;
  bool _isBusy = false;
  bool _loginCancelled = false;
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

    _database = await openFlowlogDatabase();
    return _database!;
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isBusy = true;
      _statusMessage = null;
    });

    String? message;
    try {
      await _saveSettingsInternal();
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

  Future<void> _signInWithBrowser() async {
    final serverUrl = _serverController.text.trim();
    if (serverUrl.isEmpty) {
      setState(() => _statusMessage = 'Enter your server URL first');
      return;
    }

    setState(() {
      _isBusy = true;
      _loginCancelled = false;
      _statusMessage = 'Starting browser sign-in…';
    });

    try {
      final session = await widget.loginFlowStarter(serverUrl);
      if (!mounted || _loginCancelled) {
        return;
      }

      final launched = await widget.urlLauncher(Uri.parse(session.loginUrl));
      if (!launched) {
        setState(() => _statusMessage = 'Could not open browser');
        return;
      }

      if (!mounted || _loginCancelled) {
        return;
      }

      setState(() {
        _statusMessage =
            'Complete sign-in in your browser, then return to Flowlog';
      });

      final credentials = await _waitForBrowserLogin(session);
      if (!mounted || _loginCancelled || credentials == null) {
        return;
      }

      setState(() {
        _serverController.text = credentials.serverUrl;
        _usernameController.text = credentials.loginName;
        _passwordController.text = credentials.appPassword;
        _statusMessage = 'Signed in as ${credentials.loginName}';
      });

      await _saveSettingsInternal();
    } catch (error) {
      if (mounted && !_loginCancelled) {
        setState(() => _statusMessage = 'Sign-in failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<NextcloudLoginCredentials?> _waitForBrowserLogin(
    NextcloudLoginSession session,
  ) async {
    final deadline = DateTime.now().add(const Duration(minutes: 20));

    while (!_loginCancelled && DateTime.now().isBefore(deadline)) {
      final result = await widget.loginFlowPoller(session);
      if (result.isCompleted) {
        return result.credentials;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    if (_loginCancelled) {
      return null;
    }

    throw const NextcloudLoginTimeoutException(
      'Nextcloud login timed out after browser sign-in',
    );
  }

  void _cancelBrowserSignIn() {
    setState(() {
      _loginCancelled = true;
      _isBusy = false;
      _statusMessage = 'Sign-in cancelled';
    });
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
            ? 'Sync skipped — sign in or check server URL and credentials'
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
    _loginCancelled = true;
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
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

    final waitingForBrowser =
        _isBusy && _statusMessage?.contains('Complete sign-in') == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Sync shots, profiles, and beans with your Nextcloud instance '
          'over WebDAV. Sign in with your browser (recommended) or paste '
          'an app password manually.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Note: Transfer uses your WebDAV credentials. On-device encryption is '
          'currently a basic placeholder and will be improved before relying on '
          'it for sensitive data.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
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
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('nextcloud_sign_in_button'),
          onPressed: _isBusy ? null : () => unawaited(_signInWithBrowser()),
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Nextcloud'),
        ),
        if (waitingForBrowser) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('nextcloud_cancel_sign_in_button'),
            onPressed: _cancelBrowserSignIn,
            child: const Text('Cancel sign-in'),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or enter manually',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
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