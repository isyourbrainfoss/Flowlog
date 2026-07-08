import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';
import 'type_converters.dart';

part 'flowlog_database.g.dart';

/// Drift-backed SQLite database for Flowlog shot persistence.
@DriftDatabase(
  tables: [
    Shots,
    ShotSamples,
    ShotAnnotations,
    Beans,
    Tags,
    ShotTags,
    SavedProfiles,
    SavedProfileSamples,
  ],
)
class FlowlogDatabase extends _$FlowlogDatabase {
  FlowlogDatabase(super.executor);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(beans);
          }
          if (from < 3) {
            await m.createTable(tags);
            await m.createTable(shotTags);
          }
          if (from < 4) {
            await m.createTable(shotAnnotations);
          }
          if (from < 5) {
            await m.createTable(savedProfiles);
            await m.createTable(savedProfileSamples);
          }
          if (from < 6) {
            final beanColumns = await m.database
                .customSelect(
                  'PRAGMA table_info(beans)',
                  readsFrom: {beans},
                )
                .map((row) => row.read<String>('name'))
                .get();
            if (!beanColumns.contains('roast_date')) {
              await m.addColumn(beans, beans.roastDate);
            }
          }
          if (from < 7) {
            final beanColumns = await m.database
                .customSelect(
                  'PRAGMA table_info(beans)',
                  readsFrom: {beans},
                )
                .map((row) => row.read<String>('name'))
                .get();
            if (!beanColumns.contains('process')) {
              await m.addColumn(beans, beans.process);
            }
          }
          if (from < 8) {
            await m.addColumn(shots, shots.location);
          }
          if (from < 9) {
            await m.addColumn(shots, shots.latitude);
            await m.addColumn(shots, shots.longitude);
          }
          if (from < 10) {
            final beanColumns = await m.database
                .customSelect(
                  'PRAGMA table_info(beans)',
                  readsFrom: {beans},
                )
                .map((row) => row.read<String>('name'))
                .get();
            if (!beanColumns.contains('variety')) {
              await m.addColumn(beans, beans.variety);
            }
          }
          if (from < 11) {
            final beanColumns = await m.database
                .customSelect(
                  'PRAGMA table_info(beans)',
                  readsFrom: {beans},
                )
                .map((row) => row.read<String>('name'))
                .get();
            if (!beanColumns.contains('brand')) {
              await m.addColumn(beans, beans.brand);
            }
          }
          if (from < 12) {
            final shotColumns = await m.database
                .customSelect(
                  'PRAGMA table_info(shots)',
                  readsFrom: {shots},
                )
                .map((row) => row.read<String>('name'))
                .get();
            if (!shotColumns.contains('coffeejack_rewind_turns')) {
              await m.addColumn(shots, shots.coffeejackRewindTurns);
            }
            if (!shotColumns.contains('coffeejack_preinfusion_turns')) {
              await m.addColumn(shots, shots.coffeejackPreinfusionTurns);
            }
          }
          if (from < 13) {
            final shotColumns = await m.database
                .customSelect(
                  'PRAGMA table_info(shots)',
                  readsFrom: {shots},
                )
                .map((row) => row.read<String>('name'))
                .get();
            if (!shotColumns.contains('flavour_intensities')) {
              await m.addColumn(shots, shots.flavourIntensities);
            }
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