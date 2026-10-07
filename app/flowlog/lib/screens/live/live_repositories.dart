import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog_core/flowlog_core.dart';

/// Lazily opens the Flowlog database and repositories used by Live.
///
/// Injected repositories (tests) win; they are read through resolvers on
/// every call so a rebuilt widget's overrides apply. Otherwise each
/// repository is created on first use against one shared [FlowlogDatabase].
class LiveRepositories {
  LiveRepositories({
    ShotRepository? Function()? shotOverride,
    BeanRepository? Function()? beanOverride,
    ProfileRepository? Function()? profileOverride,
    Future<FlowlogDatabase> Function()? openDatabase,
  }) : _shotOverride = shotOverride ?? _none,
       _beanOverride = beanOverride ?? _none,
       _profileOverride = profileOverride ?? _none,
       _openDatabase = openDatabase ?? openFlowlogDatabase;

  static Null _none() => null;

  final ShotRepository? Function() _shotOverride;
  final BeanRepository? Function() _beanOverride;
  final ProfileRepository? Function() _profileOverride;
  final Future<FlowlogDatabase> Function() _openDatabase;

  FlowlogDatabase? _database;
  ShotRepository? _shotRepository;
  BeanRepository? _beanRepository;
  ProfileRepository? _profileRepository;

  Future<FlowlogDatabase> database() async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<BeanRepository> beans() async {
    final override = _beanOverride();
    if (override != null) {
      return override;
    }
    if (_beanRepository != null) {
      return _beanRepository!;
    }

    final db = await database();
    _beanRepository = BeanRepository(db);
    return _beanRepository!;
  }

  Future<ShotRepository> shots() async {
    final override = _shotOverride();
    if (override != null) {
      return override;
    }
    if (_shotRepository != null) {
      return _shotRepository!;
    }

    final db = await database();
    _shotRepository = ShotRepository(db);
    return _shotRepository!;
  }

  Future<ProfileRepository> profiles() async {
    final override = _profileOverride();
    if (override != null) {
      return override;
    }
    if (_profileRepository != null) {
      return _profileRepository!;
    }

    final db = await database();
    _profileRepository = ProfileRepository(db);
    return _profileRepository!;
  }
}
