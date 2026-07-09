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
  TextColumn get flavourIntensities =>
      text().withDefault(const Constant('{}'))();
  TextColumn get location => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get coffeejackRewindTurns => integer().nullable()();
  IntColumn get coffeejackPreinfusionTurns => integer().nullable()();
  RealColumn get autoStartPressureBar => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Coffee bean inventory entry.
@DataClassName('BeanRow')
class Beans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get origin => text().nullable()();
  TextColumn get roastLevel => text().nullable()();
  TextColumn get roastDate =>
      text().nullable().map(const NullableUtcIso8601Converter())();
  TextColumn get process => text().nullable()();
  TextColumn get variety => text().nullable()();
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

/// Saved pressure profile and metadata for repeat shots.
@DataClassName('SavedProfileRow')
class SavedProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get createdAt =>
      text().map(const UtcIso8601Converter())();
  TextColumn get sourceShotId => text().nullable()();
  RealColumn get doseG => real().nullable()();
  RealColumn get yieldG => real().nullable()();
  RealColumn get grindSetting => real().nullable()();
  TextColumn get beanId => text().nullable()();
  RealColumn get waterTempC => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Pressure curve samples for a [SavedProfiles] entry.
@DataClassName('SavedProfileSampleRow')
class SavedProfileSamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId =>
      text().references(SavedProfiles, #id, onDelete: KeyAction.cascade)();
  IntColumn get elapsedMs => integer()();
  RealColumn get pressureBar => real()();
}