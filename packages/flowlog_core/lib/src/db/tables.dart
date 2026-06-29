import 'package:drift/drift.dart';

import 'type_converters.dart';

/// Shot metadata persisted in SQLite.
@DataClassName('ShotRow')
class Shots extends Table {
  TextColumn get id => text()();
  TextColumn get startedAt =>
      text().map(const UtcIso8601Converter())();
  TextColumn get endedAt =>
      text().nullable().map(const NullableUtcIso8601Converter())();
  RealColumn get doseG => real().nullable()();
  RealColumn get yieldG => real().nullable()();
  RealColumn get grindSetting => real().nullable()();
  TextColumn get beanId => text().nullable()();
  RealColumn get waterTempC => real().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get tasteScore => integer().nullable()();
  TextColumn get flavourTags =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Coffee bean inventory entry.
@DataClassName('BeanRow')
class Beans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get origin => text().nullable()();
  TextColumn get roastLevel => text().nullable()();
  RealColumn get stockG => real().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// User-defined tag for organizing shots.
@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Many-to-many link between shots and tags.
@DataClassName('ShotTagRow')
class ShotTags extends Table {
  TextColumn get shotId =>
      text().references(Shots, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {shotId, tagId};
}

/// Chart markers (channel marks and notes) for a shot.
@DataClassName('ShotAnnotationRow')
class ShotAnnotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get shotId =>
      text().references(Shots, #id, onDelete: KeyAction.cascade)();
  IntColumn get elapsedMs => integer()();
  TextColumn get label => text()();
  TextColumn get type => text()();
}

/// Time-series samples captured during a shot.
@DataClassName('ShotSampleRow')
class ShotSamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get shotId =>
      text().references(Shots, #id, onDelete: KeyAction.cascade)();
  IntColumn get elapsedMs => integer()();
  RealColumn get pressureBar => real().nullable()();
  RealColumn get weightG => real().nullable()();
  RealColumn get flowGs => real().nullable()();
  RealColumn get tempC => real().nullable()();
}