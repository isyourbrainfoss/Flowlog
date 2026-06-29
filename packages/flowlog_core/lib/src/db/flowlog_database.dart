import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';
import 'type_converters.dart';

part 'flowlog_database.g.dart';

/// Drift-backed SQLite database for Flowlog shot persistence.
@DriftDatabase(tables: [Shots, ShotSamples, Beans])
class FlowlogDatabase extends _$FlowlogDatabase {
  FlowlogDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(beans);
          }
        },
      );

  /// Opens an in-memory database for tests.
  factory FlowlogDatabase.inMemory() {
    return FlowlogDatabase(NativeDatabase.memory());
  }

  /// Opens a file-backed database at [path].
  factory FlowlogDatabase.openFile(String path) {
    return FlowlogDatabase(NativeDatabase(File(path)));
  }

  /// Opens a file-backed database in [directory] named [fileName].
  static Future<FlowlogDatabase> openInDirectory(
    String directory, {
    String fileName = 'flowlog.db',
  }) async {
    final file = File(p.join(directory, fileName));
    return FlowlogDatabase.openFile(file.path);
  }
}