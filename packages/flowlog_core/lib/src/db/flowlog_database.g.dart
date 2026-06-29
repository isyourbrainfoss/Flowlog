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
          ..write('flavourTags: $flavourTags')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
  );
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
          other.flavourTags == this.flavourTags);
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

abstract class _$FlowlogDatabase extends GeneratedDatabase {
  _$FlowlogDatabase(QueryExecutor e) : super(e);
  $FlowlogDatabaseManager get managers => $FlowlogDatabaseManager(this);
  late final $ShotsTable shots = $ShotsTable(this);
  late final $ShotSamplesTable shotSamples = $ShotSamplesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [shots, shotSamples];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'shots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shot_samples', kind: UpdateKind.delete)],
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
          PrefetchHooks Function({bool shotSamplesRefs})
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
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ShotsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({shotSamplesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (shotSamplesRefs) db.shotSamples],
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
                          $$ShotsTableReferences(db, table, p0).shotSamplesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.shotId == item.id),
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
      PrefetchHooks Function({bool shotSamplesRefs})
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

class $FlowlogDatabaseManager {
  final _$FlowlogDatabase _db;
  $FlowlogDatabaseManager(this._db);
  $$ShotsTableTableManager get shots =>
      $$ShotsTableTableManager(_db, _db.shots);
  $$ShotSamplesTableTableManager get shotSamples =>
      $$ShotSamplesTableTableManager(_db, _db.shotSamples);
}
