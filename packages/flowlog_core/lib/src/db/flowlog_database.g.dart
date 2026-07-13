// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flowlog_database.dart';

// ignore_for_file: type=lint
class $ShotsTable extends Shots with TableInfo<$ShotsTable, ShotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> startedAt =
      GeneratedColumn<String>(
        'started_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ShotsTable.$converterstartedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> endedAt =
      GeneratedColumn<String>(
        'ended_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($ShotsTable.$converterendedAt);
  static const VerificationMeta _doseGMeta = const VerificationMeta('doseG');
  @override
  late final GeneratedColumn<double> doseG = GeneratedColumn<double>(
    'dose_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yieldGMeta = const VerificationMeta('yieldG');
  @override
  late final GeneratedColumn<double> yieldG = GeneratedColumn<double>(
    'yield_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _grindSettingMeta = const VerificationMeta(
    'grindSetting',
  );
  @override
  late final GeneratedColumn<double> grindSetting = GeneratedColumn<double>(
    'grind_setting',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _beanIdMeta = const VerificationMeta('beanId');
  @override
  late final GeneratedColumn<String> beanId = GeneratedColumn<String>(
    'bean_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _waterTempCMeta = const VerificationMeta(
    'waterTempC',
  );
  @override
  late final GeneratedColumn<double> waterTempC = GeneratedColumn<double>(
    'water_temp_c',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tasteScoreMeta = const VerificationMeta(
    'tasteScore',
  );
  @override
  late final GeneratedColumn<int> tasteScore = GeneratedColumn<int>(
    'taste_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _flavourTagsMeta = const VerificationMeta(
    'flavourTags',
  );
  @override
  late final GeneratedColumn<String> flavourTags = GeneratedColumn<String>(
    'flavour_tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _flavourIntensitiesMeta =
      const VerificationMeta('flavourIntensities');
  @override
  late final GeneratedColumn<String> flavourIntensities =
      GeneratedColumn<String>(
        'flavour_intensities',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coffeejackRewindTurnsMeta =
      const VerificationMeta('coffeejackRewindTurns');
  @override
  late final GeneratedColumn<int> coffeejackRewindTurns = GeneratedColumn<int>(
    'coffeejack_rewind_turns',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coffeejackPreinfusionTurnsMeta =
      const VerificationMeta('coffeejackPreinfusionTurns');
  @override
  late final GeneratedColumn<int> coffeejackPreinfusionTurns =
      GeneratedColumn<int>(
        'coffeejack_preinfusion_turns',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _grinderMeta = const VerificationMeta(
    'grinder',
  );
  @override
  late final GeneratedColumn<String> grinder = GeneratedColumn<String>(
    'grinder',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _showerScreenMeta = const VerificationMeta(
    'showerScreen',
  );
  @override
  late final GeneratedColumn<String> showerScreen = GeneratedColumn<String>(
    'shower_screen',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _basketMeta = const VerificationMeta('basket');
  @override
  late final GeneratedColumn<String> basket = GeneratedColumn<String>(
    'basket',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scaleMeta = const VerificationMeta('scale');
  @override
  late final GeneratedColumn<String> scale = GeneratedColumn<String>(
    'scale',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _brewerMeta = const VerificationMeta('brewer');
  @override
  late final GeneratedColumn<String> brewer = GeneratedColumn<String>(
    'brewer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String>
  lastModifiedAt = GeneratedColumn<String>(
    'last_modified_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<DateTime?>($ShotsTable.$converterlastModifiedAt);
  static const VerificationMeta _autoStartPressureBarMeta =
      const VerificationMeta('autoStartPressureBar');
  @override
  late final GeneratedColumn<double> autoStartPressureBar =
      GeneratedColumn<double>(
        'auto_start_pressure_bar',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _targetClosenessPercentMeta =
      const VerificationMeta('targetClosenessPercent');
  @override
  late final GeneratedColumn<double> targetClosenessPercent =
      GeneratedColumn<double>(
        'target_closeness_percent',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _targetMaxStreakSecondsMeta =
      const VerificationMeta('targetMaxStreakSeconds');
  @override
  late final GeneratedColumn<int> targetMaxStreakSeconds = GeneratedColumn<int>(
    'target_max_streak_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetScoreMeta = const VerificationMeta(
    'targetScore',
  );
  @override
  late final GeneratedColumn<double> targetScore = GeneratedColumn<double>(
    'target_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    doseG,
    yieldG,
    grindSetting,
    beanId,
    waterTempC,
    notes,
    tasteScore,
    flavourTags,
    flavourIntensities,
    location,
    latitude,
    longitude,
    coffeejackRewindTurns,
    coffeejackPreinfusionTurns,
    grinder,
    showerScreen,
    basket,
    scale,
    brewer,
    lastModifiedAt,
    autoStartPressureBar,
    targetClosenessPercent,
    targetMaxStreakSeconds,
    targetScore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dose_g')) {
      context.handle(
        _doseGMeta,
        doseG.isAcceptableOrUnknown(data['dose_g']!, _doseGMeta),
      );
    }
    if (data.containsKey('yield_g')) {
      context.handle(
        _yieldGMeta,
        yieldG.isAcceptableOrUnknown(data['yield_g']!, _yieldGMeta),
      );
    }
    if (data.containsKey('grind_setting')) {
      context.handle(
        _grindSettingMeta,
        grindSetting.isAcceptableOrUnknown(
          data['grind_setting']!,
          _grindSettingMeta,
        ),
      );
    }
    if (data.containsKey('bean_id')) {
      context.handle(
        _beanIdMeta,
        beanId.isAcceptableOrUnknown(data['bean_id']!, _beanIdMeta),
      );
    }
    if (data.containsKey('water_temp_c')) {
      context.handle(
        _waterTempCMeta,
        waterTempC.isAcceptableOrUnknown(
          data['water_temp_c']!,
          _waterTempCMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('taste_score')) {
      context.handle(
        _tasteScoreMeta,
        tasteScore.isAcceptableOrUnknown(data['taste_score']!, _tasteScoreMeta),
      );
    }
    if (data.containsKey('flavour_tags')) {
      context.handle(
        _flavourTagsMeta,
        flavourTags.isAcceptableOrUnknown(
          data['flavour_tags']!,
          _flavourTagsMeta,
        ),
      );
    }
    if (data.containsKey('flavour_intensities')) {
      context.handle(
        _flavourIntensitiesMeta,
        flavourIntensities.isAcceptableOrUnknown(
          data['flavour_intensities']!,
          _flavourIntensitiesMeta,
        ),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('coffeejack_rewind_turns')) {
      context.handle(
        _coffeejackRewindTurnsMeta,
        coffeejackRewindTurns.isAcceptableOrUnknown(
          data['coffeejack_rewind_turns']!,
          _coffeejackRewindTurnsMeta,
        ),
      );
    }
    if (data.containsKey('coffeejack_preinfusion_turns')) {
      context.handle(
        _coffeejackPreinfusionTurnsMeta,
        coffeejackPreinfusionTurns.isAcceptableOrUnknown(
          data['coffeejack_preinfusion_turns']!,
          _coffeejackPreinfusionTurnsMeta,
        ),
      );
    }
    if (data.containsKey('grinder')) {
      context.handle(
        _grinderMeta,
        grinder.isAcceptableOrUnknown(data['grinder']!, _grinderMeta),
      );
    }
    if (data.containsKey('shower_screen')) {
      context.handle(
        _showerScreenMeta,
        showerScreen.isAcceptableOrUnknown(
          data['shower_screen']!,
          _showerScreenMeta,
        ),
      );
    }
    if (data.containsKey('basket')) {
      context.handle(
        _basketMeta,
        basket.isAcceptableOrUnknown(data['basket']!, _basketMeta),
      );
    }
    if (data.containsKey('scale')) {
      context.handle(
        _scaleMeta,
        scale.isAcceptableOrUnknown(data['scale']!, _scaleMeta),
      );
    }
    if (data.containsKey('brewer')) {
      context.handle(
        _brewerMeta,
        brewer.isAcceptableOrUnknown(data['brewer']!, _brewerMeta),
      );
    }
    if (data.containsKey('auto_start_pressure_bar')) {
      context.handle(
        _autoStartPressureBarMeta,
        autoStartPressureBar.isAcceptableOrUnknown(
          data['auto_start_pressure_bar']!,
          _autoStartPressureBarMeta,
        ),
      );
    }
    if (data.containsKey('target_closeness_percent')) {
      context.handle(
        _targetClosenessPercentMeta,
        targetClosenessPercent.isAcceptableOrUnknown(
          data['target_closeness_percent']!,
          _targetClosenessPercentMeta,
        ),
      );
    }
    if (data.containsKey('target_max_streak_seconds')) {
      context.handle(
        _targetMaxStreakSecondsMeta,
        targetMaxStreakSeconds.isAcceptableOrUnknown(
          data['target_max_streak_seconds']!,
          _targetMaxStreakSecondsMeta,
        ),
      );
    }
    if (data.containsKey('target_score')) {
      context.handle(
        _targetScoreMeta,
        targetScore.isAcceptableOrUnknown(
          data['target_score']!,
          _targetScoreMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: $ShotsTable.$converterstartedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}started_at'],
        )!,
      ),
      endedAt: $ShotsTable.$converterendedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}ended_at'],
        ),
      ),
      doseG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dose_g'],
      ),
      yieldG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}yield_g'],
      ),
      grindSetting: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grind_setting'],
      ),
      beanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bean_id'],
      ),
      waterTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}water_temp_c'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      tasteScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}taste_score'],
      ),
      flavourTags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flavour_tags'],
      )!,
      flavourIntensities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flavour_intensities'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      coffeejackRewindTurns: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coffeejack_rewind_turns'],
      ),
      coffeejackPreinfusionTurns: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coffeejack_preinfusion_turns'],
      ),
      grinder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grinder'],
      ),
      showerScreen: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shower_screen'],
      ),
      basket: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}basket'],
      ),
      scale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scale'],
      ),
      brewer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brewer'],
      ),
      lastModifiedAt: $ShotsTable.$converterlastModifiedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}last_modified_at'],
        ),
      ),
      autoStartPressureBar: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}auto_start_pressure_bar'],
      ),
      targetClosenessPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_closeness_percent'],
      ),
      targetMaxStreakSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_max_streak_seconds'],
      ),
      targetScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_score'],
      ),
    );
  }

  @override
  $ShotsTable createAlias(String alias) {
    return $ShotsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterstartedAt =
      const UtcIso8601Converter();
  static TypeConverter<DateTime?, String?> $converterendedAt =
      const NullableUtcIso8601Converter();
  static TypeConverter<DateTime?, String?> $converterlastModifiedAt =
      const NullableUtcIso8601Converter();
}

class ShotRow extends DataClass implements Insertable<ShotRow> {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double? doseG;
  final double? yieldG;
  final double? grindSetting;
  final String? beanId;
  final double? waterTempC;
  final String? notes;
  final int? tasteScore;
  final String flavourTags;
  final String flavourIntensities;
  final String? location;
  final double? latitude;
  final double? longitude;
  final int? coffeejackRewindTurns;
  final int? coffeejackPreinfusionTurns;
  final String? grinder;
  final String? showerScreen;
  final String? basket;
  final String? scale;
  final String? brewer;
  final DateTime? lastModifiedAt;
  final double? autoStartPressureBar;
  final double? targetClosenessPercent;
  final int? targetMaxStreakSeconds;
  final double? targetScore;
  const ShotRow({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.doseG,
    this.yieldG,
    this.grindSetting,
    this.beanId,
    this.waterTempC,
    this.notes,
    this.tasteScore,
    required this.flavourTags,
    required this.flavourIntensities,
    this.location,
    this.latitude,
    this.longitude,
    this.coffeejackRewindTurns,
    this.coffeejackPreinfusionTurns,
    this.grinder,
    this.showerScreen,
    this.basket,
    this.scale,
    this.brewer,
    this.lastModifiedAt,
    this.autoStartPressureBar,
    this.targetClosenessPercent,
    this.targetMaxStreakSeconds,
    this.targetScore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['started_at'] = Variable<String>(
        $ShotsTable.$converterstartedAt.toSql(startedAt),
      );
    }
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<String>(
        $ShotsTable.$converterendedAt.toSql(endedAt),
      );
    }
    if (!nullToAbsent || doseG != null) {
      map['dose_g'] = Variable<double>(doseG);
    }
    if (!nullToAbsent || yieldG != null) {
      map['yield_g'] = Variable<double>(yieldG);
    }
    if (!nullToAbsent || grindSetting != null) {
      map['grind_setting'] = Variable<double>(grindSetting);
    }
    if (!nullToAbsent || beanId != null) {
      map['bean_id'] = Variable<String>(beanId);
    }
    if (!nullToAbsent || waterTempC != null) {
      map['water_temp_c'] = Variable<double>(waterTempC);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || tasteScore != null) {
      map['taste_score'] = Variable<int>(tasteScore);
    }
    map['flavour_tags'] = Variable<String>(flavourTags);
    map['flavour_intensities'] = Variable<String>(flavourIntensities);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || coffeejackRewindTurns != null) {
      map['coffeejack_rewind_turns'] = Variable<int>(coffeejackRewindTurns);
    }
    if (!nullToAbsent || coffeejackPreinfusionTurns != null) {
      map['coffeejack_preinfusion_turns'] = Variable<int>(
        coffeejackPreinfusionTurns,
      );
    }
    if (!nullToAbsent || grinder != null) {
      map['grinder'] = Variable<String>(grinder);
    }
    if (!nullToAbsent || showerScreen != null) {
      map['shower_screen'] = Variable<String>(showerScreen);
    }
    if (!nullToAbsent || basket != null) {
      map['basket'] = Variable<String>(basket);
    }
    if (!nullToAbsent || scale != null) {
      map['scale'] = Variable<String>(scale);
    }
    if (!nullToAbsent || brewer != null) {
      map['brewer'] = Variable<String>(brewer);
    }
    if (!nullToAbsent || lastModifiedAt != null) {
      map['last_modified_at'] = Variable<String>(
        $ShotsTable.$converterlastModifiedAt.toSql(lastModifiedAt),
      );
    }
    if (!nullToAbsent || autoStartPressureBar != null) {
      map['auto_start_pressure_bar'] = Variable<double>(autoStartPressureBar);
    }
    if (!nullToAbsent || targetClosenessPercent != null) {
      map['target_closeness_percent'] = Variable<double>(
        targetClosenessPercent,
      );
    }
    if (!nullToAbsent || targetMaxStreakSeconds != null) {
      map['target_max_streak_seconds'] = Variable<int>(targetMaxStreakSeconds);
    }
    if (!nullToAbsent || targetScore != null) {
      map['target_score'] = Variable<double>(targetScore);
    }
    return map;
  }

  ShotsCompanion toCompanion(bool nullToAbsent) {
    return ShotsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      doseG: doseG == null && nullToAbsent
          ? const Value.absent()
          : Value(doseG),
      yieldG: yieldG == null && nullToAbsent
          ? const Value.absent()
          : Value(yieldG),
      grindSetting: grindSetting == null && nullToAbsent
          ? const Value.absent()
          : Value(grindSetting),
      beanId: beanId == null && nullToAbsent
          ? const Value.absent()
          : Value(beanId),
      waterTempC: waterTempC == null && nullToAbsent
          ? const Value.absent()
          : Value(waterTempC),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      tasteScore: tasteScore == null && nullToAbsent
          ? const Value.absent()
          : Value(tasteScore),
      flavourTags: Value(flavourTags),
      flavourIntensities: Value(flavourIntensities),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      coffeejackRewindTurns: coffeejackRewindTurns == null && nullToAbsent
          ? const Value.absent()
          : Value(coffeejackRewindTurns),
      coffeejackPreinfusionTurns:
          coffeejackPreinfusionTurns == null && nullToAbsent
          ? const Value.absent()
          : Value(coffeejackPreinfusionTurns),
      grinder: grinder == null && nullToAbsent
          ? const Value.absent()
          : Value(grinder),
      showerScreen: showerScreen == null && nullToAbsent
          ? const Value.absent()
          : Value(showerScreen),
      basket: basket == null && nullToAbsent
          ? const Value.absent()
          : Value(basket),
      scale: scale == null && nullToAbsent
          ? const Value.absent()
          : Value(scale),
      brewer: brewer == null && nullToAbsent
          ? const Value.absent()
          : Value(brewer),
      lastModifiedAt: lastModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedAt),
      autoStartPressureBar: autoStartPressureBar == null && nullToAbsent
          ? const Value.absent()
          : Value(autoStartPressureBar),
      targetClosenessPercent: targetClosenessPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(targetClosenessPercent),
      targetMaxStreakSeconds: targetMaxStreakSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(targetMaxStreakSeconds),
      targetScore: targetScore == null && nullToAbsent
          ? const Value.absent()
          : Value(targetScore),
    );
  }

  factory ShotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShotRow(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      doseG: serializer.fromJson<double?>(json['doseG']),
      yieldG: serializer.fromJson<double?>(json['yieldG']),
      grindSetting: serializer.fromJson<double?>(json['grindSetting']),
      beanId: serializer.fromJson<String?>(json['beanId']),
      waterTempC: serializer.fromJson<double?>(json['waterTempC']),
      notes: serializer.fromJson<String?>(json['notes']),
      tasteScore: serializer.fromJson<int?>(json['tasteScore']),
      flavourTags: serializer.fromJson<String>(json['flavourTags']),
      flavourIntensities: serializer.fromJson<String>(
        json['flavourIntensities'],
      ),
      location: serializer.fromJson<String?>(json['location']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      coffeejackRewindTurns: serializer.fromJson<int?>(
        json['coffeejackRewindTurns'],
      ),
      coffeejackPreinfusionTurns: serializer.fromJson<int?>(
        json['coffeejackPreinfusionTurns'],
      ),
      grinder: serializer.fromJson<String?>(json['grinder']),
      showerScreen: serializer.fromJson<String?>(json['showerScreen']),
      basket: serializer.fromJson<String?>(json['basket']),
      scale: serializer.fromJson<String?>(json['scale']),
      brewer: serializer.fromJson<String?>(json['brewer']),
      lastModifiedAt: serializer.fromJson<DateTime?>(json['lastModifiedAt']),
      autoStartPressureBar: serializer.fromJson<double?>(
        json['autoStartPressureBar'],
      ),
      targetClosenessPercent: serializer.fromJson<double?>(
        json['targetClosenessPercent'],
      ),
      targetMaxStreakSeconds: serializer.fromJson<int?>(
        json['targetMaxStreakSeconds'],
      ),
      targetScore: serializer.fromJson<double?>(json['targetScore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'doseG': serializer.toJson<double?>(doseG),
      'yieldG': serializer.toJson<double?>(yieldG),
      'grindSetting': serializer.toJson<double?>(grindSetting),
      'beanId': serializer.toJson<String?>(beanId),
      'waterTempC': serializer.toJson<double?>(waterTempC),
      'notes': serializer.toJson<String?>(notes),
      'tasteScore': serializer.toJson<int?>(tasteScore),
      'flavourTags': serializer.toJson<String>(flavourTags),
      'flavourIntensities': serializer.toJson<String>(flavourIntensities),
      'location': serializer.toJson<String?>(location),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'coffeejackRewindTurns': serializer.toJson<int?>(coffeejackRewindTurns),
      'coffeejackPreinfusionTurns': serializer.toJson<int?>(
        coffeejackPreinfusionTurns,
      ),
      'grinder': serializer.toJson<String?>(grinder),
      'showerScreen': serializer.toJson<String?>(showerScreen),
      'basket': serializer.toJson<String?>(basket),
      'scale': serializer.toJson<String?>(scale),
      'brewer': serializer.toJson<String?>(brewer),
      'lastModifiedAt': serializer.toJson<DateTime?>(lastModifiedAt),
      'autoStartPressureBar': serializer.toJson<double?>(autoStartPressureBar),
      'targetClosenessPercent': serializer.toJson<double?>(
        targetClosenessPercent,
      ),
      'targetMaxStreakSeconds': serializer.toJson<int?>(targetMaxStreakSeconds),
      'targetScore': serializer.toJson<double?>(targetScore),
    };
  }

  ShotRow copyWith({
    String? id,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<double?> doseG = const Value.absent(),
    Value<double?> yieldG = const Value.absent(),
    Value<double?> grindSetting = const Value.absent(),
    Value<String?> beanId = const Value.absent(),
    Value<double?> waterTempC = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<int?> tasteScore = const Value.absent(),
    String? flavourTags,
    String? flavourIntensities,
    Value<String?> location = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<int?> coffeejackRewindTurns = const Value.absent(),
    Value<int?> coffeejackPreinfusionTurns = const Value.absent(),
    Value<String?> grinder = const Value.absent(),
    Value<String?> showerScreen = const Value.absent(),
    Value<String?> basket = const Value.absent(),
    Value<String?> scale = const Value.absent(),
    Value<String?> brewer = const Value.absent(),
    Value<DateTime?> lastModifiedAt = const Value.absent(),
    Value<double?> autoStartPressureBar = const Value.absent(),
    Value<double?> targetClosenessPercent = const Value.absent(),
    Value<int?> targetMaxStreakSeconds = const Value.absent(),
    Value<double?> targetScore = const Value.absent(),
  }) => ShotRow(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    doseG: doseG.present ? doseG.value : this.doseG,
    yieldG: yieldG.present ? yieldG.value : this.yieldG,
    grindSetting: grindSetting.present ? grindSetting.value : this.grindSetting,
    beanId: beanId.present ? beanId.value : this.beanId,
    waterTempC: waterTempC.present ? waterTempC.value : this.waterTempC,
    notes: notes.present ? notes.value : this.notes,
    tasteScore: tasteScore.present ? tasteScore.value : this.tasteScore,
    flavourTags: flavourTags ?? this.flavourTags,
    flavourIntensities: flavourIntensities ?? this.flavourIntensities,
    location: location.present ? location.value : this.location,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    coffeejackRewindTurns: coffeejackRewindTurns.present
        ? coffeejackRewindTurns.value
        : this.coffeejackRewindTurns,
    coffeejackPreinfusionTurns: coffeejackPreinfusionTurns.present
        ? coffeejackPreinfusionTurns.value
        : this.coffeejackPreinfusionTurns,
    grinder: grinder.present ? grinder.value : this.grinder,
    showerScreen: showerScreen.present ? showerScreen.value : this.showerScreen,
    basket: basket.present ? basket.value : this.basket,
    scale: scale.present ? scale.value : this.scale,
    brewer: brewer.present ? brewer.value : this.brewer,
    lastModifiedAt: lastModifiedAt.present
        ? lastModifiedAt.value
        : this.lastModifiedAt,
    autoStartPressureBar: autoStartPressureBar.present
        ? autoStartPressureBar.value
        : this.autoStartPressureBar,
    targetClosenessPercent: targetClosenessPercent.present
        ? targetClosenessPercent.value
        : this.targetClosenessPercent,
    targetMaxStreakSeconds: targetMaxStreakSeconds.present
        ? targetMaxStreakSeconds.value
        : this.targetMaxStreakSeconds,
    targetScore: targetScore.present ? targetScore.value : this.targetScore,
  );
  ShotRow copyWithCompanion(ShotsCompanion data) {
    return ShotRow(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      doseG: data.doseG.present ? data.doseG.value : this.doseG,
      yieldG: data.yieldG.present ? data.yieldG.value : this.yieldG,
      grindSetting: data.grindSetting.present
          ? data.grindSetting.value
          : this.grindSetting,
      beanId: data.beanId.present ? data.beanId.value : this.beanId,
      waterTempC: data.waterTempC.present
          ? data.waterTempC.value
          : this.waterTempC,
      notes: data.notes.present ? data.notes.value : this.notes,
      tasteScore: data.tasteScore.present
          ? data.tasteScore.value
          : this.tasteScore,
      flavourTags: data.flavourTags.present
          ? data.flavourTags.value
          : this.flavourTags,
      flavourIntensities: data.flavourIntensities.present
          ? data.flavourIntensities.value
          : this.flavourIntensities,
      location: data.location.present ? data.location.value : this.location,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      coffeejackRewindTurns: data.coffeejackRewindTurns.present
          ? data.coffeejackRewindTurns.value
          : this.coffeejackRewindTurns,
      coffeejackPreinfusionTurns: data.coffeejackPreinfusionTurns.present
          ? data.coffeejackPreinfusionTurns.value
          : this.coffeejackPreinfusionTurns,
      grinder: data.grinder.present ? data.grinder.value : this.grinder,
      showerScreen: data.showerScreen.present
          ? data.showerScreen.value
          : this.showerScreen,
      basket: data.basket.present ? data.basket.value : this.basket,
      scale: data.scale.present ? data.scale.value : this.scale,
      brewer: data.brewer.present ? data.brewer.value : this.brewer,
      lastModifiedAt: data.lastModifiedAt.present
          ? data.lastModifiedAt.value
          : this.lastModifiedAt,
      autoStartPressureBar: data.autoStartPressureBar.present
          ? data.autoStartPressureBar.value
          : this.autoStartPressureBar,
      targetClosenessPercent: data.targetClosenessPercent.present
          ? data.targetClosenessPercent.value
          : this.targetClosenessPercent,
      targetMaxStreakSeconds: data.targetMaxStreakSeconds.present
          ? data.targetMaxStreakSeconds.value
          : this.targetMaxStreakSeconds,
      targetScore: data.targetScore.present
          ? data.targetScore.value
          : this.targetScore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShotRow(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('doseG: $doseG, ')
          ..write('yieldG: $yieldG, ')
          ..write('grindSetting: $grindSetting, ')
          ..write('beanId: $beanId, ')
          ..write('waterTempC: $waterTempC, ')
          ..write('notes: $notes, ')
          ..write('tasteScore: $tasteScore, ')
          ..write('flavourTags: $flavourTags, ')
          ..write('flavourIntensities: $flavourIntensities, ')
          ..write('location: $location, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('coffeejackRewindTurns: $coffeejackRewindTurns, ')
          ..write('coffeejackPreinfusionTurns: $coffeejackPreinfusionTurns, ')
          ..write('grinder: $grinder, ')
          ..write('showerScreen: $showerScreen, ')
          ..write('basket: $basket, ')
          ..write('scale: $scale, ')
          ..write('brewer: $brewer, ')
          ..write('lastModifiedAt: $lastModifiedAt, ')
          ..write('autoStartPressureBar: $autoStartPressureBar, ')
          ..write('targetClosenessPercent: $targetClosenessPercent, ')
          ..write('targetMaxStreakSeconds: $targetMaxStreakSeconds, ')
          ..write('targetScore: $targetScore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    startedAt,
    endedAt,
    doseG,
    yieldG,
    grindSetting,
    beanId,
    waterTempC,
    notes,
    tasteScore,
    flavourTags,
    flavourIntensities,
    location,
    latitude,
    longitude,
    coffeejackRewindTurns,
    coffeejackPreinfusionTurns,
    grinder,
    showerScreen,
    basket,
    scale,
    brewer,
    lastModifiedAt,
    autoStartPressureBar,
    targetClosenessPercent,
    targetMaxStreakSeconds,
    targetScore,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShotRow &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.doseG == this.doseG &&
          other.yieldG == this.yieldG &&
          other.grindSetting == this.grindSetting &&
          other.beanId == this.beanId &&
          other.waterTempC == this.waterTempC &&
          other.notes == this.notes &&
          other.tasteScore == this.tasteScore &&
          other.flavourTags == this.flavourTags &&
          other.flavourIntensities == this.flavourIntensities &&
          other.location == this.location &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.coffeejackRewindTurns == this.coffeejackRewindTurns &&
          other.coffeejackPreinfusionTurns == this.coffeejackPreinfusionTurns &&
          other.grinder == this.grinder &&
          other.showerScreen == this.showerScreen &&
          other.basket == this.basket &&
          other.scale == this.scale &&
          other.brewer == this.brewer &&
          other.lastModifiedAt == this.lastModifiedAt &&
          other.autoStartPressureBar == this.autoStartPressureBar &&
          other.targetClosenessPercent == this.targetClosenessPercent &&
          other.targetMaxStreakSeconds == this.targetMaxStreakSeconds &&
          other.targetScore == this.targetScore);
}

class ShotsCompanion extends UpdateCompanion<ShotRow> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<double?> doseG;
  final Value<double?> yieldG;
  final Value<double?> grindSetting;
  final Value<String?> beanId;
  final Value<double?> waterTempC;
  final Value<String?> notes;
  final Value<int?> tasteScore;
  final Value<String> flavourTags;
  final Value<String> flavourIntensities;
  final Value<String?> location;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<int?> coffeejackRewindTurns;
  final Value<int?> coffeejackPreinfusionTurns;
  final Value<String?> grinder;
  final Value<String?> showerScreen;
  final Value<String?> basket;
  final Value<String?> scale;
  final Value<String?> brewer;
  final Value<DateTime?> lastModifiedAt;
  final Value<double?> autoStartPressureBar;
  final Value<double?> targetClosenessPercent;
  final Value<int?> targetMaxStreakSeconds;
  final Value<double?> targetScore;
  final Value<int> rowid;
  const ShotsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.doseG = const Value.absent(),
    this.yieldG = const Value.absent(),
    this.grindSetting = const Value.absent(),
    this.beanId = const Value.absent(),
    this.waterTempC = const Value.absent(),
    this.notes = const Value.absent(),
    this.tasteScore = const Value.absent(),
    this.flavourTags = const Value.absent(),
    this.flavourIntensities = const Value.absent(),
    this.location = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.coffeejackRewindTurns = const Value.absent(),
    this.coffeejackPreinfusionTurns = const Value.absent(),
    this.grinder = const Value.absent(),
    this.showerScreen = const Value.absent(),
    this.basket = const Value.absent(),
    this.scale = const Value.absent(),
    this.brewer = const Value.absent(),
    this.lastModifiedAt = const Value.absent(),
    this.autoStartPressureBar = const Value.absent(),
    this.targetClosenessPercent = const Value.absent(),
    this.targetMaxStreakSeconds = const Value.absent(),
    this.targetScore = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShotsCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.doseG = const Value.absent(),
    this.yieldG = const Value.absent(),
    this.grindSetting = const Value.absent(),
    this.beanId = const Value.absent(),
    this.waterTempC = const Value.absent(),
    this.notes = const Value.absent(),
    this.tasteScore = const Value.absent(),
    this.flavourTags = const Value.absent(),
    this.flavourIntensities = const Value.absent(),
    this.location = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.coffeejackRewindTurns = const Value.absent(),
    this.coffeejackPreinfusionTurns = const Value.absent(),
    this.grinder = const Value.absent(),
    this.showerScreen = const Value.absent(),
    this.basket = const Value.absent(),
    this.scale = const Value.absent(),
    this.brewer = const Value.absent(),
    this.lastModifiedAt = const Value.absent(),
    this.autoStartPressureBar = const Value.absent(),
    this.targetClosenessPercent = const Value.absent(),
    this.targetMaxStreakSeconds = const Value.absent(),
    this.targetScore = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt);
  static Insertable<ShotRow> custom({
    Expression<String>? id,
    Expression<String>? startedAt,
    Expression<String>? endedAt,
    Expression<double>? doseG,
    Expression<double>? yieldG,
    Expression<double>? grindSetting,
    Expression<String>? beanId,
    Expression<double>? waterTempC,
    Expression<String>? notes,
    Expression<int>? tasteScore,
    Expression<String>? flavourTags,
    Expression<String>? flavourIntensities,
    Expression<String>? location,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? coffeejackRewindTurns,
    Expression<int>? coffeejackPreinfusionTurns,
    Expression<String>? grinder,
    Expression<String>? showerScreen,
    Expression<String>? basket,
    Expression<String>? scale,
    Expression<String>? brewer,
    Expression<String>? lastModifiedAt,
    Expression<double>? autoStartPressureBar,
    Expression<double>? targetClosenessPercent,
    Expression<int>? targetMaxStreakSeconds,
    Expression<double>? targetScore,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (doseG != null) 'dose_g': doseG,
      if (yieldG != null) 'yield_g': yieldG,
      if (grindSetting != null) 'grind_setting': grindSetting,
      if (beanId != null) 'bean_id': beanId,
      if (waterTempC != null) 'water_temp_c': waterTempC,
      if (notes != null) 'notes': notes,
      if (tasteScore != null) 'taste_score': tasteScore,
      if (flavourTags != null) 'flavour_tags': flavourTags,
      if (flavourIntensities != null) 'flavour_intensities': flavourIntensities,
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (coffeejackRewindTurns != null)
        'coffeejack_rewind_turns': coffeejackRewindTurns,
      if (coffeejackPreinfusionTurns != null)
        'coffeejack_preinfusion_turns': coffeejackPreinfusionTurns,
      if (grinder != null) 'grinder': grinder,
      if (showerScreen != null) 'shower_screen': showerScreen,
      if (basket != null) 'basket': basket,
      if (scale != null) 'scale': scale,
      if (brewer != null) 'brewer': brewer,
      if (lastModifiedAt != null) 'last_modified_at': lastModifiedAt,
      if (autoStartPressureBar != null)
        'auto_start_pressure_bar': autoStartPressureBar,
      if (targetClosenessPercent != null)
        'target_closeness_percent': targetClosenessPercent,
      if (targetMaxStreakSeconds != null)
        'target_max_streak_seconds': targetMaxStreakSeconds,
      if (targetScore != null) 'target_score': targetScore,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShotsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<double?>? doseG,
    Value<double?>? yieldG,
    Value<double?>? grindSetting,
    Value<String?>? beanId,
    Value<double?>? waterTempC,
    Value<String?>? notes,
    Value<int?>? tasteScore,
    Value<String>? flavourTags,
    Value<String>? flavourIntensities,
    Value<String?>? location,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<int?>? coffeejackRewindTurns,
    Value<int?>? coffeejackPreinfusionTurns,
    Value<String?>? grinder,
    Value<String?>? showerScreen,
    Value<String?>? basket,
    Value<String?>? scale,
    Value<String?>? brewer,
    Value<DateTime?>? lastModifiedAt,
    Value<double?>? autoStartPressureBar,
    Value<double?>? targetClosenessPercent,
    Value<int?>? targetMaxStreakSeconds,
    Value<double?>? targetScore,
    Value<int>? rowid,
  }) {
    return ShotsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      doseG: doseG ?? this.doseG,
      yieldG: yieldG ?? this.yieldG,
      grindSetting: grindSetting ?? this.grindSetting,
      beanId: beanId ?? this.beanId,
      waterTempC: waterTempC ?? this.waterTempC,
      notes: notes ?? this.notes,
      tasteScore: tasteScore ?? this.tasteScore,
      flavourTags: flavourTags ?? this.flavourTags,
      flavourIntensities: flavourIntensities ?? this.flavourIntensities,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      coffeejackRewindTurns:
          coffeejackRewindTurns ?? this.coffeejackRewindTurns,
      coffeejackPreinfusionTurns:
          coffeejackPreinfusionTurns ?? this.coffeejackPreinfusionTurns,
      grinder: grinder ?? this.grinder,
      showerScreen: showerScreen ?? this.showerScreen,
      basket: basket ?? this.basket,
      scale: scale ?? this.scale,
      brewer: brewer ?? this.brewer,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      autoStartPressureBar: autoStartPressureBar ?? this.autoStartPressureBar,
      targetClosenessPercent:
          targetClosenessPercent ?? this.targetClosenessPercent,
      targetMaxStreakSeconds:
          targetMaxStreakSeconds ?? this.targetMaxStreakSeconds,
      targetScore: targetScore ?? this.targetScore,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(
        $ShotsTable.$converterstartedAt.toSql(startedAt.value),
      );
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<String>(
        $ShotsTable.$converterendedAt.toSql(endedAt.value),
      );
    }
    if (doseG.present) {
      map['dose_g'] = Variable<double>(doseG.value);
    }
    if (yieldG.present) {
      map['yield_g'] = Variable<double>(yieldG.value);
    }
    if (grindSetting.present) {
      map['grind_setting'] = Variable<double>(grindSetting.value);
    }
    if (beanId.present) {
      map['bean_id'] = Variable<String>(beanId.value);
    }
    if (waterTempC.present) {
      map['water_temp_c'] = Variable<double>(waterTempC.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (tasteScore.present) {
      map['taste_score'] = Variable<int>(tasteScore.value);
    }
    if (flavourTags.present) {
      map['flavour_tags'] = Variable<String>(flavourTags.value);
    }
    if (flavourIntensities.present) {
      map['flavour_intensities'] = Variable<String>(flavourIntensities.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (coffeejackRewindTurns.present) {
      map['coffeejack_rewind_turns'] = Variable<int>(
        coffeejackRewindTurns.value,
      );
    }
    if (coffeejackPreinfusionTurns.present) {
      map['coffeejack_preinfusion_turns'] = Variable<int>(
        coffeejackPreinfusionTurns.value,
      );
    }
    if (grinder.present) {
      map['grinder'] = Variable<String>(grinder.value);
    }
    if (showerScreen.present) {
      map['shower_screen'] = Variable<String>(showerScreen.value);
    }
    if (basket.present) {
      map['basket'] = Variable<String>(basket.value);
    }
    if (scale.present) {
      map['scale'] = Variable<String>(scale.value);
    }
    if (brewer.present) {
      map['brewer'] = Variable<String>(brewer.value);
    }
    if (lastModifiedAt.present) {
      map['last_modified_at'] = Variable<String>(
        $ShotsTable.$converterlastModifiedAt.toSql(lastModifiedAt.value),
      );
    }
    if (autoStartPressureBar.present) {
      map['auto_start_pressure_bar'] = Variable<double>(
        autoStartPressureBar.value,
      );
    }
    if (targetClosenessPercent.present) {
      map['target_closeness_percent'] = Variable<double>(
        targetClosenessPercent.value,
      );
    }
    if (targetMaxStreakSeconds.present) {
      map['target_max_streak_seconds'] = Variable<int>(
        targetMaxStreakSeconds.value,
      );
    }
    if (targetScore.present) {
      map['target_score'] = Variable<double>(targetScore.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShotsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('doseG: $doseG, ')
          ..write('yieldG: $yieldG, ')
          ..write('grindSetting: $grindSetting, ')
          ..write('beanId: $beanId, ')
          ..write('waterTempC: $waterTempC, ')
          ..write('notes: $notes, ')
          ..write('tasteScore: $tasteScore, ')
          ..write('flavourTags: $flavourTags, ')
          ..write('flavourIntensities: $flavourIntensities, ')
          ..write('location: $location, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('coffeejackRewindTurns: $coffeejackRewindTurns, ')
          ..write('coffeejackPreinfusionTurns: $coffeejackPreinfusionTurns, ')
          ..write('grinder: $grinder, ')
          ..write('showerScreen: $showerScreen, ')
          ..write('basket: $basket, ')
          ..write('scale: $scale, ')
          ..write('brewer: $brewer, ')
          ..write('lastModifiedAt: $lastModifiedAt, ')
          ..write('autoStartPressureBar: $autoStartPressureBar, ')
          ..write('targetClosenessPercent: $targetClosenessPercent, ')
          ..write('targetMaxStreakSeconds: $targetMaxStreakSeconds, ')
          ..write('targetScore: $targetScore, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShotSamplesTable extends ShotSamples
    with TableInfo<$ShotSamplesTable, ShotSampleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShotSamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _shotIdMeta = const VerificationMeta('shotId');
  @override
  late final GeneratedColumn<String> shotId = GeneratedColumn<String>(
    'shot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shots (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _elapsedMsMeta = const VerificationMeta(
    'elapsedMs',
  );
  @override
  late final GeneratedColumn<int> elapsedMs = GeneratedColumn<int>(
    'elapsed_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pressureBarMeta = const VerificationMeta(
    'pressureBar',
  );
  @override
  late final GeneratedColumn<double> pressureBar = GeneratedColumn<double>(
    'pressure_bar',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightGMeta = const VerificationMeta(
    'weightG',
  );
  @override
  late final GeneratedColumn<double> weightG = GeneratedColumn<double>(
    'weight_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _flowGsMeta = const VerificationMeta('flowGs');
  @override
  late final GeneratedColumn<double> flowGs = GeneratedColumn<double>(
    'flow_gs',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tempCMeta = const VerificationMeta('tempC');
  @override
  late final GeneratedColumn<double> tempC = GeneratedColumn<double>(
    'temp_c',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shotId,
    elapsedMs,
    pressureBar,
    weightG,
    flowGs,
    tempC,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shot_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShotSampleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('shot_id')) {
      context.handle(
        _shotIdMeta,
        shotId.isAcceptableOrUnknown(data['shot_id']!, _shotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shotIdMeta);
    }
    if (data.containsKey('elapsed_ms')) {
      context.handle(
        _elapsedMsMeta,
        elapsedMs.isAcceptableOrUnknown(data['elapsed_ms']!, _elapsedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_elapsedMsMeta);
    }
    if (data.containsKey('pressure_bar')) {
      context.handle(
        _pressureBarMeta,
        pressureBar.isAcceptableOrUnknown(
          data['pressure_bar']!,
          _pressureBarMeta,
        ),
      );
    }
    if (data.containsKey('weight_g')) {
      context.handle(
        _weightGMeta,
        weightG.isAcceptableOrUnknown(data['weight_g']!, _weightGMeta),
      );
    }
    if (data.containsKey('flow_gs')) {
      context.handle(
        _flowGsMeta,
        flowGs.isAcceptableOrUnknown(data['flow_gs']!, _flowGsMeta),
      );
    }
    if (data.containsKey('temp_c')) {
      context.handle(
        _tempCMeta,
        tempC.isAcceptableOrUnknown(data['temp_c']!, _tempCMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShotSampleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShotSampleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      shotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shot_id'],
      )!,
      elapsedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_ms'],
      )!,
      pressureBar: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pressure_bar'],
      ),
      weightG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_g'],
      ),
      flowGs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}flow_gs'],
      ),
      tempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temp_c'],
      ),
    );
  }

  @override
  $ShotSamplesTable createAlias(String alias) {
    return $ShotSamplesTable(attachedDatabase, alias);
  }
}

class ShotSampleRow extends DataClass implements Insertable<ShotSampleRow> {
  final int id;
  final String shotId;
  final int elapsedMs;
  final double? pressureBar;
  final double? weightG;
  final double? flowGs;
  final double? tempC;
  const ShotSampleRow({
    required this.id,
    required this.shotId,
    required this.elapsedMs,
    this.pressureBar,
    this.weightG,
    this.flowGs,
    this.tempC,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['shot_id'] = Variable<String>(shotId);
    map['elapsed_ms'] = Variable<int>(elapsedMs);
    if (!nullToAbsent || pressureBar != null) {
      map['pressure_bar'] = Variable<double>(pressureBar);
    }
    if (!nullToAbsent || weightG != null) {
      map['weight_g'] = Variable<double>(weightG);
    }
    if (!nullToAbsent || flowGs != null) {
      map['flow_gs'] = Variable<double>(flowGs);
    }
    if (!nullToAbsent || tempC != null) {
      map['temp_c'] = Variable<double>(tempC);
    }
    return map;
  }

  ShotSamplesCompanion toCompanion(bool nullToAbsent) {
    return ShotSamplesCompanion(
      id: Value(id),
      shotId: Value(shotId),
      elapsedMs: Value(elapsedMs),
      pressureBar: pressureBar == null && nullToAbsent
          ? const Value.absent()
          : Value(pressureBar),
      weightG: weightG == null && nullToAbsent
          ? const Value.absent()
          : Value(weightG),
      flowGs: flowGs == null && nullToAbsent
          ? const Value.absent()
          : Value(flowGs),
      tempC: tempC == null && nullToAbsent
          ? const Value.absent()
          : Value(tempC),
    );
  }

  factory ShotSampleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShotSampleRow(
      id: serializer.fromJson<int>(json['id']),
      shotId: serializer.fromJson<String>(json['shotId']),
      elapsedMs: serializer.fromJson<int>(json['elapsedMs']),
      pressureBar: serializer.fromJson<double?>(json['pressureBar']),
      weightG: serializer.fromJson<double?>(json['weightG']),
      flowGs: serializer.fromJson<double?>(json['flowGs']),
      tempC: serializer.fromJson<double?>(json['tempC']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'shotId': serializer.toJson<String>(shotId),
      'elapsedMs': serializer.toJson<int>(elapsedMs),
      'pressureBar': serializer.toJson<double?>(pressureBar),
      'weightG': serializer.toJson<double?>(weightG),
      'flowGs': serializer.toJson<double?>(flowGs),
      'tempC': serializer.toJson<double?>(tempC),
    };
  }

  ShotSampleRow copyWith({
    int? id,
    String? shotId,
    int? elapsedMs,
    Value<double?> pressureBar = const Value.absent(),
    Value<double?> weightG = const Value.absent(),
    Value<double?> flowGs = const Value.absent(),
    Value<double?> tempC = const Value.absent(),
  }) => ShotSampleRow(
    id: id ?? this.id,
    shotId: shotId ?? this.shotId,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    pressureBar: pressureBar.present ? pressureBar.value : this.pressureBar,
    weightG: weightG.present ? weightG.value : this.weightG,
    flowGs: flowGs.present ? flowGs.value : this.flowGs,
    tempC: tempC.present ? tempC.value : this.tempC,
  );
  ShotSampleRow copyWithCompanion(ShotSamplesCompanion data) {
    return ShotSampleRow(
      id: data.id.present ? data.id.value : this.id,
      shotId: data.shotId.present ? data.shotId.value : this.shotId,
      elapsedMs: data.elapsedMs.present ? data.elapsedMs.value : this.elapsedMs,
      pressureBar: data.pressureBar.present
          ? data.pressureBar.value
          : this.pressureBar,
      weightG: data.weightG.present ? data.weightG.value : this.weightG,
      flowGs: data.flowGs.present ? data.flowGs.value : this.flowGs,
      tempC: data.tempC.present ? data.tempC.value : this.tempC,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShotSampleRow(')
          ..write('id: $id, ')
          ..write('shotId: $shotId, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('pressureBar: $pressureBar, ')
          ..write('weightG: $weightG, ')
          ..write('flowGs: $flowGs, ')
          ..write('tempC: $tempC')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, shotId, elapsedMs, pressureBar, weightG, flowGs, tempC);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShotSampleRow &&
          other.id == this.id &&
          other.shotId == this.shotId &&
          other.elapsedMs == this.elapsedMs &&
          other.pressureBar == this.pressureBar &&
          other.weightG == this.weightG &&
          other.flowGs == this.flowGs &&
          other.tempC == this.tempC);
}

class ShotSamplesCompanion extends UpdateCompanion<ShotSampleRow> {
  final Value<int> id;
  final Value<String> shotId;
  final Value<int> elapsedMs;
  final Value<double?> pressureBar;
  final Value<double?> weightG;
  final Value<double?> flowGs;
  final Value<double?> tempC;
  const ShotSamplesCompanion({
    this.id = const Value.absent(),
    this.shotId = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.pressureBar = const Value.absent(),
    this.weightG = const Value.absent(),
    this.flowGs = const Value.absent(),
    this.tempC = const Value.absent(),
  });
  ShotSamplesCompanion.insert({
    this.id = const Value.absent(),
    required String shotId,
    required int elapsedMs,
    this.pressureBar = const Value.absent(),
    this.weightG = const Value.absent(),
    this.flowGs = const Value.absent(),
    this.tempC = const Value.absent(),
  }) : shotId = Value(shotId),
       elapsedMs = Value(elapsedMs);
  static Insertable<ShotSampleRow> custom({
    Expression<int>? id,
    Expression<String>? shotId,
    Expression<int>? elapsedMs,
    Expression<double>? pressureBar,
    Expression<double>? weightG,
    Expression<double>? flowGs,
    Expression<double>? tempC,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shotId != null) 'shot_id': shotId,
      if (elapsedMs != null) 'elapsed_ms': elapsedMs,
      if (pressureBar != null) 'pressure_bar': pressureBar,
      if (weightG != null) 'weight_g': weightG,
      if (flowGs != null) 'flow_gs': flowGs,
      if (tempC != null) 'temp_c': tempC,
    });
  }

  ShotSamplesCompanion copyWith({
    Value<int>? id,
    Value<String>? shotId,
    Value<int>? elapsedMs,
    Value<double?>? pressureBar,
    Value<double?>? weightG,
    Value<double?>? flowGs,
    Value<double?>? tempC,
  }) {
    return ShotSamplesCompanion(
      id: id ?? this.id,
      shotId: shotId ?? this.shotId,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      pressureBar: pressureBar ?? this.pressureBar,
      weightG: weightG ?? this.weightG,
      flowGs: flowGs ?? this.flowGs,
      tempC: tempC ?? this.tempC,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (shotId.present) {
      map['shot_id'] = Variable<String>(shotId.value);
    }
    if (elapsedMs.present) {
      map['elapsed_ms'] = Variable<int>(elapsedMs.value);
    }
    if (pressureBar.present) {
      map['pressure_bar'] = Variable<double>(pressureBar.value);
    }
    if (weightG.present) {
      map['weight_g'] = Variable<double>(weightG.value);
    }
    if (flowGs.present) {
      map['flow_gs'] = Variable<double>(flowGs.value);
    }
    if (tempC.present) {
      map['temp_c'] = Variable<double>(tempC.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShotSamplesCompanion(')
          ..write('id: $id, ')
          ..write('shotId: $shotId, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('pressureBar: $pressureBar, ')
          ..write('weightG: $weightG, ')
          ..write('flowGs: $flowGs, ')
          ..write('tempC: $tempC')
          ..write(')'))
        .toString();
  }
}

class $ShotAnnotationsTable extends ShotAnnotations
    with TableInfo<$ShotAnnotationsTable, ShotAnnotationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShotAnnotationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _shotIdMeta = const VerificationMeta('shotId');
  @override
  late final GeneratedColumn<String> shotId = GeneratedColumn<String>(
    'shot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shots (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _elapsedMsMeta = const VerificationMeta(
    'elapsedMs',
  );
  @override
  late final GeneratedColumn<int> elapsedMs = GeneratedColumn<int>(
    'elapsed_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, shotId, elapsedMs, label, type];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shot_annotations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShotAnnotationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('shot_id')) {
      context.handle(
        _shotIdMeta,
        shotId.isAcceptableOrUnknown(data['shot_id']!, _shotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shotIdMeta);
    }
    if (data.containsKey('elapsed_ms')) {
      context.handle(
        _elapsedMsMeta,
        elapsedMs.isAcceptableOrUnknown(data['elapsed_ms']!, _elapsedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_elapsedMsMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShotAnnotationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShotAnnotationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      shotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shot_id'],
      )!,
      elapsedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_ms'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
    );
  }

  @override
  $ShotAnnotationsTable createAlias(String alias) {
    return $ShotAnnotationsTable(attachedDatabase, alias);
  }
}

class ShotAnnotationRow extends DataClass
    implements Insertable<ShotAnnotationRow> {
  final int id;
  final String shotId;
  final int elapsedMs;
  final String label;
  final String type;
  const ShotAnnotationRow({
    required this.id,
    required this.shotId,
    required this.elapsedMs,
    required this.label,
    required this.type,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['shot_id'] = Variable<String>(shotId);
    map['elapsed_ms'] = Variable<int>(elapsedMs);
    map['label'] = Variable<String>(label);
    map['type'] = Variable<String>(type);
    return map;
  }

  ShotAnnotationsCompanion toCompanion(bool nullToAbsent) {
    return ShotAnnotationsCompanion(
      id: Value(id),
      shotId: Value(shotId),
      elapsedMs: Value(elapsedMs),
      label: Value(label),
      type: Value(type),
    );
  }

  factory ShotAnnotationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShotAnnotationRow(
      id: serializer.fromJson<int>(json['id']),
      shotId: serializer.fromJson<String>(json['shotId']),
      elapsedMs: serializer.fromJson<int>(json['elapsedMs']),
      label: serializer.fromJson<String>(json['label']),
      type: serializer.fromJson<String>(json['type']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'shotId': serializer.toJson<String>(shotId),
      'elapsedMs': serializer.toJson<int>(elapsedMs),
      'label': serializer.toJson<String>(label),
      'type': serializer.toJson<String>(type),
    };
  }

  ShotAnnotationRow copyWith({
    int? id,
    String? shotId,
    int? elapsedMs,
    String? label,
    String? type,
  }) => ShotAnnotationRow(
    id: id ?? this.id,
    shotId: shotId ?? this.shotId,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    label: label ?? this.label,
    type: type ?? this.type,
  );
  ShotAnnotationRow copyWithCompanion(ShotAnnotationsCompanion data) {
    return ShotAnnotationRow(
      id: data.id.present ? data.id.value : this.id,
      shotId: data.shotId.present ? data.shotId.value : this.shotId,
      elapsedMs: data.elapsedMs.present ? data.elapsedMs.value : this.elapsedMs,
      label: data.label.present ? data.label.value : this.label,
      type: data.type.present ? data.type.value : this.type,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShotAnnotationRow(')
          ..write('id: $id, ')
          ..write('shotId: $shotId, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('label: $label, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, shotId, elapsedMs, label, type);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShotAnnotationRow &&
          other.id == this.id &&
          other.shotId == this.shotId &&
          other.elapsedMs == this.elapsedMs &&
          other.label == this.label &&
          other.type == this.type);
}

class ShotAnnotationsCompanion extends UpdateCompanion<ShotAnnotationRow> {
  final Value<int> id;
  final Value<String> shotId;
  final Value<int> elapsedMs;
  final Value<String> label;
  final Value<String> type;
  const ShotAnnotationsCompanion({
    this.id = const Value.absent(),
    this.shotId = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.label = const Value.absent(),
    this.type = const Value.absent(),
  });
  ShotAnnotationsCompanion.insert({
    this.id = const Value.absent(),
    required String shotId,
    required int elapsedMs,
    required String label,
    required String type,
  }) : shotId = Value(shotId),
       elapsedMs = Value(elapsedMs),
       label = Value(label),
       type = Value(type);
  static Insertable<ShotAnnotationRow> custom({
    Expression<int>? id,
    Expression<String>? shotId,
    Expression<int>? elapsedMs,
    Expression<String>? label,
    Expression<String>? type,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shotId != null) 'shot_id': shotId,
      if (elapsedMs != null) 'elapsed_ms': elapsedMs,
      if (label != null) 'label': label,
      if (type != null) 'type': type,
    });
  }

  ShotAnnotationsCompanion copyWith({
    Value<int>? id,
    Value<String>? shotId,
    Value<int>? elapsedMs,
    Value<String>? label,
    Value<String>? type,
  }) {
    return ShotAnnotationsCompanion(
      id: id ?? this.id,
      shotId: shotId ?? this.shotId,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      label: label ?? this.label,
      type: type ?? this.type,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (shotId.present) {
      map['shot_id'] = Variable<String>(shotId.value);
    }
    if (elapsedMs.present) {
      map['elapsed_ms'] = Variable<int>(elapsedMs.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShotAnnotationsCompanion(')
          ..write('id: $id, ')
          ..write('shotId: $shotId, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('label: $label, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }
}

class $BeansTable extends Beans with TableInfo<$BeansTable, BeanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BeansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roastLevelMeta = const VerificationMeta(
    'roastLevel',
  );
  @override
  late final GeneratedColumn<String> roastLevel = GeneratedColumn<String>(
    'roast_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> roastDate =
      GeneratedColumn<String>(
        'roast_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($BeansTable.$converterroastDate);
  static const VerificationMeta _processMeta = const VerificationMeta(
    'process',
  );
  @override
  late final GeneratedColumn<String> process = GeneratedColumn<String>(
    'process',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _varietyMeta = const VerificationMeta(
    'variety',
  );
  @override
  late final GeneratedColumn<String> variety = GeneratedColumn<String>(
    'variety',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stockGMeta = const VerificationMeta('stockG');
  @override
  late final GeneratedColumn<double> stockG = GeneratedColumn<double>(
    'stock_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    brand,
    origin,
    roastLevel,
    roastDate,
    process,
    variety,
    stockG,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'beans';
  @override
  VerificationContext validateIntegrity(
    Insertable<BeanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('roast_level')) {
      context.handle(
        _roastLevelMeta,
        roastLevel.isAcceptableOrUnknown(data['roast_level']!, _roastLevelMeta),
      );
    }
    if (data.containsKey('process')) {
      context.handle(
        _processMeta,
        process.isAcceptableOrUnknown(data['process']!, _processMeta),
      );
    }
    if (data.containsKey('variety')) {
      context.handle(
        _varietyMeta,
        variety.isAcceptableOrUnknown(data['variety']!, _varietyMeta),
      );
    }
    if (data.containsKey('stock_g')) {
      context.handle(
        _stockGMeta,
        stockG.isAcceptableOrUnknown(data['stock_g']!, _stockGMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BeanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BeanRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      roastLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roast_level'],
      ),
      roastDate: $BeansTable.$converterroastDate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}roast_date'],
        ),
      ),
      process: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}process'],
      ),
      variety: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variety'],
      ),
      stockG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stock_g'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $BeansTable createAlias(String alias) {
    return $BeansTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime?, String?> $converterroastDate =
      const NullableUtcIso8601Converter();
}

class BeanRow extends DataClass implements Insertable<BeanRow> {
  final String id;
  final String name;
  final String? brand;
  final String? origin;
  final String? roastLevel;
  final DateTime? roastDate;
  final String? process;
  final String? variety;
  final double? stockG;
  final String? notes;
  const BeanRow({
    required this.id,
    required this.name,
    this.brand,
    this.origin,
    this.roastLevel,
    this.roastDate,
    this.process,
    this.variety,
    this.stockG,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || roastLevel != null) {
      map['roast_level'] = Variable<String>(roastLevel);
    }
    if (!nullToAbsent || roastDate != null) {
      map['roast_date'] = Variable<String>(
        $BeansTable.$converterroastDate.toSql(roastDate),
      );
    }
    if (!nullToAbsent || process != null) {
      map['process'] = Variable<String>(process);
    }
    if (!nullToAbsent || variety != null) {
      map['variety'] = Variable<String>(variety);
    }
    if (!nullToAbsent || stockG != null) {
      map['stock_g'] = Variable<double>(stockG);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  BeansCompanion toCompanion(bool nullToAbsent) {
    return BeansCompanion(
      id: Value(id),
      name: Value(name),
      brand: brand == null && nullToAbsent
          ? const Value.absent()
          : Value(brand),
      origin: origin == null && nullToAbsent
          ? const Value.absent()
          : Value(origin),
      roastLevel: roastLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(roastLevel),
      roastDate: roastDate == null && nullToAbsent
          ? const Value.absent()
          : Value(roastDate),
      process: process == null && nullToAbsent
          ? const Value.absent()
          : Value(process),
      variety: variety == null && nullToAbsent
          ? const Value.absent()
          : Value(variety),
      stockG: stockG == null && nullToAbsent
          ? const Value.absent()
          : Value(stockG),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory BeanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BeanRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      brand: serializer.fromJson<String?>(json['brand']),
      origin: serializer.fromJson<String?>(json['origin']),
      roastLevel: serializer.fromJson<String?>(json['roastLevel']),
      roastDate: serializer.fromJson<DateTime?>(json['roastDate']),
      process: serializer.fromJson<String?>(json['process']),
      variety: serializer.fromJson<String?>(json['variety']),
      stockG: serializer.fromJson<double?>(json['stockG']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'brand': serializer.toJson<String?>(brand),
      'origin': serializer.toJson<String?>(origin),
      'roastLevel': serializer.toJson<String?>(roastLevel),
      'roastDate': serializer.toJson<DateTime?>(roastDate),
      'process': serializer.toJson<String?>(process),
      'variety': serializer.toJson<String?>(variety),
      'stockG': serializer.toJson<double?>(stockG),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  BeanRow copyWith({
    String? id,
    String? name,
    Value<String?> brand = const Value.absent(),
    Value<String?> origin = const Value.absent(),
    Value<String?> roastLevel = const Value.absent(),
    Value<DateTime?> roastDate = const Value.absent(),
    Value<String?> process = const Value.absent(),
    Value<String?> variety = const Value.absent(),
    Value<double?> stockG = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => BeanRow(
    id: id ?? this.id,
    name: name ?? this.name,
    brand: brand.present ? brand.value : this.brand,
    origin: origin.present ? origin.value : this.origin,
    roastLevel: roastLevel.present ? roastLevel.value : this.roastLevel,
    roastDate: roastDate.present ? roastDate.value : this.roastDate,
    process: process.present ? process.value : this.process,
    variety: variety.present ? variety.value : this.variety,
    stockG: stockG.present ? stockG.value : this.stockG,
    notes: notes.present ? notes.value : this.notes,
  );
  BeanRow copyWithCompanion(BeansCompanion data) {
    return BeanRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      brand: data.brand.present ? data.brand.value : this.brand,
      origin: data.origin.present ? data.origin.value : this.origin,
      roastLevel: data.roastLevel.present
          ? data.roastLevel.value
          : this.roastLevel,
      roastDate: data.roastDate.present ? data.roastDate.value : this.roastDate,
      process: data.process.present ? data.process.value : this.process,
      variety: data.variety.present ? data.variety.value : this.variety,
      stockG: data.stockG.present ? data.stockG.value : this.stockG,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BeanRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('origin: $origin, ')
          ..write('roastLevel: $roastLevel, ')
          ..write('roastDate: $roastDate, ')
          ..write('process: $process, ')
          ..write('variety: $variety, ')
          ..write('stockG: $stockG, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    brand,
    origin,
    roastLevel,
    roastDate,
    process,
    variety,
    stockG,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BeanRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.brand == this.brand &&
          other.origin == this.origin &&
          other.roastLevel == this.roastLevel &&
          other.roastDate == this.roastDate &&
          other.process == this.process &&
          other.variety == this.variety &&
          other.stockG == this.stockG &&
          other.notes == this.notes);
}

class BeansCompanion extends UpdateCompanion<BeanRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> brand;
  final Value<String?> origin;
  final Value<String?> roastLevel;
  final Value<DateTime?> roastDate;
  final Value<String?> process;
  final Value<String?> variety;
  final Value<double?> stockG;
  final Value<String?> notes;
  final Value<int> rowid;
  const BeansCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.origin = const Value.absent(),
    this.roastLevel = const Value.absent(),
    this.roastDate = const Value.absent(),
    this.process = const Value.absent(),
    this.variety = const Value.absent(),
    this.stockG = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BeansCompanion.insert({
    required String id,
    required String name,
    this.brand = const Value.absent(),
    this.origin = const Value.absent(),
    this.roastLevel = const Value.absent(),
    this.roastDate = const Value.absent(),
    this.process = const Value.absent(),
    this.variety = const Value.absent(),
    this.stockG = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<BeanRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? brand,
    Expression<String>? origin,
    Expression<String>? roastLevel,
    Expression<String>? roastDate,
    Expression<String>? process,
    Expression<String>? variety,
    Expression<double>? stockG,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (brand != null) 'brand': brand,
      if (origin != null) 'origin': origin,
      if (roastLevel != null) 'roast_level': roastLevel,
      if (roastDate != null) 'roast_date': roastDate,
      if (process != null) 'process': process,
      if (variety != null) 'variety': variety,
      if (stockG != null) 'stock_g': stockG,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BeansCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? brand,
    Value<String?>? origin,
    Value<String?>? roastLevel,
    Value<DateTime?>? roastDate,
    Value<String?>? process,
    Value<String?>? variety,
    Value<double?>? stockG,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return BeansCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      origin: origin ?? this.origin,
      roastLevel: roastLevel ?? this.roastLevel,
      roastDate: roastDate ?? this.roastDate,
      process: process ?? this.process,
      variety: variety ?? this.variety,
      stockG: stockG ?? this.stockG,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (roastLevel.present) {
      map['roast_level'] = Variable<String>(roastLevel.value);
    }
    if (roastDate.present) {
      map['roast_date'] = Variable<String>(
        $BeansTable.$converterroastDate.toSql(roastDate.value),
      );
    }
    if (process.present) {
      map['process'] = Variable<String>(process.value);
    }
    if (variety.present) {
      map['variety'] = Variable<String>(variety.value);
    }
    if (stockG.present) {
      map['stock_g'] = Variable<double>(stockG.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BeansCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('origin: $origin, ')
          ..write('roastLevel: $roastLevel, ')
          ..write('roastDate: $roastDate, ')
          ..write('process: $process, ')
          ..write('variety: $variety, ')
          ..write('stockG: $stockG, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, TagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class TagRow extends DataClass implements Insertable<TagRow> {
  final String id;
  final String name;
  const TagRow({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(id: Value(id), name: Value(name));
  }

  factory TagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  TagRow copyWith({String? id, String? name}) =>
      TagRow(id: id ?? this.id, name: name ?? this.name);
  TagRow copyWithCompanion(TagsCompanion data) {
    return TagRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRow(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRow && other.id == this.id && other.name == this.name);
}

class TagsCompanion extends UpdateCompanion<TagRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<TagRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShotTagsTable extends ShotTags
    with TableInfo<$ShotTagsTable, ShotTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShotTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _shotIdMeta = const VerificationMeta('shotId');
  @override
  late final GeneratedColumn<String> shotId = GeneratedColumn<String>(
    'shot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shots (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [shotId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shot_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShotTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('shot_id')) {
      context.handle(
        _shotIdMeta,
        shotId.isAcceptableOrUnknown(data['shot_id']!, _shotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shotIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {shotId, tagId};
  @override
  ShotTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShotTagRow(
      shotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shot_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $ShotTagsTable createAlias(String alias) {
    return $ShotTagsTable(attachedDatabase, alias);
  }
}

class ShotTagRow extends DataClass implements Insertable<ShotTagRow> {
  final String shotId;
  final String tagId;
  const ShotTagRow({required this.shotId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['shot_id'] = Variable<String>(shotId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  ShotTagsCompanion toCompanion(bool nullToAbsent) {
    return ShotTagsCompanion(shotId: Value(shotId), tagId: Value(tagId));
  }

  factory ShotTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShotTagRow(
      shotId: serializer.fromJson<String>(json['shotId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'shotId': serializer.toJson<String>(shotId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  ShotTagRow copyWith({String? shotId, String? tagId}) =>
      ShotTagRow(shotId: shotId ?? this.shotId, tagId: tagId ?? this.tagId);
  ShotTagRow copyWithCompanion(ShotTagsCompanion data) {
    return ShotTagRow(
      shotId: data.shotId.present ? data.shotId.value : this.shotId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShotTagRow(')
          ..write('shotId: $shotId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(shotId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShotTagRow &&
          other.shotId == this.shotId &&
          other.tagId == this.tagId);
}

class ShotTagsCompanion extends UpdateCompanion<ShotTagRow> {
  final Value<String> shotId;
  final Value<String> tagId;
  final Value<int> rowid;
  const ShotTagsCompanion({
    this.shotId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShotTagsCompanion.insert({
    required String shotId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : shotId = Value(shotId),
       tagId = Value(tagId);
  static Insertable<ShotTagRow> custom({
    Expression<String>? shotId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (shotId != null) 'shot_id': shotId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShotTagsCompanion copyWith({
    Value<String>? shotId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return ShotTagsCompanion(
      shotId: shotId ?? this.shotId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (shotId.present) {
      map['shot_id'] = Variable<String>(shotId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShotTagsCompanion(')
          ..write('shotId: $shotId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedProfilesTable extends SavedProfiles
    with TableInfo<$SavedProfilesTable, SavedProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> createdAt =
      GeneratedColumn<String>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SavedProfilesTable.$convertercreatedAt);
  static const VerificationMeta _sourceShotIdMeta = const VerificationMeta(
    'sourceShotId',
  );
  @override
  late final GeneratedColumn<String> sourceShotId = GeneratedColumn<String>(
    'source_shot_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doseGMeta = const VerificationMeta('doseG');
  @override
  late final GeneratedColumn<double> doseG = GeneratedColumn<double>(
    'dose_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yieldGMeta = const VerificationMeta('yieldG');
  @override
  late final GeneratedColumn<double> yieldG = GeneratedColumn<double>(
    'yield_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _grindSettingMeta = const VerificationMeta(
    'grindSetting',
  );
  @override
  late final GeneratedColumn<double> grindSetting = GeneratedColumn<double>(
    'grind_setting',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _beanIdMeta = const VerificationMeta('beanId');
  @override
  late final GeneratedColumn<String> beanId = GeneratedColumn<String>(
    'bean_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _waterTempCMeta = const VerificationMeta(
    'waterTempC',
  );
  @override
  late final GeneratedColumn<double> waterTempC = GeneratedColumn<double>(
    'water_temp_c',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    sourceShotId,
    doseG,
    yieldG,
    grindSetting,
    beanId,
    waterTempC,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('source_shot_id')) {
      context.handle(
        _sourceShotIdMeta,
        sourceShotId.isAcceptableOrUnknown(
          data['source_shot_id']!,
          _sourceShotIdMeta,
        ),
      );
    }
    if (data.containsKey('dose_g')) {
      context.handle(
        _doseGMeta,
        doseG.isAcceptableOrUnknown(data['dose_g']!, _doseGMeta),
      );
    }
    if (data.containsKey('yield_g')) {
      context.handle(
        _yieldGMeta,
        yieldG.isAcceptableOrUnknown(data['yield_g']!, _yieldGMeta),
      );
    }
    if (data.containsKey('grind_setting')) {
      context.handle(
        _grindSettingMeta,
        grindSetting.isAcceptableOrUnknown(
          data['grind_setting']!,
          _grindSettingMeta,
        ),
      );
    }
    if (data.containsKey('bean_id')) {
      context.handle(
        _beanIdMeta,
        beanId.isAcceptableOrUnknown(data['bean_id']!, _beanIdMeta),
      );
    }
    if (data.containsKey('water_temp_c')) {
      context.handle(
        _waterTempCMeta,
        waterTempC.isAcceptableOrUnknown(
          data['water_temp_c']!,
          _waterTempCMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: $SavedProfilesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      sourceShotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_shot_id'],
      ),
      doseG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dose_g'],
      ),
      yieldG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}yield_g'],
      ),
      grindSetting: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grind_setting'],
      ),
      beanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bean_id'],
      ),
      waterTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}water_temp_c'],
      ),
    );
  }

  @override
  $SavedProfilesTable createAlias(String alias) {
    return $SavedProfilesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $convertercreatedAt =
      const UtcIso8601Converter();
}

class SavedProfileRow extends DataClass implements Insertable<SavedProfileRow> {
  final String id;
  final String name;
  final DateTime createdAt;
  final String? sourceShotId;
  final double? doseG;
  final double? yieldG;
  final double? grindSetting;
  final String? beanId;
  final double? waterTempC;
  const SavedProfileRow({
    required this.id,
    required this.name,
    required this.createdAt,
    this.sourceShotId,
    this.doseG,
    this.yieldG,
    this.grindSetting,
    this.beanId,
    this.waterTempC,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['created_at'] = Variable<String>(
        $SavedProfilesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    if (!nullToAbsent || sourceShotId != null) {
      map['source_shot_id'] = Variable<String>(sourceShotId);
    }
    if (!nullToAbsent || doseG != null) {
      map['dose_g'] = Variable<double>(doseG);
    }
    if (!nullToAbsent || yieldG != null) {
      map['yield_g'] = Variable<double>(yieldG);
    }
    if (!nullToAbsent || grindSetting != null) {
      map['grind_setting'] = Variable<double>(grindSetting);
    }
    if (!nullToAbsent || beanId != null) {
      map['bean_id'] = Variable<String>(beanId);
    }
    if (!nullToAbsent || waterTempC != null) {
      map['water_temp_c'] = Variable<double>(waterTempC);
    }
    return map;
  }

  SavedProfilesCompanion toCompanion(bool nullToAbsent) {
    return SavedProfilesCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      sourceShotId: sourceShotId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceShotId),
      doseG: doseG == null && nullToAbsent
          ? const Value.absent()
          : Value(doseG),
      yieldG: yieldG == null && nullToAbsent
          ? const Value.absent()
          : Value(yieldG),
      grindSetting: grindSetting == null && nullToAbsent
          ? const Value.absent()
          : Value(grindSetting),
      beanId: beanId == null && nullToAbsent
          ? const Value.absent()
          : Value(beanId),
      waterTempC: waterTempC == null && nullToAbsent
          ? const Value.absent()
          : Value(waterTempC),
    );
  }

  factory SavedProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      sourceShotId: serializer.fromJson<String?>(json['sourceShotId']),
      doseG: serializer.fromJson<double?>(json['doseG']),
      yieldG: serializer.fromJson<double?>(json['yieldG']),
      grindSetting: serializer.fromJson<double?>(json['grindSetting']),
      beanId: serializer.fromJson<String?>(json['beanId']),
      waterTempC: serializer.fromJson<double?>(json['waterTempC']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'sourceShotId': serializer.toJson<String?>(sourceShotId),
      'doseG': serializer.toJson<double?>(doseG),
      'yieldG': serializer.toJson<double?>(yieldG),
      'grindSetting': serializer.toJson<double?>(grindSetting),
      'beanId': serializer.toJson<String?>(beanId),
      'waterTempC': serializer.toJson<double?>(waterTempC),
    };
  }

  SavedProfileRow copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    Value<String?> sourceShotId = const Value.absent(),
    Value<double?> doseG = const Value.absent(),
    Value<double?> yieldG = const Value.absent(),
    Value<double?> grindSetting = const Value.absent(),
    Value<String?> beanId = const Value.absent(),
    Value<double?> waterTempC = const Value.absent(),
  }) => SavedProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    sourceShotId: sourceShotId.present ? sourceShotId.value : this.sourceShotId,
    doseG: doseG.present ? doseG.value : this.doseG,
    yieldG: yieldG.present ? yieldG.value : this.yieldG,
    grindSetting: grindSetting.present ? grindSetting.value : this.grindSetting,
    beanId: beanId.present ? beanId.value : this.beanId,
    waterTempC: waterTempC.present ? waterTempC.value : this.waterTempC,
  );
  SavedProfileRow copyWithCompanion(SavedProfilesCompanion data) {
    return SavedProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sourceShotId: data.sourceShotId.present
          ? data.sourceShotId.value
          : this.sourceShotId,
      doseG: data.doseG.present ? data.doseG.value : this.doseG,
      yieldG: data.yieldG.present ? data.yieldG.value : this.yieldG,
      grindSetting: data.grindSetting.present
          ? data.grindSetting.value
          : this.grindSetting,
      beanId: data.beanId.present ? data.beanId.value : this.beanId,
      waterTempC: data.waterTempC.present
          ? data.waterTempC.value
          : this.waterTempC,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('sourceShotId: $sourceShotId, ')
          ..write('doseG: $doseG, ')
          ..write('yieldG: $yieldG, ')
          ..write('grindSetting: $grindSetting, ')
          ..write('beanId: $beanId, ')
          ..write('waterTempC: $waterTempC')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    createdAt,
    sourceShotId,
    doseG,
    yieldG,
    grindSetting,
    beanId,
    waterTempC,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.sourceShotId == this.sourceShotId &&
          other.doseG == this.doseG &&
          other.yieldG == this.yieldG &&
          other.grindSetting == this.grindSetting &&
          other.beanId == this.beanId &&
          other.waterTempC == this.waterTempC);
}

class SavedProfilesCompanion extends UpdateCompanion<SavedProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<String?> sourceShotId;
  final Value<double?> doseG;
  final Value<double?> yieldG;
  final Value<double?> grindSetting;
  final Value<String?> beanId;
  final Value<double?> waterTempC;
  final Value<int> rowid;
  const SavedProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sourceShotId = const Value.absent(),
    this.doseG = const Value.absent(),
    this.yieldG = const Value.absent(),
    this.grindSetting = const Value.absent(),
    this.beanId = const Value.absent(),
    this.waterTempC = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedProfilesCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    this.sourceShotId = const Value.absent(),
    this.doseG = const Value.absent(),
    this.yieldG = const Value.absent(),
    this.grindSetting = const Value.absent(),
    this.beanId = const Value.absent(),
    this.waterTempC = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<SavedProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? createdAt,
    Expression<String>? sourceShotId,
    Expression<double>? doseG,
    Expression<double>? yieldG,
    Expression<double>? grindSetting,
    Expression<String>? beanId,
    Expression<double>? waterTempC,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (sourceShotId != null) 'source_shot_id': sourceShotId,
      if (doseG != null) 'dose_g': doseG,
      if (yieldG != null) 'yield_g': yieldG,
      if (grindSetting != null) 'grind_setting': grindSetting,
      if (beanId != null) 'bean_id': beanId,
      if (waterTempC != null) 'water_temp_c': waterTempC,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<String?>? sourceShotId,
    Value<double?>? doseG,
    Value<double?>? yieldG,
    Value<double?>? grindSetting,
    Value<String?>? beanId,
    Value<double?>? waterTempC,
    Value<int>? rowid,
  }) {
    return SavedProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sourceShotId: sourceShotId ?? this.sourceShotId,
      doseG: doseG ?? this.doseG,
      yieldG: yieldG ?? this.yieldG,
      grindSetting: grindSetting ?? this.grindSetting,
      beanId: beanId ?? this.beanId,
      waterTempC: waterTempC ?? this.waterTempC,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(
        $SavedProfilesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (sourceShotId.present) {
      map['source_shot_id'] = Variable<String>(sourceShotId.value);
    }
    if (doseG.present) {
      map['dose_g'] = Variable<double>(doseG.value);
    }
    if (yieldG.present) {
      map['yield_g'] = Variable<double>(yieldG.value);
    }
    if (grindSetting.present) {
      map['grind_setting'] = Variable<double>(grindSetting.value);
    }
    if (beanId.present) {
      map['bean_id'] = Variable<String>(beanId.value);
    }
    if (waterTempC.present) {
      map['water_temp_c'] = Variable<double>(waterTempC.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('sourceShotId: $sourceShotId, ')
          ..write('doseG: $doseG, ')
          ..write('yieldG: $yieldG, ')
          ..write('grindSetting: $grindSetting, ')
          ..write('beanId: $beanId, ')
          ..write('waterTempC: $waterTempC, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedProfileSamplesTable extends SavedProfileSamples
    with TableInfo<$SavedProfileSamplesTable, SavedProfileSampleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedProfileSamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _elapsedMsMeta = const VerificationMeta(
    'elapsedMs',
  );
  @override
  late final GeneratedColumn<int> elapsedMs = GeneratedColumn<int>(
    'elapsed_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pressureBarMeta = const VerificationMeta(
    'pressureBar',
  );
  @override
  late final GeneratedColumn<double> pressureBar = GeneratedColumn<double>(
    'pressure_bar',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, profileId, elapsedMs, pressureBar];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_profile_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedProfileSampleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('elapsed_ms')) {
      context.handle(
        _elapsedMsMeta,
        elapsedMs.isAcceptableOrUnknown(data['elapsed_ms']!, _elapsedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_elapsedMsMeta);
    }
    if (data.containsKey('pressure_bar')) {
      context.handle(
        _pressureBarMeta,
        pressureBar.isAcceptableOrUnknown(
          data['pressure_bar']!,
          _pressureBarMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pressureBarMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedProfileSampleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedProfileSampleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      elapsedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_ms'],
      )!,
      pressureBar: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pressure_bar'],
      )!,
    );
  }

  @override
  $SavedProfileSamplesTable createAlias(String alias) {
    return $SavedProfileSamplesTable(attachedDatabase, alias);
  }
}

class SavedProfileSampleRow extends DataClass
    implements Insertable<SavedProfileSampleRow> {
  final int id;
  final String profileId;
  final int elapsedMs;
  final double pressureBar;
  const SavedProfileSampleRow({
    required this.id,
    required this.profileId,
    required this.elapsedMs,
    required this.pressureBar,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['elapsed_ms'] = Variable<int>(elapsedMs);
    map['pressure_bar'] = Variable<double>(pressureBar);
    return map;
  }

  SavedProfileSamplesCompanion toCompanion(bool nullToAbsent) {
    return SavedProfileSamplesCompanion(
      id: Value(id),
      profileId: Value(profileId),
      elapsedMs: Value(elapsedMs),
      pressureBar: Value(pressureBar),
    );
  }

  factory SavedProfileSampleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedProfileSampleRow(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      elapsedMs: serializer.fromJson<int>(json['elapsedMs']),
      pressureBar: serializer.fromJson<double>(json['pressureBar']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<String>(profileId),
      'elapsedMs': serializer.toJson<int>(elapsedMs),
      'pressureBar': serializer.toJson<double>(pressureBar),
    };
  }

  SavedProfileSampleRow copyWith({
    int? id,
    String? profileId,
    int? elapsedMs,
    double? pressureBar,
  }) => SavedProfileSampleRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    pressureBar: pressureBar ?? this.pressureBar,
  );
  SavedProfileSampleRow copyWithCompanion(SavedProfileSamplesCompanion data) {
    return SavedProfileSampleRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      elapsedMs: data.elapsedMs.present ? data.elapsedMs.value : this.elapsedMs,
      pressureBar: data.pressureBar.present
          ? data.pressureBar.value
          : this.pressureBar,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedProfileSampleRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('pressureBar: $pressureBar')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, profileId, elapsedMs, pressureBar);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedProfileSampleRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.elapsedMs == this.elapsedMs &&
          other.pressureBar == this.pressureBar);
}

class SavedProfileSamplesCompanion
    extends UpdateCompanion<SavedProfileSampleRow> {
  final Value<int> id;
  final Value<String> profileId;
  final Value<int> elapsedMs;
  final Value<double> pressureBar;
  const SavedProfileSamplesCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.pressureBar = const Value.absent(),
  });
  SavedProfileSamplesCompanion.insert({
    this.id = const Value.absent(),
    required String profileId,
    required int elapsedMs,
    required double pressureBar,
  }) : profileId = Value(profileId),
       elapsedMs = Value(elapsedMs),
       pressureBar = Value(pressureBar);
  static Insertable<SavedProfileSampleRow> custom({
    Expression<int>? id,
    Expression<String>? profileId,
    Expression<int>? elapsedMs,
    Expression<double>? pressureBar,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (elapsedMs != null) 'elapsed_ms': elapsedMs,
      if (pressureBar != null) 'pressure_bar': pressureBar,
    });
  }

  SavedProfileSamplesCompanion copyWith({
    Value<int>? id,
    Value<String>? profileId,
    Value<int>? elapsedMs,
    Value<double>? pressureBar,
  }) {
    return SavedProfileSamplesCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      pressureBar: pressureBar ?? this.pressureBar,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (elapsedMs.present) {
      map['elapsed_ms'] = Variable<int>(elapsedMs.value);
    }
    if (pressureBar.present) {
      map['pressure_bar'] = Variable<double>(pressureBar.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedProfileSamplesCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('pressureBar: $pressureBar')
          ..write(')'))
        .toString();
  }
}

abstract class _$FlowlogDatabase extends GeneratedDatabase {
  _$FlowlogDatabase(QueryExecutor e) : super(e);
  $FlowlogDatabaseManager get managers => $FlowlogDatabaseManager(this);
  late final $ShotsTable shots = $ShotsTable(this);
  late final $ShotSamplesTable shotSamples = $ShotSamplesTable(this);
  late final $ShotAnnotationsTable shotAnnotations = $ShotAnnotationsTable(
    this,
  );
  late final $BeansTable beans = $BeansTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $ShotTagsTable shotTags = $ShotTagsTable(this);
  late final $SavedProfilesTable savedProfiles = $SavedProfilesTable(this);
  late final $SavedProfileSamplesTable savedProfileSamples =
      $SavedProfileSamplesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    shots,
    shotSamples,
    shotAnnotations,
    beans,
    tags,
    shotTags,
    savedProfiles,
    savedProfileSamples,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'shots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shot_samples', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'shots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shot_annotations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'shots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shot_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shot_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'saved_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_profile_samples', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ShotsTableCreateCompanionBuilder =
    ShotsCompanion Function({
      required String id,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<double?> doseG,
      Value<double?> yieldG,
      Value<double?> grindSetting,
      Value<String?> beanId,
      Value<double?> waterTempC,
      Value<String?> notes,
      Value<int?> tasteScore,
      Value<String> flavourTags,
      Value<String> flavourIntensities,
      Value<String?> location,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<int?> coffeejackRewindTurns,
      Value<int?> coffeejackPreinfusionTurns,
      Value<String?> grinder,
      Value<String?> showerScreen,
      Value<String?> basket,
      Value<String?> scale,
      Value<String?> brewer,
      Value<DateTime?> lastModifiedAt,
      Value<double?> autoStartPressureBar,
      Value<double?> targetClosenessPercent,
      Value<int?> targetMaxStreakSeconds,
      Value<double?> targetScore,
      Value<int> rowid,
    });
typedef $$ShotsTableUpdateCompanionBuilder =
    ShotsCompanion Function({
      Value<String> id,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<double?> doseG,
      Value<double?> yieldG,
      Value<double?> grindSetting,
      Value<String?> beanId,
      Value<double?> waterTempC,
      Value<String?> notes,
      Value<int?> tasteScore,
      Value<String> flavourTags,
      Value<String> flavourIntensities,
      Value<String?> location,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<int?> coffeejackRewindTurns,
      Value<int?> coffeejackPreinfusionTurns,
      Value<String?> grinder,
      Value<String?> showerScreen,
      Value<String?> basket,
      Value<String?> scale,
      Value<String?> brewer,
      Value<DateTime?> lastModifiedAt,
      Value<double?> autoStartPressureBar,
      Value<double?> targetClosenessPercent,
      Value<int?> targetMaxStreakSeconds,
      Value<double?> targetScore,
      Value<int> rowid,
    });

final class $$ShotsTableReferences
    extends BaseReferences<_$FlowlogDatabase, $ShotsTable, ShotRow> {
  $$ShotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ShotSamplesTable, List<ShotSampleRow>>
  _shotSamplesRefsTable(_$FlowlogDatabase db) => MultiTypedResultKey.fromTable(
    db.shotSamples,
    aliasName: 'shots__id__shot_samples__shot_id',
  );

  $$ShotSamplesTableProcessedTableManager get shotSamplesRefs {
    final manager = $$ShotSamplesTableTableManager(
      $_db,
      $_db.shotSamples,
    ).filter((f) => f.shotId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_shotSamplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ShotAnnotationsTable, List<ShotAnnotationRow>>
  _shotAnnotationsRefsTable(_$FlowlogDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.shotAnnotations,
        aliasName: 'shots__id__shot_annotations__shot_id',
      );

  $$ShotAnnotationsTableProcessedTableManager get shotAnnotationsRefs {
    final manager = $$ShotAnnotationsTableTableManager(
      $_db,
      $_db.shotAnnotations,
    ).filter((f) => f.shotId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _shotAnnotationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ShotTagsTable, List<ShotTagRow>>
  _shotTagsRefsTable(_$FlowlogDatabase db) => MultiTypedResultKey.fromTable(
    db.shotTags,
    aliasName: 'shots__id__shot_tags__shot_id',
  );

  $$ShotTagsTableProcessedTableManager get shotTagsRefs {
    final manager = $$ShotTagsTableTableManager(
      $_db,
      $_db.shotTags,
    ).filter((f) => f.shotId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_shotTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ShotsTableFilterComposer
    extends Composer<_$FlowlogDatabase, $ShotsTable> {
  $$ShotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get startedAt =>
      $composableBuilder(
        column: $table.startedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get endedAt =>
      $composableBuilder(
        column: $table.endedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get doseG => $composableBuilder(
    column: $table.doseG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get yieldG => $composableBuilder(
    column: $table.yieldG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grindSetting => $composableBuilder(
    column: $table.grindSetting,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beanId => $composableBuilder(
    column: $table.beanId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get waterTempC => $composableBuilder(
    column: $table.waterTempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tasteScore => $composableBuilder(
    column: $table.tasteScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flavourTags => $composableBuilder(
    column: $table.flavourTags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flavourIntensities => $composableBuilder(
    column: $table.flavourIntensities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coffeejackRewindTurns => $composableBuilder(
    column: $table.coffeejackRewindTurns,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coffeejackPreinfusionTurns => $composableBuilder(
    column: $table.coffeejackPreinfusionTurns,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grinder => $composableBuilder(
    column: $table.grinder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get showerScreen => $composableBuilder(
    column: $table.showerScreen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basket => $composableBuilder(
    column: $table.basket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scale => $composableBuilder(
    column: $table.scale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brewer => $composableBuilder(
    column: $table.brewer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String>
  get lastModifiedAt => $composableBuilder(
    column: $table.lastModifiedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get autoStartPressureBar => $composableBuilder(
    column: $table.autoStartPressureBar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetClosenessPercent => $composableBuilder(
    column: $table.targetClosenessPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetMaxStreakSeconds => $composableBuilder(
    column: $table.targetMaxStreakSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetScore => $composableBuilder(
    column: $table.targetScore,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> shotSamplesRefs(
    Expression<bool> Function($$ShotSamplesTableFilterComposer f) f,
  ) {
    final $$ShotSamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotSamples,
      getReferencedColumn: (t) => t.shotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotSamplesTableFilterComposer(
            $db: $db,
            $table: $db.shotSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> shotAnnotationsRefs(
    Expression<bool> Function($$ShotAnnotationsTableFilterComposer f) f,
  ) {
    final $$ShotAnnotationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotAnnotations,
      getReferencedColumn: (t) => t.shotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotAnnotationsTableFilterComposer(
            $db: $db,
            $table: $db.shotAnnotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> shotTagsRefs(
    Expression<bool> Function($$ShotTagsTableFilterComposer f) f,
  ) {
    final $$ShotTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotTags,
      getReferencedColumn: (t) => t.shotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotTagsTableFilterComposer(
            $db: $db,
            $table: $db.shotTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShotsTableOrderingComposer
    extends Composer<_$FlowlogDatabase, $ShotsTable> {
  $$ShotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get doseG => $composableBuilder(
    column: $table.doseG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get yieldG => $composableBuilder(
    column: $table.yieldG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grindSetting => $composableBuilder(
    column: $table.grindSetting,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beanId => $composableBuilder(
    column: $table.beanId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get waterTempC => $composableBuilder(
    column: $table.waterTempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tasteScore => $composableBuilder(
    column: $table.tasteScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flavourTags => $composableBuilder(
    column: $table.flavourTags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flavourIntensities => $composableBuilder(
    column: $table.flavourIntensities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coffeejackRewindTurns => $composableBuilder(
    column: $table.coffeejackRewindTurns,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coffeejackPreinfusionTurns => $composableBuilder(
    column: $table.coffeejackPreinfusionTurns,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grinder => $composableBuilder(
    column: $table.grinder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get showerScreen => $composableBuilder(
    column: $table.showerScreen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basket => $composableBuilder(
    column: $table.basket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scale => $composableBuilder(
    column: $table.scale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brewer => $composableBuilder(
    column: $table.brewer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedAt => $composableBuilder(
    column: $table.lastModifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get autoStartPressureBar => $composableBuilder(
    column: $table.autoStartPressureBar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetClosenessPercent => $composableBuilder(
    column: $table.targetClosenessPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetMaxStreakSeconds => $composableBuilder(
    column: $table.targetMaxStreakSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetScore => $composableBuilder(
    column: $table.targetScore,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShotsTableAnnotationComposer
    extends Composer<_$FlowlogDatabase, $ShotsTable> {
  $$ShotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<double> get doseG =>
      $composableBuilder(column: $table.doseG, builder: (column) => column);

  GeneratedColumn<double> get yieldG =>
      $composableBuilder(column: $table.yieldG, builder: (column) => column);

  GeneratedColumn<double> get grindSetting => $composableBuilder(
    column: $table.grindSetting,
    builder: (column) => column,
  );

  GeneratedColumn<String> get beanId =>
      $composableBuilder(column: $table.beanId, builder: (column) => column);

  GeneratedColumn<double> get waterTempC => $composableBuilder(
    column: $table.waterTempC,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get tasteScore => $composableBuilder(
    column: $table.tasteScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get flavourTags => $composableBuilder(
    column: $table.flavourTags,
    builder: (column) => column,
  );

  GeneratedColumn<String> get flavourIntensities => $composableBuilder(
    column: $table.flavourIntensities,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get coffeejackRewindTurns => $composableBuilder(
    column: $table.coffeejackRewindTurns,
    builder: (column) => column,
  );

  GeneratedColumn<int> get coffeejackPreinfusionTurns => $composableBuilder(
    column: $table.coffeejackPreinfusionTurns,
    builder: (column) => column,
  );

  GeneratedColumn<String> get grinder =>
      $composableBuilder(column: $table.grinder, builder: (column) => column);

  GeneratedColumn<String> get showerScreen => $composableBuilder(
    column: $table.showerScreen,
    builder: (column) => column,
  );

  GeneratedColumn<String> get basket =>
      $composableBuilder(column: $table.basket, builder: (column) => column);

  GeneratedColumn<String> get scale =>
      $composableBuilder(column: $table.scale, builder: (column) => column);

  GeneratedColumn<String> get brewer =>
      $composableBuilder(column: $table.brewer, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get lastModifiedAt =>
      $composableBuilder(
        column: $table.lastModifiedAt,
        builder: (column) => column,
      );

  GeneratedColumn<double> get autoStartPressureBar => $composableBuilder(
    column: $table.autoStartPressureBar,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetClosenessPercent => $composableBuilder(
    column: $table.targetClosenessPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetMaxStreakSeconds => $composableBuilder(
    column: $table.targetMaxStreakSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetScore => $composableBuilder(
    column: $table.targetScore,
    builder: (column) => column,
  );

  Expression<T> shotSamplesRefs<T extends Object>(
    Expression<T> Function($$ShotSamplesTableAnnotationComposer a) f,
  ) {
    final $$ShotSamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotSamples,
      getReferencedColumn: (t) => t.shotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotSamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.shotSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> shotAnnotationsRefs<T extends Object>(
    Expression<T> Function($$ShotAnnotationsTableAnnotationComposer a) f,
  ) {
    final $$ShotAnnotationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotAnnotations,
      getReferencedColumn: (t) => t.shotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotAnnotationsTableAnnotationComposer(
            $db: $db,
            $table: $db.shotAnnotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> shotTagsRefs<T extends Object>(
    Expression<T> Function($$ShotTagsTableAnnotationComposer a) f,
  ) {
    final $$ShotTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotTags,
      getReferencedColumn: (t) => t.shotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.shotTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShotsTableTableManager
    extends
        RootTableManager<
          _$FlowlogDatabase,
          $ShotsTable,
          ShotRow,
          $$ShotsTableFilterComposer,
          $$ShotsTableOrderingComposer,
          $$ShotsTableAnnotationComposer,
          $$ShotsTableCreateCompanionBuilder,
          $$ShotsTableUpdateCompanionBuilder,
          (ShotRow, $$ShotsTableReferences),
          ShotRow,
          PrefetchHooks Function({
            bool shotSamplesRefs,
            bool shotAnnotationsRefs,
            bool shotTagsRefs,
          })
        > {
  $$ShotsTableTableManager(_$FlowlogDatabase db, $ShotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<double?> doseG = const Value.absent(),
                Value<double?> yieldG = const Value.absent(),
                Value<double?> grindSetting = const Value.absent(),
                Value<String?> beanId = const Value.absent(),
                Value<double?> waterTempC = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> tasteScore = const Value.absent(),
                Value<String> flavourTags = const Value.absent(),
                Value<String> flavourIntensities = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<int?> coffeejackRewindTurns = const Value.absent(),
                Value<int?> coffeejackPreinfusionTurns = const Value.absent(),
                Value<String?> grinder = const Value.absent(),
                Value<String?> showerScreen = const Value.absent(),
                Value<String?> basket = const Value.absent(),
                Value<String?> scale = const Value.absent(),
                Value<String?> brewer = const Value.absent(),
                Value<DateTime?> lastModifiedAt = const Value.absent(),
                Value<double?> autoStartPressureBar = const Value.absent(),
                Value<double?> targetClosenessPercent = const Value.absent(),
                Value<int?> targetMaxStreakSeconds = const Value.absent(),
                Value<double?> targetScore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShotsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                doseG: doseG,
                yieldG: yieldG,
                grindSetting: grindSetting,
                beanId: beanId,
                waterTempC: waterTempC,
                notes: notes,
                tasteScore: tasteScore,
                flavourTags: flavourTags,
                flavourIntensities: flavourIntensities,
                location: location,
                latitude: latitude,
                longitude: longitude,
                coffeejackRewindTurns: coffeejackRewindTurns,
                coffeejackPreinfusionTurns: coffeejackPreinfusionTurns,
                grinder: grinder,
                showerScreen: showerScreen,
                basket: basket,
                scale: scale,
                brewer: brewer,
                lastModifiedAt: lastModifiedAt,
                autoStartPressureBar: autoStartPressureBar,
                targetClosenessPercent: targetClosenessPercent,
                targetMaxStreakSeconds: targetMaxStreakSeconds,
                targetScore: targetScore,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<double?> doseG = const Value.absent(),
                Value<double?> yieldG = const Value.absent(),
                Value<double?> grindSetting = const Value.absent(),
                Value<String?> beanId = const Value.absent(),
                Value<double?> waterTempC = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> tasteScore = const Value.absent(),
                Value<String> flavourTags = const Value.absent(),
                Value<String> flavourIntensities = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<int?> coffeejackRewindTurns = const Value.absent(),
                Value<int?> coffeejackPreinfusionTurns = const Value.absent(),
                Value<String?> grinder = const Value.absent(),
                Value<String?> showerScreen = const Value.absent(),
                Value<String?> basket = const Value.absent(),
                Value<String?> scale = const Value.absent(),
                Value<String?> brewer = const Value.absent(),
                Value<DateTime?> lastModifiedAt = const Value.absent(),
                Value<double?> autoStartPressureBar = const Value.absent(),
                Value<double?> targetClosenessPercent = const Value.absent(),
                Value<int?> targetMaxStreakSeconds = const Value.absent(),
                Value<double?> targetScore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShotsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                doseG: doseG,
                yieldG: yieldG,
                grindSetting: grindSetting,
                beanId: beanId,
                waterTempC: waterTempC,
                notes: notes,
                tasteScore: tasteScore,
                flavourTags: flavourTags,
                flavourIntensities: flavourIntensities,
                location: location,
                latitude: latitude,
                longitude: longitude,
                coffeejackRewindTurns: coffeejackRewindTurns,
                coffeejackPreinfusionTurns: coffeejackPreinfusionTurns,
                grinder: grinder,
                showerScreen: showerScreen,
                basket: basket,
                scale: scale,
                brewer: brewer,
                lastModifiedAt: lastModifiedAt,
                autoStartPressureBar: autoStartPressureBar,
                targetClosenessPercent: targetClosenessPercent,
                targetMaxStreakSeconds: targetMaxStreakSeconds,
                targetScore: targetScore,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ShotsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                shotSamplesRefs = false,
                shotAnnotationsRefs = false,
                shotTagsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (shotSamplesRefs) db.shotSamples,
                    if (shotAnnotationsRefs) db.shotAnnotations,
                    if (shotTagsRefs) db.shotTags,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (shotSamplesRefs)
                        await $_getPrefetchedData<
                          ShotRow,
                          $ShotsTable,
                          ShotSampleRow
                        >(
                          currentTable: table,
                          referencedTable: $$ShotsTableReferences
                              ._shotSamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShotsTableReferences(
                                db,
                                table,
                                p0,
                              ).shotSamplesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.shotId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (shotAnnotationsRefs)
                        await $_getPrefetchedData<
                          ShotRow,
                          $ShotsTable,
                          ShotAnnotationRow
                        >(
                          currentTable: table,
                          referencedTable: $$ShotsTableReferences
                              ._shotAnnotationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShotsTableReferences(
                                db,
                                table,
                                p0,
                              ).shotAnnotationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.shotId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (shotTagsRefs)
                        await $_getPrefetchedData<
                          ShotRow,
                          $ShotsTable,
                          ShotTagRow
                        >(
                          currentTable: table,
                          referencedTable: $$ShotsTableReferences
                              ._shotTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShotsTableReferences(
                                db,
                                table,
                                p0,
                              ).shotTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.shotId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ShotsTableProcessedTableManager =
    ProcessedTableManager<
      _$FlowlogDatabase,
      $ShotsTable,
      ShotRow,
      $$ShotsTableFilterComposer,
      $$ShotsTableOrderingComposer,
      $$ShotsTableAnnotationComposer,
      $$ShotsTableCreateCompanionBuilder,
      $$ShotsTableUpdateCompanionBuilder,
      (ShotRow, $$ShotsTableReferences),
      ShotRow,
      PrefetchHooks Function({
        bool shotSamplesRefs,
        bool shotAnnotationsRefs,
        bool shotTagsRefs,
      })
    >;
typedef $$ShotSamplesTableCreateCompanionBuilder =
    ShotSamplesCompanion Function({
      Value<int> id,
      required String shotId,
      required int elapsedMs,
      Value<double?> pressureBar,
      Value<double?> weightG,
      Value<double?> flowGs,
      Value<double?> tempC,
    });
typedef $$ShotSamplesTableUpdateCompanionBuilder =
    ShotSamplesCompanion Function({
      Value<int> id,
      Value<String> shotId,
      Value<int> elapsedMs,
      Value<double?> pressureBar,
      Value<double?> weightG,
      Value<double?> flowGs,
      Value<double?> tempC,
    });

final class $$ShotSamplesTableReferences
    extends
        BaseReferences<_$FlowlogDatabase, $ShotSamplesTable, ShotSampleRow> {
  $$ShotSamplesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ShotsTable _shotIdTable(_$FlowlogDatabase db) =>
      db.shots.createAlias('shot_samples__shot_id__shots__id');

  $$ShotsTableProcessedTableManager get shotId {
    final $_column = $_itemColumn<String>('shot_id')!;

    final manager = $$ShotsTableTableManager(
      $_db,
      $_db.shots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShotSamplesTableFilterComposer
    extends Composer<_$FlowlogDatabase, $ShotSamplesTable> {
  $$ShotSamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pressureBar => $composableBuilder(
    column: $table.pressureBar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightG => $composableBuilder(
    column: $table.weightG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get flowGs => $composableBuilder(
    column: $table.flowGs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tempC => $composableBuilder(
    column: $table.tempC,
    builder: (column) => ColumnFilters(column),
  );

  $$ShotsTableFilterComposer get shotId {
    final $$ShotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableFilterComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotSamplesTableOrderingComposer
    extends Composer<_$FlowlogDatabase, $ShotSamplesTable> {
  $$ShotSamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pressureBar => $composableBuilder(
    column: $table.pressureBar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightG => $composableBuilder(
    column: $table.weightG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get flowGs => $composableBuilder(
    column: $table.flowGs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tempC => $composableBuilder(
    column: $table.tempC,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShotsTableOrderingComposer get shotId {
    final $$ShotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableOrderingComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotSamplesTableAnnotationComposer
    extends Composer<_$FlowlogDatabase, $ShotSamplesTable> {
  $$ShotSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get elapsedMs =>
      $composableBuilder(column: $table.elapsedMs, builder: (column) => column);

  GeneratedColumn<double> get pressureBar => $composableBuilder(
    column: $table.pressureBar,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weightG =>
      $composableBuilder(column: $table.weightG, builder: (column) => column);

  GeneratedColumn<double> get flowGs =>
      $composableBuilder(column: $table.flowGs, builder: (column) => column);

  GeneratedColumn<double> get tempC =>
      $composableBuilder(column: $table.tempC, builder: (column) => column);

  $$ShotsTableAnnotationComposer get shotId {
    final $$ShotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableAnnotationComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotSamplesTableTableManager
    extends
        RootTableManager<
          _$FlowlogDatabase,
          $ShotSamplesTable,
          ShotSampleRow,
          $$ShotSamplesTableFilterComposer,
          $$ShotSamplesTableOrderingComposer,
          $$ShotSamplesTableAnnotationComposer,
          $$ShotSamplesTableCreateCompanionBuilder,
          $$ShotSamplesTableUpdateCompanionBuilder,
          (ShotSampleRow, $$ShotSamplesTableReferences),
          ShotSampleRow,
          PrefetchHooks Function({bool shotId})
        > {
  $$ShotSamplesTableTableManager(_$FlowlogDatabase db, $ShotSamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShotSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShotSamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShotSamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> shotId = const Value.absent(),
                Value<int> elapsedMs = const Value.absent(),
                Value<double?> pressureBar = const Value.absent(),
                Value<double?> weightG = const Value.absent(),
                Value<double?> flowGs = const Value.absent(),
                Value<double?> tempC = const Value.absent(),
              }) => ShotSamplesCompanion(
                id: id,
                shotId: shotId,
                elapsedMs: elapsedMs,
                pressureBar: pressureBar,
                weightG: weightG,
                flowGs: flowGs,
                tempC: tempC,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String shotId,
                required int elapsedMs,
                Value<double?> pressureBar = const Value.absent(),
                Value<double?> weightG = const Value.absent(),
                Value<double?> flowGs = const Value.absent(),
                Value<double?> tempC = const Value.absent(),
              }) => ShotSamplesCompanion.insert(
                id: id,
                shotId: shotId,
                elapsedMs: elapsedMs,
                pressureBar: pressureBar,
                weightG: weightG,
                flowGs: flowGs,
                tempC: tempC,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShotSamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (shotId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.shotId,
                                referencedTable: $$ShotSamplesTableReferences
                                    ._shotIdTable(db),
                                referencedColumn: $$ShotSamplesTableReferences
                                    ._shotIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShotSamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$FlowlogDatabase,
      $ShotSamplesTable,
      ShotSampleRow,
      $$ShotSamplesTableFilterComposer,
      $$ShotSamplesTableOrderingComposer,
      $$ShotSamplesTableAnnotationComposer,
      $$ShotSamplesTableCreateCompanionBuilder,
      $$ShotSamplesTableUpdateCompanionBuilder,
      (ShotSampleRow, $$ShotSamplesTableReferences),
      ShotSampleRow,
      PrefetchHooks Function({bool shotId})
    >;
typedef $$ShotAnnotationsTableCreateCompanionBuilder =
    ShotAnnotationsCompanion Function({
      Value<int> id,
      required String shotId,
      required int elapsedMs,
      required String label,
      required String type,
    });
typedef $$ShotAnnotationsTableUpdateCompanionBuilder =
    ShotAnnotationsCompanion Function({
      Value<int> id,
      Value<String> shotId,
      Value<int> elapsedMs,
      Value<String> label,
      Value<String> type,
    });

final class $$ShotAnnotationsTableReferences
    extends
        BaseReferences<
          _$FlowlogDatabase,
          $ShotAnnotationsTable,
          ShotAnnotationRow
        > {
  $$ShotAnnotationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShotsTable _shotIdTable(_$FlowlogDatabase db) =>
      db.shots.createAlias('shot_annotations__shot_id__shots__id');

  $$ShotsTableProcessedTableManager get shotId {
    final $_column = $_itemColumn<String>('shot_id')!;

    final manager = $$ShotsTableTableManager(
      $_db,
      $_db.shots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShotAnnotationsTableFilterComposer
    extends Composer<_$FlowlogDatabase, $ShotAnnotationsTable> {
  $$ShotAnnotationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  $$ShotsTableFilterComposer get shotId {
    final $$ShotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableFilterComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotAnnotationsTableOrderingComposer
    extends Composer<_$FlowlogDatabase, $ShotAnnotationsTable> {
  $$ShotAnnotationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShotsTableOrderingComposer get shotId {
    final $$ShotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableOrderingComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotAnnotationsTableAnnotationComposer
    extends Composer<_$FlowlogDatabase, $ShotAnnotationsTable> {
  $$ShotAnnotationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get elapsedMs =>
      $composableBuilder(column: $table.elapsedMs, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  $$ShotsTableAnnotationComposer get shotId {
    final $$ShotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableAnnotationComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotAnnotationsTableTableManager
    extends
        RootTableManager<
          _$FlowlogDatabase,
          $ShotAnnotationsTable,
          ShotAnnotationRow,
          $$ShotAnnotationsTableFilterComposer,
          $$ShotAnnotationsTableOrderingComposer,
          $$ShotAnnotationsTableAnnotationComposer,
          $$ShotAnnotationsTableCreateCompanionBuilder,
          $$ShotAnnotationsTableUpdateCompanionBuilder,
          (ShotAnnotationRow, $$ShotAnnotationsTableReferences),
          ShotAnnotationRow,
          PrefetchHooks Function({bool shotId})
        > {
  $$ShotAnnotationsTableTableManager(
    _$FlowlogDatabase db,
    $ShotAnnotationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShotAnnotationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShotAnnotationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShotAnnotationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> shotId = const Value.absent(),
                Value<int> elapsedMs = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> type = const Value.absent(),
              }) => ShotAnnotationsCompanion(
                id: id,
                shotId: shotId,
                elapsedMs: elapsedMs,
                label: label,
                type: type,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String shotId,
                required int elapsedMs,
                required String label,
                required String type,
              }) => ShotAnnotationsCompanion.insert(
                id: id,
                shotId: shotId,
                elapsedMs: elapsedMs,
                label: label,
                type: type,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShotAnnotationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (shotId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.shotId,
                                referencedTable:
                                    $$ShotAnnotationsTableReferences
                                        ._shotIdTable(db),
                                referencedColumn:
                                    $$ShotAnnotationsTableReferences
                                        ._shotIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShotAnnotationsTableProcessedTableManager =
    ProcessedTableManager<
      _$FlowlogDatabase,
      $ShotAnnotationsTable,
      ShotAnnotationRow,
      $$ShotAnnotationsTableFilterComposer,
      $$ShotAnnotationsTableOrderingComposer,
      $$ShotAnnotationsTableAnnotationComposer,
      $$ShotAnnotationsTableCreateCompanionBuilder,
      $$ShotAnnotationsTableUpdateCompanionBuilder,
      (ShotAnnotationRow, $$ShotAnnotationsTableReferences),
      ShotAnnotationRow,
      PrefetchHooks Function({bool shotId})
    >;
typedef $$BeansTableCreateCompanionBuilder =
    BeansCompanion Function({
      required String id,
      required String name,
      Value<String?> brand,
      Value<String?> origin,
      Value<String?> roastLevel,
      Value<DateTime?> roastDate,
      Value<String?> process,
      Value<String?> variety,
      Value<double?> stockG,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$BeansTableUpdateCompanionBuilder =
    BeansCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> brand,
      Value<String?> origin,
      Value<String?> roastLevel,
      Value<DateTime?> roastDate,
      Value<String?> process,
      Value<String?> variety,
      Value<double?> stockG,
      Value<String?> notes,
      Value<int> rowid,
    });

class $$BeansTableFilterComposer
    extends Composer<_$FlowlogDatabase, $BeansTable> {
  $$BeansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roastLevel => $composableBuilder(
    column: $table.roastLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get roastDate =>
      $composableBuilder(
        column: $table.roastDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get process => $composableBuilder(
    column: $table.process,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variety => $composableBuilder(
    column: $table.variety,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stockG => $composableBuilder(
    column: $table.stockG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BeansTableOrderingComposer
    extends Composer<_$FlowlogDatabase, $BeansTable> {
  $$BeansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roastLevel => $composableBuilder(
    column: $table.roastLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roastDate => $composableBuilder(
    column: $table.roastDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get process => $composableBuilder(
    column: $table.process,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variety => $composableBuilder(
    column: $table.variety,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stockG => $composableBuilder(
    column: $table.stockG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BeansTableAnnotationComposer
    extends Composer<_$FlowlogDatabase, $BeansTable> {
  $$BeansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get roastLevel => $composableBuilder(
    column: $table.roastLevel,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, String> get roastDate =>
      $composableBuilder(column: $table.roastDate, builder: (column) => column);

  GeneratedColumn<String> get process =>
      $composableBuilder(column: $table.process, builder: (column) => column);

  GeneratedColumn<String> get variety =>
      $composableBuilder(column: $table.variety, builder: (column) => column);

  GeneratedColumn<double> get stockG =>
      $composableBuilder(column: $table.stockG, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$BeansTableTableManager
    extends
        RootTableManager<
          _$FlowlogDatabase,
          $BeansTable,
          BeanRow,
          $$BeansTableFilterComposer,
          $$BeansTableOrderingComposer,
          $$BeansTableAnnotationComposer,
          $$BeansTableCreateCompanionBuilder,
          $$BeansTableUpdateCompanionBuilder,
          (BeanRow, BaseReferences<_$FlowlogDatabase, $BeansTable, BeanRow>),
          BeanRow,
          PrefetchHooks Function()
        > {
  $$BeansTableTableManager(_$FlowlogDatabase db, $BeansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BeansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BeansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BeansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> roastLevel = const Value.absent(),
                Value<DateTime?> roastDate = const Value.absent(),
                Value<String?> process = const Value.absent(),
                Value<String?> variety = const Value.absent(),
                Value<double?> stockG = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BeansCompanion(
                id: id,
                name: name,
                brand: brand,
                origin: origin,
                roastLevel: roastLevel,
                roastDate: roastDate,
                process: process,
                variety: variety,
                stockG: stockG,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> brand = const Value.absent(),
                Value<String?> origin = const Value.absent(),
                Value<String?> roastLevel = const Value.absent(),
                Value<DateTime?> roastDate = const Value.absent(),
                Value<String?> process = const Value.absent(),
                Value<String?> variety = const Value.absent(),
                Value<double?> stockG = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BeansCompanion.insert(
                id: id,
                name: name,
                brand: brand,
                origin: origin,
                roastLevel: roastLevel,
                roastDate: roastDate,
                process: process,
                variety: variety,
                stockG: stockG,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BeansTableProcessedTableManager =
    ProcessedTableManager<
      _$FlowlogDatabase,
      $BeansTable,
      BeanRow,
      $$BeansTableFilterComposer,
      $$BeansTableOrderingComposer,
      $$BeansTableAnnotationComposer,
      $$BeansTableCreateCompanionBuilder,
      $$BeansTableUpdateCompanionBuilder,
      (BeanRow, BaseReferences<_$FlowlogDatabase, $BeansTable, BeanRow>),
      BeanRow,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String name,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> rowid,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$FlowlogDatabase, $TagsTable, TagRow> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ShotTagsTable, List<ShotTagRow>>
  _shotTagsRefsTable(_$FlowlogDatabase db) => MultiTypedResultKey.fromTable(
    db.shotTags,
    aliasName: 'tags__id__shot_tags__tag_id',
  );

  $$ShotTagsTableProcessedTableManager get shotTagsRefs {
    final manager = $$ShotTagsTableTableManager(
      $_db,
      $_db.shotTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_shotTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer
    extends Composer<_$FlowlogDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> shotTagsRefs(
    Expression<bool> Function($$ShotTagsTableFilterComposer f) f,
  ) {
    final $$ShotTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotTagsTableFilterComposer(
            $db: $db,
            $table: $db.shotTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer
    extends Composer<_$FlowlogDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$FlowlogDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> shotTagsRefs<T extends Object>(
    Expression<T> Function($$ShotTagsTableAnnotationComposer a) f,
  ) {
    final $$ShotTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shotTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.shotTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$FlowlogDatabase,
          $TagsTable,
          TagRow,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (TagRow, $$TagsTableReferences),
          TagRow,
          PrefetchHooks Function({bool shotTagsRefs})
        > {
  $$TagsTableTableManager(_$FlowlogDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(id: id, name: name, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(id: id, name: name, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({shotTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (shotTagsRefs) db.shotTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (shotTagsRefs)
                    await $_getPrefetchedData<TagRow, $TagsTable, ShotTagRow>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences._shotTagsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).shotTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$FlowlogDatabase,
      $TagsTable,
      TagRow,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (TagRow, $$TagsTableReferences),
      TagRow,
      PrefetchHooks Function({bool shotTagsRefs})
    >;
typedef $$ShotTagsTableCreateCompanionBuilder =
    ShotTagsCompanion Function({
      required String shotId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$ShotTagsTableUpdateCompanionBuilder =
    ShotTagsCompanion Function({
      Value<String> shotId,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$ShotTagsTableReferences
    extends BaseReferences<_$FlowlogDatabase, $ShotTagsTable, ShotTagRow> {
  $$ShotTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ShotsTable _shotIdTable(_$FlowlogDatabase db) =>
      db.shots.createAlias('shot_tags__shot_id__shots__id');

  $$ShotsTableProcessedTableManager get shotId {
    final $_column = $_itemColumn<String>('shot_id')!;

    final manager = $$ShotsTableTableManager(
      $_db,
      $_db.shots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$FlowlogDatabase db) =>
      db.tags.createAlias('shot_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShotTagsTableFilterComposer
    extends Composer<_$FlowlogDatabase, $ShotTagsTable> {
  $$ShotTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ShotsTableFilterComposer get shotId {
    final $$ShotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableFilterComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotTagsTableOrderingComposer
    extends Composer<_$FlowlogDatabase, $ShotTagsTable> {
  $$ShotTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ShotsTableOrderingComposer get shotId {
    final $$ShotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableOrderingComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotTagsTableAnnotationComposer
    extends Composer<_$FlowlogDatabase, $ShotTagsTable> {
  $$ShotTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ShotsTableAnnotationComposer get shotId {
    final $$ShotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shotId,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableAnnotationComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotTagsTableTableManager
    extends
        RootTableManager<
          _$FlowlogDatabase,
          $ShotTagsTable,
          ShotTagRow,
          $$ShotTagsTableFilterComposer,
          $$ShotTagsTableOrderingComposer,
          $$ShotTagsTableAnnotationComposer,
          $$ShotTagsTableCreateCompanionBuilder,
          $$ShotTagsTableUpdateCompanionBuilder,
          (ShotTagRow, $$ShotTagsTableReferences),
          ShotTagRow,
          PrefetchHooks Function({bool shotId, bool tagId})
        > {
  $$ShotTagsTableTableManager(_$FlowlogDatabase db, $ShotTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShotTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShotTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShotTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> shotId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  ShotTagsCompanion(shotId: shotId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required String shotId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => ShotTagsCompanion.insert(
                shotId: shotId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShotTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shotId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (shotId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.shotId,
                                referencedTable: $$ShotTagsTableReferences
                                    ._shotIdTable(db),
                                referencedColumn: $$ShotTagsTableReferences
                                    ._shotIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$ShotTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$ShotTagsTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShotTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$FlowlogDatabase,
      $ShotTagsTable,
      ShotTagRow,
      $$ShotTagsTableFilterComposer,
      $$ShotTagsTableOrderingComposer,
      $$ShotTagsTableAnnotationComposer,
      $$ShotTagsTableCreateCompanionBuilder,
      $$ShotTagsTableUpdateCompanionBuilder,
      (ShotTagRow, $$ShotTagsTableReferences),
      ShotTagRow,
      PrefetchHooks Function({bool shotId, bool tagId})
    >;
typedef $$SavedProfilesTableCreateCompanionBuilder =
    SavedProfilesCompanion Function({
      required String id,
      required String name,
      required DateTime createdAt,
      Value<String?> sourceShotId,
      Value<double?> doseG,
      Value<double?> yieldG,
      Value<double?> grindSetting,
      Value<String?> beanId,
      Value<double?> waterTempC,
      Value<int> rowid,
    });
typedef $$SavedProfilesTableUpdateCompanionBuilder =
    SavedProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<String?> sourceShotId,
      Value<double?> doseG,
      Value<double?> yieldG,
      Value<double?> grindSetting,
      Value<String?> beanId,
      Value<double?> waterTempC,
      Value<int> rowid,
    });

final class $$SavedProfilesTableReferences
    extends
        BaseReferences<
          _$FlowlogDatabase,
          $SavedProfilesTable,
          SavedProfileRow
        > {
  $$SavedProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $SavedProfileSamplesTable,
    List<SavedProfileSampleRow>
  >
  _savedProfileSamplesRefsTable(_$FlowlogDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.savedProfileSamples,
        aliasName: 'saved_profiles__id__saved_profile_samples__profile_id',
      );

  $$SavedProfileSamplesTableProcessedTableManager get savedProfileSamplesRefs {
    final manager = $$SavedProfileSamplesTableTableManager(
      $_db,
      $_db.savedProfileSamples,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _savedProfileSamplesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SavedProfilesTableFilterComposer
    extends Composer<_$FlowlogDatabase, $SavedProfilesTable> {
  $$SavedProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get sourceShotId => $composableBuilder(
    column: $table.sourceShotId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get doseG => $composableBuilder(
    column: $table.doseG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get yieldG => $composableBuilder(
    column: $table.yieldG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grindSetting => $composableBuilder(
    column: $table.grindSetting,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beanId => $composableBuilder(
    column: $table.beanId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get waterTempC => $composableBuilder(
    column: $table.waterTempC,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> savedProfileSamplesRefs(
    Expression<bool> Function($$SavedProfileSamplesTableFilterComposer f) f,
  ) {
    final $$SavedProfileSamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedProfileSamples,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedProfileSamplesTableFilterComposer(
            $db: $db,
            $table: $db.savedProfileSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedProfilesTableOrderingComposer
    extends Composer<_$FlowlogDatabase, $SavedProfilesTable> {
  $$SavedProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceShotId => $composableBuilder(
    column: $table.sourceShotId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get doseG => $composableBuilder(
    column: $table.doseG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get yieldG => $composableBuilder(
    column: $table.yieldG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grindSetting => $composableBuilder(
    column: $table.grindSetting,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beanId => $composableBuilder(
    column: $table.beanId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get waterTempC => $composableBuilder(
    column: $table.waterTempC,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedProfilesTableAnnotationComposer
    extends Composer<_$FlowlogDatabase, $SavedProfilesTable> {
  $$SavedProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get sourceShotId => $composableBuilder(
    column: $table.sourceShotId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get doseG =>
      $composableBuilder(column: $table.doseG, builder: (column) => column);

  GeneratedColumn<double> get yieldG =>
      $composableBuilder(column: $table.yieldG, builder: (column) => column);

  GeneratedColumn<double> get grindSetting => $composableBuilder(
    column: $table.grindSetting,
    builder: (column) => column,
  );

  GeneratedColumn<String> get beanId =>
      $composableBuilder(column: $table.beanId, builder: (column) => column);

  GeneratedColumn<double> get waterTempC => $composableBuilder(
    column: $table.waterTempC,
    builder: (column) => column,
  );

  Expression<T> savedProfileSamplesRefs<T extends Object>(
    Expression<T> Function($$SavedProfileSamplesTableAnnotationComposer a) f,
  ) {
    final $$SavedProfileSamplesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.savedProfileSamples,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SavedProfileSamplesTableAnnotationComposer(
                $db: $db,
                $table: $db.savedProfileSamples,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SavedProfilesTableTableManager
    extends
        RootTableManager<
          _$FlowlogDatabase,
          $SavedProfilesTable,
          SavedProfileRow,
          $$SavedProfilesTableFilterComposer,
          $$SavedProfilesTableOrderingComposer,
          $$SavedProfilesTableAnnotationComposer,
          $$SavedProfilesTableCreateCompanionBuilder,
          $$SavedProfilesTableUpdateCompanionBuilder,
          (SavedProfileRow, $$SavedProfilesTableReferences),
          SavedProfileRow,
          PrefetchHooks Function({bool savedProfileSamplesRefs})
        > {
  $$SavedProfilesTableTableManager(
    _$FlowlogDatabase db,
    $SavedProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> sourceShotId = const Value.absent(),
                Value<double?> doseG = const Value.absent(),
                Value<double?> yieldG = const Value.absent(),
                Value<double?> grindSetting = const Value.absent(),
                Value<String?> beanId = const Value.absent(),
                Value<double?> waterTempC = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedProfilesCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                sourceShotId: sourceShotId,
                doseG: doseG,
                yieldG: yieldG,
                grindSetting: grindSetting,
                beanId: beanId,
                waterTempC: waterTempC,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdAt,
                Value<String?> sourceShotId = const Value.absent(),
                Value<double?> doseG = const Value.absent(),
                Value<double?> yieldG = const Value.absent(),
                Value<double?> grindSetting = const Value.absent(),
                Value<String?> beanId = const Value.absent(),
                Value<double?> waterTempC = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedProfilesCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                sourceShotId: sourceShotId,
                doseG: doseG,
                yieldG: yieldG,
                grindSetting: grindSetting,
                beanId: beanId,
                waterTempC: waterTempC,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({savedProfileSamplesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (savedProfileSamplesRefs) db.savedProfileSamples,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (savedProfileSamplesRefs)
                    await $_getPrefetchedData<
                      SavedProfileRow,
                      $SavedProfilesTable,
                      SavedProfileSampleRow
                    >(
                      currentTable: table,
                      referencedTable: $$SavedProfilesTableReferences
                          ._savedProfileSamplesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SavedProfilesTableReferences(
                            db,
                            table,
                            p0,
                          ).savedProfileSamplesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.profileId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SavedProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$FlowlogDatabase,
      $SavedProfilesTable,
      SavedProfileRow,
      $$SavedProfilesTableFilterComposer,
      $$SavedProfilesTableOrderingComposer,
      $$SavedProfilesTableAnnotationComposer,
      $$SavedProfilesTableCreateCompanionBuilder,
      $$SavedProfilesTableUpdateCompanionBuilder,
      (SavedProfileRow, $$SavedProfilesTableReferences),
      SavedProfileRow,
      PrefetchHooks Function({bool savedProfileSamplesRefs})
    >;
typedef $$SavedProfileSamplesTableCreateCompanionBuilder =
    SavedProfileSamplesCompanion Function({
      Value<int> id,
      required String profileId,
      required int elapsedMs,
      required double pressureBar,
    });
typedef $$SavedProfileSamplesTableUpdateCompanionBuilder =
    SavedProfileSamplesCompanion Function({
      Value<int> id,
      Value<String> profileId,
      Value<int> elapsedMs,
      Value<double> pressureBar,
    });

final class $$SavedProfileSamplesTableReferences
    extends
        BaseReferences<
          _$FlowlogDatabase,
          $SavedProfileSamplesTable,
          SavedProfileSampleRow
        > {
  $$SavedProfileSamplesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SavedProfilesTable _profileIdTable(_$FlowlogDatabase db) => db
      .savedProfiles
      .createAlias('saved_profile_samples__profile_id__saved_profiles__id');

  $$SavedProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$SavedProfilesTableTableManager(
      $_db,
      $_db.savedProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SavedProfileSamplesTableFilterComposer
    extends Composer<_$FlowlogDatabase, $SavedProfileSamplesTable> {
  $$SavedProfileSamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pressureBar => $composableBuilder(
    column: $table.pressureBar,
    builder: (column) => ColumnFilters(column),
  );

  $$SavedProfilesTableFilterComposer get profileId {
    final $$SavedProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.savedProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedProfilesTableFilterComposer(
            $db: $db,
            $table: $db.savedProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedProfileSamplesTableOrderingComposer
    extends Composer<_$FlowlogDatabase, $SavedProfileSamplesTable> {
  $$SavedProfileSamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pressureBar => $composableBuilder(
    column: $table.pressureBar,
    builder: (column) => ColumnOrderings(column),
  );

  $$SavedProfilesTableOrderingComposer get profileId {
    final $$SavedProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.savedProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.savedProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedProfileSamplesTableAnnotationComposer
    extends Composer<_$FlowlogDatabase, $SavedProfileSamplesTable> {
  $$SavedProfileSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get elapsedMs =>
      $composableBuilder(column: $table.elapsedMs, builder: (column) => column);

  GeneratedColumn<double> get pressureBar => $composableBuilder(
    column: $table.pressureBar,
    builder: (column) => column,
  );

  $$SavedProfilesTableAnnotationComposer get profileId {
    final $$SavedProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.savedProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.savedProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedProfileSamplesTableTableManager
    extends
        RootTableManager<
          _$FlowlogDatabase,
          $SavedProfileSamplesTable,
          SavedProfileSampleRow,
          $$SavedProfileSamplesTableFilterComposer,
          $$SavedProfileSamplesTableOrderingComposer,
          $$SavedProfileSamplesTableAnnotationComposer,
          $$SavedProfileSamplesTableCreateCompanionBuilder,
          $$SavedProfileSamplesTableUpdateCompanionBuilder,
          (SavedProfileSampleRow, $$SavedProfileSamplesTableReferences),
          SavedProfileSampleRow,
          PrefetchHooks Function({bool profileId})
        > {
  $$SavedProfileSamplesTableTableManager(
    _$FlowlogDatabase db,
    $SavedProfileSamplesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedProfileSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedProfileSamplesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SavedProfileSamplesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> elapsedMs = const Value.absent(),
                Value<double> pressureBar = const Value.absent(),
              }) => SavedProfileSamplesCompanion(
                id: id,
                profileId: profileId,
                elapsedMs: elapsedMs,
                pressureBar: pressureBar,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String profileId,
                required int elapsedMs,
                required double pressureBar,
              }) => SavedProfileSamplesCompanion.insert(
                id: id,
                profileId: profileId,
                elapsedMs: elapsedMs,
                pressureBar: pressureBar,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedProfileSamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable:
                                    $$SavedProfileSamplesTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$SavedProfileSamplesTableReferences
                                        ._profileIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SavedProfileSamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$FlowlogDatabase,
      $SavedProfileSamplesTable,
      SavedProfileSampleRow,
      $$SavedProfileSamplesTableFilterComposer,
      $$SavedProfileSamplesTableOrderingComposer,
      $$SavedProfileSamplesTableAnnotationComposer,
      $$SavedProfileSamplesTableCreateCompanionBuilder,
      $$SavedProfileSamplesTableUpdateCompanionBuilder,
      (SavedProfileSampleRow, $$SavedProfileSamplesTableReferences),
      SavedProfileSampleRow,
      PrefetchHooks Function({bool profileId})
    >;

class $FlowlogDatabaseManager {
  final _$FlowlogDatabase _db;
  $FlowlogDatabaseManager(this._db);
  $$ShotsTableTableManager get shots =>
      $$ShotsTableTableManager(_db, _db.shots);
  $$ShotSamplesTableTableManager get shotSamples =>
      $$ShotSamplesTableTableManager(_db, _db.shotSamples);
  $$ShotAnnotationsTableTableManager get shotAnnotations =>
      $$ShotAnnotationsTableTableManager(_db, _db.shotAnnotations);
  $$BeansTableTableManager get beans =>
      $$BeansTableTableManager(_db, _db.beans);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$ShotTagsTableTableManager get shotTags =>
      $$ShotTagsTableTableManager(_db, _db.shotTags);
  $$SavedProfilesTableTableManager get savedProfiles =>
      $$SavedProfilesTableTableManager(_db, _db.savedProfiles);
  $$SavedProfileSamplesTableTableManager get savedProfileSamples =>
      $$SavedProfileSamplesTableTableManager(_db, _db.savedProfileSamples);
}
