// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RoutinesTableTable extends RoutinesTable
    with TableInfo<$RoutinesTableTable, Routine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutinesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _blockCountMeta = const VerificationMeta(
    'blockCount',
  );
  @override
  late final GeneratedColumn<int> blockCount = GeneratedColumn<int>(
    'block_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPublicMeta = const VerificationMeta(
    'isPublic',
  );
  @override
  late final GeneratedColumn<bool> isPublic = GeneratedColumn<bool>(
    'is_public',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_public" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    blockCount,
    isPublic,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routines';
  @override
  VerificationContext validateIntegrity(
    Insertable<Routine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('block_count')) {
      context.handle(
        _blockCountMeta,
        blockCount.isAcceptableOrUnknown(data['block_count']!, _blockCountMeta),
      );
    }
    if (data.containsKey('is_public')) {
      context.handle(
        _isPublicMeta,
        isPublic.isAcceptableOrUnknown(data['is_public']!, _isPublicMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Routine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Routine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      blockCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}block_count'],
      )!,
      isPublic: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_public'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RoutinesTableTable createAlias(String alias) {
    return $RoutinesTableTable(attachedDatabase, alias);
  }
}

class Routine extends DataClass implements Insertable<Routine> {
  final int id;
  final String name;
  final String description;
  final int blockCount;
  final bool isPublic;
  final DateTime updatedAt;
  const Routine({
    required this.id,
    required this.name,
    required this.description,
    required this.blockCount,
    required this.isPublic,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['block_count'] = Variable<int>(blockCount);
    map['is_public'] = Variable<bool>(isPublic);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RoutinesTableCompanion toCompanion(bool nullToAbsent) {
    return RoutinesTableCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      blockCount: Value(blockCount),
      isPublic: Value(isPublic),
      updatedAt: Value(updatedAt),
    );
  }

  factory Routine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Routine(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      blockCount: serializer.fromJson<int>(json['blockCount']),
      isPublic: serializer.fromJson<bool>(json['isPublic']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'blockCount': serializer.toJson<int>(blockCount),
      'isPublic': serializer.toJson<bool>(isPublic),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Routine copyWith({
    int? id,
    String? name,
    String? description,
    int? blockCount,
    bool? isPublic,
    DateTime? updatedAt,
  }) => Routine(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    blockCount: blockCount ?? this.blockCount,
    isPublic: isPublic ?? this.isPublic,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Routine copyWithCompanion(RoutinesTableCompanion data) {
    return Routine(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      blockCount: data.blockCount.present
          ? data.blockCount.value
          : this.blockCount,
      isPublic: data.isPublic.present ? data.isPublic.value : this.isPublic,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Routine(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('blockCount: $blockCount, ')
          ..write('isPublic: $isPublic, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, blockCount, isPublic, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Routine &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.blockCount == this.blockCount &&
          other.isPublic == this.isPublic &&
          other.updatedAt == this.updatedAt);
}

class RoutinesTableCompanion extends UpdateCompanion<Routine> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> description;
  final Value<int> blockCount;
  final Value<bool> isPublic;
  final Value<DateTime> updatedAt;
  const RoutinesTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.blockCount = const Value.absent(),
    this.isPublic = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RoutinesTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.blockCount = const Value.absent(),
    this.isPublic = const Value.absent(),
    required DateTime updatedAt,
  }) : name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<Routine> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? blockCount,
    Expression<bool>? isPublic,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (blockCount != null) 'block_count': blockCount,
      if (isPublic != null) 'is_public': isPublic,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RoutinesTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? description,
    Value<int>? blockCount,
    Value<bool>? isPublic,
    Value<DateTime>? updatedAt,
  }) {
    return RoutinesTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      blockCount: blockCount ?? this.blockCount,
      isPublic: isPublic ?? this.isPublic,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (blockCount.present) {
      map['block_count'] = Variable<int>(blockCount.value);
    }
    if (isPublic.present) {
      map['is_public'] = Variable<bool>(isPublic.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutinesTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('blockCount: $blockCount, ')
          ..write('isPublic: $isPublic, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSessionsTableTable extends WorkoutSessionsTable
    with TableInfo<$WorkoutSessionsTableTable, WorkoutSessionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSessionsTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workflowIdMeta = const VerificationMeta(
    'workflowId',
  );
  @override
  late final GeneratedColumn<int> workflowId = GeneratedColumn<int>(
    'workflow_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionTitleMeta = const VerificationMeta(
    'sectionTitle',
  );
  @override
  late final GeneratedColumn<String> sectionTitle = GeneratedColumn<String>(
    'section_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientId,
    serverId,
    workflowId,
    sectionId,
    sectionTitle,
    status,
    startedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSessionData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('workflow_id')) {
      context.handle(
        _workflowIdMeta,
        workflowId.isAcceptableOrUnknown(data['workflow_id']!, _workflowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workflowIdMeta);
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sectionIdMeta);
    }
    if (data.containsKey('section_title')) {
      context.handle(
        _sectionTitleMeta,
        sectionTitle.isAcceptableOrUnknown(
          data['section_title']!,
          _sectionTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sectionTitleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSessionData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSessionData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      workflowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}workflow_id'],
      )!,
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      )!,
      sectionTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_title'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $WorkoutSessionsTableTable createAlias(String alias) {
    return $WorkoutSessionsTableTable(attachedDatabase, alias);
  }
}

class WorkoutSessionData extends DataClass
    implements Insertable<WorkoutSessionData> {
  final int id;
  final String clientId;
  final int? serverId;
  final int workflowId;
  final String sectionId;
  final String sectionTitle;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  const WorkoutSessionData({
    required this.id,
    required this.clientId,
    this.serverId,
    required this.workflowId,
    required this.sectionId,
    required this.sectionTitle,
    required this.status,
    required this.startedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_id'] = Variable<String>(clientId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['workflow_id'] = Variable<int>(workflowId);
    map['section_id'] = Variable<String>(sectionId);
    map['section_title'] = Variable<String>(sectionTitle);
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  WorkoutSessionsTableCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSessionsTableCompanion(
      id: Value(id),
      clientId: Value(clientId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      workflowId: Value(workflowId),
      sectionId: Value(sectionId),
      sectionTitle: Value(sectionTitle),
      status: Value(status),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory WorkoutSessionData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSessionData(
      id: serializer.fromJson<int>(json['id']),
      clientId: serializer.fromJson<String>(json['clientId']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      workflowId: serializer.fromJson<int>(json['workflowId']),
      sectionId: serializer.fromJson<String>(json['sectionId']),
      sectionTitle: serializer.fromJson<String>(json['sectionTitle']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientId': serializer.toJson<String>(clientId),
      'serverId': serializer.toJson<int?>(serverId),
      'workflowId': serializer.toJson<int>(workflowId),
      'sectionId': serializer.toJson<String>(sectionId),
      'sectionTitle': serializer.toJson<String>(sectionTitle),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  WorkoutSessionData copyWith({
    int? id,
    String? clientId,
    Value<int?> serverId = const Value.absent(),
    int? workflowId,
    String? sectionId,
    String? sectionTitle,
    String? status,
    DateTime? startedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => WorkoutSessionData(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    serverId: serverId.present ? serverId.value : this.serverId,
    workflowId: workflowId ?? this.workflowId,
    sectionId: sectionId ?? this.sectionId,
    sectionTitle: sectionTitle ?? this.sectionTitle,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  WorkoutSessionData copyWithCompanion(WorkoutSessionsTableCompanion data) {
    return WorkoutSessionData(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      workflowId: data.workflowId.present
          ? data.workflowId.value
          : this.workflowId,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      sectionTitle: data.sectionTitle.present
          ? data.sectionTitle.value
          : this.sectionTitle,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionData(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('serverId: $serverId, ')
          ..write('workflowId: $workflowId, ')
          ..write('sectionId: $sectionId, ')
          ..write('sectionTitle: $sectionTitle, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientId,
    serverId,
    workflowId,
    sectionId,
    sectionTitle,
    status,
    startedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSessionData &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.serverId == this.serverId &&
          other.workflowId == this.workflowId &&
          other.sectionId == this.sectionId &&
          other.sectionTitle == this.sectionTitle &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt);
}

class WorkoutSessionsTableCompanion
    extends UpdateCompanion<WorkoutSessionData> {
  final Value<int> id;
  final Value<String> clientId;
  final Value<int?> serverId;
  final Value<int> workflowId;
  final Value<String> sectionId;
  final Value<String> sectionTitle;
  final Value<String> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  const WorkoutSessionsTableCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.workflowId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.sectionTitle = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  WorkoutSessionsTableCompanion.insert({
    this.id = const Value.absent(),
    required String clientId,
    this.serverId = const Value.absent(),
    required int workflowId,
    required String sectionId,
    required String sectionTitle,
    this.status = const Value.absent(),
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
  }) : clientId = Value(clientId),
       workflowId = Value(workflowId),
       sectionId = Value(sectionId),
       sectionTitle = Value(sectionTitle),
       startedAt = Value(startedAt);
  static Insertable<WorkoutSessionData> custom({
    Expression<int>? id,
    Expression<String>? clientId,
    Expression<int>? serverId,
    Expression<int>? workflowId,
    Expression<String>? sectionId,
    Expression<String>? sectionTitle,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (serverId != null) 'server_id': serverId,
      if (workflowId != null) 'workflow_id': workflowId,
      if (sectionId != null) 'section_id': sectionId,
      if (sectionTitle != null) 'section_title': sectionTitle,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  WorkoutSessionsTableCompanion copyWith({
    Value<int>? id,
    Value<String>? clientId,
    Value<int?>? serverId,
    Value<int>? workflowId,
    Value<String>? sectionId,
    Value<String>? sectionTitle,
    Value<String>? status,
    Value<DateTime>? startedAt,
    Value<DateTime?>? completedAt,
  }) {
    return WorkoutSessionsTableCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      serverId: serverId ?? this.serverId,
      workflowId: workflowId ?? this.workflowId,
      sectionId: sectionId ?? this.sectionId,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (workflowId.present) {
      map['workflow_id'] = Variable<int>(workflowId.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (sectionTitle.present) {
      map['section_title'] = Variable<String>(sectionTitle.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionsTableCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('serverId: $serverId, ')
          ..write('workflowId: $workflowId, ')
          ..write('sectionId: $sectionId, ')
          ..write('sectionTitle: $sectionTitle, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSetLogsTableTable extends WorkoutSetLogsTable
    with TableInfo<$WorkoutSetLogsTableTable, WorkoutSetLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSetLogsTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sessionClientIdMeta = const VerificationMeta(
    'sessionClientId',
  );
  @override
  late final GeneratedColumn<String> sessionClientId = GeneratedColumn<String>(
    'session_client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockClientIdMeta = const VerificationMeta(
    'blockClientId',
  );
  @override
  late final GeneratedColumn<String> blockClientId = GeneratedColumn<String>(
    'block_client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeTypeSlugMeta = const VerificationMeta(
    'nodeTypeSlug',
  );
  @override
  late final GeneratedColumn<String> nodeTypeSlug = GeneratedColumn<String>(
    'node_type_slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setIndexMeta = const VerificationMeta(
    'setIndex',
  );
  @override
  late final GeneratedColumn<int> setIndex = GeneratedColumn<int>(
    'set_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prescribedRepsMeta = const VerificationMeta(
    'prescribedReps',
  );
  @override
  late final GeneratedColumn<String> prescribedReps = GeneratedColumn<String>(
    'prescribed_reps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _prescribedLoadMeta = const VerificationMeta(
    'prescribedLoad',
  );
  @override
  late final GeneratedColumn<String> prescribedLoad = GeneratedColumn<String>(
    'prescribed_load',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _actualRepsMeta = const VerificationMeta(
    'actualReps',
  );
  @override
  late final GeneratedColumn<String> actualReps = GeneratedColumn<String>(
    'actual_reps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _actualLoadMeta = const VerificationMeta(
    'actualLoad',
  );
  @override
  late final GeneratedColumn<String> actualLoad = GeneratedColumn<String>(
    'actual_load',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _actualRpeMeta = const VerificationMeta(
    'actualRpe',
  );
  @override
  late final GeneratedColumn<String> actualRpe = GeneratedColumn<String>(
    'actual_rpe',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientId,
    sessionClientId,
    serverId,
    blockClientId,
    nodeTypeSlug,
    setIndex,
    prescribedReps,
    prescribedLoad,
    actualReps,
    actualLoad,
    actualRpe,
    completed,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_set_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSetLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('session_client_id')) {
      context.handle(
        _sessionClientIdMeta,
        sessionClientId.isAcceptableOrUnknown(
          data['session_client_id']!,
          _sessionClientIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionClientIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('block_client_id')) {
      context.handle(
        _blockClientIdMeta,
        blockClientId.isAcceptableOrUnknown(
          data['block_client_id']!,
          _blockClientIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_blockClientIdMeta);
    }
    if (data.containsKey('node_type_slug')) {
      context.handle(
        _nodeTypeSlugMeta,
        nodeTypeSlug.isAcceptableOrUnknown(
          data['node_type_slug']!,
          _nodeTypeSlugMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nodeTypeSlugMeta);
    }
    if (data.containsKey('set_index')) {
      context.handle(
        _setIndexMeta,
        setIndex.isAcceptableOrUnknown(data['set_index']!, _setIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_setIndexMeta);
    }
    if (data.containsKey('prescribed_reps')) {
      context.handle(
        _prescribedRepsMeta,
        prescribedReps.isAcceptableOrUnknown(
          data['prescribed_reps']!,
          _prescribedRepsMeta,
        ),
      );
    }
    if (data.containsKey('prescribed_load')) {
      context.handle(
        _prescribedLoadMeta,
        prescribedLoad.isAcceptableOrUnknown(
          data['prescribed_load']!,
          _prescribedLoadMeta,
        ),
      );
    }
    if (data.containsKey('actual_reps')) {
      context.handle(
        _actualRepsMeta,
        actualReps.isAcceptableOrUnknown(data['actual_reps']!, _actualRepsMeta),
      );
    }
    if (data.containsKey('actual_load')) {
      context.handle(
        _actualLoadMeta,
        actualLoad.isAcceptableOrUnknown(data['actual_load']!, _actualLoadMeta),
      );
    }
    if (data.containsKey('actual_rpe')) {
      context.handle(
        _actualRpeMeta,
        actualRpe.isAcceptableOrUnknown(data['actual_rpe']!, _actualRpeMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSetLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSetLogData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      sessionClientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_client_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      blockClientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_client_id'],
      )!,
      nodeTypeSlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_type_slug'],
      )!,
      setIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_index'],
      )!,
      prescribedReps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prescribed_reps'],
      )!,
      prescribedLoad: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prescribed_load'],
      )!,
      actualReps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actual_reps'],
      )!,
      actualLoad: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actual_load'],
      )!,
      actualRpe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actual_rpe'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WorkoutSetLogsTableTable createAlias(String alias) {
    return $WorkoutSetLogsTableTable(attachedDatabase, alias);
  }
}

class WorkoutSetLogData extends DataClass
    implements Insertable<WorkoutSetLogData> {
  final int id;
  final String clientId;
  final String sessionClientId;
  final int? serverId;
  final String blockClientId;
  final String nodeTypeSlug;
  final int setIndex;
  final String prescribedReps;
  final String prescribedLoad;
  final String actualReps;
  final String actualLoad;
  final String actualRpe;
  final bool completed;
  final DateTime createdAt;
  const WorkoutSetLogData({
    required this.id,
    required this.clientId,
    required this.sessionClientId,
    this.serverId,
    required this.blockClientId,
    required this.nodeTypeSlug,
    required this.setIndex,
    required this.prescribedReps,
    required this.prescribedLoad,
    required this.actualReps,
    required this.actualLoad,
    required this.actualRpe,
    required this.completed,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_id'] = Variable<String>(clientId);
    map['session_client_id'] = Variable<String>(sessionClientId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['block_client_id'] = Variable<String>(blockClientId);
    map['node_type_slug'] = Variable<String>(nodeTypeSlug);
    map['set_index'] = Variable<int>(setIndex);
    map['prescribed_reps'] = Variable<String>(prescribedReps);
    map['prescribed_load'] = Variable<String>(prescribedLoad);
    map['actual_reps'] = Variable<String>(actualReps);
    map['actual_load'] = Variable<String>(actualLoad);
    map['actual_rpe'] = Variable<String>(actualRpe);
    map['completed'] = Variable<bool>(completed);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WorkoutSetLogsTableCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetLogsTableCompanion(
      id: Value(id),
      clientId: Value(clientId),
      sessionClientId: Value(sessionClientId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      blockClientId: Value(blockClientId),
      nodeTypeSlug: Value(nodeTypeSlug),
      setIndex: Value(setIndex),
      prescribedReps: Value(prescribedReps),
      prescribedLoad: Value(prescribedLoad),
      actualReps: Value(actualReps),
      actualLoad: Value(actualLoad),
      actualRpe: Value(actualRpe),
      completed: Value(completed),
      createdAt: Value(createdAt),
    );
  }

  factory WorkoutSetLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSetLogData(
      id: serializer.fromJson<int>(json['id']),
      clientId: serializer.fromJson<String>(json['clientId']),
      sessionClientId: serializer.fromJson<String>(json['sessionClientId']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      blockClientId: serializer.fromJson<String>(json['blockClientId']),
      nodeTypeSlug: serializer.fromJson<String>(json['nodeTypeSlug']),
      setIndex: serializer.fromJson<int>(json['setIndex']),
      prescribedReps: serializer.fromJson<String>(json['prescribedReps']),
      prescribedLoad: serializer.fromJson<String>(json['prescribedLoad']),
      actualReps: serializer.fromJson<String>(json['actualReps']),
      actualLoad: serializer.fromJson<String>(json['actualLoad']),
      actualRpe: serializer.fromJson<String>(json['actualRpe']),
      completed: serializer.fromJson<bool>(json['completed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientId': serializer.toJson<String>(clientId),
      'sessionClientId': serializer.toJson<String>(sessionClientId),
      'serverId': serializer.toJson<int?>(serverId),
      'blockClientId': serializer.toJson<String>(blockClientId),
      'nodeTypeSlug': serializer.toJson<String>(nodeTypeSlug),
      'setIndex': serializer.toJson<int>(setIndex),
      'prescribedReps': serializer.toJson<String>(prescribedReps),
      'prescribedLoad': serializer.toJson<String>(prescribedLoad),
      'actualReps': serializer.toJson<String>(actualReps),
      'actualLoad': serializer.toJson<String>(actualLoad),
      'actualRpe': serializer.toJson<String>(actualRpe),
      'completed': serializer.toJson<bool>(completed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WorkoutSetLogData copyWith({
    int? id,
    String? clientId,
    String? sessionClientId,
    Value<int?> serverId = const Value.absent(),
    String? blockClientId,
    String? nodeTypeSlug,
    int? setIndex,
    String? prescribedReps,
    String? prescribedLoad,
    String? actualReps,
    String? actualLoad,
    String? actualRpe,
    bool? completed,
    DateTime? createdAt,
  }) => WorkoutSetLogData(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    sessionClientId: sessionClientId ?? this.sessionClientId,
    serverId: serverId.present ? serverId.value : this.serverId,
    blockClientId: blockClientId ?? this.blockClientId,
    nodeTypeSlug: nodeTypeSlug ?? this.nodeTypeSlug,
    setIndex: setIndex ?? this.setIndex,
    prescribedReps: prescribedReps ?? this.prescribedReps,
    prescribedLoad: prescribedLoad ?? this.prescribedLoad,
    actualReps: actualReps ?? this.actualReps,
    actualLoad: actualLoad ?? this.actualLoad,
    actualRpe: actualRpe ?? this.actualRpe,
    completed: completed ?? this.completed,
    createdAt: createdAt ?? this.createdAt,
  );
  WorkoutSetLogData copyWithCompanion(WorkoutSetLogsTableCompanion data) {
    return WorkoutSetLogData(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      sessionClientId: data.sessionClientId.present
          ? data.sessionClientId.value
          : this.sessionClientId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      blockClientId: data.blockClientId.present
          ? data.blockClientId.value
          : this.blockClientId,
      nodeTypeSlug: data.nodeTypeSlug.present
          ? data.nodeTypeSlug.value
          : this.nodeTypeSlug,
      setIndex: data.setIndex.present ? data.setIndex.value : this.setIndex,
      prescribedReps: data.prescribedReps.present
          ? data.prescribedReps.value
          : this.prescribedReps,
      prescribedLoad: data.prescribedLoad.present
          ? data.prescribedLoad.value
          : this.prescribedLoad,
      actualReps: data.actualReps.present
          ? data.actualReps.value
          : this.actualReps,
      actualLoad: data.actualLoad.present
          ? data.actualLoad.value
          : this.actualLoad,
      actualRpe: data.actualRpe.present ? data.actualRpe.value : this.actualRpe,
      completed: data.completed.present ? data.completed.value : this.completed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetLogData(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('sessionClientId: $sessionClientId, ')
          ..write('serverId: $serverId, ')
          ..write('blockClientId: $blockClientId, ')
          ..write('nodeTypeSlug: $nodeTypeSlug, ')
          ..write('setIndex: $setIndex, ')
          ..write('prescribedReps: $prescribedReps, ')
          ..write('prescribedLoad: $prescribedLoad, ')
          ..write('actualReps: $actualReps, ')
          ..write('actualLoad: $actualLoad, ')
          ..write('actualRpe: $actualRpe, ')
          ..write('completed: $completed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientId,
    sessionClientId,
    serverId,
    blockClientId,
    nodeTypeSlug,
    setIndex,
    prescribedReps,
    prescribedLoad,
    actualReps,
    actualLoad,
    actualRpe,
    completed,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSetLogData &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.sessionClientId == this.sessionClientId &&
          other.serverId == this.serverId &&
          other.blockClientId == this.blockClientId &&
          other.nodeTypeSlug == this.nodeTypeSlug &&
          other.setIndex == this.setIndex &&
          other.prescribedReps == this.prescribedReps &&
          other.prescribedLoad == this.prescribedLoad &&
          other.actualReps == this.actualReps &&
          other.actualLoad == this.actualLoad &&
          other.actualRpe == this.actualRpe &&
          other.completed == this.completed &&
          other.createdAt == this.createdAt);
}

class WorkoutSetLogsTableCompanion extends UpdateCompanion<WorkoutSetLogData> {
  final Value<int> id;
  final Value<String> clientId;
  final Value<String> sessionClientId;
  final Value<int?> serverId;
  final Value<String> blockClientId;
  final Value<String> nodeTypeSlug;
  final Value<int> setIndex;
  final Value<String> prescribedReps;
  final Value<String> prescribedLoad;
  final Value<String> actualReps;
  final Value<String> actualLoad;
  final Value<String> actualRpe;
  final Value<bool> completed;
  final Value<DateTime> createdAt;
  const WorkoutSetLogsTableCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.sessionClientId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.blockClientId = const Value.absent(),
    this.nodeTypeSlug = const Value.absent(),
    this.setIndex = const Value.absent(),
    this.prescribedReps = const Value.absent(),
    this.prescribedLoad = const Value.absent(),
    this.actualReps = const Value.absent(),
    this.actualLoad = const Value.absent(),
    this.actualRpe = const Value.absent(),
    this.completed = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WorkoutSetLogsTableCompanion.insert({
    this.id = const Value.absent(),
    required String clientId,
    required String sessionClientId,
    this.serverId = const Value.absent(),
    required String blockClientId,
    required String nodeTypeSlug,
    required int setIndex,
    this.prescribedReps = const Value.absent(),
    this.prescribedLoad = const Value.absent(),
    this.actualReps = const Value.absent(),
    this.actualLoad = const Value.absent(),
    this.actualRpe = const Value.absent(),
    this.completed = const Value.absent(),
    required DateTime createdAt,
  }) : clientId = Value(clientId),
       sessionClientId = Value(sessionClientId),
       blockClientId = Value(blockClientId),
       nodeTypeSlug = Value(nodeTypeSlug),
       setIndex = Value(setIndex),
       createdAt = Value(createdAt);
  static Insertable<WorkoutSetLogData> custom({
    Expression<int>? id,
    Expression<String>? clientId,
    Expression<String>? sessionClientId,
    Expression<int>? serverId,
    Expression<String>? blockClientId,
    Expression<String>? nodeTypeSlug,
    Expression<int>? setIndex,
    Expression<String>? prescribedReps,
    Expression<String>? prescribedLoad,
    Expression<String>? actualReps,
    Expression<String>? actualLoad,
    Expression<String>? actualRpe,
    Expression<bool>? completed,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (sessionClientId != null) 'session_client_id': sessionClientId,
      if (serverId != null) 'server_id': serverId,
      if (blockClientId != null) 'block_client_id': blockClientId,
      if (nodeTypeSlug != null) 'node_type_slug': nodeTypeSlug,
      if (setIndex != null) 'set_index': setIndex,
      if (prescribedReps != null) 'prescribed_reps': prescribedReps,
      if (prescribedLoad != null) 'prescribed_load': prescribedLoad,
      if (actualReps != null) 'actual_reps': actualReps,
      if (actualLoad != null) 'actual_load': actualLoad,
      if (actualRpe != null) 'actual_rpe': actualRpe,
      if (completed != null) 'completed': completed,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WorkoutSetLogsTableCompanion copyWith({
    Value<int>? id,
    Value<String>? clientId,
    Value<String>? sessionClientId,
    Value<int?>? serverId,
    Value<String>? blockClientId,
    Value<String>? nodeTypeSlug,
    Value<int>? setIndex,
    Value<String>? prescribedReps,
    Value<String>? prescribedLoad,
    Value<String>? actualReps,
    Value<String>? actualLoad,
    Value<String>? actualRpe,
    Value<bool>? completed,
    Value<DateTime>? createdAt,
  }) {
    return WorkoutSetLogsTableCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      sessionClientId: sessionClientId ?? this.sessionClientId,
      serverId: serverId ?? this.serverId,
      blockClientId: blockClientId ?? this.blockClientId,
      nodeTypeSlug: nodeTypeSlug ?? this.nodeTypeSlug,
      setIndex: setIndex ?? this.setIndex,
      prescribedReps: prescribedReps ?? this.prescribedReps,
      prescribedLoad: prescribedLoad ?? this.prescribedLoad,
      actualReps: actualReps ?? this.actualReps,
      actualLoad: actualLoad ?? this.actualLoad,
      actualRpe: actualRpe ?? this.actualRpe,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (sessionClientId.present) {
      map['session_client_id'] = Variable<String>(sessionClientId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (blockClientId.present) {
      map['block_client_id'] = Variable<String>(blockClientId.value);
    }
    if (nodeTypeSlug.present) {
      map['node_type_slug'] = Variable<String>(nodeTypeSlug.value);
    }
    if (setIndex.present) {
      map['set_index'] = Variable<int>(setIndex.value);
    }
    if (prescribedReps.present) {
      map['prescribed_reps'] = Variable<String>(prescribedReps.value);
    }
    if (prescribedLoad.present) {
      map['prescribed_load'] = Variable<String>(prescribedLoad.value);
    }
    if (actualReps.present) {
      map['actual_reps'] = Variable<String>(actualReps.value);
    }
    if (actualLoad.present) {
      map['actual_load'] = Variable<String>(actualLoad.value);
    }
    if (actualRpe.present) {
      map['actual_rpe'] = Variable<String>(actualRpe.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetLogsTableCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('sessionClientId: $sessionClientId, ')
          ..write('serverId: $serverId, ')
          ..write('blockClientId: $blockClientId, ')
          ..write('nodeTypeSlug: $nodeTypeSlug, ')
          ..write('setIndex: $setIndex, ')
          ..write('prescribedReps: $prescribedReps, ')
          ..write('prescribedLoad: $prescribedLoad, ')
          ..write('actualReps: $actualReps, ')
          ..write('actualLoad: $actualLoad, ')
          ..write('actualRpe: $actualRpe, ')
          ..write('completed: $completed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTableTable extends SyncQueueTable
    with TableInfo<$SyncQueueTableTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityClientIdMeta = const VerificationMeta(
    'entityClientId',
  );
  @override
  late final GeneratedColumn<String> entityClientId = GeneratedColumn<String>(
    'entity_client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityClientId,
    entityType,
    action,
    payload,
    status,
    attempts,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_client_id')) {
      context.handle(
        _entityClientIdMeta,
        entityClientId.isAcceptableOrUnknown(
          data['entity_client_id']!,
          _entityClientIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entityClientIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityClientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_client_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncQueueTableTable createAlias(String alias) {
    return $SyncQueueTableTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;
  final String entityClientId;
  final String entityType;
  final String action;
  final String payload;
  final String status;
  final int attempts;
  final DateTime createdAt;
  const SyncQueueData({
    required this.id,
    required this.entityClientId,
    required this.entityType,
    required this.action,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_client_id'] = Variable<String>(entityClientId);
    map['entity_type'] = Variable<String>(entityType);
    map['action'] = Variable<String>(action);
    map['payload'] = Variable<String>(payload);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncQueueTableCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueTableCompanion(
      id: Value(id),
      entityClientId: Value(entityClientId),
      entityType: Value(entityType),
      action: Value(action),
      payload: Value(payload),
      status: Value(status),
      attempts: Value(attempts),
      createdAt: Value(createdAt),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      entityClientId: serializer.fromJson<String>(json['entityClientId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      action: serializer.fromJson<String>(json['action']),
      payload: serializer.fromJson<String>(json['payload']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityClientId': serializer.toJson<String>(entityClientId),
      'entityType': serializer.toJson<String>(entityType),
      'action': serializer.toJson<String>(action),
      'payload': serializer.toJson<String>(payload),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncQueueData copyWith({
    int? id,
    String? entityClientId,
    String? entityType,
    String? action,
    String? payload,
    String? status,
    int? attempts,
    DateTime? createdAt,
  }) => SyncQueueData(
    id: id ?? this.id,
    entityClientId: entityClientId ?? this.entityClientId,
    entityType: entityType ?? this.entityType,
    action: action ?? this.action,
    payload: payload ?? this.payload,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    createdAt: createdAt ?? this.createdAt,
  );
  SyncQueueData copyWithCompanion(SyncQueueTableCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      entityClientId: data.entityClientId.present
          ? data.entityClientId.value
          : this.entityClientId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      action: data.action.present ? data.action.value : this.action,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('entityClientId: $entityClientId, ')
          ..write('entityType: $entityType, ')
          ..write('action: $action, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityClientId,
    entityType,
    action,
    payload,
    status,
    attempts,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.entityClientId == this.entityClientId &&
          other.entityType == this.entityType &&
          other.action == this.action &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.createdAt == this.createdAt);
}

class SyncQueueTableCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> entityClientId;
  final Value<String> entityType;
  final Value<String> action;
  final Value<String> payload;
  final Value<String> status;
  final Value<int> attempts;
  final Value<DateTime> createdAt;
  const SyncQueueTableCompanion({
    this.id = const Value.absent(),
    this.entityClientId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.action = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyncQueueTableCompanion.insert({
    this.id = const Value.absent(),
    required String entityClientId,
    required String entityType,
    required String action,
    required String payload,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    required DateTime createdAt,
  }) : entityClientId = Value(entityClientId),
       entityType = Value(entityType),
       action = Value(action),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? entityClientId,
    Expression<String>? entityType,
    Expression<String>? action,
    Expression<String>? payload,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityClientId != null) 'entity_client_id': entityClientId,
      if (entityType != null) 'entity_type': entityType,
      if (action != null) 'action': action,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyncQueueTableCompanion copyWith({
    Value<int>? id,
    Value<String>? entityClientId,
    Value<String>? entityType,
    Value<String>? action,
    Value<String>? payload,
    Value<String>? status,
    Value<int>? attempts,
    Value<DateTime>? createdAt,
  }) {
    return SyncQueueTableCompanion(
      id: id ?? this.id,
      entityClientId: entityClientId ?? this.entityClientId,
      entityType: entityType ?? this.entityType,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityClientId.present) {
      map['entity_client_id'] = Variable<String>(entityClientId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueTableCompanion(')
          ..write('id: $id, ')
          ..write('entityClientId: $entityClientId, ')
          ..write('entityType: $entityType, ')
          ..write('action: $action, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RoutinesTableTable routinesTable = $RoutinesTableTable(this);
  late final $WorkoutSessionsTableTable workoutSessionsTable =
      $WorkoutSessionsTableTable(this);
  late final $WorkoutSetLogsTableTable workoutSetLogsTable =
      $WorkoutSetLogsTableTable(this);
  late final $SyncQueueTableTable syncQueueTable = $SyncQueueTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    routinesTable,
    workoutSessionsTable,
    workoutSetLogsTable,
    syncQueueTable,
  ];
}

typedef $$RoutinesTableTableCreateCompanionBuilder =
    RoutinesTableCompanion Function({
      Value<int> id,
      required String name,
      Value<String> description,
      Value<int> blockCount,
      Value<bool> isPublic,
      required DateTime updatedAt,
    });
typedef $$RoutinesTableTableUpdateCompanionBuilder =
    RoutinesTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> description,
      Value<int> blockCount,
      Value<bool> isPublic,
      Value<DateTime> updatedAt,
    });

class $$RoutinesTableTableFilterComposer
    extends Composer<_$AppDatabase, $RoutinesTableTable> {
  $$RoutinesTableTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blockCount => $composableBuilder(
    column: $table.blockCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPublic => $composableBuilder(
    column: $table.isPublic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RoutinesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutinesTableTable> {
  $$RoutinesTableTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blockCount => $composableBuilder(
    column: $table.blockCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPublic => $composableBuilder(
    column: $table.isPublic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutinesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutinesTableTable> {
  $$RoutinesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blockCount => $composableBuilder(
    column: $table.blockCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPublic =>
      $composableBuilder(column: $table.isPublic, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RoutinesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutinesTableTable,
          Routine,
          $$RoutinesTableTableFilterComposer,
          $$RoutinesTableTableOrderingComposer,
          $$RoutinesTableTableAnnotationComposer,
          $$RoutinesTableTableCreateCompanionBuilder,
          $$RoutinesTableTableUpdateCompanionBuilder,
          (
            Routine,
            BaseReferences<_$AppDatabase, $RoutinesTableTable, Routine>,
          ),
          Routine,
          PrefetchHooks Function()
        > {
  $$RoutinesTableTableTableManager(_$AppDatabase db, $RoutinesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutinesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutinesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutinesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> blockCount = const Value.absent(),
                Value<bool> isPublic = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => RoutinesTableCompanion(
                id: id,
                name: name,
                description: description,
                blockCount: blockCount,
                isPublic: isPublic,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> description = const Value.absent(),
                Value<int> blockCount = const Value.absent(),
                Value<bool> isPublic = const Value.absent(),
                required DateTime updatedAt,
              }) => RoutinesTableCompanion.insert(
                id: id,
                name: name,
                description: description,
                blockCount: blockCount,
                isPublic: isPublic,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RoutinesTableTable, Routine>(table),
                  BaseReferences<_$AppDatabase, $RoutinesTableTable, Routine>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RoutinesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutinesTableTable,
      Routine,
      $$RoutinesTableTableFilterComposer,
      $$RoutinesTableTableOrderingComposer,
      $$RoutinesTableTableAnnotationComposer,
      $$RoutinesTableTableCreateCompanionBuilder,
      $$RoutinesTableTableUpdateCompanionBuilder,
      (Routine, BaseReferences<_$AppDatabase, $RoutinesTableTable, Routine>),
      Routine,
      PrefetchHooks Function()
    >;
typedef $$WorkoutSessionsTableTableCreateCompanionBuilder =
    WorkoutSessionsTableCompanion Function({
      Value<int> id,
      required String clientId,
      Value<int?> serverId,
      required int workflowId,
      required String sectionId,
      required String sectionTitle,
      Value<String> status,
      required DateTime startedAt,
      Value<DateTime?> completedAt,
    });
typedef $$WorkoutSessionsTableTableUpdateCompanionBuilder =
    WorkoutSessionsTableCompanion Function({
      Value<int> id,
      Value<String> clientId,
      Value<int?> serverId,
      Value<int> workflowId,
      Value<String> sectionId,
      Value<String> sectionTitle,
      Value<String> status,
      Value<DateTime> startedAt,
      Value<DateTime?> completedAt,
    });

class $$WorkoutSessionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTableTable> {
  $$WorkoutSessionsTableTableFilterComposer({
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

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get workflowId => $composableBuilder(
    column: $table.workflowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionTitle => $composableBuilder(
    column: $table.sectionTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkoutSessionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTableTable> {
  $$WorkoutSessionsTableTableOrderingComposer({
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

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get workflowId => $composableBuilder(
    column: $table.workflowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionTitle => $composableBuilder(
    column: $table.sectionTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutSessionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTableTable> {
  $$WorkoutSessionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get workflowId => $composableBuilder(
    column: $table.workflowId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get sectionTitle => $composableBuilder(
    column: $table.sectionTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$WorkoutSessionsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSessionsTableTable,
          WorkoutSessionData,
          $$WorkoutSessionsTableTableFilterComposer,
          $$WorkoutSessionsTableTableOrderingComposer,
          $$WorkoutSessionsTableTableAnnotationComposer,
          $$WorkoutSessionsTableTableCreateCompanionBuilder,
          $$WorkoutSessionsTableTableUpdateCompanionBuilder,
          (
            WorkoutSessionData,
            BaseReferences<
              _$AppDatabase,
              $WorkoutSessionsTableTable,
              WorkoutSessionData
            >,
          ),
          WorkoutSessionData,
          PrefetchHooks Function()
        > {
  $$WorkoutSessionsTableTableTableManager(
    _$AppDatabase db,
    $WorkoutSessionsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSessionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSessionsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkoutSessionsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<int> workflowId = const Value.absent(),
                Value<String> sectionId = const Value.absent(),
                Value<String> sectionTitle = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => WorkoutSessionsTableCompanion(
                id: id,
                clientId: clientId,
                serverId: serverId,
                workflowId: workflowId,
                sectionId: sectionId,
                sectionTitle: sectionTitle,
                status: status,
                startedAt: startedAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientId,
                Value<int?> serverId = const Value.absent(),
                required int workflowId,
                required String sectionId,
                required String sectionTitle,
                Value<String> status = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> completedAt = const Value.absent(),
              }) => WorkoutSessionsTableCompanion.insert(
                id: id,
                clientId: clientId,
                serverId: serverId,
                workflowId: workflowId,
                sectionId: sectionId,
                sectionTitle: sectionTitle,
                status: status,
                startedAt: startedAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutSessionsTableTable, WorkoutSessionData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $WorkoutSessionsTableTable,
                    WorkoutSessionData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkoutSessionsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSessionsTableTable,
      WorkoutSessionData,
      $$WorkoutSessionsTableTableFilterComposer,
      $$WorkoutSessionsTableTableOrderingComposer,
      $$WorkoutSessionsTableTableAnnotationComposer,
      $$WorkoutSessionsTableTableCreateCompanionBuilder,
      $$WorkoutSessionsTableTableUpdateCompanionBuilder,
      (
        WorkoutSessionData,
        BaseReferences<
          _$AppDatabase,
          $WorkoutSessionsTableTable,
          WorkoutSessionData
        >,
      ),
      WorkoutSessionData,
      PrefetchHooks Function()
    >;
typedef $$WorkoutSetLogsTableTableCreateCompanionBuilder =
    WorkoutSetLogsTableCompanion Function({
      Value<int> id,
      required String clientId,
      required String sessionClientId,
      Value<int?> serverId,
      required String blockClientId,
      required String nodeTypeSlug,
      required int setIndex,
      Value<String> prescribedReps,
      Value<String> prescribedLoad,
      Value<String> actualReps,
      Value<String> actualLoad,
      Value<String> actualRpe,
      Value<bool> completed,
      required DateTime createdAt,
    });
typedef $$WorkoutSetLogsTableTableUpdateCompanionBuilder =
    WorkoutSetLogsTableCompanion Function({
      Value<int> id,
      Value<String> clientId,
      Value<String> sessionClientId,
      Value<int?> serverId,
      Value<String> blockClientId,
      Value<String> nodeTypeSlug,
      Value<int> setIndex,
      Value<String> prescribedReps,
      Value<String> prescribedLoad,
      Value<String> actualReps,
      Value<String> actualLoad,
      Value<String> actualRpe,
      Value<bool> completed,
      Value<DateTime> createdAt,
    });

class $$WorkoutSetLogsTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSetLogsTableTable> {
  $$WorkoutSetLogsTableTableFilterComposer({
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

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionClientId => $composableBuilder(
    column: $table.sessionClientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockClientId => $composableBuilder(
    column: $table.blockClientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeTypeSlug => $composableBuilder(
    column: $table.nodeTypeSlug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setIndex => $composableBuilder(
    column: $table.setIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prescribedReps => $composableBuilder(
    column: $table.prescribedReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prescribedLoad => $composableBuilder(
    column: $table.prescribedLoad,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actualReps => $composableBuilder(
    column: $table.actualReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actualLoad => $composableBuilder(
    column: $table.actualLoad,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actualRpe => $composableBuilder(
    column: $table.actualRpe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkoutSetLogsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSetLogsTableTable> {
  $$WorkoutSetLogsTableTableOrderingComposer({
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

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionClientId => $composableBuilder(
    column: $table.sessionClientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockClientId => $composableBuilder(
    column: $table.blockClientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeTypeSlug => $composableBuilder(
    column: $table.nodeTypeSlug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setIndex => $composableBuilder(
    column: $table.setIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prescribedReps => $composableBuilder(
    column: $table.prescribedReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prescribedLoad => $composableBuilder(
    column: $table.prescribedLoad,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actualReps => $composableBuilder(
    column: $table.actualReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actualLoad => $composableBuilder(
    column: $table.actualLoad,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actualRpe => $composableBuilder(
    column: $table.actualRpe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutSetLogsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSetLogsTableTable> {
  $$WorkoutSetLogsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get sessionClientId => $composableBuilder(
    column: $table.sessionClientId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get blockClientId => $composableBuilder(
    column: $table.blockClientId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nodeTypeSlug => $composableBuilder(
    column: $table.nodeTypeSlug,
    builder: (column) => column,
  );

  GeneratedColumn<int> get setIndex =>
      $composableBuilder(column: $table.setIndex, builder: (column) => column);

  GeneratedColumn<String> get prescribedReps => $composableBuilder(
    column: $table.prescribedReps,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prescribedLoad => $composableBuilder(
    column: $table.prescribedLoad,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actualReps => $composableBuilder(
    column: $table.actualReps,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actualLoad => $composableBuilder(
    column: $table.actualLoad,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actualRpe =>
      $composableBuilder(column: $table.actualRpe, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WorkoutSetLogsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSetLogsTableTable,
          WorkoutSetLogData,
          $$WorkoutSetLogsTableTableFilterComposer,
          $$WorkoutSetLogsTableTableOrderingComposer,
          $$WorkoutSetLogsTableTableAnnotationComposer,
          $$WorkoutSetLogsTableTableCreateCompanionBuilder,
          $$WorkoutSetLogsTableTableUpdateCompanionBuilder,
          (
            WorkoutSetLogData,
            BaseReferences<
              _$AppDatabase,
              $WorkoutSetLogsTableTable,
              WorkoutSetLogData
            >,
          ),
          WorkoutSetLogData,
          PrefetchHooks Function()
        > {
  $$WorkoutSetLogsTableTableTableManager(
    _$AppDatabase db,
    $WorkoutSetLogsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSetLogsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSetLogsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkoutSetLogsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String> sessionClientId = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> blockClientId = const Value.absent(),
                Value<String> nodeTypeSlug = const Value.absent(),
                Value<int> setIndex = const Value.absent(),
                Value<String> prescribedReps = const Value.absent(),
                Value<String> prescribedLoad = const Value.absent(),
                Value<String> actualReps = const Value.absent(),
                Value<String> actualLoad = const Value.absent(),
                Value<String> actualRpe = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => WorkoutSetLogsTableCompanion(
                id: id,
                clientId: clientId,
                sessionClientId: sessionClientId,
                serverId: serverId,
                blockClientId: blockClientId,
                nodeTypeSlug: nodeTypeSlug,
                setIndex: setIndex,
                prescribedReps: prescribedReps,
                prescribedLoad: prescribedLoad,
                actualReps: actualReps,
                actualLoad: actualLoad,
                actualRpe: actualRpe,
                completed: completed,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientId,
                required String sessionClientId,
                Value<int?> serverId = const Value.absent(),
                required String blockClientId,
                required String nodeTypeSlug,
                required int setIndex,
                Value<String> prescribedReps = const Value.absent(),
                Value<String> prescribedLoad = const Value.absent(),
                Value<String> actualReps = const Value.absent(),
                Value<String> actualLoad = const Value.absent(),
                Value<String> actualRpe = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                required DateTime createdAt,
              }) => WorkoutSetLogsTableCompanion.insert(
                id: id,
                clientId: clientId,
                sessionClientId: sessionClientId,
                serverId: serverId,
                blockClientId: blockClientId,
                nodeTypeSlug: nodeTypeSlug,
                setIndex: setIndex,
                prescribedReps: prescribedReps,
                prescribedLoad: prescribedLoad,
                actualReps: actualReps,
                actualLoad: actualLoad,
                actualRpe: actualRpe,
                completed: completed,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutSetLogsTableTable, WorkoutSetLogData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $WorkoutSetLogsTableTable,
                    WorkoutSetLogData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkoutSetLogsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSetLogsTableTable,
      WorkoutSetLogData,
      $$WorkoutSetLogsTableTableFilterComposer,
      $$WorkoutSetLogsTableTableOrderingComposer,
      $$WorkoutSetLogsTableTableAnnotationComposer,
      $$WorkoutSetLogsTableTableCreateCompanionBuilder,
      $$WorkoutSetLogsTableTableUpdateCompanionBuilder,
      (
        WorkoutSetLogData,
        BaseReferences<
          _$AppDatabase,
          $WorkoutSetLogsTableTable,
          WorkoutSetLogData
        >,
      ),
      WorkoutSetLogData,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableTableCreateCompanionBuilder =
    SyncQueueTableCompanion Function({
      Value<int> id,
      required String entityClientId,
      required String entityType,
      required String action,
      required String payload,
      Value<String> status,
      Value<int> attempts,
      required DateTime createdAt,
    });
typedef $$SyncQueueTableTableUpdateCompanionBuilder =
    SyncQueueTableCompanion Function({
      Value<int> id,
      Value<String> entityClientId,
      Value<String> entityType,
      Value<String> action,
      Value<String> payload,
      Value<String> status,
      Value<int> attempts,
      Value<DateTime> createdAt,
    });

class $$SyncQueueTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableFilterComposer({
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

  ColumnFilters<String> get entityClientId => $composableBuilder(
    column: $table.entityClientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableOrderingComposer({
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

  ColumnOrderings<String> get entityClientId => $composableBuilder(
    column: $table.entityClientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityClientId => $composableBuilder(
    column: $table.entityClientId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncQueueTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTableTable,
          SyncQueueData,
          $$SyncQueueTableTableFilterComposer,
          $$SyncQueueTableTableOrderingComposer,
          $$SyncQueueTableTableAnnotationComposer,
          $$SyncQueueTableTableCreateCompanionBuilder,
          $$SyncQueueTableTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDatabase, $SyncQueueTableTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableTableManager(
    _$AppDatabase db,
    $SyncQueueTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityClientId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SyncQueueTableCompanion(
                id: id,
                entityClientId: entityClientId,
                entityType: entityType,
                action: action,
                payload: payload,
                status: status,
                attempts: attempts,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityClientId,
                required String entityType,
                required String action,
                required String payload,
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                required DateTime createdAt,
              }) => SyncQueueTableCompanion.insert(
                id: id,
                entityClientId: entityClientId,
                entityType: entityType,
                action: action,
                payload: payload,
                status: status,
                attempts: attempts,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncQueueTableTable, SyncQueueData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncQueueTableTable,
                    SyncQueueData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTableTable,
      SyncQueueData,
      $$SyncQueueTableTableFilterComposer,
      $$SyncQueueTableTableOrderingComposer,
      $$SyncQueueTableTableAnnotationComposer,
      $$SyncQueueTableTableCreateCompanionBuilder,
      $$SyncQueueTableTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$AppDatabase, $SyncQueueTableTable, SyncQueueData>,
      ),
      SyncQueueData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RoutinesTableTableTableManager get routinesTable =>
      $$RoutinesTableTableTableManager(_db, _db.routinesTable);
  $$WorkoutSessionsTableTableTableManager get workoutSessionsTable =>
      $$WorkoutSessionsTableTableTableManager(_db, _db.workoutSessionsTable);
  $$WorkoutSetLogsTableTableTableManager get workoutSetLogsTable =>
      $$WorkoutSetLogsTableTableTableManager(_db, _db.workoutSetLogsTable);
  $$SyncQueueTableTableTableManager get syncQueueTable =>
      $$SyncQueueTableTableTableManager(_db, _db.syncQueueTable);
}
