// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FoldersTable extends Folders with TableInfo<$FoldersTable, FolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, parentId, name, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class FolderRow extends DataClass implements Insertable<FolderRow> {
  final String id;
  final String? parentId;
  final String name;
  final int position;
  const FolderRow({
    required this.id,
    this.parentId,
    required this.name,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      position: Value(position),
    );
  }

  factory FolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderRow(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
    };
  }

  FolderRow copyWith({
    String? id,
    Value<String?> parentId = const Value.absent(),
    String? name,
    int? position,
  }) => FolderRow(
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    position: position ?? this.position,
  );
  FolderRow copyWithCompanion(FoldersCompanion data) {
    return FolderRow(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderRow(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentId, name, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderRow &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.position == this.position);
}

class FoldersCompanion extends UpdateCompanion<FolderRow> {
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<int> position;
  final Value<int> rowid;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String id,
    this.parentId = const Value.absent(),
    required String name,
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<FolderRow> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith({
    Value<String>? id,
    Value<String?>? parentId,
    Value<String>? name,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SourcesTable extends Sources with TableInfo<$SourcesTable, SourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 500,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markdownMeta = const VerificationMeta(
    'markdown',
  );
  @override
  late final GeneratedColumn<String> markdown = GeneratedColumn<String>(
    'markdown',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 64,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    check: () => ComparableExpr(wordCount).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtUtcMeta = const VerificationMeta(
    'importedAtUtc',
  );
  @override
  late final GeneratedColumn<int> importedAtUtc = GeneratedColumn<int>(
    'imported_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paceMeta = const VerificationMeta('pace');
  @override
  late final GeneratedColumn<int> pace = GeneratedColumn<int>(
    'pace',
    aliasedName,
    false,
    check: () => ComparableExpr(pace).isBetweenValues(0, 2),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _markerBlockIdMeta = const VerificationMeta(
    'markerBlockId',
  );
  @override
  late final GeneratedColumn<String> markerBlockId = GeneratedColumn<String>(
    'marker_block_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _markerOffsetMeta = const VerificationMeta(
    'markerOffset',
  );
  @override
  late final GeneratedColumn<int> markerOffset = GeneratedColumn<int>(
    'marker_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _softBlockIdMeta = const VerificationMeta(
    'softBlockId',
  );
  @override
  late final GeneratedColumn<String> softBlockId = GeneratedColumn<String>(
    'soft_block_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _softOffsetMeta = const VerificationMeta(
    'softOffset',
  );
  @override
  late final GeneratedColumn<int> softOffset = GeneratedColumn<int>(
    'soft_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    markdown,
    contentHash,
    wordCount,
    importedAtUtc,
    pace,
    markerBlockId,
    markerOffset,
    softBlockId,
    softOffset,
    folderId,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('markdown')) {
      context.handle(
        _markdownMeta,
        markdown.isAcceptableOrUnknown(data['markdown']!, _markdownMeta),
      );
    } else if (isInserting) {
      context.missing(_markdownMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    } else if (isInserting) {
      context.missing(_wordCountMeta);
    }
    if (data.containsKey('imported_at_utc')) {
      context.handle(
        _importedAtUtcMeta,
        importedAtUtc.isAcceptableOrUnknown(
          data['imported_at_utc']!,
          _importedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importedAtUtcMeta);
    }
    if (data.containsKey('pace')) {
      context.handle(
        _paceMeta,
        pace.isAcceptableOrUnknown(data['pace']!, _paceMeta),
      );
    }
    if (data.containsKey('marker_block_id')) {
      context.handle(
        _markerBlockIdMeta,
        markerBlockId.isAcceptableOrUnknown(
          data['marker_block_id']!,
          _markerBlockIdMeta,
        ),
      );
    }
    if (data.containsKey('marker_offset')) {
      context.handle(
        _markerOffsetMeta,
        markerOffset.isAcceptableOrUnknown(
          data['marker_offset']!,
          _markerOffsetMeta,
        ),
      );
    }
    if (data.containsKey('soft_block_id')) {
      context.handle(
        _softBlockIdMeta,
        softBlockId.isAcceptableOrUnknown(
          data['soft_block_id']!,
          _softBlockIdMeta,
        ),
      );
    }
    if (data.containsKey('soft_offset')) {
      context.handle(
        _softOffsetMeta,
        softOffset.isAcceptableOrUnknown(data['soft_offset']!, _softOffsetMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      markdown: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}markdown'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      importedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_at_utc'],
      )!,
      pace: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pace'],
      )!,
      markerBlockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}marker_block_id'],
      ),
      markerOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}marker_offset'],
      ),
      softBlockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}soft_block_id'],
      ),
      softOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}soft_offset'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $SourcesTable createAlias(String alias) {
    return $SourcesTable(attachedDatabase, alias);
  }
}

class SourceRow extends DataClass implements Insertable<SourceRow> {
  final String id;
  final String title;

  /// Normalized original markdown. Every anchor addresses this exact text.
  final String markdown;
  final String contentHash;
  final int wordCount;
  final int importedAtUtc;

  /// Index into the reading-pace enum.
  final int pace;

  /// Explicit resume marker. Both columns are set or both are null.
  final String? markerBlockId;
  final int? markerOffset;

  /// Soft position. Never drives scheduling.
  final String? softBlockId;
  final int? softOffset;
  final String? folderId;

  /// Bumped on every write, for change detection and diagnostics.
  final int revision;
  const SourceRow({
    required this.id,
    required this.title,
    required this.markdown,
    required this.contentHash,
    required this.wordCount,
    required this.importedAtUtc,
    required this.pace,
    this.markerBlockId,
    this.markerOffset,
    this.softBlockId,
    this.softOffset,
    this.folderId,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['markdown'] = Variable<String>(markdown);
    map['content_hash'] = Variable<String>(contentHash);
    map['word_count'] = Variable<int>(wordCount);
    map['imported_at_utc'] = Variable<int>(importedAtUtc);
    map['pace'] = Variable<int>(pace);
    if (!nullToAbsent || markerBlockId != null) {
      map['marker_block_id'] = Variable<String>(markerBlockId);
    }
    if (!nullToAbsent || markerOffset != null) {
      map['marker_offset'] = Variable<int>(markerOffset);
    }
    if (!nullToAbsent || softBlockId != null) {
      map['soft_block_id'] = Variable<String>(softBlockId);
    }
    if (!nullToAbsent || softOffset != null) {
      map['soft_offset'] = Variable<int>(softOffset);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  SourcesCompanion toCompanion(bool nullToAbsent) {
    return SourcesCompanion(
      id: Value(id),
      title: Value(title),
      markdown: Value(markdown),
      contentHash: Value(contentHash),
      wordCount: Value(wordCount),
      importedAtUtc: Value(importedAtUtc),
      pace: Value(pace),
      markerBlockId: markerBlockId == null && nullToAbsent
          ? const Value.absent()
          : Value(markerBlockId),
      markerOffset: markerOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(markerOffset),
      softBlockId: softBlockId == null && nullToAbsent
          ? const Value.absent()
          : Value(softBlockId),
      softOffset: softOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(softOffset),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      revision: Value(revision),
    );
  }

  factory SourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      markdown: serializer.fromJson<String>(json['markdown']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      importedAtUtc: serializer.fromJson<int>(json['importedAtUtc']),
      pace: serializer.fromJson<int>(json['pace']),
      markerBlockId: serializer.fromJson<String?>(json['markerBlockId']),
      markerOffset: serializer.fromJson<int?>(json['markerOffset']),
      softBlockId: serializer.fromJson<String?>(json['softBlockId']),
      softOffset: serializer.fromJson<int?>(json['softOffset']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'markdown': serializer.toJson<String>(markdown),
      'contentHash': serializer.toJson<String>(contentHash),
      'wordCount': serializer.toJson<int>(wordCount),
      'importedAtUtc': serializer.toJson<int>(importedAtUtc),
      'pace': serializer.toJson<int>(pace),
      'markerBlockId': serializer.toJson<String?>(markerBlockId),
      'markerOffset': serializer.toJson<int?>(markerOffset),
      'softBlockId': serializer.toJson<String?>(softBlockId),
      'softOffset': serializer.toJson<int?>(softOffset),
      'folderId': serializer.toJson<String?>(folderId),
      'revision': serializer.toJson<int>(revision),
    };
  }

  SourceRow copyWith({
    String? id,
    String? title,
    String? markdown,
    String? contentHash,
    int? wordCount,
    int? importedAtUtc,
    int? pace,
    Value<String?> markerBlockId = const Value.absent(),
    Value<int?> markerOffset = const Value.absent(),
    Value<String?> softBlockId = const Value.absent(),
    Value<int?> softOffset = const Value.absent(),
    Value<String?> folderId = const Value.absent(),
    int? revision,
  }) => SourceRow(
    id: id ?? this.id,
    title: title ?? this.title,
    markdown: markdown ?? this.markdown,
    contentHash: contentHash ?? this.contentHash,
    wordCount: wordCount ?? this.wordCount,
    importedAtUtc: importedAtUtc ?? this.importedAtUtc,
    pace: pace ?? this.pace,
    markerBlockId: markerBlockId.present
        ? markerBlockId.value
        : this.markerBlockId,
    markerOffset: markerOffset.present ? markerOffset.value : this.markerOffset,
    softBlockId: softBlockId.present ? softBlockId.value : this.softBlockId,
    softOffset: softOffset.present ? softOffset.value : this.softOffset,
    folderId: folderId.present ? folderId.value : this.folderId,
    revision: revision ?? this.revision,
  );
  SourceRow copyWithCompanion(SourcesCompanion data) {
    return SourceRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      markdown: data.markdown.present ? data.markdown.value : this.markdown,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      importedAtUtc: data.importedAtUtc.present
          ? data.importedAtUtc.value
          : this.importedAtUtc,
      pace: data.pace.present ? data.pace.value : this.pace,
      markerBlockId: data.markerBlockId.present
          ? data.markerBlockId.value
          : this.markerBlockId,
      markerOffset: data.markerOffset.present
          ? data.markerOffset.value
          : this.markerOffset,
      softBlockId: data.softBlockId.present
          ? data.softBlockId.value
          : this.softBlockId,
      softOffset: data.softOffset.present
          ? data.softOffset.value
          : this.softOffset,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('markdown: $markdown, ')
          ..write('contentHash: $contentHash, ')
          ..write('wordCount: $wordCount, ')
          ..write('importedAtUtc: $importedAtUtc, ')
          ..write('pace: $pace, ')
          ..write('markerBlockId: $markerBlockId, ')
          ..write('markerOffset: $markerOffset, ')
          ..write('softBlockId: $softBlockId, ')
          ..write('softOffset: $softOffset, ')
          ..write('folderId: $folderId, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    markdown,
    contentHash,
    wordCount,
    importedAtUtc,
    pace,
    markerBlockId,
    markerOffset,
    softBlockId,
    softOffset,
    folderId,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.markdown == this.markdown &&
          other.contentHash == this.contentHash &&
          other.wordCount == this.wordCount &&
          other.importedAtUtc == this.importedAtUtc &&
          other.pace == this.pace &&
          other.markerBlockId == this.markerBlockId &&
          other.markerOffset == this.markerOffset &&
          other.softBlockId == this.softBlockId &&
          other.softOffset == this.softOffset &&
          other.folderId == this.folderId &&
          other.revision == this.revision);
}

class SourcesCompanion extends UpdateCompanion<SourceRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> markdown;
  final Value<String> contentHash;
  final Value<int> wordCount;
  final Value<int> importedAtUtc;
  final Value<int> pace;
  final Value<String?> markerBlockId;
  final Value<int?> markerOffset;
  final Value<String?> softBlockId;
  final Value<int?> softOffset;
  final Value<String?> folderId;
  final Value<int> revision;
  final Value<int> rowid;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.markdown = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.importedAtUtc = const Value.absent(),
    this.pace = const Value.absent(),
    this.markerBlockId = const Value.absent(),
    this.markerOffset = const Value.absent(),
    this.softBlockId = const Value.absent(),
    this.softOffset = const Value.absent(),
    this.folderId = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourcesCompanion.insert({
    required String id,
    required String title,
    required String markdown,
    required String contentHash,
    required int wordCount,
    required int importedAtUtc,
    this.pace = const Value.absent(),
    this.markerBlockId = const Value.absent(),
    this.markerOffset = const Value.absent(),
    this.softBlockId = const Value.absent(),
    this.softOffset = const Value.absent(),
    this.folderId = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       markdown = Value(markdown),
       contentHash = Value(contentHash),
       wordCount = Value(wordCount),
       importedAtUtc = Value(importedAtUtc);
  static Insertable<SourceRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? markdown,
    Expression<String>? contentHash,
    Expression<int>? wordCount,
    Expression<int>? importedAtUtc,
    Expression<int>? pace,
    Expression<String>? markerBlockId,
    Expression<int>? markerOffset,
    Expression<String>? softBlockId,
    Expression<int>? softOffset,
    Expression<String>? folderId,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (markdown != null) 'markdown': markdown,
      if (contentHash != null) 'content_hash': contentHash,
      if (wordCount != null) 'word_count': wordCount,
      if (importedAtUtc != null) 'imported_at_utc': importedAtUtc,
      if (pace != null) 'pace': pace,
      if (markerBlockId != null) 'marker_block_id': markerBlockId,
      if (markerOffset != null) 'marker_offset': markerOffset,
      if (softBlockId != null) 'soft_block_id': softBlockId,
      if (softOffset != null) 'soft_offset': softOffset,
      if (folderId != null) 'folder_id': folderId,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? markdown,
    Value<String>? contentHash,
    Value<int>? wordCount,
    Value<int>? importedAtUtc,
    Value<int>? pace,
    Value<String?>? markerBlockId,
    Value<int?>? markerOffset,
    Value<String?>? softBlockId,
    Value<int?>? softOffset,
    Value<String?>? folderId,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return SourcesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      markdown: markdown ?? this.markdown,
      contentHash: contentHash ?? this.contentHash,
      wordCount: wordCount ?? this.wordCount,
      importedAtUtc: importedAtUtc ?? this.importedAtUtc,
      pace: pace ?? this.pace,
      markerBlockId: markerBlockId ?? this.markerBlockId,
      markerOffset: markerOffset ?? this.markerOffset,
      softBlockId: softBlockId ?? this.softBlockId,
      softOffset: softOffset ?? this.softOffset,
      folderId: folderId ?? this.folderId,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (markdown.present) {
      map['markdown'] = Variable<String>(markdown.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (importedAtUtc.present) {
      map['imported_at_utc'] = Variable<int>(importedAtUtc.value);
    }
    if (pace.present) {
      map['pace'] = Variable<int>(pace.value);
    }
    if (markerBlockId.present) {
      map['marker_block_id'] = Variable<String>(markerBlockId.value);
    }
    if (markerOffset.present) {
      map['marker_offset'] = Variable<int>(markerOffset.value);
    }
    if (softBlockId.present) {
      map['soft_block_id'] = Variable<String>(softBlockId.value);
    }
    if (softOffset.present) {
      map['soft_offset'] = Variable<int>(softOffset.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('markdown: $markdown, ')
          ..write('contentHash: $contentHash, ')
          ..write('wordCount: $wordCount, ')
          ..write('importedAtUtc: $importedAtUtc, ')
          ..write('pace: $pace, ')
          ..write('markerBlockId: $markerBlockId, ')
          ..write('markerOffset: $markerOffset, ')
          ..write('softBlockId: $softBlockId, ')
          ..write('softOffset: $softOffset, ')
          ..write('folderId: $folderId, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlocksTable extends Blocks with TableInfo<$BlocksTable, BlockRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _idxMeta = const VerificationMeta('idx');
  @override
  late final GeneratedColumn<int> idx = GeneratedColumn<int>(
    'idx',
    aliasedName,
    false,
    check: () => ComparableExpr(idx).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    check: () => ComparableExpr(type).isBetweenValues(0, 7),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawMeta = const VerificationMeta('raw');
  @override
  late final GeneratedColumn<String> raw = GeneratedColumn<String>(
    'raw',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startUtf8Meta = const VerificationMeta(
    'startUtf8',
  );
  @override
  late final GeneratedColumn<int> startUtf8 = GeneratedColumn<int>(
    'start_utf8',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endUtf8Meta = const VerificationMeta(
    'endUtf8',
  );
  @override
  late final GeneratedColumn<int> endUtf8 = GeneratedColumn<int>(
    'end_utf8',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startUtf16Meta = const VerificationMeta(
    'startUtf16',
  );
  @override
  late final GeneratedColumn<int> startUtf16 = GeneratedColumn<int>(
    'start_utf16',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentSpansMeta = const VerificationMeta(
    'contentSpans',
  );
  @override
  late final GeneratedColumn<String> contentSpans = GeneratedColumn<String>(
    'content_spans',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headingLevelMeta = const VerificationMeta(
    'headingLevel',
  );
  @override
  late final GeneratedColumn<int> headingLevel = GeneratedColumn<int>(
    'heading_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeLanguageMeta = const VerificationMeta(
    'codeLanguage',
  );
  @override
  late final GeneratedColumn<String> codeLanguage = GeneratedColumn<String>(
    'code_language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderedMeta = const VerificationMeta(
    'ordered',
  );
  @override
  late final GeneratedColumn<bool> ordered = GeneratedColumn<bool>(
    'ordered',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ordered" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _listMarkerMeta = const VerificationMeta(
    'listMarker',
  );
  @override
  late final GeneratedColumn<String> listMarker = GeneratedColumn<String>(
    'list_marker',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _listDepthMeta = const VerificationMeta(
    'listDepth',
  );
  @override
  late final GeneratedColumn<int> listDepth = GeneratedColumn<int>(
    'list_depth',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _quoteDepthMeta = const VerificationMeta(
    'quoteDepth',
  );
  @override
  late final GeneratedColumn<int> quoteDepth = GeneratedColumn<int>(
    'quote_depth',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    idx,
    type,
    raw,
    startUtf8,
    endUtf8,
    startUtf16,
    contentSpans,
    headingLevel,
    codeLanguage,
    ordered,
    listMarker,
    listDepth,
    quoteDepth,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlockRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('idx')) {
      context.handle(
        _idxMeta,
        idx.isAcceptableOrUnknown(data['idx']!, _idxMeta),
      );
    } else if (isInserting) {
      context.missing(_idxMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('raw')) {
      context.handle(
        _rawMeta,
        raw.isAcceptableOrUnknown(data['raw']!, _rawMeta),
      );
    } else if (isInserting) {
      context.missing(_rawMeta);
    }
    if (data.containsKey('start_utf8')) {
      context.handle(
        _startUtf8Meta,
        startUtf8.isAcceptableOrUnknown(data['start_utf8']!, _startUtf8Meta),
      );
    } else if (isInserting) {
      context.missing(_startUtf8Meta);
    }
    if (data.containsKey('end_utf8')) {
      context.handle(
        _endUtf8Meta,
        endUtf8.isAcceptableOrUnknown(data['end_utf8']!, _endUtf8Meta),
      );
    } else if (isInserting) {
      context.missing(_endUtf8Meta);
    }
    if (data.containsKey('start_utf16')) {
      context.handle(
        _startUtf16Meta,
        startUtf16.isAcceptableOrUnknown(data['start_utf16']!, _startUtf16Meta),
      );
    } else if (isInserting) {
      context.missing(_startUtf16Meta);
    }
    if (data.containsKey('content_spans')) {
      context.handle(
        _contentSpansMeta,
        contentSpans.isAcceptableOrUnknown(
          data['content_spans']!,
          _contentSpansMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentSpansMeta);
    }
    if (data.containsKey('heading_level')) {
      context.handle(
        _headingLevelMeta,
        headingLevel.isAcceptableOrUnknown(
          data['heading_level']!,
          _headingLevelMeta,
        ),
      );
    }
    if (data.containsKey('code_language')) {
      context.handle(
        _codeLanguageMeta,
        codeLanguage.isAcceptableOrUnknown(
          data['code_language']!,
          _codeLanguageMeta,
        ),
      );
    }
    if (data.containsKey('ordered')) {
      context.handle(
        _orderedMeta,
        ordered.isAcceptableOrUnknown(data['ordered']!, _orderedMeta),
      );
    }
    if (data.containsKey('list_marker')) {
      context.handle(
        _listMarkerMeta,
        listMarker.isAcceptableOrUnknown(data['list_marker']!, _listMarkerMeta),
      );
    }
    if (data.containsKey('list_depth')) {
      context.handle(
        _listDepthMeta,
        listDepth.isAcceptableOrUnknown(data['list_depth']!, _listDepthMeta),
      );
    }
    if (data.containsKey('quote_depth')) {
      context.handle(
        _quoteDepthMeta,
        quoteDepth.isAcceptableOrUnknown(data['quote_depth']!, _quoteDepthMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BlockRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlockRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      idx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}idx'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      raw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw'],
      )!,
      startUtf8: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_utf8'],
      )!,
      endUtf8: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_utf8'],
      )!,
      startUtf16: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_utf16'],
      )!,
      contentSpans: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_spans'],
      )!,
      headingLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}heading_level'],
      ),
      codeLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code_language'],
      ),
      ordered: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ordered'],
      )!,
      listMarker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_marker'],
      ),
      listDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}list_depth'],
      )!,
      quoteDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quote_depth'],
      )!,
    );
  }

  @override
  $BlocksTable createAlias(String alias) {
    return $BlocksTable(attachedDatabase, alias);
  }
}

class BlockRow extends DataClass implements Insertable<BlockRow> {
  final String id;
  final String sourceId;
  final int idx;

  /// Index into the block-type enum.
  final int type;
  final String raw;
  final int startUtf8;
  final int endUtf8;
  final int startUtf16;

  /// JSON array of `[start, end]` UTF-16 pairs, relative to [raw].
  final String contentSpans;
  final int? headingLevel;
  final String? codeLanguage;
  final bool ordered;
  final String? listMarker;
  final int listDepth;
  final int quoteDepth;
  const BlockRow({
    required this.id,
    required this.sourceId,
    required this.idx,
    required this.type,
    required this.raw,
    required this.startUtf8,
    required this.endUtf8,
    required this.startUtf16,
    required this.contentSpans,
    this.headingLevel,
    this.codeLanguage,
    required this.ordered,
    this.listMarker,
    required this.listDepth,
    required this.quoteDepth,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['idx'] = Variable<int>(idx);
    map['type'] = Variable<int>(type);
    map['raw'] = Variable<String>(raw);
    map['start_utf8'] = Variable<int>(startUtf8);
    map['end_utf8'] = Variable<int>(endUtf8);
    map['start_utf16'] = Variable<int>(startUtf16);
    map['content_spans'] = Variable<String>(contentSpans);
    if (!nullToAbsent || headingLevel != null) {
      map['heading_level'] = Variable<int>(headingLevel);
    }
    if (!nullToAbsent || codeLanguage != null) {
      map['code_language'] = Variable<String>(codeLanguage);
    }
    map['ordered'] = Variable<bool>(ordered);
    if (!nullToAbsent || listMarker != null) {
      map['list_marker'] = Variable<String>(listMarker);
    }
    map['list_depth'] = Variable<int>(listDepth);
    map['quote_depth'] = Variable<int>(quoteDepth);
    return map;
  }

  BlocksCompanion toCompanion(bool nullToAbsent) {
    return BlocksCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      idx: Value(idx),
      type: Value(type),
      raw: Value(raw),
      startUtf8: Value(startUtf8),
      endUtf8: Value(endUtf8),
      startUtf16: Value(startUtf16),
      contentSpans: Value(contentSpans),
      headingLevel: headingLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(headingLevel),
      codeLanguage: codeLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(codeLanguage),
      ordered: Value(ordered),
      listMarker: listMarker == null && nullToAbsent
          ? const Value.absent()
          : Value(listMarker),
      listDepth: Value(listDepth),
      quoteDepth: Value(quoteDepth),
    );
  }

  factory BlockRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlockRow(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      idx: serializer.fromJson<int>(json['idx']),
      type: serializer.fromJson<int>(json['type']),
      raw: serializer.fromJson<String>(json['raw']),
      startUtf8: serializer.fromJson<int>(json['startUtf8']),
      endUtf8: serializer.fromJson<int>(json['endUtf8']),
      startUtf16: serializer.fromJson<int>(json['startUtf16']),
      contentSpans: serializer.fromJson<String>(json['contentSpans']),
      headingLevel: serializer.fromJson<int?>(json['headingLevel']),
      codeLanguage: serializer.fromJson<String?>(json['codeLanguage']),
      ordered: serializer.fromJson<bool>(json['ordered']),
      listMarker: serializer.fromJson<String?>(json['listMarker']),
      listDepth: serializer.fromJson<int>(json['listDepth']),
      quoteDepth: serializer.fromJson<int>(json['quoteDepth']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'idx': serializer.toJson<int>(idx),
      'type': serializer.toJson<int>(type),
      'raw': serializer.toJson<String>(raw),
      'startUtf8': serializer.toJson<int>(startUtf8),
      'endUtf8': serializer.toJson<int>(endUtf8),
      'startUtf16': serializer.toJson<int>(startUtf16),
      'contentSpans': serializer.toJson<String>(contentSpans),
      'headingLevel': serializer.toJson<int?>(headingLevel),
      'codeLanguage': serializer.toJson<String?>(codeLanguage),
      'ordered': serializer.toJson<bool>(ordered),
      'listMarker': serializer.toJson<String?>(listMarker),
      'listDepth': serializer.toJson<int>(listDepth),
      'quoteDepth': serializer.toJson<int>(quoteDepth),
    };
  }

  BlockRow copyWith({
    String? id,
    String? sourceId,
    int? idx,
    int? type,
    String? raw,
    int? startUtf8,
    int? endUtf8,
    int? startUtf16,
    String? contentSpans,
    Value<int?> headingLevel = const Value.absent(),
    Value<String?> codeLanguage = const Value.absent(),
    bool? ordered,
    Value<String?> listMarker = const Value.absent(),
    int? listDepth,
    int? quoteDepth,
  }) => BlockRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    idx: idx ?? this.idx,
    type: type ?? this.type,
    raw: raw ?? this.raw,
    startUtf8: startUtf8 ?? this.startUtf8,
    endUtf8: endUtf8 ?? this.endUtf8,
    startUtf16: startUtf16 ?? this.startUtf16,
    contentSpans: contentSpans ?? this.contentSpans,
    headingLevel: headingLevel.present ? headingLevel.value : this.headingLevel,
    codeLanguage: codeLanguage.present ? codeLanguage.value : this.codeLanguage,
    ordered: ordered ?? this.ordered,
    listMarker: listMarker.present ? listMarker.value : this.listMarker,
    listDepth: listDepth ?? this.listDepth,
    quoteDepth: quoteDepth ?? this.quoteDepth,
  );
  BlockRow copyWithCompanion(BlocksCompanion data) {
    return BlockRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      idx: data.idx.present ? data.idx.value : this.idx,
      type: data.type.present ? data.type.value : this.type,
      raw: data.raw.present ? data.raw.value : this.raw,
      startUtf8: data.startUtf8.present ? data.startUtf8.value : this.startUtf8,
      endUtf8: data.endUtf8.present ? data.endUtf8.value : this.endUtf8,
      startUtf16: data.startUtf16.present
          ? data.startUtf16.value
          : this.startUtf16,
      contentSpans: data.contentSpans.present
          ? data.contentSpans.value
          : this.contentSpans,
      headingLevel: data.headingLevel.present
          ? data.headingLevel.value
          : this.headingLevel,
      codeLanguage: data.codeLanguage.present
          ? data.codeLanguage.value
          : this.codeLanguage,
      ordered: data.ordered.present ? data.ordered.value : this.ordered,
      listMarker: data.listMarker.present
          ? data.listMarker.value
          : this.listMarker,
      listDepth: data.listDepth.present ? data.listDepth.value : this.listDepth,
      quoteDepth: data.quoteDepth.present
          ? data.quoteDepth.value
          : this.quoteDepth,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlockRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('idx: $idx, ')
          ..write('type: $type, ')
          ..write('raw: $raw, ')
          ..write('startUtf8: $startUtf8, ')
          ..write('endUtf8: $endUtf8, ')
          ..write('startUtf16: $startUtf16, ')
          ..write('contentSpans: $contentSpans, ')
          ..write('headingLevel: $headingLevel, ')
          ..write('codeLanguage: $codeLanguage, ')
          ..write('ordered: $ordered, ')
          ..write('listMarker: $listMarker, ')
          ..write('listDepth: $listDepth, ')
          ..write('quoteDepth: $quoteDepth')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    idx,
    type,
    raw,
    startUtf8,
    endUtf8,
    startUtf16,
    contentSpans,
    headingLevel,
    codeLanguage,
    ordered,
    listMarker,
    listDepth,
    quoteDepth,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.idx == this.idx &&
          other.type == this.type &&
          other.raw == this.raw &&
          other.startUtf8 == this.startUtf8 &&
          other.endUtf8 == this.endUtf8 &&
          other.startUtf16 == this.startUtf16 &&
          other.contentSpans == this.contentSpans &&
          other.headingLevel == this.headingLevel &&
          other.codeLanguage == this.codeLanguage &&
          other.ordered == this.ordered &&
          other.listMarker == this.listMarker &&
          other.listDepth == this.listDepth &&
          other.quoteDepth == this.quoteDepth);
}

class BlocksCompanion extends UpdateCompanion<BlockRow> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<int> idx;
  final Value<int> type;
  final Value<String> raw;
  final Value<int> startUtf8;
  final Value<int> endUtf8;
  final Value<int> startUtf16;
  final Value<String> contentSpans;
  final Value<int?> headingLevel;
  final Value<String?> codeLanguage;
  final Value<bool> ordered;
  final Value<String?> listMarker;
  final Value<int> listDepth;
  final Value<int> quoteDepth;
  final Value<int> rowid;
  const BlocksCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.idx = const Value.absent(),
    this.type = const Value.absent(),
    this.raw = const Value.absent(),
    this.startUtf8 = const Value.absent(),
    this.endUtf8 = const Value.absent(),
    this.startUtf16 = const Value.absent(),
    this.contentSpans = const Value.absent(),
    this.headingLevel = const Value.absent(),
    this.codeLanguage = const Value.absent(),
    this.ordered = const Value.absent(),
    this.listMarker = const Value.absent(),
    this.listDepth = const Value.absent(),
    this.quoteDepth = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlocksCompanion.insert({
    required String id,
    required String sourceId,
    required int idx,
    required int type,
    required String raw,
    required int startUtf8,
    required int endUtf8,
    required int startUtf16,
    required String contentSpans,
    this.headingLevel = const Value.absent(),
    this.codeLanguage = const Value.absent(),
    this.ordered = const Value.absent(),
    this.listMarker = const Value.absent(),
    this.listDepth = const Value.absent(),
    this.quoteDepth = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       idx = Value(idx),
       type = Value(type),
       raw = Value(raw),
       startUtf8 = Value(startUtf8),
       endUtf8 = Value(endUtf8),
       startUtf16 = Value(startUtf16),
       contentSpans = Value(contentSpans);
  static Insertable<BlockRow> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<int>? idx,
    Expression<int>? type,
    Expression<String>? raw,
    Expression<int>? startUtf8,
    Expression<int>? endUtf8,
    Expression<int>? startUtf16,
    Expression<String>? contentSpans,
    Expression<int>? headingLevel,
    Expression<String>? codeLanguage,
    Expression<bool>? ordered,
    Expression<String>? listMarker,
    Expression<int>? listDepth,
    Expression<int>? quoteDepth,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (idx != null) 'idx': idx,
      if (type != null) 'type': type,
      if (raw != null) 'raw': raw,
      if (startUtf8 != null) 'start_utf8': startUtf8,
      if (endUtf8 != null) 'end_utf8': endUtf8,
      if (startUtf16 != null) 'start_utf16': startUtf16,
      if (contentSpans != null) 'content_spans': contentSpans,
      if (headingLevel != null) 'heading_level': headingLevel,
      if (codeLanguage != null) 'code_language': codeLanguage,
      if (ordered != null) 'ordered': ordered,
      if (listMarker != null) 'list_marker': listMarker,
      if (listDepth != null) 'list_depth': listDepth,
      if (quoteDepth != null) 'quote_depth': quoteDepth,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlocksCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<int>? idx,
    Value<int>? type,
    Value<String>? raw,
    Value<int>? startUtf8,
    Value<int>? endUtf8,
    Value<int>? startUtf16,
    Value<String>? contentSpans,
    Value<int?>? headingLevel,
    Value<String?>? codeLanguage,
    Value<bool>? ordered,
    Value<String?>? listMarker,
    Value<int>? listDepth,
    Value<int>? quoteDepth,
    Value<int>? rowid,
  }) {
    return BlocksCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      idx: idx ?? this.idx,
      type: type ?? this.type,
      raw: raw ?? this.raw,
      startUtf8: startUtf8 ?? this.startUtf8,
      endUtf8: endUtf8 ?? this.endUtf8,
      startUtf16: startUtf16 ?? this.startUtf16,
      contentSpans: contentSpans ?? this.contentSpans,
      headingLevel: headingLevel ?? this.headingLevel,
      codeLanguage: codeLanguage ?? this.codeLanguage,
      ordered: ordered ?? this.ordered,
      listMarker: listMarker ?? this.listMarker,
      listDepth: listDepth ?? this.listDepth,
      quoteDepth: quoteDepth ?? this.quoteDepth,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (idx.present) {
      map['idx'] = Variable<int>(idx.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (raw.present) {
      map['raw'] = Variable<String>(raw.value);
    }
    if (startUtf8.present) {
      map['start_utf8'] = Variable<int>(startUtf8.value);
    }
    if (endUtf8.present) {
      map['end_utf8'] = Variable<int>(endUtf8.value);
    }
    if (startUtf16.present) {
      map['start_utf16'] = Variable<int>(startUtf16.value);
    }
    if (contentSpans.present) {
      map['content_spans'] = Variable<String>(contentSpans.value);
    }
    if (headingLevel.present) {
      map['heading_level'] = Variable<int>(headingLevel.value);
    }
    if (codeLanguage.present) {
      map['code_language'] = Variable<String>(codeLanguage.value);
    }
    if (ordered.present) {
      map['ordered'] = Variable<bool>(ordered.value);
    }
    if (listMarker.present) {
      map['list_marker'] = Variable<String>(listMarker.value);
    }
    if (listDepth.present) {
      map['list_depth'] = Variable<int>(listDepth.value);
    }
    if (quoteDepth.present) {
      map['quote_depth'] = Variable<int>(quoteDepth.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlocksCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('idx: $idx, ')
          ..write('type: $type, ')
          ..write('raw: $raw, ')
          ..write('startUtf8: $startUtf8, ')
          ..write('endUtf8: $endUtf8, ')
          ..write('startUtf16: $startUtf16, ')
          ..write('contentSpans: $contentSpans, ')
          ..write('headingLevel: $headingLevel, ')
          ..write('codeLanguage: $codeLanguage, ')
          ..write('ordered: $ordered, ')
          ..write('listMarker: $listMarker, ')
          ..write('listDepth: $listDepth, ')
          ..write('quoteDepth: $quoteDepth, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExtractsTable extends Extracts
    with TableInfo<$ExtractsTable, ExtractRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExtractsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markdownMeta = const VerificationMeta(
    'markdown',
  );
  @override
  late final GeneratedColumn<String> markdown = GeneratedColumn<String>(
    'markdown',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIsSourceMeta = const VerificationMeta(
    'parentIsSource',
  );
  @override
  late final GeneratedColumn<bool> parentIsSource = GeneratedColumn<bool>(
    'parent_is_source',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("parent_is_source" IN (0, 1))',
    ),
  );
  static const VerificationMeta _startBlockIdMeta = const VerificationMeta(
    'startBlockId',
  );
  @override
  late final GeneratedColumn<String> startBlockId = GeneratedColumn<String>(
    'start_block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endBlockIdMeta = const VerificationMeta(
    'endBlockId',
  );
  @override
  late final GeneratedColumn<String> endBlockId = GeneratedColumn<String>(
    'end_block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedTextHashMeta = const VerificationMeta(
    'selectedTextHash',
  );
  @override
  late final GeneratedColumn<String> selectedTextHash = GeneratedColumn<String>(
    'selected_text_hash',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 64,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editedAtUtcMeta = const VerificationMeta(
    'editedAtUtc',
  );
  @override
  late final GeneratedColumn<int> editedAtUtc = GeneratedColumn<int>(
    'edited_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    markdown,
    sourceId,
    parentId,
    parentIsSource,
    startBlockId,
    startOffset,
    endBlockId,
    endOffset,
    selectedTextHash,
    createdAtUtc,
    editedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'extracts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExtractRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('markdown')) {
      context.handle(
        _markdownMeta,
        markdown.isAcceptableOrUnknown(data['markdown']!, _markdownMeta),
      );
    } else if (isInserting) {
      context.missing(_markdownMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_parentIdMeta);
    }
    if (data.containsKey('parent_is_source')) {
      context.handle(
        _parentIsSourceMeta,
        parentIsSource.isAcceptableOrUnknown(
          data['parent_is_source']!,
          _parentIsSourceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parentIsSourceMeta);
    }
    if (data.containsKey('start_block_id')) {
      context.handle(
        _startBlockIdMeta,
        startBlockId.isAcceptableOrUnknown(
          data['start_block_id']!,
          _startBlockIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startBlockIdMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_block_id')) {
      context.handle(
        _endBlockIdMeta,
        endBlockId.isAcceptableOrUnknown(
          data['end_block_id']!,
          _endBlockIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endBlockIdMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('selected_text_hash')) {
      context.handle(
        _selectedTextHashMeta,
        selectedTextHash.isAcceptableOrUnknown(
          data['selected_text_hash']!,
          _selectedTextHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selectedTextHashMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('edited_at_utc')) {
      context.handle(
        _editedAtUtcMeta,
        editedAtUtc.isAcceptableOrUnknown(
          data['edited_at_utc']!,
          _editedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExtractRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExtractRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      markdown: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}markdown'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      )!,
      parentIsSource: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}parent_is_source'],
      )!,
      startBlockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_block_id'],
      )!,
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      )!,
      endBlockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_block_id'],
      )!,
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
      )!,
      selectedTextHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_text_hash'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      editedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}edited_at_utc'],
      ),
    );
  }

  @override
  $ExtractsTable createAlias(String alias) {
    return $ExtractsTable(attachedDatabase, alias);
  }
}

class ExtractRow extends DataClass implements Insertable<ExtractRow> {
  final String id;
  final String markdown;

  /// Root source, denormalized so opening context never walks the chain.
  final String sourceId;

  /// Immediate parent: a source or another extract.
  final String parentId;
  final bool parentIsSource;
  final String startBlockId;
  final int startOffset;
  final String endBlockId;
  final int endOffset;
  final String selectedTextHash;
  final int createdAtUtc;
  final int? editedAtUtc;
  const ExtractRow({
    required this.id,
    required this.markdown,
    required this.sourceId,
    required this.parentId,
    required this.parentIsSource,
    required this.startBlockId,
    required this.startOffset,
    required this.endBlockId,
    required this.endOffset,
    required this.selectedTextHash,
    required this.createdAtUtc,
    this.editedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['markdown'] = Variable<String>(markdown);
    map['source_id'] = Variable<String>(sourceId);
    map['parent_id'] = Variable<String>(parentId);
    map['parent_is_source'] = Variable<bool>(parentIsSource);
    map['start_block_id'] = Variable<String>(startBlockId);
    map['start_offset'] = Variable<int>(startOffset);
    map['end_block_id'] = Variable<String>(endBlockId);
    map['end_offset'] = Variable<int>(endOffset);
    map['selected_text_hash'] = Variable<String>(selectedTextHash);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    if (!nullToAbsent || editedAtUtc != null) {
      map['edited_at_utc'] = Variable<int>(editedAtUtc);
    }
    return map;
  }

  ExtractsCompanion toCompanion(bool nullToAbsent) {
    return ExtractsCompanion(
      id: Value(id),
      markdown: Value(markdown),
      sourceId: Value(sourceId),
      parentId: Value(parentId),
      parentIsSource: Value(parentIsSource),
      startBlockId: Value(startBlockId),
      startOffset: Value(startOffset),
      endBlockId: Value(endBlockId),
      endOffset: Value(endOffset),
      selectedTextHash: Value(selectedTextHash),
      createdAtUtc: Value(createdAtUtc),
      editedAtUtc: editedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(editedAtUtc),
    );
  }

  factory ExtractRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExtractRow(
      id: serializer.fromJson<String>(json['id']),
      markdown: serializer.fromJson<String>(json['markdown']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      parentId: serializer.fromJson<String>(json['parentId']),
      parentIsSource: serializer.fromJson<bool>(json['parentIsSource']),
      startBlockId: serializer.fromJson<String>(json['startBlockId']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endBlockId: serializer.fromJson<String>(json['endBlockId']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      selectedTextHash: serializer.fromJson<String>(json['selectedTextHash']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      editedAtUtc: serializer.fromJson<int?>(json['editedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'markdown': serializer.toJson<String>(markdown),
      'sourceId': serializer.toJson<String>(sourceId),
      'parentId': serializer.toJson<String>(parentId),
      'parentIsSource': serializer.toJson<bool>(parentIsSource),
      'startBlockId': serializer.toJson<String>(startBlockId),
      'startOffset': serializer.toJson<int>(startOffset),
      'endBlockId': serializer.toJson<String>(endBlockId),
      'endOffset': serializer.toJson<int>(endOffset),
      'selectedTextHash': serializer.toJson<String>(selectedTextHash),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'editedAtUtc': serializer.toJson<int?>(editedAtUtc),
    };
  }

  ExtractRow copyWith({
    String? id,
    String? markdown,
    String? sourceId,
    String? parentId,
    bool? parentIsSource,
    String? startBlockId,
    int? startOffset,
    String? endBlockId,
    int? endOffset,
    String? selectedTextHash,
    int? createdAtUtc,
    Value<int?> editedAtUtc = const Value.absent(),
  }) => ExtractRow(
    id: id ?? this.id,
    markdown: markdown ?? this.markdown,
    sourceId: sourceId ?? this.sourceId,
    parentId: parentId ?? this.parentId,
    parentIsSource: parentIsSource ?? this.parentIsSource,
    startBlockId: startBlockId ?? this.startBlockId,
    startOffset: startOffset ?? this.startOffset,
    endBlockId: endBlockId ?? this.endBlockId,
    endOffset: endOffset ?? this.endOffset,
    selectedTextHash: selectedTextHash ?? this.selectedTextHash,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    editedAtUtc: editedAtUtc.present ? editedAtUtc.value : this.editedAtUtc,
  );
  ExtractRow copyWithCompanion(ExtractsCompanion data) {
    return ExtractRow(
      id: data.id.present ? data.id.value : this.id,
      markdown: data.markdown.present ? data.markdown.value : this.markdown,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      parentIsSource: data.parentIsSource.present
          ? data.parentIsSource.value
          : this.parentIsSource,
      startBlockId: data.startBlockId.present
          ? data.startBlockId.value
          : this.startBlockId,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      endBlockId: data.endBlockId.present
          ? data.endBlockId.value
          : this.endBlockId,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      selectedTextHash: data.selectedTextHash.present
          ? data.selectedTextHash.value
          : this.selectedTextHash,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      editedAtUtc: data.editedAtUtc.present
          ? data.editedAtUtc.value
          : this.editedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExtractRow(')
          ..write('id: $id, ')
          ..write('markdown: $markdown, ')
          ..write('sourceId: $sourceId, ')
          ..write('parentId: $parentId, ')
          ..write('parentIsSource: $parentIsSource, ')
          ..write('startBlockId: $startBlockId, ')
          ..write('startOffset: $startOffset, ')
          ..write('endBlockId: $endBlockId, ')
          ..write('endOffset: $endOffset, ')
          ..write('selectedTextHash: $selectedTextHash, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('editedAtUtc: $editedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    markdown,
    sourceId,
    parentId,
    parentIsSource,
    startBlockId,
    startOffset,
    endBlockId,
    endOffset,
    selectedTextHash,
    createdAtUtc,
    editedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtractRow &&
          other.id == this.id &&
          other.markdown == this.markdown &&
          other.sourceId == this.sourceId &&
          other.parentId == this.parentId &&
          other.parentIsSource == this.parentIsSource &&
          other.startBlockId == this.startBlockId &&
          other.startOffset == this.startOffset &&
          other.endBlockId == this.endBlockId &&
          other.endOffset == this.endOffset &&
          other.selectedTextHash == this.selectedTextHash &&
          other.createdAtUtc == this.createdAtUtc &&
          other.editedAtUtc == this.editedAtUtc);
}

class ExtractsCompanion extends UpdateCompanion<ExtractRow> {
  final Value<String> id;
  final Value<String> markdown;
  final Value<String> sourceId;
  final Value<String> parentId;
  final Value<bool> parentIsSource;
  final Value<String> startBlockId;
  final Value<int> startOffset;
  final Value<String> endBlockId;
  final Value<int> endOffset;
  final Value<String> selectedTextHash;
  final Value<int> createdAtUtc;
  final Value<int?> editedAtUtc;
  final Value<int> rowid;
  const ExtractsCompanion({
    this.id = const Value.absent(),
    this.markdown = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.parentIsSource = const Value.absent(),
    this.startBlockId = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endBlockId = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.selectedTextHash = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.editedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExtractsCompanion.insert({
    required String id,
    required String markdown,
    required String sourceId,
    required String parentId,
    required bool parentIsSource,
    required String startBlockId,
    required int startOffset,
    required String endBlockId,
    required int endOffset,
    required String selectedTextHash,
    required int createdAtUtc,
    this.editedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       markdown = Value(markdown),
       sourceId = Value(sourceId),
       parentId = Value(parentId),
       parentIsSource = Value(parentIsSource),
       startBlockId = Value(startBlockId),
       startOffset = Value(startOffset),
       endBlockId = Value(endBlockId),
       endOffset = Value(endOffset),
       selectedTextHash = Value(selectedTextHash),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<ExtractRow> custom({
    Expression<String>? id,
    Expression<String>? markdown,
    Expression<String>? sourceId,
    Expression<String>? parentId,
    Expression<bool>? parentIsSource,
    Expression<String>? startBlockId,
    Expression<int>? startOffset,
    Expression<String>? endBlockId,
    Expression<int>? endOffset,
    Expression<String>? selectedTextHash,
    Expression<int>? createdAtUtc,
    Expression<int>? editedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (markdown != null) 'markdown': markdown,
      if (sourceId != null) 'source_id': sourceId,
      if (parentId != null) 'parent_id': parentId,
      if (parentIsSource != null) 'parent_is_source': parentIsSource,
      if (startBlockId != null) 'start_block_id': startBlockId,
      if (startOffset != null) 'start_offset': startOffset,
      if (endBlockId != null) 'end_block_id': endBlockId,
      if (endOffset != null) 'end_offset': endOffset,
      if (selectedTextHash != null) 'selected_text_hash': selectedTextHash,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (editedAtUtc != null) 'edited_at_utc': editedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExtractsCompanion copyWith({
    Value<String>? id,
    Value<String>? markdown,
    Value<String>? sourceId,
    Value<String>? parentId,
    Value<bool>? parentIsSource,
    Value<String>? startBlockId,
    Value<int>? startOffset,
    Value<String>? endBlockId,
    Value<int>? endOffset,
    Value<String>? selectedTextHash,
    Value<int>? createdAtUtc,
    Value<int?>? editedAtUtc,
    Value<int>? rowid,
  }) {
    return ExtractsCompanion(
      id: id ?? this.id,
      markdown: markdown ?? this.markdown,
      sourceId: sourceId ?? this.sourceId,
      parentId: parentId ?? this.parentId,
      parentIsSource: parentIsSource ?? this.parentIsSource,
      startBlockId: startBlockId ?? this.startBlockId,
      startOffset: startOffset ?? this.startOffset,
      endBlockId: endBlockId ?? this.endBlockId,
      endOffset: endOffset ?? this.endOffset,
      selectedTextHash: selectedTextHash ?? this.selectedTextHash,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      editedAtUtc: editedAtUtc ?? this.editedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (markdown.present) {
      map['markdown'] = Variable<String>(markdown.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (parentIsSource.present) {
      map['parent_is_source'] = Variable<bool>(parentIsSource.value);
    }
    if (startBlockId.present) {
      map['start_block_id'] = Variable<String>(startBlockId.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endBlockId.present) {
      map['end_block_id'] = Variable<String>(endBlockId.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (selectedTextHash.present) {
      map['selected_text_hash'] = Variable<String>(selectedTextHash.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (editedAtUtc.present) {
      map['edited_at_utc'] = Variable<int>(editedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExtractsCompanion(')
          ..write('id: $id, ')
          ..write('markdown: $markdown, ')
          ..write('sourceId: $sourceId, ')
          ..write('parentId: $parentId, ')
          ..write('parentIsSource: $parentIsSource, ')
          ..write('startBlockId: $startBlockId, ')
          ..write('startOffset: $startOffset, ')
          ..write('endBlockId: $endBlockId, ')
          ..write('endOffset: $endOffset, ')
          ..write('selectedTextHash: $selectedTextHash, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('editedAtUtc: $editedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardsTable extends Cards with TableInfo<$CardsTable, CardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extractIdMeta = const VerificationMeta(
    'extractId',
  );
  @override
  late final GeneratedColumn<String> extractId = GeneratedColumn<String>(
    'extract_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES extracts (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    check: () => ComparableExpr(kind).isBetweenValues(0, 1),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frontMeta = const VerificationMeta('front');
  @override
  late final GeneratedColumn<String> front = GeneratedColumn<String>(
    'front',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backMeta = const VerificationMeta('back');
  @override
  late final GeneratedColumn<String> back = GeneratedColumn<String>(
    'back',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clozeOrdinalMeta = const VerificationMeta(
    'clozeOrdinal',
  );
  @override
  late final GeneratedColumn<int> clozeOrdinal = GeneratedColumn<int>(
    'cloze_ordinal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editedAtUtcMeta = const VerificationMeta(
    'editedAtUtc',
  );
  @override
  late final GeneratedColumn<int> editedAtUtc = GeneratedColumn<int>(
    'edited_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    extractId,
    sourceId,
    kind,
    front,
    back,
    clozeOrdinal,
    createdAtUtc,
    editedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('extract_id')) {
      context.handle(
        _extractIdMeta,
        extractId.isAcceptableOrUnknown(data['extract_id']!, _extractIdMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('front')) {
      context.handle(
        _frontMeta,
        front.isAcceptableOrUnknown(data['front']!, _frontMeta),
      );
    } else if (isInserting) {
      context.missing(_frontMeta);
    }
    if (data.containsKey('back')) {
      context.handle(
        _backMeta,
        back.isAcceptableOrUnknown(data['back']!, _backMeta),
      );
    } else if (isInserting) {
      context.missing(_backMeta);
    }
    if (data.containsKey('cloze_ordinal')) {
      context.handle(
        _clozeOrdinalMeta,
        clozeOrdinal.isAcceptableOrUnknown(
          data['cloze_ordinal']!,
          _clozeOrdinalMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('edited_at_utc')) {
      context.handle(
        _editedAtUtcMeta,
        editedAtUtc.isAcceptableOrUnknown(
          data['edited_at_utc']!,
          _editedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      extractId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extract_id'],
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      front: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}front'],
      )!,
      back: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}back'],
      )!,
      clozeOrdinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cloze_ordinal'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      editedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}edited_at_utc'],
      ),
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class CardRow extends DataClass implements Insertable<CardRow> {
  final String id;

  /// Parent extract, when the card was formulated from one.
  ///
  /// Two nullable foreign keys rather than one polymorphic column: a card can
  /// hang off an extract, off an article directly, or off nothing at all, and
  /// each of the two real parents still gets database-level integrity.
  final String? extractId;

  /// Parent source, when the card was formulated straight from an article.
  final String? sourceId;

  /// Index into the card-kind enum.
  final int kind;
  final String front;
  final String back;
  final int? clozeOrdinal;
  final int createdAtUtc;
  final int? editedAtUtc;
  const CardRow({
    required this.id,
    this.extractId,
    this.sourceId,
    required this.kind,
    required this.front,
    required this.back,
    this.clozeOrdinal,
    required this.createdAtUtc,
    this.editedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || extractId != null) {
      map['extract_id'] = Variable<String>(extractId);
    }
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    map['kind'] = Variable<int>(kind);
    map['front'] = Variable<String>(front);
    map['back'] = Variable<String>(back);
    if (!nullToAbsent || clozeOrdinal != null) {
      map['cloze_ordinal'] = Variable<int>(clozeOrdinal);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    if (!nullToAbsent || editedAtUtc != null) {
      map['edited_at_utc'] = Variable<int>(editedAtUtc);
    }
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      extractId: extractId == null && nullToAbsent
          ? const Value.absent()
          : Value(extractId),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      kind: Value(kind),
      front: Value(front),
      back: Value(back),
      clozeOrdinal: clozeOrdinal == null && nullToAbsent
          ? const Value.absent()
          : Value(clozeOrdinal),
      createdAtUtc: Value(createdAtUtc),
      editedAtUtc: editedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(editedAtUtc),
    );
  }

  factory CardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardRow(
      id: serializer.fromJson<String>(json['id']),
      extractId: serializer.fromJson<String?>(json['extractId']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      kind: serializer.fromJson<int>(json['kind']),
      front: serializer.fromJson<String>(json['front']),
      back: serializer.fromJson<String>(json['back']),
      clozeOrdinal: serializer.fromJson<int?>(json['clozeOrdinal']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      editedAtUtc: serializer.fromJson<int?>(json['editedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'extractId': serializer.toJson<String?>(extractId),
      'sourceId': serializer.toJson<String?>(sourceId),
      'kind': serializer.toJson<int>(kind),
      'front': serializer.toJson<String>(front),
      'back': serializer.toJson<String>(back),
      'clozeOrdinal': serializer.toJson<int?>(clozeOrdinal),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'editedAtUtc': serializer.toJson<int?>(editedAtUtc),
    };
  }

  CardRow copyWith({
    String? id,
    Value<String?> extractId = const Value.absent(),
    Value<String?> sourceId = const Value.absent(),
    int? kind,
    String? front,
    String? back,
    Value<int?> clozeOrdinal = const Value.absent(),
    int? createdAtUtc,
    Value<int?> editedAtUtc = const Value.absent(),
  }) => CardRow(
    id: id ?? this.id,
    extractId: extractId.present ? extractId.value : this.extractId,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    kind: kind ?? this.kind,
    front: front ?? this.front,
    back: back ?? this.back,
    clozeOrdinal: clozeOrdinal.present ? clozeOrdinal.value : this.clozeOrdinal,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    editedAtUtc: editedAtUtc.present ? editedAtUtc.value : this.editedAtUtc,
  );
  CardRow copyWithCompanion(CardsCompanion data) {
    return CardRow(
      id: data.id.present ? data.id.value : this.id,
      extractId: data.extractId.present ? data.extractId.value : this.extractId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      front: data.front.present ? data.front.value : this.front,
      back: data.back.present ? data.back.value : this.back,
      clozeOrdinal: data.clozeOrdinal.present
          ? data.clozeOrdinal.value
          : this.clozeOrdinal,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      editedAtUtc: data.editedAtUtc.present
          ? data.editedAtUtc.value
          : this.editedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardRow(')
          ..write('id: $id, ')
          ..write('extractId: $extractId, ')
          ..write('sourceId: $sourceId, ')
          ..write('kind: $kind, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('clozeOrdinal: $clozeOrdinal, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('editedAtUtc: $editedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    extractId,
    sourceId,
    kind,
    front,
    back,
    clozeOrdinal,
    createdAtUtc,
    editedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardRow &&
          other.id == this.id &&
          other.extractId == this.extractId &&
          other.sourceId == this.sourceId &&
          other.kind == this.kind &&
          other.front == this.front &&
          other.back == this.back &&
          other.clozeOrdinal == this.clozeOrdinal &&
          other.createdAtUtc == this.createdAtUtc &&
          other.editedAtUtc == this.editedAtUtc);
}

class CardsCompanion extends UpdateCompanion<CardRow> {
  final Value<String> id;
  final Value<String?> extractId;
  final Value<String?> sourceId;
  final Value<int> kind;
  final Value<String> front;
  final Value<String> back;
  final Value<int?> clozeOrdinal;
  final Value<int> createdAtUtc;
  final Value<int?> editedAtUtc;
  final Value<int> rowid;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.extractId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.front = const Value.absent(),
    this.back = const Value.absent(),
    this.clozeOrdinal = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.editedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardsCompanion.insert({
    required String id,
    this.extractId = const Value.absent(),
    this.sourceId = const Value.absent(),
    required int kind,
    required String front,
    required String back,
    this.clozeOrdinal = const Value.absent(),
    required int createdAtUtc,
    this.editedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       front = Value(front),
       back = Value(back),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<CardRow> custom({
    Expression<String>? id,
    Expression<String>? extractId,
    Expression<String>? sourceId,
    Expression<int>? kind,
    Expression<String>? front,
    Expression<String>? back,
    Expression<int>? clozeOrdinal,
    Expression<int>? createdAtUtc,
    Expression<int>? editedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (extractId != null) 'extract_id': extractId,
      if (sourceId != null) 'source_id': sourceId,
      if (kind != null) 'kind': kind,
      if (front != null) 'front': front,
      if (back != null) 'back': back,
      if (clozeOrdinal != null) 'cloze_ordinal': clozeOrdinal,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (editedAtUtc != null) 'edited_at_utc': editedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardsCompanion copyWith({
    Value<String>? id,
    Value<String?>? extractId,
    Value<String?>? sourceId,
    Value<int>? kind,
    Value<String>? front,
    Value<String>? back,
    Value<int?>? clozeOrdinal,
    Value<int>? createdAtUtc,
    Value<int?>? editedAtUtc,
    Value<int>? rowid,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      extractId: extractId ?? this.extractId,
      sourceId: sourceId ?? this.sourceId,
      kind: kind ?? this.kind,
      front: front ?? this.front,
      back: back ?? this.back,
      clozeOrdinal: clozeOrdinal ?? this.clozeOrdinal,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      editedAtUtc: editedAtUtc ?? this.editedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (extractId.present) {
      map['extract_id'] = Variable<String>(extractId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (front.present) {
      map['front'] = Variable<String>(front.value);
    }
    if (back.present) {
      map['back'] = Variable<String>(back.value);
    }
    if (clozeOrdinal.present) {
      map['cloze_ordinal'] = Variable<int>(clozeOrdinal.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (editedAtUtc.present) {
      map['edited_at_utc'] = Variable<int>(editedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('extractId: $extractId, ')
          ..write('sourceId: $sourceId, ')
          ..write('kind: $kind, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('clozeOrdinal: $clozeOrdinal, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('editedAtUtc: $editedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ElementSchedulesTable extends ElementSchedules
    with TableInfo<$ElementSchedulesTable, ScheduleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ElementSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _elementIdMeta = const VerificationMeta(
    'elementId',
  );
  @override
  late final GeneratedColumn<String> elementId = GeneratedColumn<String>(
    'element_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _elementTypeMeta = const VerificationMeta(
    'elementType',
  );
  @override
  late final GeneratedColumn<int> elementType = GeneratedColumn<int>(
    'element_type',
    aliasedName,
    false,
    check: () => ComparableExpr(elementType).isBetweenValues(0, 2),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityKeyMeta = const VerificationMeta(
    'priorityKey',
  );
  @override
  late final GeneratedColumn<String> priorityKey = GeneratedColumn<String>(
    'priority_key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<int> lifecycle = GeneratedColumn<int>(
    'lifecycle',
    aliasedName,
    false,
    check: () => ComparableExpr(lifecycle).isBetweenValues(0, 4),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDayMeta = const VerificationMeta('dueDay');
  @override
  late final GeneratedColumn<int> dueDay = GeneratedColumn<int>(
    'due_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalDueDayMeta = const VerificationMeta(
    'originalDueDay',
  );
  @override
  late final GeneratedColumn<int> originalDueDay = GeneratedColumn<int>(
    'original_due_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deferredUntilMeta = const VerificationMeta(
    'deferredUntil',
  );
  @override
  late final GeneratedColumn<int> deferredUntil = GeneratedColumn<int>(
    'deferred_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deferralKindMeta = const VerificationMeta(
    'deferralKind',
  );
  @override
  late final GeneratedColumn<int> deferralKind = GeneratedColumn<int>(
    'deferral_kind',
    aliasedName,
    false,
    check: () => ComparableExpr(deferralKind).isBetweenValues(0, 2),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _zoneIdMeta = const VerificationMeta('zoneId');
  @override
  late final GeneratedColumn<String> zoneId = GeneratedColumn<String>(
    'zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    elementId,
    elementType,
    priorityKey,
    lifecycle,
    dueDay,
    originalDueDay,
    deferredUntil,
    deferralKind,
    zoneId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'element_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('element_id')) {
      context.handle(
        _elementIdMeta,
        elementId.isAcceptableOrUnknown(data['element_id']!, _elementIdMeta),
      );
    } else if (isInserting) {
      context.missing(_elementIdMeta);
    }
    if (data.containsKey('element_type')) {
      context.handle(
        _elementTypeMeta,
        elementType.isAcceptableOrUnknown(
          data['element_type']!,
          _elementTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_elementTypeMeta);
    }
    if (data.containsKey('priority_key')) {
      context.handle(
        _priorityKeyMeta,
        priorityKey.isAcceptableOrUnknown(
          data['priority_key']!,
          _priorityKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_priorityKeyMeta);
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    } else if (isInserting) {
      context.missing(_lifecycleMeta);
    }
    if (data.containsKey('due_day')) {
      context.handle(
        _dueDayMeta,
        dueDay.isAcceptableOrUnknown(data['due_day']!, _dueDayMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDayMeta);
    }
    if (data.containsKey('original_due_day')) {
      context.handle(
        _originalDueDayMeta,
        originalDueDay.isAcceptableOrUnknown(
          data['original_due_day']!,
          _originalDueDayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalDueDayMeta);
    }
    if (data.containsKey('deferred_until')) {
      context.handle(
        _deferredUntilMeta,
        deferredUntil.isAcceptableOrUnknown(
          data['deferred_until']!,
          _deferredUntilMeta,
        ),
      );
    }
    if (data.containsKey('deferral_kind')) {
      context.handle(
        _deferralKindMeta,
        deferralKind.isAcceptableOrUnknown(
          data['deferral_kind']!,
          _deferralKindMeta,
        ),
      );
    }
    if (data.containsKey('zone_id')) {
      context.handle(
        _zoneIdMeta,
        zoneId.isAcceptableOrUnknown(data['zone_id']!, _zoneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_zoneIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {elementId, elementType};
  @override
  ScheduleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleRow(
      elementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}element_id'],
      )!,
      elementType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}element_type'],
      )!,
      priorityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority_key'],
      )!,
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lifecycle'],
      )!,
      dueDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_day'],
      )!,
      originalDueDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}original_due_day'],
      )!,
      deferredUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deferred_until'],
      ),
      deferralKind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deferral_kind'],
      )!,
      zoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zone_id'],
      )!,
    );
  }

  @override
  $ElementSchedulesTable createAlias(String alias) {
    return $ElementSchedulesTable(attachedDatabase, alias);
  }
}

class ScheduleRow extends DataClass implements Insertable<ScheduleRow> {
  final String elementId;

  /// Index into the element-type enum.
  final int elementType;

  /// Sortable relative priority. Lower sorts as more important.
  final String priorityKey;

  /// Index into the lifecycle enum.
  final int lifecycle;

  /// Days since the Unix epoch.
  final int dueDay;

  /// What the scheduler chose, preserved across postponement.
  final int originalDueDay;

  /// Where auto-postpone or a manual Later moved the element to.
  final int? deferredUntil;

  /// Index into the deferral-kind enum: none, manual, automatic.
  ///
  /// Recalling same-day overload deferrals must not undo what the user
  /// deliberately pushed away, so the two are distinguishable in storage.
  final int deferralKind;
  final String zoneId;
  const ScheduleRow({
    required this.elementId,
    required this.elementType,
    required this.priorityKey,
    required this.lifecycle,
    required this.dueDay,
    required this.originalDueDay,
    this.deferredUntil,
    required this.deferralKind,
    required this.zoneId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['element_id'] = Variable<String>(elementId);
    map['element_type'] = Variable<int>(elementType);
    map['priority_key'] = Variable<String>(priorityKey);
    map['lifecycle'] = Variable<int>(lifecycle);
    map['due_day'] = Variable<int>(dueDay);
    map['original_due_day'] = Variable<int>(originalDueDay);
    if (!nullToAbsent || deferredUntil != null) {
      map['deferred_until'] = Variable<int>(deferredUntil);
    }
    map['deferral_kind'] = Variable<int>(deferralKind);
    map['zone_id'] = Variable<String>(zoneId);
    return map;
  }

  ElementSchedulesCompanion toCompanion(bool nullToAbsent) {
    return ElementSchedulesCompanion(
      elementId: Value(elementId),
      elementType: Value(elementType),
      priorityKey: Value(priorityKey),
      lifecycle: Value(lifecycle),
      dueDay: Value(dueDay),
      originalDueDay: Value(originalDueDay),
      deferredUntil: deferredUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(deferredUntil),
      deferralKind: Value(deferralKind),
      zoneId: Value(zoneId),
    );
  }

  factory ScheduleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleRow(
      elementId: serializer.fromJson<String>(json['elementId']),
      elementType: serializer.fromJson<int>(json['elementType']),
      priorityKey: serializer.fromJson<String>(json['priorityKey']),
      lifecycle: serializer.fromJson<int>(json['lifecycle']),
      dueDay: serializer.fromJson<int>(json['dueDay']),
      originalDueDay: serializer.fromJson<int>(json['originalDueDay']),
      deferredUntil: serializer.fromJson<int?>(json['deferredUntil']),
      deferralKind: serializer.fromJson<int>(json['deferralKind']),
      zoneId: serializer.fromJson<String>(json['zoneId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'elementId': serializer.toJson<String>(elementId),
      'elementType': serializer.toJson<int>(elementType),
      'priorityKey': serializer.toJson<String>(priorityKey),
      'lifecycle': serializer.toJson<int>(lifecycle),
      'dueDay': serializer.toJson<int>(dueDay),
      'originalDueDay': serializer.toJson<int>(originalDueDay),
      'deferredUntil': serializer.toJson<int?>(deferredUntil),
      'deferralKind': serializer.toJson<int>(deferralKind),
      'zoneId': serializer.toJson<String>(zoneId),
    };
  }

  ScheduleRow copyWith({
    String? elementId,
    int? elementType,
    String? priorityKey,
    int? lifecycle,
    int? dueDay,
    int? originalDueDay,
    Value<int?> deferredUntil = const Value.absent(),
    int? deferralKind,
    String? zoneId,
  }) => ScheduleRow(
    elementId: elementId ?? this.elementId,
    elementType: elementType ?? this.elementType,
    priorityKey: priorityKey ?? this.priorityKey,
    lifecycle: lifecycle ?? this.lifecycle,
    dueDay: dueDay ?? this.dueDay,
    originalDueDay: originalDueDay ?? this.originalDueDay,
    deferredUntil: deferredUntil.present
        ? deferredUntil.value
        : this.deferredUntil,
    deferralKind: deferralKind ?? this.deferralKind,
    zoneId: zoneId ?? this.zoneId,
  );
  ScheduleRow copyWithCompanion(ElementSchedulesCompanion data) {
    return ScheduleRow(
      elementId: data.elementId.present ? data.elementId.value : this.elementId,
      elementType: data.elementType.present
          ? data.elementType.value
          : this.elementType,
      priorityKey: data.priorityKey.present
          ? data.priorityKey.value
          : this.priorityKey,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      dueDay: data.dueDay.present ? data.dueDay.value : this.dueDay,
      originalDueDay: data.originalDueDay.present
          ? data.originalDueDay.value
          : this.originalDueDay,
      deferredUntil: data.deferredUntil.present
          ? data.deferredUntil.value
          : this.deferredUntil,
      deferralKind: data.deferralKind.present
          ? data.deferralKind.value
          : this.deferralKind,
      zoneId: data.zoneId.present ? data.zoneId.value : this.zoneId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleRow(')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('priorityKey: $priorityKey, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('dueDay: $dueDay, ')
          ..write('originalDueDay: $originalDueDay, ')
          ..write('deferredUntil: $deferredUntil, ')
          ..write('deferralKind: $deferralKind, ')
          ..write('zoneId: $zoneId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    elementId,
    elementType,
    priorityKey,
    lifecycle,
    dueDay,
    originalDueDay,
    deferredUntil,
    deferralKind,
    zoneId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleRow &&
          other.elementId == this.elementId &&
          other.elementType == this.elementType &&
          other.priorityKey == this.priorityKey &&
          other.lifecycle == this.lifecycle &&
          other.dueDay == this.dueDay &&
          other.originalDueDay == this.originalDueDay &&
          other.deferredUntil == this.deferredUntil &&
          other.deferralKind == this.deferralKind &&
          other.zoneId == this.zoneId);
}

class ElementSchedulesCompanion extends UpdateCompanion<ScheduleRow> {
  final Value<String> elementId;
  final Value<int> elementType;
  final Value<String> priorityKey;
  final Value<int> lifecycle;
  final Value<int> dueDay;
  final Value<int> originalDueDay;
  final Value<int?> deferredUntil;
  final Value<int> deferralKind;
  final Value<String> zoneId;
  final Value<int> rowid;
  const ElementSchedulesCompanion({
    this.elementId = const Value.absent(),
    this.elementType = const Value.absent(),
    this.priorityKey = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.originalDueDay = const Value.absent(),
    this.deferredUntil = const Value.absent(),
    this.deferralKind = const Value.absent(),
    this.zoneId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ElementSchedulesCompanion.insert({
    required String elementId,
    required int elementType,
    required String priorityKey,
    required int lifecycle,
    required int dueDay,
    required int originalDueDay,
    this.deferredUntil = const Value.absent(),
    this.deferralKind = const Value.absent(),
    required String zoneId,
    this.rowid = const Value.absent(),
  }) : elementId = Value(elementId),
       elementType = Value(elementType),
       priorityKey = Value(priorityKey),
       lifecycle = Value(lifecycle),
       dueDay = Value(dueDay),
       originalDueDay = Value(originalDueDay),
       zoneId = Value(zoneId);
  static Insertable<ScheduleRow> custom({
    Expression<String>? elementId,
    Expression<int>? elementType,
    Expression<String>? priorityKey,
    Expression<int>? lifecycle,
    Expression<int>? dueDay,
    Expression<int>? originalDueDay,
    Expression<int>? deferredUntil,
    Expression<int>? deferralKind,
    Expression<String>? zoneId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (elementId != null) 'element_id': elementId,
      if (elementType != null) 'element_type': elementType,
      if (priorityKey != null) 'priority_key': priorityKey,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (dueDay != null) 'due_day': dueDay,
      if (originalDueDay != null) 'original_due_day': originalDueDay,
      if (deferredUntil != null) 'deferred_until': deferredUntil,
      if (deferralKind != null) 'deferral_kind': deferralKind,
      if (zoneId != null) 'zone_id': zoneId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ElementSchedulesCompanion copyWith({
    Value<String>? elementId,
    Value<int>? elementType,
    Value<String>? priorityKey,
    Value<int>? lifecycle,
    Value<int>? dueDay,
    Value<int>? originalDueDay,
    Value<int?>? deferredUntil,
    Value<int>? deferralKind,
    Value<String>? zoneId,
    Value<int>? rowid,
  }) {
    return ElementSchedulesCompanion(
      elementId: elementId ?? this.elementId,
      elementType: elementType ?? this.elementType,
      priorityKey: priorityKey ?? this.priorityKey,
      lifecycle: lifecycle ?? this.lifecycle,
      dueDay: dueDay ?? this.dueDay,
      originalDueDay: originalDueDay ?? this.originalDueDay,
      deferredUntil: deferredUntil ?? this.deferredUntil,
      deferralKind: deferralKind ?? this.deferralKind,
      zoneId: zoneId ?? this.zoneId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (elementId.present) {
      map['element_id'] = Variable<String>(elementId.value);
    }
    if (elementType.present) {
      map['element_type'] = Variable<int>(elementType.value);
    }
    if (priorityKey.present) {
      map['priority_key'] = Variable<String>(priorityKey.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<int>(lifecycle.value);
    }
    if (dueDay.present) {
      map['due_day'] = Variable<int>(dueDay.value);
    }
    if (originalDueDay.present) {
      map['original_due_day'] = Variable<int>(originalDueDay.value);
    }
    if (deferredUntil.present) {
      map['deferred_until'] = Variable<int>(deferredUntil.value);
    }
    if (deferralKind.present) {
      map['deferral_kind'] = Variable<int>(deferralKind.value);
    }
    if (zoneId.present) {
      map['zone_id'] = Variable<String>(zoneId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ElementSchedulesCompanion(')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('priorityKey: $priorityKey, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('dueDay: $dueDay, ')
          ..write('originalDueDay: $originalDueDay, ')
          ..write('deferredUntil: $deferredUntil, ')
          ..write('deferralKind: $deferralKind, ')
          ..write('zoneId: $zoneId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TopicStatesTable extends TopicStates
    with TableInfo<$TopicStatesTable, TopicStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TopicStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _elementIdMeta = const VerificationMeta(
    'elementId',
  );
  @override
  late final GeneratedColumn<String> elementId = GeneratedColumn<String>(
    'element_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _elementTypeMeta = const VerificationMeta(
    'elementType',
  );
  @override
  late final GeneratedColumn<int> elementType = GeneratedColumn<int>(
    'element_type',
    aliasedName,
    false,
    check: () => ComparableExpr(elementType).isBetweenValues(0, 1),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  );
  static const VerificationMeta _stepIndexMeta = const VerificationMeta(
    'stepIndex',
  );
  @override
  late final GeneratedColumn<int> stepIndex = GeneratedColumn<int>(
    'step_index',
    aliasedName,
    false,
    check: () => ComparableExpr(stepIndex).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    elementId,
    elementType,
    profileId,
    stepIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'topic_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<TopicStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('element_id')) {
      context.handle(
        _elementIdMeta,
        elementId.isAcceptableOrUnknown(data['element_id']!, _elementIdMeta),
      );
    } else if (isInserting) {
      context.missing(_elementIdMeta);
    }
    if (data.containsKey('element_type')) {
      context.handle(
        _elementTypeMeta,
        elementType.isAcceptableOrUnknown(
          data['element_type']!,
          _elementTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_elementTypeMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('step_index')) {
      context.handle(
        _stepIndexMeta,
        stepIndex.isAcceptableOrUnknown(data['step_index']!, _stepIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_stepIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {elementId, elementType};
  @override
  TopicStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TopicStateRow(
      elementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}element_id'],
      )!,
      elementType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}element_type'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      stepIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}step_index'],
      )!,
    );
  }

  @override
  $TopicStatesTable createAlias(String alias) {
    return $TopicStatesTable(attachedDatabase, alias);
  }
}

class TopicStateRow extends DataClass implements Insertable<TopicStateRow> {
  final String elementId;
  final int elementType;

  /// Which configured interval sequence paces this topic.
  final String profileId;

  /// Position in that sequence. The final value repeats.
  final int stepIndex;
  const TopicStateRow({
    required this.elementId,
    required this.elementType,
    required this.profileId,
    required this.stepIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['element_id'] = Variable<String>(elementId);
    map['element_type'] = Variable<int>(elementType);
    map['profile_id'] = Variable<String>(profileId);
    map['step_index'] = Variable<int>(stepIndex);
    return map;
  }

  TopicStatesCompanion toCompanion(bool nullToAbsent) {
    return TopicStatesCompanion(
      elementId: Value(elementId),
      elementType: Value(elementType),
      profileId: Value(profileId),
      stepIndex: Value(stepIndex),
    );
  }

  factory TopicStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TopicStateRow(
      elementId: serializer.fromJson<String>(json['elementId']),
      elementType: serializer.fromJson<int>(json['elementType']),
      profileId: serializer.fromJson<String>(json['profileId']),
      stepIndex: serializer.fromJson<int>(json['stepIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'elementId': serializer.toJson<String>(elementId),
      'elementType': serializer.toJson<int>(elementType),
      'profileId': serializer.toJson<String>(profileId),
      'stepIndex': serializer.toJson<int>(stepIndex),
    };
  }

  TopicStateRow copyWith({
    String? elementId,
    int? elementType,
    String? profileId,
    int? stepIndex,
  }) => TopicStateRow(
    elementId: elementId ?? this.elementId,
    elementType: elementType ?? this.elementType,
    profileId: profileId ?? this.profileId,
    stepIndex: stepIndex ?? this.stepIndex,
  );
  TopicStateRow copyWithCompanion(TopicStatesCompanion data) {
    return TopicStateRow(
      elementId: data.elementId.present ? data.elementId.value : this.elementId,
      elementType: data.elementType.present
          ? data.elementType.value
          : this.elementType,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      stepIndex: data.stepIndex.present ? data.stepIndex.value : this.stepIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TopicStateRow(')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('profileId: $profileId, ')
          ..write('stepIndex: $stepIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(elementId, elementType, profileId, stepIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TopicStateRow &&
          other.elementId == this.elementId &&
          other.elementType == this.elementType &&
          other.profileId == this.profileId &&
          other.stepIndex == this.stepIndex);
}

class TopicStatesCompanion extends UpdateCompanion<TopicStateRow> {
  final Value<String> elementId;
  final Value<int> elementType;
  final Value<String> profileId;
  final Value<int> stepIndex;
  final Value<int> rowid;
  const TopicStatesCompanion({
    this.elementId = const Value.absent(),
    this.elementType = const Value.absent(),
    this.profileId = const Value.absent(),
    this.stepIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TopicStatesCompanion.insert({
    required String elementId,
    required int elementType,
    required String profileId,
    required int stepIndex,
    this.rowid = const Value.absent(),
  }) : elementId = Value(elementId),
       elementType = Value(elementType),
       profileId = Value(profileId),
       stepIndex = Value(stepIndex);
  static Insertable<TopicStateRow> custom({
    Expression<String>? elementId,
    Expression<int>? elementType,
    Expression<String>? profileId,
    Expression<int>? stepIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (elementId != null) 'element_id': elementId,
      if (elementType != null) 'element_type': elementType,
      if (profileId != null) 'profile_id': profileId,
      if (stepIndex != null) 'step_index': stepIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TopicStatesCompanion copyWith({
    Value<String>? elementId,
    Value<int>? elementType,
    Value<String>? profileId,
    Value<int>? stepIndex,
    Value<int>? rowid,
  }) {
    return TopicStatesCompanion(
      elementId: elementId ?? this.elementId,
      elementType: elementType ?? this.elementType,
      profileId: profileId ?? this.profileId,
      stepIndex: stepIndex ?? this.stepIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (elementId.present) {
      map['element_id'] = Variable<String>(elementId.value);
    }
    if (elementType.present) {
      map['element_type'] = Variable<int>(elementType.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (stepIndex.present) {
      map['step_index'] = Variable<int>(stepIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TopicStatesCompanion(')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('profileId: $profileId, ')
          ..write('stepIndex: $stepIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardMemoriesTable extends CardMemories
    with TableInfo<$CardMemoriesTable, CardMemoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardMemoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _stabilityMeta = const VerificationMeta(
    'stability',
  );
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
    'stability',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
    'difficulty',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<int> state = GeneratedColumn<int>(
    'state',
    aliasedName,
    false,
    check: () => ComparableExpr(state).isBetweenValues(1, 3),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepMeta = const VerificationMeta('step');
  @override
  late final GeneratedColumn<int> step = GeneratedColumn<int>(
    'step',
    aliasedName,
    true,
    check: () => ComparableExpr(step).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    check: () => ComparableExpr(reps).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    check: () => ComparableExpr(lapses).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReviewUtcMeta = const VerificationMeta(
    'lastReviewUtc',
  );
  @override
  late final GeneratedColumn<int> lastReviewUtc = GeneratedColumn<int>(
    'last_review_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueAtUtcMeta = const VerificationMeta(
    'dueAtUtc',
  );
  @override
  late final GeneratedColumn<int> dueAtUtc = GeneratedColumn<int>(
    'due_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalDueAtUtcMeta = const VerificationMeta(
    'originalDueAtUtc',
  );
  @override
  late final GeneratedColumn<int> originalDueAtUtc = GeneratedColumn<int>(
    'original_due_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deferredUntilUtcMeta = const VerificationMeta(
    'deferredUntilUtc',
  );
  @override
  late final GeneratedColumn<int> deferredUntilUtc = GeneratedColumn<int>(
    'deferred_until_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schedulerVersionMeta = const VerificationMeta(
    'schedulerVersion',
  );
  @override
  late final GeneratedColumn<String> schedulerVersion = GeneratedColumn<String>(
    'scheduler_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parametersVersionMeta = const VerificationMeta(
    'parametersVersion',
  );
  @override
  late final GeneratedColumn<String> parametersVersion =
      GeneratedColumn<String>(
        'parameters_version',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    cardId,
    stability,
    difficulty,
    state,
    step,
    reps,
    lapses,
    lastReviewUtc,
    dueAtUtc,
    originalDueAtUtc,
    deferredUntilUtc,
    schedulerVersion,
    parametersVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_memories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardMemoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('stability')) {
      context.handle(
        _stabilityMeta,
        stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('step')) {
      context.handle(
        _stepMeta,
        step.isAcceptableOrUnknown(data['step']!, _stepMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    if (data.containsKey('last_review_utc')) {
      context.handle(
        _lastReviewUtcMeta,
        lastReviewUtc.isAcceptableOrUnknown(
          data['last_review_utc']!,
          _lastReviewUtcMeta,
        ),
      );
    }
    if (data.containsKey('due_at_utc')) {
      context.handle(
        _dueAtUtcMeta,
        dueAtUtc.isAcceptableOrUnknown(data['due_at_utc']!, _dueAtUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtUtcMeta);
    }
    if (data.containsKey('original_due_at_utc')) {
      context.handle(
        _originalDueAtUtcMeta,
        originalDueAtUtc.isAcceptableOrUnknown(
          data['original_due_at_utc']!,
          _originalDueAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalDueAtUtcMeta);
    }
    if (data.containsKey('deferred_until_utc')) {
      context.handle(
        _deferredUntilUtcMeta,
        deferredUntilUtc.isAcceptableOrUnknown(
          data['deferred_until_utc']!,
          _deferredUntilUtcMeta,
        ),
      );
    }
    if (data.containsKey('scheduler_version')) {
      context.handle(
        _schedulerVersionMeta,
        schedulerVersion.isAcceptableOrUnknown(
          data['scheduler_version']!,
          _schedulerVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schedulerVersionMeta);
    }
    if (data.containsKey('parameters_version')) {
      context.handle(
        _parametersVersionMeta,
        parametersVersion.isAcceptableOrUnknown(
          data['parameters_version']!,
          _parametersVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parametersVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardId};
  @override
  CardMemoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardMemoryRow(
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_id'],
      )!,
      stability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability'],
      ),
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}state'],
      )!,
      step: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}step'],
      ),
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
      lastReviewUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_review_utc'],
      ),
      dueAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_at_utc'],
      )!,
      originalDueAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}original_due_at_utc'],
      )!,
      deferredUntilUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deferred_until_utc'],
      ),
      schedulerVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduler_version'],
      )!,
      parametersVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameters_version'],
      )!,
    );
  }

  @override
  $CardMemoriesTable createAlias(String alias) {
    return $CardMemoriesTable(attachedDatabase, alias);
  }
}

class CardMemoryRow extends DataClass implements Insertable<CardMemoryRow> {
  final String cardId;

  /// Null until the first review, matching dart-fsrs' new-card shape.
  final double? stability;

  /// Null until the first review, matching dart-fsrs' new-card shape.
  final double? difficulty;

  /// dart-fsrs state: learning (1), review (2), relearning (3).
  final int state;

  /// Position in the active learning or relearning steps. Null in review.
  final int? step;
  final int reps;
  final int lapses;
  final int? lastReviewUtc;
  final int dueAtUtc;
  final int originalDueAtUtc;
  final int? deferredUntilUtc;

  /// Pinned scheduler build and parameter set, recorded so history stays
  /// interpretable after either changes.
  final String schedulerVersion;
  final String parametersVersion;
  const CardMemoryRow({
    required this.cardId,
    this.stability,
    this.difficulty,
    required this.state,
    this.step,
    required this.reps,
    required this.lapses,
    this.lastReviewUtc,
    required this.dueAtUtc,
    required this.originalDueAtUtc,
    this.deferredUntilUtc,
    required this.schedulerVersion,
    required this.parametersVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<String>(cardId);
    if (!nullToAbsent || stability != null) {
      map['stability'] = Variable<double>(stability);
    }
    if (!nullToAbsent || difficulty != null) {
      map['difficulty'] = Variable<double>(difficulty);
    }
    map['state'] = Variable<int>(state);
    if (!nullToAbsent || step != null) {
      map['step'] = Variable<int>(step);
    }
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    if (!nullToAbsent || lastReviewUtc != null) {
      map['last_review_utc'] = Variable<int>(lastReviewUtc);
    }
    map['due_at_utc'] = Variable<int>(dueAtUtc);
    map['original_due_at_utc'] = Variable<int>(originalDueAtUtc);
    if (!nullToAbsent || deferredUntilUtc != null) {
      map['deferred_until_utc'] = Variable<int>(deferredUntilUtc);
    }
    map['scheduler_version'] = Variable<String>(schedulerVersion);
    map['parameters_version'] = Variable<String>(parametersVersion);
    return map;
  }

  CardMemoriesCompanion toCompanion(bool nullToAbsent) {
    return CardMemoriesCompanion(
      cardId: Value(cardId),
      stability: stability == null && nullToAbsent
          ? const Value.absent()
          : Value(stability),
      difficulty: difficulty == null && nullToAbsent
          ? const Value.absent()
          : Value(difficulty),
      state: Value(state),
      step: step == null && nullToAbsent ? const Value.absent() : Value(step),
      reps: Value(reps),
      lapses: Value(lapses),
      lastReviewUtc: lastReviewUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewUtc),
      dueAtUtc: Value(dueAtUtc),
      originalDueAtUtc: Value(originalDueAtUtc),
      deferredUntilUtc: deferredUntilUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deferredUntilUtc),
      schedulerVersion: Value(schedulerVersion),
      parametersVersion: Value(parametersVersion),
    );
  }

  factory CardMemoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardMemoryRow(
      cardId: serializer.fromJson<String>(json['cardId']),
      stability: serializer.fromJson<double?>(json['stability']),
      difficulty: serializer.fromJson<double?>(json['difficulty']),
      state: serializer.fromJson<int>(json['state']),
      step: serializer.fromJson<int?>(json['step']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
      lastReviewUtc: serializer.fromJson<int?>(json['lastReviewUtc']),
      dueAtUtc: serializer.fromJson<int>(json['dueAtUtc']),
      originalDueAtUtc: serializer.fromJson<int>(json['originalDueAtUtc']),
      deferredUntilUtc: serializer.fromJson<int?>(json['deferredUntilUtc']),
      schedulerVersion: serializer.fromJson<String>(json['schedulerVersion']),
      parametersVersion: serializer.fromJson<String>(json['parametersVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<String>(cardId),
      'stability': serializer.toJson<double?>(stability),
      'difficulty': serializer.toJson<double?>(difficulty),
      'state': serializer.toJson<int>(state),
      'step': serializer.toJson<int?>(step),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
      'lastReviewUtc': serializer.toJson<int?>(lastReviewUtc),
      'dueAtUtc': serializer.toJson<int>(dueAtUtc),
      'originalDueAtUtc': serializer.toJson<int>(originalDueAtUtc),
      'deferredUntilUtc': serializer.toJson<int?>(deferredUntilUtc),
      'schedulerVersion': serializer.toJson<String>(schedulerVersion),
      'parametersVersion': serializer.toJson<String>(parametersVersion),
    };
  }

  CardMemoryRow copyWith({
    String? cardId,
    Value<double?> stability = const Value.absent(),
    Value<double?> difficulty = const Value.absent(),
    int? state,
    Value<int?> step = const Value.absent(),
    int? reps,
    int? lapses,
    Value<int?> lastReviewUtc = const Value.absent(),
    int? dueAtUtc,
    int? originalDueAtUtc,
    Value<int?> deferredUntilUtc = const Value.absent(),
    String? schedulerVersion,
    String? parametersVersion,
  }) => CardMemoryRow(
    cardId: cardId ?? this.cardId,
    stability: stability.present ? stability.value : this.stability,
    difficulty: difficulty.present ? difficulty.value : this.difficulty,
    state: state ?? this.state,
    step: step.present ? step.value : this.step,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    lastReviewUtc: lastReviewUtc.present
        ? lastReviewUtc.value
        : this.lastReviewUtc,
    dueAtUtc: dueAtUtc ?? this.dueAtUtc,
    originalDueAtUtc: originalDueAtUtc ?? this.originalDueAtUtc,
    deferredUntilUtc: deferredUntilUtc.present
        ? deferredUntilUtc.value
        : this.deferredUntilUtc,
    schedulerVersion: schedulerVersion ?? this.schedulerVersion,
    parametersVersion: parametersVersion ?? this.parametersVersion,
  );
  CardMemoryRow copyWithCompanion(CardMemoriesCompanion data) {
    return CardMemoryRow(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      state: data.state.present ? data.state.value : this.state,
      step: data.step.present ? data.step.value : this.step,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      lastReviewUtc: data.lastReviewUtc.present
          ? data.lastReviewUtc.value
          : this.lastReviewUtc,
      dueAtUtc: data.dueAtUtc.present ? data.dueAtUtc.value : this.dueAtUtc,
      originalDueAtUtc: data.originalDueAtUtc.present
          ? data.originalDueAtUtc.value
          : this.originalDueAtUtc,
      deferredUntilUtc: data.deferredUntilUtc.present
          ? data.deferredUntilUtc.value
          : this.deferredUntilUtc,
      schedulerVersion: data.schedulerVersion.present
          ? data.schedulerVersion.value
          : this.schedulerVersion,
      parametersVersion: data.parametersVersion.present
          ? data.parametersVersion.value
          : this.parametersVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardMemoryRow(')
          ..write('cardId: $cardId, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('state: $state, ')
          ..write('step: $step, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastReviewUtc: $lastReviewUtc, ')
          ..write('dueAtUtc: $dueAtUtc, ')
          ..write('originalDueAtUtc: $originalDueAtUtc, ')
          ..write('deferredUntilUtc: $deferredUntilUtc, ')
          ..write('schedulerVersion: $schedulerVersion, ')
          ..write('parametersVersion: $parametersVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cardId,
    stability,
    difficulty,
    state,
    step,
    reps,
    lapses,
    lastReviewUtc,
    dueAtUtc,
    originalDueAtUtc,
    deferredUntilUtc,
    schedulerVersion,
    parametersVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardMemoryRow &&
          other.cardId == this.cardId &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty &&
          other.state == this.state &&
          other.step == this.step &&
          other.reps == this.reps &&
          other.lapses == this.lapses &&
          other.lastReviewUtc == this.lastReviewUtc &&
          other.dueAtUtc == this.dueAtUtc &&
          other.originalDueAtUtc == this.originalDueAtUtc &&
          other.deferredUntilUtc == this.deferredUntilUtc &&
          other.schedulerVersion == this.schedulerVersion &&
          other.parametersVersion == this.parametersVersion);
}

class CardMemoriesCompanion extends UpdateCompanion<CardMemoryRow> {
  final Value<String> cardId;
  final Value<double?> stability;
  final Value<double?> difficulty;
  final Value<int> state;
  final Value<int?> step;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<int?> lastReviewUtc;
  final Value<int> dueAtUtc;
  final Value<int> originalDueAtUtc;
  final Value<int?> deferredUntilUtc;
  final Value<String> schedulerVersion;
  final Value<String> parametersVersion;
  final Value<int> rowid;
  const CardMemoriesCompanion({
    this.cardId = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.state = const Value.absent(),
    this.step = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastReviewUtc = const Value.absent(),
    this.dueAtUtc = const Value.absent(),
    this.originalDueAtUtc = const Value.absent(),
    this.deferredUntilUtc = const Value.absent(),
    this.schedulerVersion = const Value.absent(),
    this.parametersVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardMemoriesCompanion.insert({
    required String cardId,
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    required int state,
    this.step = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastReviewUtc = const Value.absent(),
    required int dueAtUtc,
    required int originalDueAtUtc,
    this.deferredUntilUtc = const Value.absent(),
    required String schedulerVersion,
    required String parametersVersion,
    this.rowid = const Value.absent(),
  }) : cardId = Value(cardId),
       state = Value(state),
       dueAtUtc = Value(dueAtUtc),
       originalDueAtUtc = Value(originalDueAtUtc),
       schedulerVersion = Value(schedulerVersion),
       parametersVersion = Value(parametersVersion);
  static Insertable<CardMemoryRow> custom({
    Expression<String>? cardId,
    Expression<double>? stability,
    Expression<double>? difficulty,
    Expression<int>? state,
    Expression<int>? step,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<int>? lastReviewUtc,
    Expression<int>? dueAtUtc,
    Expression<int>? originalDueAtUtc,
    Expression<int>? deferredUntilUtc,
    Expression<String>? schedulerVersion,
    Expression<String>? parametersVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (state != null) 'state': state,
      if (step != null) 'step': step,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (lastReviewUtc != null) 'last_review_utc': lastReviewUtc,
      if (dueAtUtc != null) 'due_at_utc': dueAtUtc,
      if (originalDueAtUtc != null) 'original_due_at_utc': originalDueAtUtc,
      if (deferredUntilUtc != null) 'deferred_until_utc': deferredUntilUtc,
      if (schedulerVersion != null) 'scheduler_version': schedulerVersion,
      if (parametersVersion != null) 'parameters_version': parametersVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardMemoriesCompanion copyWith({
    Value<String>? cardId,
    Value<double?>? stability,
    Value<double?>? difficulty,
    Value<int>? state,
    Value<int?>? step,
    Value<int>? reps,
    Value<int>? lapses,
    Value<int?>? lastReviewUtc,
    Value<int>? dueAtUtc,
    Value<int>? originalDueAtUtc,
    Value<int?>? deferredUntilUtc,
    Value<String>? schedulerVersion,
    Value<String>? parametersVersion,
    Value<int>? rowid,
  }) {
    return CardMemoriesCompanion(
      cardId: cardId ?? this.cardId,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      state: state ?? this.state,
      step: step ?? this.step,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastReviewUtc: lastReviewUtc ?? this.lastReviewUtc,
      dueAtUtc: dueAtUtc ?? this.dueAtUtc,
      originalDueAtUtc: originalDueAtUtc ?? this.originalDueAtUtc,
      deferredUntilUtc: deferredUntilUtc ?? this.deferredUntilUtc,
      schedulerVersion: schedulerVersion ?? this.schedulerVersion,
      parametersVersion: parametersVersion ?? this.parametersVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (state.present) {
      map['state'] = Variable<int>(state.value);
    }
    if (step.present) {
      map['step'] = Variable<int>(step.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (lastReviewUtc.present) {
      map['last_review_utc'] = Variable<int>(lastReviewUtc.value);
    }
    if (dueAtUtc.present) {
      map['due_at_utc'] = Variable<int>(dueAtUtc.value);
    }
    if (originalDueAtUtc.present) {
      map['original_due_at_utc'] = Variable<int>(originalDueAtUtc.value);
    }
    if (deferredUntilUtc.present) {
      map['deferred_until_utc'] = Variable<int>(deferredUntilUtc.value);
    }
    if (schedulerVersion.present) {
      map['scheduler_version'] = Variable<String>(schedulerVersion.value);
    }
    if (parametersVersion.present) {
      map['parameters_version'] = Variable<String>(parametersVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardMemoriesCompanion(')
          ..write('cardId: $cardId, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('state: $state, ')
          ..write('step: $step, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastReviewUtc: $lastReviewUtc, ')
          ..write('dueAtUtc: $dueAtUtc, ')
          ..write('originalDueAtUtc: $originalDueAtUtc, ')
          ..write('deferredUntilUtc: $deferredUntilUtc, ')
          ..write('schedulerVersion: $schedulerVersion, ')
          ..write('parametersVersion: $parametersVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewEventsTable extends ReviewEvents
    with TableInfo<$ReviewEventsTable, ReviewEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _reviewedAtUtcMeta = const VerificationMeta(
    'reviewedAtUtc',
  );
  @override
  late final GeneratedColumn<int> reviewedAtUtc = GeneratedColumn<int>(
    'reviewed_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    false,
    check: () => ComparableExpr(rating).isBetweenValues(1, 4),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preStateJsonMeta = const VerificationMeta(
    'preStateJson',
  );
  @override
  late final GeneratedColumn<String> preStateJson = GeneratedColumn<String>(
    'pre_state_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _postStateJsonMeta = const VerificationMeta(
    'postStateJson',
  );
  @override
  late final GeneratedColumn<String> postStateJson = GeneratedColumn<String>(
    'post_state_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _elapsedMsMeta = const VerificationMeta(
    'elapsedMs',
  );
  @override
  late final GeneratedColumn<int> elapsedMs = GeneratedColumn<int>(
    'elapsed_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schedulerVersionMeta = const VerificationMeta(
    'schedulerVersion',
  );
  @override
  late final GeneratedColumn<String> schedulerVersion = GeneratedColumn<String>(
    'scheduler_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parametersVersionMeta = const VerificationMeta(
    'parametersVersion',
  );
  @override
  late final GeneratedColumn<String> parametersVersion =
      GeneratedColumn<String>(
        'parameters_version',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _isPracticeMeta = const VerificationMeta(
    'isPractice',
  );
  @override
  late final GeneratedColumn<bool> isPractice = GeneratedColumn<bool>(
    'is_practice',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_practice" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    reviewedAtUtc,
    rating,
    preStateJson,
    postStateJson,
    elapsedMs,
    schedulerVersion,
    parametersVersion,
    isPractice,
    operationId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('reviewed_at_utc')) {
      context.handle(
        _reviewedAtUtcMeta,
        reviewedAtUtc.isAcceptableOrUnknown(
          data['reviewed_at_utc']!,
          _reviewedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reviewedAtUtcMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('pre_state_json')) {
      context.handle(
        _preStateJsonMeta,
        preStateJson.isAcceptableOrUnknown(
          data['pre_state_json']!,
          _preStateJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_preStateJsonMeta);
    }
    if (data.containsKey('post_state_json')) {
      context.handle(
        _postStateJsonMeta,
        postStateJson.isAcceptableOrUnknown(
          data['post_state_json']!,
          _postStateJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_postStateJsonMeta);
    }
    if (data.containsKey('elapsed_ms')) {
      context.handle(
        _elapsedMsMeta,
        elapsedMs.isAcceptableOrUnknown(data['elapsed_ms']!, _elapsedMsMeta),
      );
    }
    if (data.containsKey('scheduler_version')) {
      context.handle(
        _schedulerVersionMeta,
        schedulerVersion.isAcceptableOrUnknown(
          data['scheduler_version']!,
          _schedulerVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schedulerVersionMeta);
    }
    if (data.containsKey('parameters_version')) {
      context.handle(
        _parametersVersionMeta,
        parametersVersion.isAcceptableOrUnknown(
          data['parameters_version']!,
          _parametersVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parametersVersionMeta);
    }
    if (data.containsKey('is_practice')) {
      context.handle(
        _isPracticeMeta,
        isPractice.isAcceptableOrUnknown(data['is_practice']!, _isPracticeMeta),
      );
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_id'],
      )!,
      reviewedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reviewed_at_utc'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      )!,
      preStateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pre_state_json'],
      )!,
      postStateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_state_json'],
      )!,
      elapsedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_ms'],
      ),
      schedulerVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduler_version'],
      )!,
      parametersVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameters_version'],
      )!,
      isPractice: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_practice'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
    );
  }

  @override
  $ReviewEventsTable createAlias(String alias) {
    return $ReviewEventsTable(attachedDatabase, alias);
  }
}

class ReviewEventRow extends DataClass implements Insertable<ReviewEventRow> {
  final String id;
  final String cardId;
  final int reviewedAtUtc;

  /// Again, Hard, Good, Easy.
  final int rating;

  /// FSRS state before the review, as JSON. Undo restores from this, and a
  /// future parameter optimizer replays from it.
  final String preStateJson;
  final String postStateJson;
  final int? elapsedMs;
  final String schedulerVersion;
  final String parametersVersion;

  /// Practice-session grades are logged but never touch memory state, due
  /// dates, admission, or future optimization.
  final bool isPractice;
  final String operationId;
  const ReviewEventRow({
    required this.id,
    required this.cardId,
    required this.reviewedAtUtc,
    required this.rating,
    required this.preStateJson,
    required this.postStateJson,
    this.elapsedMs,
    required this.schedulerVersion,
    required this.parametersVersion,
    required this.isPractice,
    required this.operationId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['card_id'] = Variable<String>(cardId);
    map['reviewed_at_utc'] = Variable<int>(reviewedAtUtc);
    map['rating'] = Variable<int>(rating);
    map['pre_state_json'] = Variable<String>(preStateJson);
    map['post_state_json'] = Variable<String>(postStateJson);
    if (!nullToAbsent || elapsedMs != null) {
      map['elapsed_ms'] = Variable<int>(elapsedMs);
    }
    map['scheduler_version'] = Variable<String>(schedulerVersion);
    map['parameters_version'] = Variable<String>(parametersVersion);
    map['is_practice'] = Variable<bool>(isPractice);
    map['operation_id'] = Variable<String>(operationId);
    return map;
  }

  ReviewEventsCompanion toCompanion(bool nullToAbsent) {
    return ReviewEventsCompanion(
      id: Value(id),
      cardId: Value(cardId),
      reviewedAtUtc: Value(reviewedAtUtc),
      rating: Value(rating),
      preStateJson: Value(preStateJson),
      postStateJson: Value(postStateJson),
      elapsedMs: elapsedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(elapsedMs),
      schedulerVersion: Value(schedulerVersion),
      parametersVersion: Value(parametersVersion),
      isPractice: Value(isPractice),
      operationId: Value(operationId),
    );
  }

  factory ReviewEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewEventRow(
      id: serializer.fromJson<String>(json['id']),
      cardId: serializer.fromJson<String>(json['cardId']),
      reviewedAtUtc: serializer.fromJson<int>(json['reviewedAtUtc']),
      rating: serializer.fromJson<int>(json['rating']),
      preStateJson: serializer.fromJson<String>(json['preStateJson']),
      postStateJson: serializer.fromJson<String>(json['postStateJson']),
      elapsedMs: serializer.fromJson<int?>(json['elapsedMs']),
      schedulerVersion: serializer.fromJson<String>(json['schedulerVersion']),
      parametersVersion: serializer.fromJson<String>(json['parametersVersion']),
      isPractice: serializer.fromJson<bool>(json['isPractice']),
      operationId: serializer.fromJson<String>(json['operationId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cardId': serializer.toJson<String>(cardId),
      'reviewedAtUtc': serializer.toJson<int>(reviewedAtUtc),
      'rating': serializer.toJson<int>(rating),
      'preStateJson': serializer.toJson<String>(preStateJson),
      'postStateJson': serializer.toJson<String>(postStateJson),
      'elapsedMs': serializer.toJson<int?>(elapsedMs),
      'schedulerVersion': serializer.toJson<String>(schedulerVersion),
      'parametersVersion': serializer.toJson<String>(parametersVersion),
      'isPractice': serializer.toJson<bool>(isPractice),
      'operationId': serializer.toJson<String>(operationId),
    };
  }

  ReviewEventRow copyWith({
    String? id,
    String? cardId,
    int? reviewedAtUtc,
    int? rating,
    String? preStateJson,
    String? postStateJson,
    Value<int?> elapsedMs = const Value.absent(),
    String? schedulerVersion,
    String? parametersVersion,
    bool? isPractice,
    String? operationId,
  }) => ReviewEventRow(
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    reviewedAtUtc: reviewedAtUtc ?? this.reviewedAtUtc,
    rating: rating ?? this.rating,
    preStateJson: preStateJson ?? this.preStateJson,
    postStateJson: postStateJson ?? this.postStateJson,
    elapsedMs: elapsedMs.present ? elapsedMs.value : this.elapsedMs,
    schedulerVersion: schedulerVersion ?? this.schedulerVersion,
    parametersVersion: parametersVersion ?? this.parametersVersion,
    isPractice: isPractice ?? this.isPractice,
    operationId: operationId ?? this.operationId,
  );
  ReviewEventRow copyWithCompanion(ReviewEventsCompanion data) {
    return ReviewEventRow(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      reviewedAtUtc: data.reviewedAtUtc.present
          ? data.reviewedAtUtc.value
          : this.reviewedAtUtc,
      rating: data.rating.present ? data.rating.value : this.rating,
      preStateJson: data.preStateJson.present
          ? data.preStateJson.value
          : this.preStateJson,
      postStateJson: data.postStateJson.present
          ? data.postStateJson.value
          : this.postStateJson,
      elapsedMs: data.elapsedMs.present ? data.elapsedMs.value : this.elapsedMs,
      schedulerVersion: data.schedulerVersion.present
          ? data.schedulerVersion.value
          : this.schedulerVersion,
      parametersVersion: data.parametersVersion.present
          ? data.parametersVersion.value
          : this.parametersVersion,
      isPractice: data.isPractice.present
          ? data.isPractice.value
          : this.isPractice,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewEventRow(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('reviewedAtUtc: $reviewedAtUtc, ')
          ..write('rating: $rating, ')
          ..write('preStateJson: $preStateJson, ')
          ..write('postStateJson: $postStateJson, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('schedulerVersion: $schedulerVersion, ')
          ..write('parametersVersion: $parametersVersion, ')
          ..write('isPractice: $isPractice, ')
          ..write('operationId: $operationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cardId,
    reviewedAtUtc,
    rating,
    preStateJson,
    postStateJson,
    elapsedMs,
    schedulerVersion,
    parametersVersion,
    isPractice,
    operationId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewEventRow &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.reviewedAtUtc == this.reviewedAtUtc &&
          other.rating == this.rating &&
          other.preStateJson == this.preStateJson &&
          other.postStateJson == this.postStateJson &&
          other.elapsedMs == this.elapsedMs &&
          other.schedulerVersion == this.schedulerVersion &&
          other.parametersVersion == this.parametersVersion &&
          other.isPractice == this.isPractice &&
          other.operationId == this.operationId);
}

class ReviewEventsCompanion extends UpdateCompanion<ReviewEventRow> {
  final Value<String> id;
  final Value<String> cardId;
  final Value<int> reviewedAtUtc;
  final Value<int> rating;
  final Value<String> preStateJson;
  final Value<String> postStateJson;
  final Value<int?> elapsedMs;
  final Value<String> schedulerVersion;
  final Value<String> parametersVersion;
  final Value<bool> isPractice;
  final Value<String> operationId;
  final Value<int> rowid;
  const ReviewEventsCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.reviewedAtUtc = const Value.absent(),
    this.rating = const Value.absent(),
    this.preStateJson = const Value.absent(),
    this.postStateJson = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.schedulerVersion = const Value.absent(),
    this.parametersVersion = const Value.absent(),
    this.isPractice = const Value.absent(),
    this.operationId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewEventsCompanion.insert({
    required String id,
    required String cardId,
    required int reviewedAtUtc,
    required int rating,
    required String preStateJson,
    required String postStateJson,
    this.elapsedMs = const Value.absent(),
    required String schedulerVersion,
    required String parametersVersion,
    this.isPractice = const Value.absent(),
    required String operationId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cardId = Value(cardId),
       reviewedAtUtc = Value(reviewedAtUtc),
       rating = Value(rating),
       preStateJson = Value(preStateJson),
       postStateJson = Value(postStateJson),
       schedulerVersion = Value(schedulerVersion),
       parametersVersion = Value(parametersVersion),
       operationId = Value(operationId);
  static Insertable<ReviewEventRow> custom({
    Expression<String>? id,
    Expression<String>? cardId,
    Expression<int>? reviewedAtUtc,
    Expression<int>? rating,
    Expression<String>? preStateJson,
    Expression<String>? postStateJson,
    Expression<int>? elapsedMs,
    Expression<String>? schedulerVersion,
    Expression<String>? parametersVersion,
    Expression<bool>? isPractice,
    Expression<String>? operationId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (reviewedAtUtc != null) 'reviewed_at_utc': reviewedAtUtc,
      if (rating != null) 'rating': rating,
      if (preStateJson != null) 'pre_state_json': preStateJson,
      if (postStateJson != null) 'post_state_json': postStateJson,
      if (elapsedMs != null) 'elapsed_ms': elapsedMs,
      if (schedulerVersion != null) 'scheduler_version': schedulerVersion,
      if (parametersVersion != null) 'parameters_version': parametersVersion,
      if (isPractice != null) 'is_practice': isPractice,
      if (operationId != null) 'operation_id': operationId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? cardId,
    Value<int>? reviewedAtUtc,
    Value<int>? rating,
    Value<String>? preStateJson,
    Value<String>? postStateJson,
    Value<int?>? elapsedMs,
    Value<String>? schedulerVersion,
    Value<String>? parametersVersion,
    Value<bool>? isPractice,
    Value<String>? operationId,
    Value<int>? rowid,
  }) {
    return ReviewEventsCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      reviewedAtUtc: reviewedAtUtc ?? this.reviewedAtUtc,
      rating: rating ?? this.rating,
      preStateJson: preStateJson ?? this.preStateJson,
      postStateJson: postStateJson ?? this.postStateJson,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      schedulerVersion: schedulerVersion ?? this.schedulerVersion,
      parametersVersion: parametersVersion ?? this.parametersVersion,
      isPractice: isPractice ?? this.isPractice,
      operationId: operationId ?? this.operationId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (reviewedAtUtc.present) {
      map['reviewed_at_utc'] = Variable<int>(reviewedAtUtc.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (preStateJson.present) {
      map['pre_state_json'] = Variable<String>(preStateJson.value);
    }
    if (postStateJson.present) {
      map['post_state_json'] = Variable<String>(postStateJson.value);
    }
    if (elapsedMs.present) {
      map['elapsed_ms'] = Variable<int>(elapsedMs.value);
    }
    if (schedulerVersion.present) {
      map['scheduler_version'] = Variable<String>(schedulerVersion.value);
    }
    if (parametersVersion.present) {
      map['parameters_version'] = Variable<String>(parametersVersion.value);
    }
    if (isPractice.present) {
      map['is_practice'] = Variable<bool>(isPractice.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewEventsCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('reviewedAtUtc: $reviewedAtUtc, ')
          ..write('rating: $rating, ')
          ..write('preStateJson: $preStateJson, ')
          ..write('postStateJson: $postStateJson, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('schedulerVersion: $schedulerVersion, ')
          ..write('parametersVersion: $parametersVersion, ')
          ..write('isPractice: $isPractice, ')
          ..write('operationId: $operationId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActivityEventsTable extends ActivityEvents
    with TableInfo<$ActivityEventsTable, ActivityEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _elementIdMeta = const VerificationMeta(
    'elementId',
  );
  @override
  late final GeneratedColumn<String> elementId = GeneratedColumn<String>(
    'element_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elementTypeMeta = const VerificationMeta(
    'elementType',
  );
  @override
  late final GeneratedColumn<int> elementType = GeneratedColumn<int>(
    'element_type',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atUtcMeta = const VerificationMeta('atUtc');
  @override
  late final GeneratedColumn<int> atUtc = GeneratedColumn<int>(
    'at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operationId,
    elementId,
    elementType,
    kind,
    atUtc,
    durationMs,
    metadataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('element_id')) {
      context.handle(
        _elementIdMeta,
        elementId.isAcceptableOrUnknown(data['element_id']!, _elementIdMeta),
      );
    }
    if (data.containsKey('element_type')) {
      context.handle(
        _elementTypeMeta,
        elementType.isAcceptableOrUnknown(
          data['element_type']!,
          _elementTypeMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('at_utc')) {
      context.handle(
        _atUtcMeta,
        atUtc.isAcceptableOrUnknown(data['at_utc']!, _atUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_atUtcMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      elementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}element_id'],
      ),
      elementType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}element_type'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      atUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_utc'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
    );
  }

  @override
  $ActivityEventsTable createAlias(String alias) {
    return $ActivityEventsTable(attachedDatabase, alias);
  }
}

class ActivityEventRow extends DataClass
    implements Insertable<ActivityEventRow> {
  final String id;
  final String operationId;
  final String? elementId;
  final int? elementType;

  /// Stable dotted event name, for example `reader.done`.
  final String kind;
  final int atUtc;

  /// Foreground duration, logged from day one so time-based features remain
  /// possible later even though v1 is count-based.
  final int? durationMs;
  final String? metadataJson;
  const ActivityEventRow({
    required this.id,
    required this.operationId,
    this.elementId,
    this.elementType,
    required this.kind,
    required this.atUtc,
    this.durationMs,
    this.metadataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['operation_id'] = Variable<String>(operationId);
    if (!nullToAbsent || elementId != null) {
      map['element_id'] = Variable<String>(elementId);
    }
    if (!nullToAbsent || elementType != null) {
      map['element_type'] = Variable<int>(elementType);
    }
    map['kind'] = Variable<String>(kind);
    map['at_utc'] = Variable<int>(atUtc);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    return map;
  }

  ActivityEventsCompanion toCompanion(bool nullToAbsent) {
    return ActivityEventsCompanion(
      id: Value(id),
      operationId: Value(operationId),
      elementId: elementId == null && nullToAbsent
          ? const Value.absent()
          : Value(elementId),
      elementType: elementType == null && nullToAbsent
          ? const Value.absent()
          : Value(elementType),
      kind: Value(kind),
      atUtc: Value(atUtc),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
    );
  }

  factory ActivityEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityEventRow(
      id: serializer.fromJson<String>(json['id']),
      operationId: serializer.fromJson<String>(json['operationId']),
      elementId: serializer.fromJson<String?>(json['elementId']),
      elementType: serializer.fromJson<int?>(json['elementType']),
      kind: serializer.fromJson<String>(json['kind']),
      atUtc: serializer.fromJson<int>(json['atUtc']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'operationId': serializer.toJson<String>(operationId),
      'elementId': serializer.toJson<String?>(elementId),
      'elementType': serializer.toJson<int?>(elementType),
      'kind': serializer.toJson<String>(kind),
      'atUtc': serializer.toJson<int>(atUtc),
      'durationMs': serializer.toJson<int?>(durationMs),
      'metadataJson': serializer.toJson<String?>(metadataJson),
    };
  }

  ActivityEventRow copyWith({
    String? id,
    String? operationId,
    Value<String?> elementId = const Value.absent(),
    Value<int?> elementType = const Value.absent(),
    String? kind,
    int? atUtc,
    Value<int?> durationMs = const Value.absent(),
    Value<String?> metadataJson = const Value.absent(),
  }) => ActivityEventRow(
    id: id ?? this.id,
    operationId: operationId ?? this.operationId,
    elementId: elementId.present ? elementId.value : this.elementId,
    elementType: elementType.present ? elementType.value : this.elementType,
    kind: kind ?? this.kind,
    atUtc: atUtc ?? this.atUtc,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
  );
  ActivityEventRow copyWithCompanion(ActivityEventsCompanion data) {
    return ActivityEventRow(
      id: data.id.present ? data.id.value : this.id,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      elementId: data.elementId.present ? data.elementId.value : this.elementId,
      elementType: data.elementType.present
          ? data.elementType.value
          : this.elementType,
      kind: data.kind.present ? data.kind.value : this.kind,
      atUtc: data.atUtc.present ? data.atUtc.value : this.atUtc,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEventRow(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('kind: $kind, ')
          ..write('atUtc: $atUtc, ')
          ..write('durationMs: $durationMs, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operationId,
    elementId,
    elementType,
    kind,
    atUtc,
    durationMs,
    metadataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityEventRow &&
          other.id == this.id &&
          other.operationId == this.operationId &&
          other.elementId == this.elementId &&
          other.elementType == this.elementType &&
          other.kind == this.kind &&
          other.atUtc == this.atUtc &&
          other.durationMs == this.durationMs &&
          other.metadataJson == this.metadataJson);
}

class ActivityEventsCompanion extends UpdateCompanion<ActivityEventRow> {
  final Value<String> id;
  final Value<String> operationId;
  final Value<String?> elementId;
  final Value<int?> elementType;
  final Value<String> kind;
  final Value<int> atUtc;
  final Value<int?> durationMs;
  final Value<String?> metadataJson;
  final Value<int> rowid;
  const ActivityEventsCompanion({
    this.id = const Value.absent(),
    this.operationId = const Value.absent(),
    this.elementId = const Value.absent(),
    this.elementType = const Value.absent(),
    this.kind = const Value.absent(),
    this.atUtc = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivityEventsCompanion.insert({
    required String id,
    required String operationId,
    this.elementId = const Value.absent(),
    this.elementType = const Value.absent(),
    required String kind,
    required int atUtc,
    this.durationMs = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       operationId = Value(operationId),
       kind = Value(kind),
       atUtc = Value(atUtc);
  static Insertable<ActivityEventRow> custom({
    Expression<String>? id,
    Expression<String>? operationId,
    Expression<String>? elementId,
    Expression<int>? elementType,
    Expression<String>? kind,
    Expression<int>? atUtc,
    Expression<int>? durationMs,
    Expression<String>? metadataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationId != null) 'operation_id': operationId,
      if (elementId != null) 'element_id': elementId,
      if (elementType != null) 'element_type': elementType,
      if (kind != null) 'kind': kind,
      if (atUtc != null) 'at_utc': atUtc,
      if (durationMs != null) 'duration_ms': durationMs,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivityEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? operationId,
    Value<String?>? elementId,
    Value<int?>? elementType,
    Value<String>? kind,
    Value<int>? atUtc,
    Value<int?>? durationMs,
    Value<String?>? metadataJson,
    Value<int>? rowid,
  }) {
    return ActivityEventsCompanion(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      elementId: elementId ?? this.elementId,
      elementType: elementType ?? this.elementType,
      kind: kind ?? this.kind,
      atUtc: atUtc ?? this.atUtc,
      durationMs: durationMs ?? this.durationMs,
      metadataJson: metadataJson ?? this.metadataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (elementId.present) {
      map['element_id'] = Variable<String>(elementId.value);
    }
    if (elementType.present) {
      map['element_type'] = Variable<int>(elementType.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (atUtc.present) {
      map['at_utc'] = Variable<int>(atUtc.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEventsCompanion(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('kind: $kind, ')
          ..write('atUtc: $atUtc, ')
          ..write('durationMs: $durationMs, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DatasetMetaTable extends DatasetMeta
    with TableInfo<$DatasetMetaTable, DatasetMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DatasetMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _datasetIdMeta = const VerificationMeta(
    'datasetId',
  );
  @override
  late final GeneratedColumn<String> datasetId = GeneratedColumn<String>(
    'dataset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<int> generation = GeneratedColumn<int>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _writerEpochMeta = const VerificationMeta(
    'writerEpoch',
  );
  @override
  late final GeneratedColumn<int> writerEpoch = GeneratedColumn<int>(
    'writer_epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerDeviceIdMeta = const VerificationMeta(
    'ownerDeviceId',
  );
  @override
  late final GeneratedColumn<String> ownerDeviceId = GeneratedColumn<String>(
    'owner_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    datasetId,
    generation,
    writerEpoch,
    ownerDeviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dataset_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<DatasetMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('dataset_id')) {
      context.handle(
        _datasetIdMeta,
        datasetId.isAcceptableOrUnknown(data['dataset_id']!, _datasetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_datasetIdMeta);
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    } else if (isInserting) {
      context.missing(_generationMeta);
    }
    if (data.containsKey('writer_epoch')) {
      context.handle(
        _writerEpochMeta,
        writerEpoch.isAcceptableOrUnknown(
          data['writer_epoch']!,
          _writerEpochMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_writerEpochMeta);
    }
    if (data.containsKey('owner_device_id')) {
      context.handle(
        _ownerDeviceIdMeta,
        ownerDeviceId.isAcceptableOrUnknown(
          data['owner_device_id']!,
          _ownerDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerDeviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DatasetMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DatasetMetaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      datasetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dataset_id'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation'],
      )!,
      writerEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}writer_epoch'],
      )!,
      ownerDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_device_id'],
      )!,
    );
  }

  @override
  $DatasetMetaTable createAlias(String alias) {
    return $DatasetMetaTable(attachedDatabase, alias);
  }
}

class DatasetMetaRow extends DataClass implements Insertable<DatasetMetaRow> {
  /// Always 1: the table holds exactly one row.
  final int id;
  final String datasetId;
  final int generation;
  final int writerEpoch;
  final String ownerDeviceId;
  const DatasetMetaRow({
    required this.id,
    required this.datasetId,
    required this.generation,
    required this.writerEpoch,
    required this.ownerDeviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['dataset_id'] = Variable<String>(datasetId);
    map['generation'] = Variable<int>(generation);
    map['writer_epoch'] = Variable<int>(writerEpoch);
    map['owner_device_id'] = Variable<String>(ownerDeviceId);
    return map;
  }

  DatasetMetaCompanion toCompanion(bool nullToAbsent) {
    return DatasetMetaCompanion(
      id: Value(id),
      datasetId: Value(datasetId),
      generation: Value(generation),
      writerEpoch: Value(writerEpoch),
      ownerDeviceId: Value(ownerDeviceId),
    );
  }

  factory DatasetMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DatasetMetaRow(
      id: serializer.fromJson<int>(json['id']),
      datasetId: serializer.fromJson<String>(json['datasetId']),
      generation: serializer.fromJson<int>(json['generation']),
      writerEpoch: serializer.fromJson<int>(json['writerEpoch']),
      ownerDeviceId: serializer.fromJson<String>(json['ownerDeviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'datasetId': serializer.toJson<String>(datasetId),
      'generation': serializer.toJson<int>(generation),
      'writerEpoch': serializer.toJson<int>(writerEpoch),
      'ownerDeviceId': serializer.toJson<String>(ownerDeviceId),
    };
  }

  DatasetMetaRow copyWith({
    int? id,
    String? datasetId,
    int? generation,
    int? writerEpoch,
    String? ownerDeviceId,
  }) => DatasetMetaRow(
    id: id ?? this.id,
    datasetId: datasetId ?? this.datasetId,
    generation: generation ?? this.generation,
    writerEpoch: writerEpoch ?? this.writerEpoch,
    ownerDeviceId: ownerDeviceId ?? this.ownerDeviceId,
  );
  DatasetMetaRow copyWithCompanion(DatasetMetaCompanion data) {
    return DatasetMetaRow(
      id: data.id.present ? data.id.value : this.id,
      datasetId: data.datasetId.present ? data.datasetId.value : this.datasetId,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      writerEpoch: data.writerEpoch.present
          ? data.writerEpoch.value
          : this.writerEpoch,
      ownerDeviceId: data.ownerDeviceId.present
          ? data.ownerDeviceId.value
          : this.ownerDeviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DatasetMetaRow(')
          ..write('id: $id, ')
          ..write('datasetId: $datasetId, ')
          ..write('generation: $generation, ')
          ..write('writerEpoch: $writerEpoch, ')
          ..write('ownerDeviceId: $ownerDeviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, datasetId, generation, writerEpoch, ownerDeviceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DatasetMetaRow &&
          other.id == this.id &&
          other.datasetId == this.datasetId &&
          other.generation == this.generation &&
          other.writerEpoch == this.writerEpoch &&
          other.ownerDeviceId == this.ownerDeviceId);
}

class DatasetMetaCompanion extends UpdateCompanion<DatasetMetaRow> {
  final Value<int> id;
  final Value<String> datasetId;
  final Value<int> generation;
  final Value<int> writerEpoch;
  final Value<String> ownerDeviceId;
  const DatasetMetaCompanion({
    this.id = const Value.absent(),
    this.datasetId = const Value.absent(),
    this.generation = const Value.absent(),
    this.writerEpoch = const Value.absent(),
    this.ownerDeviceId = const Value.absent(),
  });
  DatasetMetaCompanion.insert({
    this.id = const Value.absent(),
    required String datasetId,
    required int generation,
    required int writerEpoch,
    required String ownerDeviceId,
  }) : datasetId = Value(datasetId),
       generation = Value(generation),
       writerEpoch = Value(writerEpoch),
       ownerDeviceId = Value(ownerDeviceId);
  static Insertable<DatasetMetaRow> custom({
    Expression<int>? id,
    Expression<String>? datasetId,
    Expression<int>? generation,
    Expression<int>? writerEpoch,
    Expression<String>? ownerDeviceId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (datasetId != null) 'dataset_id': datasetId,
      if (generation != null) 'generation': generation,
      if (writerEpoch != null) 'writer_epoch': writerEpoch,
      if (ownerDeviceId != null) 'owner_device_id': ownerDeviceId,
    });
  }

  DatasetMetaCompanion copyWith({
    Value<int>? id,
    Value<String>? datasetId,
    Value<int>? generation,
    Value<int>? writerEpoch,
    Value<String>? ownerDeviceId,
  }) {
    return DatasetMetaCompanion(
      id: id ?? this.id,
      datasetId: datasetId ?? this.datasetId,
      generation: generation ?? this.generation,
      writerEpoch: writerEpoch ?? this.writerEpoch,
      ownerDeviceId: ownerDeviceId ?? this.ownerDeviceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (datasetId.present) {
      map['dataset_id'] = Variable<String>(datasetId.value);
    }
    if (generation.present) {
      map['generation'] = Variable<int>(generation.value);
    }
    if (writerEpoch.present) {
      map['writer_epoch'] = Variable<int>(writerEpoch.value);
    }
    if (ownerDeviceId.present) {
      map['owner_device_id'] = Variable<String>(ownerDeviceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DatasetMetaCompanion(')
          ..write('id: $id, ')
          ..write('datasetId: $datasetId, ')
          ..write('generation: $generation, ')
          ..write('writerEpoch: $writerEpoch, ')
          ..write('ownerDeviceId: $ownerDeviceId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $SourcesTable sources = $SourcesTable(this);
  late final $BlocksTable blocks = $BlocksTable(this);
  late final $ExtractsTable extracts = $ExtractsTable(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $ElementSchedulesTable elementSchedules = $ElementSchedulesTable(
    this,
  );
  late final $TopicStatesTable topicStates = $TopicStatesTable(this);
  late final $CardMemoriesTable cardMemories = $CardMemoriesTable(this);
  late final $ReviewEventsTable reviewEvents = $ReviewEventsTable(this);
  late final $ActivityEventsTable activityEvents = $ActivityEventsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $DatasetMetaTable datasetMeta = $DatasetMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    folders,
    sources,
    blocks,
    extracts,
    cards,
    elementSchedules,
    topicStates,
    cardMemories,
    reviewEvents,
    activityEvents,
    settings,
    datasetMeta,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sources', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('blocks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_memories', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('review_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FoldersTableCreateCompanionBuilder =
    FoldersCompanion Function({
      required String id,
      Value<String?> parentId,
      required String name,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$FoldersTableUpdateCompanionBuilder =
    FoldersCompanion Function({
      Value<String> id,
      Value<String?> parentId,
      Value<String> name,
      Value<int> position,
      Value<int> rowid,
    });

final class $$FoldersTableReferences
    extends BaseReferences<_$AppDatabase, $FoldersTable, FolderRow> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SourcesTable, List<SourceRow>> _sourcesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.sources,
    aliasName: 'folders__id__sources__folder_id',
  );

  $$SourcesTableProcessedTableManager get sourcesRefs {
    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sourcesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
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

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sourcesRefs(
    Expression<bool> Function($$SourcesTableFilterComposer f) f,
  ) {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
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

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  Expression<T> sourcesRefs<T extends Object>(
    Expression<T> Function($$SourcesTableAnnotationComposer a) f,
  ) {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          FolderRow,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (FolderRow, $$FoldersTableReferences),
          FolderRow,
          PrefetchHooks Function({bool sourcesRefs})
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                parentId: parentId,
                name: name,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> parentId = const Value.absent(),
                required String name,
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                parentId: parentId,
                name: name,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourcesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sourcesRefs) db.sources],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sourcesRefs)
                    await $_getPrefetchedData<
                      FolderRow,
                      $FoldersTable,
                      SourceRow
                    >(
                      currentTable: table,
                      referencedTable: $$FoldersTableReferences
                          ._sourcesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FoldersTableReferences(db, table, p0).sourcesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      FolderRow,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (FolderRow, $$FoldersTableReferences),
      FolderRow,
      PrefetchHooks Function({bool sourcesRefs})
    >;
typedef $$SourcesTableCreateCompanionBuilder =
    SourcesCompanion Function({
      required String id,
      required String title,
      required String markdown,
      required String contentHash,
      required int wordCount,
      required int importedAtUtc,
      Value<int> pace,
      Value<String?> markerBlockId,
      Value<int?> markerOffset,
      Value<String?> softBlockId,
      Value<int?> softOffset,
      Value<String?> folderId,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$SourcesTableUpdateCompanionBuilder =
    SourcesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> markdown,
      Value<String> contentHash,
      Value<int> wordCount,
      Value<int> importedAtUtc,
      Value<int> pace,
      Value<String?> markerBlockId,
      Value<int?> markerOffset,
      Value<String?> softBlockId,
      Value<int?> softOffset,
      Value<String?> folderId,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$SourcesTableReferences
    extends BaseReferences<_$AppDatabase, $SourcesTable, SourceRow> {
  $$SourcesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoldersTable _folderIdTable(_$AppDatabase db) =>
      db.folders.createAlias('sources__folder_id__folders__id');

  $$FoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<String>('folder_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$BlocksTable, List<BlockRow>> _blocksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.blocks,
    aliasName: 'sources__id__blocks__source_id',
  );

  $$BlocksTableProcessedTableManager get blocksRefs {
    final manager = $$BlocksTableTableManager(
      $_db,
      $_db.blocks,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_blocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExtractsTable, List<ExtractRow>>
  _extractsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.extracts,
    aliasName: 'sources__id__extracts__source_id',
  );

  $$ExtractsTableProcessedTableManager get extractsRefs {
    final manager = $$ExtractsTableTableManager(
      $_db,
      $_db.extracts,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_extractsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CardsTable, List<CardRow>> _cardsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cards,
    aliasName: 'sources__id__cards__source_id',
  );

  $$CardsTableProcessedTableManager get cardsRefs {
    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SourcesTableFilterComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get markdown => $composableBuilder(
    column: $table.markdown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedAtUtc => $composableBuilder(
    column: $table.importedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pace => $composableBuilder(
    column: $table.pace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get markerBlockId => $composableBuilder(
    column: $table.markerBlockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get markerOffset => $composableBuilder(
    column: $table.markerOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get softBlockId => $composableBuilder(
    column: $table.softBlockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get softOffset => $composableBuilder(
    column: $table.softOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$FoldersTableFilterComposer get folderId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> blocksRefs(
    Expression<bool> Function($$BlocksTableFilterComposer f) f,
  ) {
    final $$BlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.blocks,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BlocksTableFilterComposer(
            $db: $db,
            $table: $db.blocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> extractsRefs(
    Expression<bool> Function($$ExtractsTableFilterComposer f) f,
  ) {
    final $$ExtractsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.extracts,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtractsTableFilterComposer(
            $db: $db,
            $table: $db.extracts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cardsRefs(
    Expression<bool> Function($$CardsTableFilterComposer f) f,
  ) {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get markdown => $composableBuilder(
    column: $table.markdown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedAtUtc => $composableBuilder(
    column: $table.importedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pace => $composableBuilder(
    column: $table.pace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get markerBlockId => $composableBuilder(
    column: $table.markerBlockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get markerOffset => $composableBuilder(
    column: $table.markerOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get softBlockId => $composableBuilder(
    column: $table.softBlockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get softOffset => $composableBuilder(
    column: $table.softOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoldersTableOrderingComposer get folderId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get markdown =>
      $composableBuilder(column: $table.markdown, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<int> get importedAtUtc => $composableBuilder(
    column: $table.importedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pace =>
      $composableBuilder(column: $table.pace, builder: (column) => column);

  GeneratedColumn<String> get markerBlockId => $composableBuilder(
    column: $table.markerBlockId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get markerOffset => $composableBuilder(
    column: $table.markerOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get softBlockId => $composableBuilder(
    column: $table.softBlockId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get softOffset => $composableBuilder(
    column: $table.softOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$FoldersTableAnnotationComposer get folderId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> blocksRefs<T extends Object>(
    Expression<T> Function($$BlocksTableAnnotationComposer a) f,
  ) {
    final $$BlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.blocks,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.blocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> extractsRefs<T extends Object>(
    Expression<T> Function($$ExtractsTableAnnotationComposer a) f,
  ) {
    final $$ExtractsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.extracts,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtractsTableAnnotationComposer(
            $db: $db,
            $table: $db.extracts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cardsRefs<T extends Object>(
    Expression<T> Function($$CardsTableAnnotationComposer a) f,
  ) {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourcesTable,
          SourceRow,
          $$SourcesTableFilterComposer,
          $$SourcesTableOrderingComposer,
          $$SourcesTableAnnotationComposer,
          $$SourcesTableCreateCompanionBuilder,
          $$SourcesTableUpdateCompanionBuilder,
          (SourceRow, $$SourcesTableReferences),
          SourceRow,
          PrefetchHooks Function({
            bool folderId,
            bool blocksRefs,
            bool extractsRefs,
            bool cardsRefs,
          })
        > {
  $$SourcesTableTableManager(_$AppDatabase db, $SourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> markdown = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<int> importedAtUtc = const Value.absent(),
                Value<int> pace = const Value.absent(),
                Value<String?> markerBlockId = const Value.absent(),
                Value<int?> markerOffset = const Value.absent(),
                Value<String?> softBlockId = const Value.absent(),
                Value<int?> softOffset = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion(
                id: id,
                title: title,
                markdown: markdown,
                contentHash: contentHash,
                wordCount: wordCount,
                importedAtUtc: importedAtUtc,
                pace: pace,
                markerBlockId: markerBlockId,
                markerOffset: markerOffset,
                softBlockId: softBlockId,
                softOffset: softOffset,
                folderId: folderId,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String markdown,
                required String contentHash,
                required int wordCount,
                required int importedAtUtc,
                Value<int> pace = const Value.absent(),
                Value<String?> markerBlockId = const Value.absent(),
                Value<int?> markerOffset = const Value.absent(),
                Value<String?> softBlockId = const Value.absent(),
                Value<int?> softOffset = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion.insert(
                id: id,
                title: title,
                markdown: markdown,
                contentHash: contentHash,
                wordCount: wordCount,
                importedAtUtc: importedAtUtc,
                pace: pace,
                markerBlockId: markerBlockId,
                markerOffset: markerOffset,
                softBlockId: softBlockId,
                softOffset: softOffset,
                folderId: folderId,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                folderId = false,
                blocksRefs = false,
                extractsRefs = false,
                cardsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (blocksRefs) db.blocks,
                    if (extractsRefs) db.extracts,
                    if (cardsRefs) db.cards,
                  ],
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
                        if (folderId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.folderId,
                                    referencedTable: $$SourcesTableReferences
                                        ._folderIdTable(db),
                                    referencedColumn: $$SourcesTableReferences
                                        ._folderIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (blocksRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          BlockRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._blocksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).blocksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (extractsRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          ExtractRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._extractsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).extractsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cardsRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          CardRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._cardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(db, table, p0).cardsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
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

typedef $$SourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourcesTable,
      SourceRow,
      $$SourcesTableFilterComposer,
      $$SourcesTableOrderingComposer,
      $$SourcesTableAnnotationComposer,
      $$SourcesTableCreateCompanionBuilder,
      $$SourcesTableUpdateCompanionBuilder,
      (SourceRow, $$SourcesTableReferences),
      SourceRow,
      PrefetchHooks Function({
        bool folderId,
        bool blocksRefs,
        bool extractsRefs,
        bool cardsRefs,
      })
    >;
typedef $$BlocksTableCreateCompanionBuilder =
    BlocksCompanion Function({
      required String id,
      required String sourceId,
      required int idx,
      required int type,
      required String raw,
      required int startUtf8,
      required int endUtf8,
      required int startUtf16,
      required String contentSpans,
      Value<int?> headingLevel,
      Value<String?> codeLanguage,
      Value<bool> ordered,
      Value<String?> listMarker,
      Value<int> listDepth,
      Value<int> quoteDepth,
      Value<int> rowid,
    });
typedef $$BlocksTableUpdateCompanionBuilder =
    BlocksCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<int> idx,
      Value<int> type,
      Value<String> raw,
      Value<int> startUtf8,
      Value<int> endUtf8,
      Value<int> startUtf16,
      Value<String> contentSpans,
      Value<int?> headingLevel,
      Value<String?> codeLanguage,
      Value<bool> ordered,
      Value<String?> listMarker,
      Value<int> listDepth,
      Value<int> quoteDepth,
      Value<int> rowid,
    });

final class $$BlocksTableReferences
    extends BaseReferences<_$AppDatabase, $BlocksTable, BlockRow> {
  $$BlocksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('blocks__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BlocksTableFilterComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableFilterComposer({
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

  ColumnFilters<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get raw => $composableBuilder(
    column: $table.raw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startUtf8 => $composableBuilder(
    column: $table.startUtf8,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endUtf8 => $composableBuilder(
    column: $table.endUtf8,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startUtf16 => $composableBuilder(
    column: $table.startUtf16,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentSpans => $composableBuilder(
    column: $table.contentSpans,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get headingLevel => $composableBuilder(
    column: $table.headingLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codeLanguage => $composableBuilder(
    column: $table.codeLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ordered => $composableBuilder(
    column: $table.ordered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listMarker => $composableBuilder(
    column: $table.listMarker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listDepth => $composableBuilder(
    column: $table.listDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quoteDepth => $composableBuilder(
    column: $table.quoteDepth,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableOrderingComposer({
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

  ColumnOrderings<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get raw => $composableBuilder(
    column: $table.raw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startUtf8 => $composableBuilder(
    column: $table.startUtf8,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endUtf8 => $composableBuilder(
    column: $table.endUtf8,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startUtf16 => $composableBuilder(
    column: $table.startUtf16,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentSpans => $composableBuilder(
    column: $table.contentSpans,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get headingLevel => $composableBuilder(
    column: $table.headingLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codeLanguage => $composableBuilder(
    column: $table.codeLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ordered => $composableBuilder(
    column: $table.ordered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listMarker => $composableBuilder(
    column: $table.listMarker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listDepth => $composableBuilder(
    column: $table.listDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quoteDepth => $composableBuilder(
    column: $table.quoteDepth,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idx =>
      $composableBuilder(column: $table.idx, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get raw =>
      $composableBuilder(column: $table.raw, builder: (column) => column);

  GeneratedColumn<int> get startUtf8 =>
      $composableBuilder(column: $table.startUtf8, builder: (column) => column);

  GeneratedColumn<int> get endUtf8 =>
      $composableBuilder(column: $table.endUtf8, builder: (column) => column);

  GeneratedColumn<int> get startUtf16 => $composableBuilder(
    column: $table.startUtf16,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentSpans => $composableBuilder(
    column: $table.contentSpans,
    builder: (column) => column,
  );

  GeneratedColumn<int> get headingLevel => $composableBuilder(
    column: $table.headingLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get codeLanguage => $composableBuilder(
    column: $table.codeLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get ordered =>
      $composableBuilder(column: $table.ordered, builder: (column) => column);

  GeneratedColumn<String> get listMarker => $composableBuilder(
    column: $table.listMarker,
    builder: (column) => column,
  );

  GeneratedColumn<int> get listDepth =>
      $composableBuilder(column: $table.listDepth, builder: (column) => column);

  GeneratedColumn<int> get quoteDepth => $composableBuilder(
    column: $table.quoteDepth,
    builder: (column) => column,
  );

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlocksTable,
          BlockRow,
          $$BlocksTableFilterComposer,
          $$BlocksTableOrderingComposer,
          $$BlocksTableAnnotationComposer,
          $$BlocksTableCreateCompanionBuilder,
          $$BlocksTableUpdateCompanionBuilder,
          (BlockRow, $$BlocksTableReferences),
          BlockRow,
          PrefetchHooks Function({bool sourceId})
        > {
  $$BlocksTableTableManager(_$AppDatabase db, $BlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> idx = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String> raw = const Value.absent(),
                Value<int> startUtf8 = const Value.absent(),
                Value<int> endUtf8 = const Value.absent(),
                Value<int> startUtf16 = const Value.absent(),
                Value<String> contentSpans = const Value.absent(),
                Value<int?> headingLevel = const Value.absent(),
                Value<String?> codeLanguage = const Value.absent(),
                Value<bool> ordered = const Value.absent(),
                Value<String?> listMarker = const Value.absent(),
                Value<int> listDepth = const Value.absent(),
                Value<int> quoteDepth = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlocksCompanion(
                id: id,
                sourceId: sourceId,
                idx: idx,
                type: type,
                raw: raw,
                startUtf8: startUtf8,
                endUtf8: endUtf8,
                startUtf16: startUtf16,
                contentSpans: contentSpans,
                headingLevel: headingLevel,
                codeLanguage: codeLanguage,
                ordered: ordered,
                listMarker: listMarker,
                listDepth: listDepth,
                quoteDepth: quoteDepth,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required int idx,
                required int type,
                required String raw,
                required int startUtf8,
                required int endUtf8,
                required int startUtf16,
                required String contentSpans,
                Value<int?> headingLevel = const Value.absent(),
                Value<String?> codeLanguage = const Value.absent(),
                Value<bool> ordered = const Value.absent(),
                Value<String?> listMarker = const Value.absent(),
                Value<int> listDepth = const Value.absent(),
                Value<int> quoteDepth = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlocksCompanion.insert(
                id: id,
                sourceId: sourceId,
                idx: idx,
                type: type,
                raw: raw,
                startUtf8: startUtf8,
                endUtf8: endUtf8,
                startUtf16: startUtf16,
                contentSpans: contentSpans,
                headingLevel: headingLevel,
                codeLanguage: codeLanguage,
                ordered: ordered,
                listMarker: listMarker,
                listDepth: listDepth,
                quoteDepth: quoteDepth,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BlocksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
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
                    if (sourceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sourceId,
                                referencedTable: $$BlocksTableReferences
                                    ._sourceIdTable(db),
                                referencedColumn: $$BlocksTableReferences
                                    ._sourceIdTable(db)
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

typedef $$BlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlocksTable,
      BlockRow,
      $$BlocksTableFilterComposer,
      $$BlocksTableOrderingComposer,
      $$BlocksTableAnnotationComposer,
      $$BlocksTableCreateCompanionBuilder,
      $$BlocksTableUpdateCompanionBuilder,
      (BlockRow, $$BlocksTableReferences),
      BlockRow,
      PrefetchHooks Function({bool sourceId})
    >;
typedef $$ExtractsTableCreateCompanionBuilder =
    ExtractsCompanion Function({
      required String id,
      required String markdown,
      required String sourceId,
      required String parentId,
      required bool parentIsSource,
      required String startBlockId,
      required int startOffset,
      required String endBlockId,
      required int endOffset,
      required String selectedTextHash,
      required int createdAtUtc,
      Value<int?> editedAtUtc,
      Value<int> rowid,
    });
typedef $$ExtractsTableUpdateCompanionBuilder =
    ExtractsCompanion Function({
      Value<String> id,
      Value<String> markdown,
      Value<String> sourceId,
      Value<String> parentId,
      Value<bool> parentIsSource,
      Value<String> startBlockId,
      Value<int> startOffset,
      Value<String> endBlockId,
      Value<int> endOffset,
      Value<String> selectedTextHash,
      Value<int> createdAtUtc,
      Value<int?> editedAtUtc,
      Value<int> rowid,
    });

final class $$ExtractsTableReferences
    extends BaseReferences<_$AppDatabase, $ExtractsTable, ExtractRow> {
  $$ExtractsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('extracts__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CardsTable, List<CardRow>> _cardsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cards,
    aliasName: 'extracts__id__cards__extract_id',
  );

  $$CardsTableProcessedTableManager get cardsRefs {
    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.extractId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExtractsTableFilterComposer
    extends Composer<_$AppDatabase, $ExtractsTable> {
  $$ExtractsTableFilterComposer({
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

  ColumnFilters<String> get markdown => $composableBuilder(
    column: $table.markdown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get parentIsSource => $composableBuilder(
    column: $table.parentIsSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startBlockId => $composableBuilder(
    column: $table.startBlockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endBlockId => $composableBuilder(
    column: $table.endBlockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedTextHash => $composableBuilder(
    column: $table.selectedTextHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get editedAtUtc => $composableBuilder(
    column: $table.editedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> cardsRefs(
    Expression<bool> Function($$CardsTableFilterComposer f) f,
  ) {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.extractId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExtractsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExtractsTable> {
  $$ExtractsTableOrderingComposer({
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

  ColumnOrderings<String> get markdown => $composableBuilder(
    column: $table.markdown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get parentIsSource => $composableBuilder(
    column: $table.parentIsSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startBlockId => $composableBuilder(
    column: $table.startBlockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endBlockId => $composableBuilder(
    column: $table.endBlockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedTextHash => $composableBuilder(
    column: $table.selectedTextHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get editedAtUtc => $composableBuilder(
    column: $table.editedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExtractsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExtractsTable> {
  $$ExtractsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get markdown =>
      $composableBuilder(column: $table.markdown, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<bool> get parentIsSource => $composableBuilder(
    column: $table.parentIsSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startBlockId => $composableBuilder(
    column: $table.startBlockId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endBlockId => $composableBuilder(
    column: $table.endBlockId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<String> get selectedTextHash => $composableBuilder(
    column: $table.selectedTextHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get editedAtUtc => $composableBuilder(
    column: $table.editedAtUtc,
    builder: (column) => column,
  );

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> cardsRefs<T extends Object>(
    Expression<T> Function($$CardsTableAnnotationComposer a) f,
  ) {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.extractId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExtractsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExtractsTable,
          ExtractRow,
          $$ExtractsTableFilterComposer,
          $$ExtractsTableOrderingComposer,
          $$ExtractsTableAnnotationComposer,
          $$ExtractsTableCreateCompanionBuilder,
          $$ExtractsTableUpdateCompanionBuilder,
          (ExtractRow, $$ExtractsTableReferences),
          ExtractRow,
          PrefetchHooks Function({bool sourceId, bool cardsRefs})
        > {
  $$ExtractsTableTableManager(_$AppDatabase db, $ExtractsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExtractsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExtractsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExtractsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> markdown = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> parentId = const Value.absent(),
                Value<bool> parentIsSource = const Value.absent(),
                Value<String> startBlockId = const Value.absent(),
                Value<int> startOffset = const Value.absent(),
                Value<String> endBlockId = const Value.absent(),
                Value<int> endOffset = const Value.absent(),
                Value<String> selectedTextHash = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int?> editedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExtractsCompanion(
                id: id,
                markdown: markdown,
                sourceId: sourceId,
                parentId: parentId,
                parentIsSource: parentIsSource,
                startBlockId: startBlockId,
                startOffset: startOffset,
                endBlockId: endBlockId,
                endOffset: endOffset,
                selectedTextHash: selectedTextHash,
                createdAtUtc: createdAtUtc,
                editedAtUtc: editedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String markdown,
                required String sourceId,
                required String parentId,
                required bool parentIsSource,
                required String startBlockId,
                required int startOffset,
                required String endBlockId,
                required int endOffset,
                required String selectedTextHash,
                required int createdAtUtc,
                Value<int?> editedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExtractsCompanion.insert(
                id: id,
                markdown: markdown,
                sourceId: sourceId,
                parentId: parentId,
                parentIsSource: parentIsSource,
                startBlockId: startBlockId,
                startOffset: startOffset,
                endBlockId: endBlockId,
                endOffset: endOffset,
                selectedTextHash: selectedTextHash,
                createdAtUtc: createdAtUtc,
                editedAtUtc: editedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExtractsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false, cardsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (cardsRefs) db.cards],
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
                    if (sourceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sourceId,
                                referencedTable: $$ExtractsTableReferences
                                    ._sourceIdTable(db),
                                referencedColumn: $$ExtractsTableReferences
                                    ._sourceIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cardsRefs)
                    await $_getPrefetchedData<
                      ExtractRow,
                      $ExtractsTable,
                      CardRow
                    >(
                      currentTable: table,
                      referencedTable: $$ExtractsTableReferences
                          ._cardsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ExtractsTableReferences(db, table, p0).cardsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.extractId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ExtractsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExtractsTable,
      ExtractRow,
      $$ExtractsTableFilterComposer,
      $$ExtractsTableOrderingComposer,
      $$ExtractsTableAnnotationComposer,
      $$ExtractsTableCreateCompanionBuilder,
      $$ExtractsTableUpdateCompanionBuilder,
      (ExtractRow, $$ExtractsTableReferences),
      ExtractRow,
      PrefetchHooks Function({bool sourceId, bool cardsRefs})
    >;
typedef $$CardsTableCreateCompanionBuilder =
    CardsCompanion Function({
      required String id,
      Value<String?> extractId,
      Value<String?> sourceId,
      required int kind,
      required String front,
      required String back,
      Value<int?> clozeOrdinal,
      required int createdAtUtc,
      Value<int?> editedAtUtc,
      Value<int> rowid,
    });
typedef $$CardsTableUpdateCompanionBuilder =
    CardsCompanion Function({
      Value<String> id,
      Value<String?> extractId,
      Value<String?> sourceId,
      Value<int> kind,
      Value<String> front,
      Value<String> back,
      Value<int?> clozeOrdinal,
      Value<int> createdAtUtc,
      Value<int?> editedAtUtc,
      Value<int> rowid,
    });

final class $$CardsTableReferences
    extends BaseReferences<_$AppDatabase, $CardsTable, CardRow> {
  $$CardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ExtractsTable _extractIdTable(_$AppDatabase db) =>
      db.extracts.createAlias('cards__extract_id__extracts__id');

  $$ExtractsTableProcessedTableManager? get extractId {
    final $_column = $_itemColumn<String>('extract_id');
    if ($_column == null) return null;
    final manager = $$ExtractsTableTableManager(
      $_db,
      $_db.extracts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_extractIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('cards__source_id__sources__id');

  $$SourcesTableProcessedTableManager? get sourceId {
    final $_column = $_itemColumn<String>('source_id');
    if ($_column == null) return null;
    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CardMemoriesTable, List<CardMemoryRow>>
  _cardMemoriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cardMemories,
    aliasName: 'cards__id__card_memories__card_id',
  );

  $$CardMemoriesTableProcessedTableManager get cardMemoriesRefs {
    final manager = $$CardMemoriesTableTableManager(
      $_db,
      $_db.cardMemories,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardMemoriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReviewEventsTable, List<ReviewEventRow>>
  _reviewEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reviewEvents,
    aliasName: 'cards__id__review_events__card_id',
  );

  $$ReviewEventsTableProcessedTableManager get reviewEventsRefs {
    final manager = $$ReviewEventsTableTableManager(
      $_db,
      $_db.reviewEvents,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_reviewEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CardsTableFilterComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
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

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get front => $composableBuilder(
    column: $table.front,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get back => $composableBuilder(
    column: $table.back,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clozeOrdinal => $composableBuilder(
    column: $table.clozeOrdinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get editedAtUtc => $composableBuilder(
    column: $table.editedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$ExtractsTableFilterComposer get extractId {
    final $$ExtractsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.extractId,
      referencedTable: $db.extracts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtractsTableFilterComposer(
            $db: $db,
            $table: $db.extracts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> cardMemoriesRefs(
    Expression<bool> Function($$CardMemoriesTableFilterComposer f) f,
  ) {
    final $$CardMemoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardMemories,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardMemoriesTableFilterComposer(
            $db: $db,
            $table: $db.cardMemories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> reviewEventsRefs(
    Expression<bool> Function($$ReviewEventsTableFilterComposer f) f,
  ) {
    final $$ReviewEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewEvents,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewEventsTableFilterComposer(
            $db: $db,
            $table: $db.reviewEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
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

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get front => $composableBuilder(
    column: $table.front,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get back => $composableBuilder(
    column: $table.back,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clozeOrdinal => $composableBuilder(
    column: $table.clozeOrdinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get editedAtUtc => $composableBuilder(
    column: $table.editedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$ExtractsTableOrderingComposer get extractId {
    final $$ExtractsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.extractId,
      referencedTable: $db.extracts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtractsTableOrderingComposer(
            $db: $db,
            $table: $db.extracts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get front =>
      $composableBuilder(column: $table.front, builder: (column) => column);

  GeneratedColumn<String> get back =>
      $composableBuilder(column: $table.back, builder: (column) => column);

  GeneratedColumn<int> get clozeOrdinal => $composableBuilder(
    column: $table.clozeOrdinal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get editedAtUtc => $composableBuilder(
    column: $table.editedAtUtc,
    builder: (column) => column,
  );

  $$ExtractsTableAnnotationComposer get extractId {
    final $$ExtractsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.extractId,
      referencedTable: $db.extracts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtractsTableAnnotationComposer(
            $db: $db,
            $table: $db.extracts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> cardMemoriesRefs<T extends Object>(
    Expression<T> Function($$CardMemoriesTableAnnotationComposer a) f,
  ) {
    final $$CardMemoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardMemories,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardMemoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.cardMemories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> reviewEventsRefs<T extends Object>(
    Expression<T> Function($$ReviewEventsTableAnnotationComposer a) f,
  ) {
    final $$ReviewEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewEvents,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardsTable,
          CardRow,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (CardRow, $$CardsTableReferences),
          CardRow,
          PrefetchHooks Function({
            bool extractId,
            bool sourceId,
            bool cardMemoriesRefs,
            bool reviewEventsRefs,
          })
        > {
  $$CardsTableTableManager(_$AppDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> extractId = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String> front = const Value.absent(),
                Value<String> back = const Value.absent(),
                Value<int?> clozeOrdinal = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int?> editedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                extractId: extractId,
                sourceId: sourceId,
                kind: kind,
                front: front,
                back: back,
                clozeOrdinal: clozeOrdinal,
                createdAtUtc: createdAtUtc,
                editedAtUtc: editedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> extractId = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                required int kind,
                required String front,
                required String back,
                Value<int?> clozeOrdinal = const Value.absent(),
                required int createdAtUtc,
                Value<int?> editedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                extractId: extractId,
                sourceId: sourceId,
                kind: kind,
                front: front,
                back: back,
                clozeOrdinal: clozeOrdinal,
                createdAtUtc: createdAtUtc,
                editedAtUtc: editedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CardsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                extractId = false,
                sourceId = false,
                cardMemoriesRefs = false,
                reviewEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cardMemoriesRefs) db.cardMemories,
                    if (reviewEventsRefs) db.reviewEvents,
                  ],
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
                        if (extractId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.extractId,
                                    referencedTable: $$CardsTableReferences
                                        ._extractIdTable(db),
                                    referencedColumn: $$CardsTableReferences
                                        ._extractIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (sourceId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sourceId,
                                    referencedTable: $$CardsTableReferences
                                        ._sourceIdTable(db),
                                    referencedColumn: $$CardsTableReferences
                                        ._sourceIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cardMemoriesRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          CardMemoryRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._cardMemoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).cardMemoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (reviewEventsRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          ReviewEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._reviewEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).reviewEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
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

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardsTable,
      CardRow,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (CardRow, $$CardsTableReferences),
      CardRow,
      PrefetchHooks Function({
        bool extractId,
        bool sourceId,
        bool cardMemoriesRefs,
        bool reviewEventsRefs,
      })
    >;
typedef $$ElementSchedulesTableCreateCompanionBuilder =
    ElementSchedulesCompanion Function({
      required String elementId,
      required int elementType,
      required String priorityKey,
      required int lifecycle,
      required int dueDay,
      required int originalDueDay,
      Value<int?> deferredUntil,
      Value<int> deferralKind,
      required String zoneId,
      Value<int> rowid,
    });
typedef $$ElementSchedulesTableUpdateCompanionBuilder =
    ElementSchedulesCompanion Function({
      Value<String> elementId,
      Value<int> elementType,
      Value<String> priorityKey,
      Value<int> lifecycle,
      Value<int> dueDay,
      Value<int> originalDueDay,
      Value<int?> deferredUntil,
      Value<int> deferralKind,
      Value<String> zoneId,
      Value<int> rowid,
    });

class $$ElementSchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $ElementSchedulesTable> {
  $$ElementSchedulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get elementId => $composableBuilder(
    column: $table.elementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elementType => $composableBuilder(
    column: $table.elementType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priorityKey => $composableBuilder(
    column: $table.priorityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originalDueDay => $composableBuilder(
    column: $table.originalDueDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deferredUntil => $composableBuilder(
    column: $table.deferredUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deferralKind => $composableBuilder(
    column: $table.deferralKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zoneId => $composableBuilder(
    column: $table.zoneId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ElementSchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $ElementSchedulesTable> {
  $$ElementSchedulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get elementId => $composableBuilder(
    column: $table.elementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elementType => $composableBuilder(
    column: $table.elementType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priorityKey => $composableBuilder(
    column: $table.priorityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originalDueDay => $composableBuilder(
    column: $table.originalDueDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deferredUntil => $composableBuilder(
    column: $table.deferredUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deferralKind => $composableBuilder(
    column: $table.deferralKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zoneId => $composableBuilder(
    column: $table.zoneId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ElementSchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ElementSchedulesTable> {
  $$ElementSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get elementId =>
      $composableBuilder(column: $table.elementId, builder: (column) => column);

  GeneratedColumn<int> get elementType => $composableBuilder(
    column: $table.elementType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priorityKey => $composableBuilder(
    column: $table.priorityKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<int> get dueDay =>
      $composableBuilder(column: $table.dueDay, builder: (column) => column);

  GeneratedColumn<int> get originalDueDay => $composableBuilder(
    column: $table.originalDueDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deferredUntil => $composableBuilder(
    column: $table.deferredUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deferralKind => $composableBuilder(
    column: $table.deferralKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get zoneId =>
      $composableBuilder(column: $table.zoneId, builder: (column) => column);
}

class $$ElementSchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ElementSchedulesTable,
          ScheduleRow,
          $$ElementSchedulesTableFilterComposer,
          $$ElementSchedulesTableOrderingComposer,
          $$ElementSchedulesTableAnnotationComposer,
          $$ElementSchedulesTableCreateCompanionBuilder,
          $$ElementSchedulesTableUpdateCompanionBuilder,
          (
            ScheduleRow,
            BaseReferences<_$AppDatabase, $ElementSchedulesTable, ScheduleRow>,
          ),
          ScheduleRow,
          PrefetchHooks Function()
        > {
  $$ElementSchedulesTableTableManager(
    _$AppDatabase db,
    $ElementSchedulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ElementSchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ElementSchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ElementSchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> elementId = const Value.absent(),
                Value<int> elementType = const Value.absent(),
                Value<String> priorityKey = const Value.absent(),
                Value<int> lifecycle = const Value.absent(),
                Value<int> dueDay = const Value.absent(),
                Value<int> originalDueDay = const Value.absent(),
                Value<int?> deferredUntil = const Value.absent(),
                Value<int> deferralKind = const Value.absent(),
                Value<String> zoneId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ElementSchedulesCompanion(
                elementId: elementId,
                elementType: elementType,
                priorityKey: priorityKey,
                lifecycle: lifecycle,
                dueDay: dueDay,
                originalDueDay: originalDueDay,
                deferredUntil: deferredUntil,
                deferralKind: deferralKind,
                zoneId: zoneId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String elementId,
                required int elementType,
                required String priorityKey,
                required int lifecycle,
                required int dueDay,
                required int originalDueDay,
                Value<int?> deferredUntil = const Value.absent(),
                Value<int> deferralKind = const Value.absent(),
                required String zoneId,
                Value<int> rowid = const Value.absent(),
              }) => ElementSchedulesCompanion.insert(
                elementId: elementId,
                elementType: elementType,
                priorityKey: priorityKey,
                lifecycle: lifecycle,
                dueDay: dueDay,
                originalDueDay: originalDueDay,
                deferredUntil: deferredUntil,
                deferralKind: deferralKind,
                zoneId: zoneId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ElementSchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ElementSchedulesTable,
      ScheduleRow,
      $$ElementSchedulesTableFilterComposer,
      $$ElementSchedulesTableOrderingComposer,
      $$ElementSchedulesTableAnnotationComposer,
      $$ElementSchedulesTableCreateCompanionBuilder,
      $$ElementSchedulesTableUpdateCompanionBuilder,
      (
        ScheduleRow,
        BaseReferences<_$AppDatabase, $ElementSchedulesTable, ScheduleRow>,
      ),
      ScheduleRow,
      PrefetchHooks Function()
    >;
typedef $$TopicStatesTableCreateCompanionBuilder =
    TopicStatesCompanion Function({
      required String elementId,
      required int elementType,
      required String profileId,
      required int stepIndex,
      Value<int> rowid,
    });
typedef $$TopicStatesTableUpdateCompanionBuilder =
    TopicStatesCompanion Function({
      Value<String> elementId,
      Value<int> elementType,
      Value<String> profileId,
      Value<int> stepIndex,
      Value<int> rowid,
    });

class $$TopicStatesTableFilterComposer
    extends Composer<_$AppDatabase, $TopicStatesTable> {
  $$TopicStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get elementId => $composableBuilder(
    column: $table.elementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elementType => $composableBuilder(
    column: $table.elementType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stepIndex => $composableBuilder(
    column: $table.stepIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TopicStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TopicStatesTable> {
  $$TopicStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get elementId => $composableBuilder(
    column: $table.elementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elementType => $composableBuilder(
    column: $table.elementType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stepIndex => $composableBuilder(
    column: $table.stepIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TopicStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TopicStatesTable> {
  $$TopicStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get elementId =>
      $composableBuilder(column: $table.elementId, builder: (column) => column);

  GeneratedColumn<int> get elementType => $composableBuilder(
    column: $table.elementType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get stepIndex =>
      $composableBuilder(column: $table.stepIndex, builder: (column) => column);
}

class $$TopicStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TopicStatesTable,
          TopicStateRow,
          $$TopicStatesTableFilterComposer,
          $$TopicStatesTableOrderingComposer,
          $$TopicStatesTableAnnotationComposer,
          $$TopicStatesTableCreateCompanionBuilder,
          $$TopicStatesTableUpdateCompanionBuilder,
          (
            TopicStateRow,
            BaseReferences<_$AppDatabase, $TopicStatesTable, TopicStateRow>,
          ),
          TopicStateRow,
          PrefetchHooks Function()
        > {
  $$TopicStatesTableTableManager(_$AppDatabase db, $TopicStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TopicStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TopicStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TopicStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> elementId = const Value.absent(),
                Value<int> elementType = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> stepIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TopicStatesCompanion(
                elementId: elementId,
                elementType: elementType,
                profileId: profileId,
                stepIndex: stepIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String elementId,
                required int elementType,
                required String profileId,
                required int stepIndex,
                Value<int> rowid = const Value.absent(),
              }) => TopicStatesCompanion.insert(
                elementId: elementId,
                elementType: elementType,
                profileId: profileId,
                stepIndex: stepIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TopicStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TopicStatesTable,
      TopicStateRow,
      $$TopicStatesTableFilterComposer,
      $$TopicStatesTableOrderingComposer,
      $$TopicStatesTableAnnotationComposer,
      $$TopicStatesTableCreateCompanionBuilder,
      $$TopicStatesTableUpdateCompanionBuilder,
      (
        TopicStateRow,
        BaseReferences<_$AppDatabase, $TopicStatesTable, TopicStateRow>,
      ),
      TopicStateRow,
      PrefetchHooks Function()
    >;
typedef $$CardMemoriesTableCreateCompanionBuilder =
    CardMemoriesCompanion Function({
      required String cardId,
      Value<double?> stability,
      Value<double?> difficulty,
      required int state,
      Value<int?> step,
      Value<int> reps,
      Value<int> lapses,
      Value<int?> lastReviewUtc,
      required int dueAtUtc,
      required int originalDueAtUtc,
      Value<int?> deferredUntilUtc,
      required String schedulerVersion,
      required String parametersVersion,
      Value<int> rowid,
    });
typedef $$CardMemoriesTableUpdateCompanionBuilder =
    CardMemoriesCompanion Function({
      Value<String> cardId,
      Value<double?> stability,
      Value<double?> difficulty,
      Value<int> state,
      Value<int?> step,
      Value<int> reps,
      Value<int> lapses,
      Value<int?> lastReviewUtc,
      Value<int> dueAtUtc,
      Value<int> originalDueAtUtc,
      Value<int?> deferredUntilUtc,
      Value<String> schedulerVersion,
      Value<String> parametersVersion,
      Value<int> rowid,
    });

final class $$CardMemoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CardMemoriesTable, CardMemoryRow> {
  $$CardMemoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardIdTable(_$AppDatabase db) =>
      db.cards.createAlias('card_memories__card_id__cards__id');

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<String>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CardMemoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CardMemoriesTable> {
  $$CardMemoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get step => $composableBuilder(
    column: $table.step,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReviewUtc => $composableBuilder(
    column: $table.lastReviewUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueAtUtc => $composableBuilder(
    column: $table.dueAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originalDueAtUtc => $composableBuilder(
    column: $table.originalDueAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deferredUntilUtc => $composableBuilder(
    column: $table.deferredUntilUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schedulerVersion => $composableBuilder(
    column: $table.schedulerVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parametersVersion => $composableBuilder(
    column: $table.parametersVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardMemoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CardMemoriesTable> {
  $$CardMemoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get step => $composableBuilder(
    column: $table.step,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReviewUtc => $composableBuilder(
    column: $table.lastReviewUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueAtUtc => $composableBuilder(
    column: $table.dueAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originalDueAtUtc => $composableBuilder(
    column: $table.originalDueAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deferredUntilUtc => $composableBuilder(
    column: $table.deferredUntilUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schedulerVersion => $composableBuilder(
    column: $table.schedulerVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parametersVersion => $composableBuilder(
    column: $table.parametersVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardMemoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardMemoriesTable> {
  $$CardMemoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<int> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get step =>
      $composableBuilder(column: $table.step, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<int> get lastReviewUtc => $composableBuilder(
    column: $table.lastReviewUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueAtUtc =>
      $composableBuilder(column: $table.dueAtUtc, builder: (column) => column);

  GeneratedColumn<int> get originalDueAtUtc => $composableBuilder(
    column: $table.originalDueAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deferredUntilUtc => $composableBuilder(
    column: $table.deferredUntilUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get schedulerVersion => $composableBuilder(
    column: $table.schedulerVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parametersVersion => $composableBuilder(
    column: $table.parametersVersion,
    builder: (column) => column,
  );

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardMemoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardMemoriesTable,
          CardMemoryRow,
          $$CardMemoriesTableFilterComposer,
          $$CardMemoriesTableOrderingComposer,
          $$CardMemoriesTableAnnotationComposer,
          $$CardMemoriesTableCreateCompanionBuilder,
          $$CardMemoriesTableUpdateCompanionBuilder,
          (CardMemoryRow, $$CardMemoriesTableReferences),
          CardMemoryRow,
          PrefetchHooks Function({bool cardId})
        > {
  $$CardMemoriesTableTableManager(_$AppDatabase db, $CardMemoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardMemoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardMemoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardMemoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cardId = const Value.absent(),
                Value<double?> stability = const Value.absent(),
                Value<double?> difficulty = const Value.absent(),
                Value<int> state = const Value.absent(),
                Value<int?> step = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int?> lastReviewUtc = const Value.absent(),
                Value<int> dueAtUtc = const Value.absent(),
                Value<int> originalDueAtUtc = const Value.absent(),
                Value<int?> deferredUntilUtc = const Value.absent(),
                Value<String> schedulerVersion = const Value.absent(),
                Value<String> parametersVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardMemoriesCompanion(
                cardId: cardId,
                stability: stability,
                difficulty: difficulty,
                state: state,
                step: step,
                reps: reps,
                lapses: lapses,
                lastReviewUtc: lastReviewUtc,
                dueAtUtc: dueAtUtc,
                originalDueAtUtc: originalDueAtUtc,
                deferredUntilUtc: deferredUntilUtc,
                schedulerVersion: schedulerVersion,
                parametersVersion: parametersVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cardId,
                Value<double?> stability = const Value.absent(),
                Value<double?> difficulty = const Value.absent(),
                required int state,
                Value<int?> step = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int?> lastReviewUtc = const Value.absent(),
                required int dueAtUtc,
                required int originalDueAtUtc,
                Value<int?> deferredUntilUtc = const Value.absent(),
                required String schedulerVersion,
                required String parametersVersion,
                Value<int> rowid = const Value.absent(),
              }) => CardMemoriesCompanion.insert(
                cardId: cardId,
                stability: stability,
                difficulty: difficulty,
                state: state,
                step: step,
                reps: reps,
                lapses: lapses,
                lastReviewUtc: lastReviewUtc,
                dueAtUtc: dueAtUtc,
                originalDueAtUtc: originalDueAtUtc,
                deferredUntilUtc: deferredUntilUtc,
                schedulerVersion: schedulerVersion,
                parametersVersion: parametersVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CardMemoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
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
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable: $$CardMemoriesTableReferences
                                    ._cardIdTable(db),
                                referencedColumn: $$CardMemoriesTableReferences
                                    ._cardIdTable(db)
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

typedef $$CardMemoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardMemoriesTable,
      CardMemoryRow,
      $$CardMemoriesTableFilterComposer,
      $$CardMemoriesTableOrderingComposer,
      $$CardMemoriesTableAnnotationComposer,
      $$CardMemoriesTableCreateCompanionBuilder,
      $$CardMemoriesTableUpdateCompanionBuilder,
      (CardMemoryRow, $$CardMemoriesTableReferences),
      CardMemoryRow,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$ReviewEventsTableCreateCompanionBuilder =
    ReviewEventsCompanion Function({
      required String id,
      required String cardId,
      required int reviewedAtUtc,
      required int rating,
      required String preStateJson,
      required String postStateJson,
      Value<int?> elapsedMs,
      required String schedulerVersion,
      required String parametersVersion,
      Value<bool> isPractice,
      required String operationId,
      Value<int> rowid,
    });
typedef $$ReviewEventsTableUpdateCompanionBuilder =
    ReviewEventsCompanion Function({
      Value<String> id,
      Value<String> cardId,
      Value<int> reviewedAtUtc,
      Value<int> rating,
      Value<String> preStateJson,
      Value<String> postStateJson,
      Value<int?> elapsedMs,
      Value<String> schedulerVersion,
      Value<String> parametersVersion,
      Value<bool> isPractice,
      Value<String> operationId,
      Value<int> rowid,
    });

final class $$ReviewEventsTableReferences
    extends BaseReferences<_$AppDatabase, $ReviewEventsTable, ReviewEventRow> {
  $$ReviewEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardIdTable(_$AppDatabase db) =>
      db.cards.createAlias('review_events__card_id__cards__id');

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<String>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReviewEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewEventsTable> {
  $$ReviewEventsTableFilterComposer({
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

  ColumnFilters<int> get reviewedAtUtc => $composableBuilder(
    column: $table.reviewedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preStateJson => $composableBuilder(
    column: $table.preStateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postStateJson => $composableBuilder(
    column: $table.postStateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schedulerVersion => $composableBuilder(
    column: $table.schedulerVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parametersVersion => $composableBuilder(
    column: $table.parametersVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPractice => $composableBuilder(
    column: $table.isPractice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewEventsTable> {
  $$ReviewEventsTableOrderingComposer({
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

  ColumnOrderings<int> get reviewedAtUtc => $composableBuilder(
    column: $table.reviewedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preStateJson => $composableBuilder(
    column: $table.preStateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postStateJson => $composableBuilder(
    column: $table.postStateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schedulerVersion => $composableBuilder(
    column: $table.schedulerVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parametersVersion => $composableBuilder(
    column: $table.parametersVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPractice => $composableBuilder(
    column: $table.isPractice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewEventsTable> {
  $$ReviewEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get reviewedAtUtc => $composableBuilder(
    column: $table.reviewedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get preStateJson => $composableBuilder(
    column: $table.preStateJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get postStateJson => $composableBuilder(
    column: $table.postStateJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get elapsedMs =>
      $composableBuilder(column: $table.elapsedMs, builder: (column) => column);

  GeneratedColumn<String> get schedulerVersion => $composableBuilder(
    column: $table.schedulerVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parametersVersion => $composableBuilder(
    column: $table.parametersVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPractice => $composableBuilder(
    column: $table.isPractice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewEventsTable,
          ReviewEventRow,
          $$ReviewEventsTableFilterComposer,
          $$ReviewEventsTableOrderingComposer,
          $$ReviewEventsTableAnnotationComposer,
          $$ReviewEventsTableCreateCompanionBuilder,
          $$ReviewEventsTableUpdateCompanionBuilder,
          (ReviewEventRow, $$ReviewEventsTableReferences),
          ReviewEventRow,
          PrefetchHooks Function({bool cardId})
        > {
  $$ReviewEventsTableTableManager(_$AppDatabase db, $ReviewEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> cardId = const Value.absent(),
                Value<int> reviewedAtUtc = const Value.absent(),
                Value<int> rating = const Value.absent(),
                Value<String> preStateJson = const Value.absent(),
                Value<String> postStateJson = const Value.absent(),
                Value<int?> elapsedMs = const Value.absent(),
                Value<String> schedulerVersion = const Value.absent(),
                Value<String> parametersVersion = const Value.absent(),
                Value<bool> isPractice = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewEventsCompanion(
                id: id,
                cardId: cardId,
                reviewedAtUtc: reviewedAtUtc,
                rating: rating,
                preStateJson: preStateJson,
                postStateJson: postStateJson,
                elapsedMs: elapsedMs,
                schedulerVersion: schedulerVersion,
                parametersVersion: parametersVersion,
                isPractice: isPractice,
                operationId: operationId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String cardId,
                required int reviewedAtUtc,
                required int rating,
                required String preStateJson,
                required String postStateJson,
                Value<int?> elapsedMs = const Value.absent(),
                required String schedulerVersion,
                required String parametersVersion,
                Value<bool> isPractice = const Value.absent(),
                required String operationId,
                Value<int> rowid = const Value.absent(),
              }) => ReviewEventsCompanion.insert(
                id: id,
                cardId: cardId,
                reviewedAtUtc: reviewedAtUtc,
                rating: rating,
                preStateJson: preStateJson,
                postStateJson: postStateJson,
                elapsedMs: elapsedMs,
                schedulerVersion: schedulerVersion,
                parametersVersion: parametersVersion,
                isPractice: isPractice,
                operationId: operationId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReviewEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
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
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable: $$ReviewEventsTableReferences
                                    ._cardIdTable(db),
                                referencedColumn: $$ReviewEventsTableReferences
                                    ._cardIdTable(db)
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

typedef $$ReviewEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewEventsTable,
      ReviewEventRow,
      $$ReviewEventsTableFilterComposer,
      $$ReviewEventsTableOrderingComposer,
      $$ReviewEventsTableAnnotationComposer,
      $$ReviewEventsTableCreateCompanionBuilder,
      $$ReviewEventsTableUpdateCompanionBuilder,
      (ReviewEventRow, $$ReviewEventsTableReferences),
      ReviewEventRow,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$ActivityEventsTableCreateCompanionBuilder =
    ActivityEventsCompanion Function({
      required String id,
      required String operationId,
      Value<String?> elementId,
      Value<int?> elementType,
      required String kind,
      required int atUtc,
      Value<int?> durationMs,
      Value<String?> metadataJson,
      Value<int> rowid,
    });
typedef $$ActivityEventsTableUpdateCompanionBuilder =
    ActivityEventsCompanion Function({
      Value<String> id,
      Value<String> operationId,
      Value<String?> elementId,
      Value<int?> elementType,
      Value<String> kind,
      Value<int> atUtc,
      Value<int?> durationMs,
      Value<String?> metadataJson,
      Value<int> rowid,
    });

class $$ActivityEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableFilterComposer({
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

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get elementId => $composableBuilder(
    column: $table.elementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elementType => $composableBuilder(
    column: $table.elementType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atUtc => $composableBuilder(
    column: $table.atUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivityEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableOrderingComposer({
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

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get elementId => $composableBuilder(
    column: $table.elementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elementType => $composableBuilder(
    column: $table.elementType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atUtc => $composableBuilder(
    column: $table.atUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivityEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get elementId =>
      $composableBuilder(column: $table.elementId, builder: (column) => column);

  GeneratedColumn<int> get elementType => $composableBuilder(
    column: $table.elementType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get atUtc =>
      $composableBuilder(column: $table.atUtc, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );
}

class $$ActivityEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivityEventsTable,
          ActivityEventRow,
          $$ActivityEventsTableFilterComposer,
          $$ActivityEventsTableOrderingComposer,
          $$ActivityEventsTableAnnotationComposer,
          $$ActivityEventsTableCreateCompanionBuilder,
          $$ActivityEventsTableUpdateCompanionBuilder,
          (
            ActivityEventRow,
            BaseReferences<
              _$AppDatabase,
              $ActivityEventsTable,
              ActivityEventRow
            >,
          ),
          ActivityEventRow,
          PrefetchHooks Function()
        > {
  $$ActivityEventsTableTableManager(
    _$AppDatabase db,
    $ActivityEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String?> elementId = const Value.absent(),
                Value<int?> elementType = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> atUtc = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityEventsCompanion(
                id: id,
                operationId: operationId,
                elementId: elementId,
                elementType: elementType,
                kind: kind,
                atUtc: atUtc,
                durationMs: durationMs,
                metadataJson: metadataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String operationId,
                Value<String?> elementId = const Value.absent(),
                Value<int?> elementType = const Value.absent(),
                required String kind,
                required int atUtc,
                Value<int?> durationMs = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityEventsCompanion.insert(
                id: id,
                operationId: operationId,
                elementId: elementId,
                elementType: elementType,
                kind: kind,
                atUtc: atUtc,
                durationMs: durationMs,
                metadataJson: metadataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivityEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivityEventsTable,
      ActivityEventRow,
      $$ActivityEventsTableFilterComposer,
      $$ActivityEventsTableOrderingComposer,
      $$ActivityEventsTableAnnotationComposer,
      $$ActivityEventsTableCreateCompanionBuilder,
      $$ActivityEventsTableUpdateCompanionBuilder,
      (
        ActivityEventRow,
        BaseReferences<_$AppDatabase, $ActivityEventsTable, ActivityEventRow>,
      ),
      ActivityEventRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$DatasetMetaTableCreateCompanionBuilder =
    DatasetMetaCompanion Function({
      Value<int> id,
      required String datasetId,
      required int generation,
      required int writerEpoch,
      required String ownerDeviceId,
    });
typedef $$DatasetMetaTableUpdateCompanionBuilder =
    DatasetMetaCompanion Function({
      Value<int> id,
      Value<String> datasetId,
      Value<int> generation,
      Value<int> writerEpoch,
      Value<String> ownerDeviceId,
    });

class $$DatasetMetaTableFilterComposer
    extends Composer<_$AppDatabase, $DatasetMetaTable> {
  $$DatasetMetaTableFilterComposer({
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

  ColumnFilters<String> get datasetId => $composableBuilder(
    column: $table.datasetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get writerEpoch => $composableBuilder(
    column: $table.writerEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerDeviceId => $composableBuilder(
    column: $table.ownerDeviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DatasetMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $DatasetMetaTable> {
  $$DatasetMetaTableOrderingComposer({
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

  ColumnOrderings<String> get datasetId => $composableBuilder(
    column: $table.datasetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get writerEpoch => $composableBuilder(
    column: $table.writerEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerDeviceId => $composableBuilder(
    column: $table.ownerDeviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DatasetMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $DatasetMetaTable> {
  $$DatasetMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get datasetId =>
      $composableBuilder(column: $table.datasetId, builder: (column) => column);

  GeneratedColumn<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get writerEpoch => $composableBuilder(
    column: $table.writerEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerDeviceId => $composableBuilder(
    column: $table.ownerDeviceId,
    builder: (column) => column,
  );
}

class $$DatasetMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DatasetMetaTable,
          DatasetMetaRow,
          $$DatasetMetaTableFilterComposer,
          $$DatasetMetaTableOrderingComposer,
          $$DatasetMetaTableAnnotationComposer,
          $$DatasetMetaTableCreateCompanionBuilder,
          $$DatasetMetaTableUpdateCompanionBuilder,
          (
            DatasetMetaRow,
            BaseReferences<_$AppDatabase, $DatasetMetaTable, DatasetMetaRow>,
          ),
          DatasetMetaRow,
          PrefetchHooks Function()
        > {
  $$DatasetMetaTableTableManager(_$AppDatabase db, $DatasetMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DatasetMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DatasetMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DatasetMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> datasetId = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<int> writerEpoch = const Value.absent(),
                Value<String> ownerDeviceId = const Value.absent(),
              }) => DatasetMetaCompanion(
                id: id,
                datasetId: datasetId,
                generation: generation,
                writerEpoch: writerEpoch,
                ownerDeviceId: ownerDeviceId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String datasetId,
                required int generation,
                required int writerEpoch,
                required String ownerDeviceId,
              }) => DatasetMetaCompanion.insert(
                id: id,
                datasetId: datasetId,
                generation: generation,
                writerEpoch: writerEpoch,
                ownerDeviceId: ownerDeviceId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DatasetMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DatasetMetaTable,
      DatasetMetaRow,
      $$DatasetMetaTableFilterComposer,
      $$DatasetMetaTableOrderingComposer,
      $$DatasetMetaTableAnnotationComposer,
      $$DatasetMetaTableCreateCompanionBuilder,
      $$DatasetMetaTableUpdateCompanionBuilder,
      (
        DatasetMetaRow,
        BaseReferences<_$AppDatabase, $DatasetMetaTable, DatasetMetaRow>,
      ),
      DatasetMetaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db, _db.sources);
  $$BlocksTableTableManager get blocks =>
      $$BlocksTableTableManager(_db, _db.blocks);
  $$ExtractsTableTableManager get extracts =>
      $$ExtractsTableTableManager(_db, _db.extracts);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$ElementSchedulesTableTableManager get elementSchedules =>
      $$ElementSchedulesTableTableManager(_db, _db.elementSchedules);
  $$TopicStatesTableTableManager get topicStates =>
      $$TopicStatesTableTableManager(_db, _db.topicStates);
  $$CardMemoriesTableTableManager get cardMemories =>
      $$CardMemoriesTableTableManager(_db, _db.cardMemories);
  $$ReviewEventsTableTableManager get reviewEvents =>
      $$ReviewEventsTableTableManager(_db, _db.reviewEvents);
  $$ActivityEventsTableTableManager get activityEvents =>
      $$ActivityEventsTableTableManager(_db, _db.activityEvents);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$DatasetMetaTableTableManager get datasetMeta =>
      $$DatasetMetaTableTableManager(_db, _db.datasetMeta);
}
