import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves durable on-device paths for Flowlog data and settings.
///
/// Uses the platform application-support directory so brew history survives
/// app updates and `flutter run` reinstalls on a phone.
class FlowlogStorage {
  FlowlogStorage({
    Future<Directory> Function()? directoryProvider,
    this.migrateLegacy = true,
  }) : _directoryProvider = directoryProvider ?? _defaultDirectoryProvider;

  /// When false, skips one-time import from the old temp-directory store.
  final bool migrateLegacy;

  static final FlowlogStorage _instance = FlowlogStorage();

  static FlowlogStorage? _override;

  /// Shared production storage; tests may replace via [overrideForTesting].
  static FlowlogStorage get shared => _override ?? _instance;

  @visibleForTesting
  static void overrideForTesting(FlowlogStorage? storage) {
    _override = storage;
  }

  final Future<Directory> Function() _directoryProvider;
  Future<String>? _rootPathFuture;
  FlowlogDatabase? _database;
  Future<FlowlogDatabase>? _databaseFuture;
  bool _migrated = false;

  static Future<Directory> _defaultDirectoryProvider() async {
    return getApplicationSupportDirectory();
  }

  Future<String> rootPath() async {
    _rootPathFuture ??= _directoryProvider().then((dir) => dir.path);
    return _rootPathFuture!;
  }

  Future<String> databaseFilePath() async {
    return p.join(await rootPath(), 'flowlog.db');
  }

  Future<String> filePath(String fileName) async {
    return p.join(await rootPath(), fileName);
  }

  Future<FlowlogDatabase> database() async {
    if (_database != null) {
      return _database!;
    }

    _databaseFuture ??= _openDatabase();
    return _databaseFuture!;
  }

  Future<FlowlogDatabase> _openDatabase() async {
    await _migrateLegacyTempFilesIfNeeded();

    final path = await databaseFilePath();
    await Directory(p.dirname(path)).create(recursive: true);
    _database = FlowlogDatabase.openFile(path);
    // Touch the schema so the sqlite file exists before the first write.
    await _database!.customSelect('SELECT 1').get();
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _databaseFuture = null;
    _rootPathFuture = null;
    _migrated = false;
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    await (_override ?? _instance).close();
    _override = null;
  }

  Future<void> _migrateLegacyTempFilesIfNeeded() async {
    if (!migrateLegacy || _migrated) {
      return;
    }
    _migrated = true;

    final legacyDir = Directory.systemTemp.path;
    final targetDir = await rootPath();
    await Directory(targetDir).create(recursive: true);

    const files = <String>[
      'flowlog.db',
      'flowlog_auto_start_settings.json',
      'flowlog_brew_location.json',
      'flowlog_nextcloud_settings.json',
      'flowlog_nextcloud_credentials.json',
    ];

    for (final name in files) {
      final legacy = File(p.join(legacyDir, name));
      final target = File(p.join(targetDir, name));
      if (legacy.existsSync() && !target.existsSync()) {
        await legacy.copy(target.path);
      }
    }
  }
}

/// Opens the shared file-backed [FlowlogDatabase].
Future<FlowlogDatabase> openFlowlogDatabase() {
  return FlowlogStorage.shared.database();
}