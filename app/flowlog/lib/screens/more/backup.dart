import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Outcome of saving or sharing a backup file.
@immutable
class BackupSaveOutcome {
  const BackupSaveOutcome({
    required this.success,
    this.message,
    this.savedPath,
  });

  const BackupSaveOutcome.cancelled()
      : success = false,
        message = 'Export cancelled',
        savedPath = null;

  const BackupSaveOutcome.saved(String path, {String? message})
      : success = true,
        message = message ?? 'Backup saved',
        savedPath = path;

  final bool success;
  final String? message;
  final String? savedPath;
}

/// Outcome of picking a backup file for import.
@immutable
class BackupPickOutcome {
  const BackupPickOutcome({
    required this.success,
    this.message,
    this.path,
    this.contents,
  });

  const BackupPickOutcome.cancelled()
      : success = false,
        message = 'Import cancelled',
        path = null,
        contents = null;

  const BackupPickOutcome.picked({
    required this.path,
    required this.contents,
  })  : success = true,
        message = null;

  final bool success;
  final String? message;
  final String? path;
  final String? contents;
}

/// Platform I/O for full backup export and import.
abstract class BackupActions {
  Future<BackupSaveOutcome> saveBackup({
    required String suggestedName,
    required String content,
  });

  Future<BackupPickOutcome> pickBackup();
}

/// Test-friendly stub that records backup I/O without platform plugins.
class StubBackupActions implements BackupActions {
  StubBackupActions({this.saveDirectory});

  final String? saveDirectory;

  String? lastSavedPath;
  String? lastSavedContent;
  String? lastPickedPath;
  String? lastPickedContent;
  int saveCalls = 0;
  int pickCalls = 0;

  void stagePick({required String path, required String contents}) {
    lastPickedPath = path;
    lastPickedContent = contents;
  }

  @override
  Future<BackupSaveOutcome> saveBackup({
    required String suggestedName,
    required String content,
  }) async {
    saveCalls++;
    final directory = saveDirectory ?? Directory.systemTemp.path;
    Directory(directory).createSync(recursive: true);
    final path = '$directory/$suggestedName';
    lastSavedPath = path;
    lastSavedContent = content;
    await File(path).writeAsString(content);
    return BackupSaveOutcome.saved(path);
  }

  @override
  Future<BackupPickOutcome> pickBackup() async {
    pickCalls++;
    if (lastPickedContent == null) {
      return const BackupPickOutcome.cancelled();
    }
    return BackupPickOutcome.picked(
      path: lastPickedPath ?? 'staged.flowlog',
      contents: lastPickedContent!,
    );
  }
}

class LinuxBackupActions implements BackupActions {
  @override
  Future<BackupSaveOutcome> saveBackup({
    required String suggestedName,
    required String content,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Flowlog backup',
          extensions: [flowlogBackupExtension],
        ),
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );

    if (location == null) {
      return const BackupSaveOutcome.cancelled();
    }

    final file = File(location.path);
    await file.writeAsString(content);
    return BackupSaveOutcome.saved(file.path);
  }

  @override
  Future<BackupPickOutcome> pickBackup() async {
    const typeGroup = XTypeGroup(
      label: 'Flowlog backup',
      extensions: [flowlogBackupExtension, 'json'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) {
      return const BackupPickOutcome.cancelled();
    }

    final contents = await File(file.path).readAsString();
    return BackupPickOutcome.picked(path: file.path, contents: contents);
  }
}

class AndroidBackupActions implements BackupActions {
  @override
  Future<BackupSaveOutcome> saveBackup({
    required String suggestedName,
    required String content,
  }) async {
    final tempDir = Directory.systemTemp.createTempSync('flowlog-backup');
    final file = File('${tempDir.path}/$suggestedName');
    await file.writeAsString(content);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Flowlog backup',
    );
    return BackupSaveOutcome.saved(
      file.path,
      message: 'Backup shared',
    );
  }

  @override
  Future<BackupPickOutcome> pickBackup() async {
    const typeGroup = XTypeGroup(
      label: 'Flowlog backup',
      extensions: [flowlogBackupExtension, 'json'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) {
      return const BackupPickOutcome.cancelled();
    }

    final contents = await File(file.path).readAsString();
    return BackupPickOutcome.picked(path: file.path, contents: contents);
  }
}

BackupActions defaultBackupActions() {
  if (kIsWeb) {
    return StubBackupActions();
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => AndroidBackupActions(),
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.macOS =>
      LinuxBackupActions(),
    _ => StubBackupActions(),
  };
}

String defaultBackupFilename() {
  final stamp = DateTime.now().toUtc();
  final y = stamp.year.toString().padLeft(4, '0');
  final m = stamp.month.toString().padLeft(2, '0');
  final d = stamp.day.toString().padLeft(2, '0');
  return 'flowlog-backup-$y-$m-$d.$flowlogBackupExtension';
}

/// Full backup export and merge import for cross-device sync.
class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    this.database,
    this.backupActions,
  });

  final FlowlogDatabase? database;
  final BackupActions? backupActions;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  FlowlogDatabase? _database;
  bool _ownsDatabase = false;
  late final BackupActions _actions;
  bool _isBusy = false;
  String? _statusMessage;
  Future<_BackupCounts>? _countsFuture;

  @override
  void initState() {
    super.initState();
    _actions = widget.backupActions ?? defaultBackupActions();
    _countsFuture = _loadCounts();
  }

  Future<FlowlogDatabase> _ensureDatabase() async {
    if (widget.database != null) {
      return widget.database!;
    }
    if (_database != null) {
      return _database!;
    }

    _database = await openFlowlogDatabase();
    _ownsDatabase = true;
    return _database!;
  }

  Future<_BackupCounts> _loadCounts() async {
    final database = await _ensureDatabase();
    final shots = await ShotRepository(database).listShots();
    final profiles = await ProfileRepository(database).listProfiles();
    final beans = await BeanRepository(database).listBeans();
    return _BackupCounts(
      shots: shots.length,
      profiles: profiles.length,
      beans: beans.length,
    );
  }

  Future<void> _refreshCounts() async {
    setState(() {
      _countsFuture = _loadCounts();
    });
    await _countsFuture;
  }

  Future<void> _exportBackup() async {
    setState(() {
      _isBusy = true;
      _statusMessage = null;
    });

    try {
      final database = await _ensureDatabase();
      final payload = await buildSyncPayloadFromDatabase(database);
      final content = encodeSyncBackup(payload);
      final outcome = await _actions.saveBackup(
        suggestedName: defaultBackupFilename(),
        content: content,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = outcome.success
            ? '${outcome.message}: ${payload.shots.length} shots, '
                '${payload.profiles.length} profiles, ${payload.beans.length} beans'
            : outcome.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Export failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _importAndMerge() async {
    setState(() {
      _isBusy = true;
      _statusMessage = null;
    });

    try {
      final pick = await _actions.pickBackup();
      if (!pick.success || pick.contents == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _statusMessage = pick.message ?? 'Import cancelled';
        });
        return;
      }

      final payload = parseSyncBackup(pick.contents!);
      final database = await _ensureDatabase();
      final result = await mergeSyncPayload(
        database: database,
        payload: payload,
      );

      await _refreshCounts();

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            'Merged ${result.shotsMerged} shots, ${result.profilesMerged} '
            'profiles, and ${result.beansMerged} beans from backup.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Import failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BackupCounts>(
      future: _countsFuture,
      builder: (context, snapshot) {
        final counts = snapshot.data;
        final loadingCounts = snapshot.connectionState != ConnectionState.done;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Export a full backup of shots, saved profiles, and beans. '
              'Import merges by id — existing records are updated, new ones '
              'are added. Use this to combine data from Android and Linux.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: loadingCounts
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'On this device',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Text('${counts?.shots ?? 0} shots'),
                          Text('${counts?.profiles ?? 0} saved profiles'),
                          Text('${counts?.beans ?? 0} beans'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('backup_export_button'),
              onPressed: _isBusy ? null : _exportBackup,
              icon: _isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: const Text('Export backup'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('backup_import_button'),
              onPressed: _isBusy ? null : _importAndMerge,
              icon: const Icon(Icons.download),
              label: const Text('Import & merge'),
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
      },
    );
  }
}

class _BackupCounts {
  const _BackupCounts({
    required this.shots,
    required this.profiles,
    required this.beans,
  });

  final int shots;
  final int profiles;
  final int beans;
}