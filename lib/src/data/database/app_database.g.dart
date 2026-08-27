// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
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
    markerBlockId,
    markerOffset,
    softBlockId,
    softOffset,
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

  /// Explicit resume marker. Both columns are set or both are null.
  final String? markerBlockId;
  final int? markerOffset;

  /// Soft position. Never drives scheduling.
  final String? softBlockId;
  final int? softOffset;

  /// Bumped on every write, for change detection and diagnostics.
  final int revision;
  const SourceRow({
    required this.id,
    required this.title,
    required this.markdown,
    required this.contentHash,
    required this.wordCount,
    required this.importedAtUtc,
    this.markerBlockId,
    this.markerOffset,
    this.softBlockId,
    this.softOffset,
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
      markerBlockId: serializer.fromJson<String?>(json['markerBlockId']),
      markerOffset: serializer.fromJson<int?>(json['markerOffset']),
      softBlockId: serializer.fromJson<String?>(json['softBlockId']),
      softOffset: serializer.fromJson<int?>(json['softOffset']),
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
      'markerBlockId': serializer.toJson<String?>(markerBlockId),
      'markerOffset': serializer.toJson<int?>(markerOffset),
      'softBlockId': serializer.toJson<String?>(softBlockId),
      'softOffset': serializer.toJson<int?>(softOffset),
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
    Value<String?> markerBlockId = const Value.absent(),
    Value<int?> markerOffset = const Value.absent(),
    Value<String?> softBlockId = const Value.absent(),
    Value<int?> softOffset = const Value.absent(),
    int? revision,
  }) => SourceRow(
    id: id ?? this.id,
    title: title ?? this.title,
    markdown: markdown ?? this.markdown,
    contentHash: contentHash ?? this.contentHash,
    wordCount: wordCount ?? this.wordCount,
    importedAtUtc: importedAtUtc ?? this.importedAtUtc,
    markerBlockId: markerBlockId.present
        ? markerBlockId.value
        : this.markerBlockId,
    markerOffset: markerOffset.present ? markerOffset.value : this.markerOffset,
    softBlockId: softBlockId.present ? softBlockId.value : this.softBlockId,
    softOffset: softOffset.present ? softOffset.value : this.softOffset,
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
          ..write('markerBlockId: $markerBlockId, ')
          ..write('markerOffset: $markerOffset, ')
          ..write('softBlockId: $softBlockId, ')
          ..write('softOffset: $softOffset, ')
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
    markerBlockId,
    markerOffset,
    softBlockId,
    softOffset,
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
          other.markerBlockId == this.markerBlockId &&
          other.markerOffset == this.markerOffset &&
          other.softBlockId == this.softBlockId &&
          other.softOffset == this.softOffset &&
          other.revision == this.revision);
}

class SourcesCompanion extends UpdateCompanion<SourceRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> markdown;
  final Value<String> contentHash;
  final Value<int> wordCount;
  final Value<int> importedAtUtc;
  final Value<String?> markerBlockId;
  final Value<int?> markerOffset;
  final Value<String?> softBlockId;
  final Value<int?> softOffset;
  final Value<int> revision;
  final Value<int> rowid;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.markdown = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.importedAtUtc = const Value.absent(),
    this.markerBlockId = const Value.absent(),
    this.markerOffset = const Value.absent(),
    this.softBlockId = const Value.absent(),
    this.softOffset = const Value.absent(),
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
    this.markerBlockId = const Value.absent(),
    this.markerOffset = const Value.absent(),
    this.softBlockId = const Value.absent(),
    this.softOffset = const Value.absent(),
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
    Expression<String>? markerBlockId,
    Expression<int>? markerOffset,
    Expression<String>? softBlockId,
    Expression<int>? softOffset,
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
      if (markerBlockId != null) 'marker_block_id': markerBlockId,
      if (markerOffset != null) 'marker_offset': markerOffset,
      if (softBlockId != null) 'soft_block_id': softBlockId,
      if (softOffset != null) 'soft_offset': softOffset,
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
    Value<String?>? markerBlockId,
    Value<int?>? markerOffset,
    Value<String?>? softBlockId,
    Value<int?>? softOffset,
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
      markerBlockId: markerBlockId ?? this.markerBlockId,
      markerOffset: markerOffset ?? this.markerOffset,
      softBlockId: softBlockId ?? this.softBlockId,
      softOffset: softOffset ?? this.softOffset,
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
          ..write('markerBlockId: $markerBlockId, ')
          ..write('markerOffset: $markerOffset, ')
          ..write('softBlockId: $softBlockId, ')
          ..write('softOffset: $softOffset, ')
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
  static const VerificationMeta _parentElementIdMeta = const VerificationMeta(
    'parentElementId',
  );
  @override
  late final GeneratedColumn<String> parentElementId = GeneratedColumn<String>(
    'parent_element_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentElementTypeMeta = const VerificationMeta(
    'parentElementType',
  );
  @override
  late final GeneratedColumn<int> parentElementType = GeneratedColumn<int>(
    'parent_element_type',
    aliasedName,
    true,
    check: () => ComparableExpr(parentElementType).isBetweenValues(0, 1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
    parentElementId,
    parentElementType,
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
    if (data.containsKey('parent_element_id')) {
      context.handle(
        _parentElementIdMeta,
        parentElementId.isAcceptableOrUnknown(
          data['parent_element_id']!,
          _parentElementIdMeta,
        ),
      );
    }
    if (data.containsKey('parent_element_type')) {
      context.handle(
        _parentElementTypeMeta,
        parentElementType.isAcceptableOrUnknown(
          data['parent_element_type']!,
          _parentElementTypeMeta,
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
      parentElementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_element_id'],
      ),
      parentElementType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_element_type'],
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

  /// Sole canonical learning-element parent. [parentElementType] is null iff
  /// this is a standalone card. Referential validation is performed against
  /// the common schedule table inside the insertion transaction because
  /// SQLite cannot express a polymorphic foreign key.
  final String? parentElementId;
  final int? parentElementType;

  /// Index into the card-kind enum.
  final int kind;
  final String front;
  final String back;
  final int? clozeOrdinal;
  final int createdAtUtc;
  final int? editedAtUtc;
  const CardRow({
    required this.id,
    this.parentElementId,
    this.parentElementType,
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
    if (!nullToAbsent || parentElementId != null) {
      map['parent_element_id'] = Variable<String>(parentElementId);
    }
    if (!nullToAbsent || parentElementType != null) {
      map['parent_element_type'] = Variable<int>(parentElementType);
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
      parentElementId: parentElementId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentElementId),
      parentElementType: parentElementType == null && nullToAbsent
          ? const Value.absent()
          : Value(parentElementType),
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
      parentElementId: serializer.fromJson<String?>(json['parentElementId']),
      parentElementType: serializer.fromJson<int?>(json['parentElementType']),
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
      'parentElementId': serializer.toJson<String?>(parentElementId),
      'parentElementType': serializer.toJson<int?>(parentElementType),
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
    Value<String?> parentElementId = const Value.absent(),
    Value<int?> parentElementType = const Value.absent(),
    int? kind,
    String? front,
    String? back,
    Value<int?> clozeOrdinal = const Value.absent(),
    int? createdAtUtc,
    Value<int?> editedAtUtc = const Value.absent(),
  }) => CardRow(
    id: id ?? this.id,
    parentElementId: parentElementId.present
        ? parentElementId.value
        : this.parentElementId,
    parentElementType: parentElementType.present
        ? parentElementType.value
        : this.parentElementType,
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
      parentElementId: data.parentElementId.present
          ? data.parentElementId.value
          : this.parentElementId,
      parentElementType: data.parentElementType.present
          ? data.parentElementType.value
          : this.parentElementType,
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
          ..write('parentElementId: $parentElementId, ')
          ..write('parentElementType: $parentElementType, ')
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
    parentElementId,
    parentElementType,
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
          other.parentElementId == this.parentElementId &&
          other.parentElementType == this.parentElementType &&
          other.kind == this.kind &&
          other.front == this.front &&
          other.back == this.back &&
          other.clozeOrdinal == this.clozeOrdinal &&
          other.createdAtUtc == this.createdAtUtc &&
          other.editedAtUtc == this.editedAtUtc);
}

class CardsCompanion extends UpdateCompanion<CardRow> {
  final Value<String> id;
  final Value<String?> parentElementId;
  final Value<int?> parentElementType;
  final Value<int> kind;
  final Value<String> front;
  final Value<String> back;
  final Value<int?> clozeOrdinal;
  final Value<int> createdAtUtc;
  final Value<int?> editedAtUtc;
  final Value<int> rowid;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.parentElementId = const Value.absent(),
    this.parentElementType = const Value.absent(),
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
    this.parentElementId = const Value.absent(),
    this.parentElementType = const Value.absent(),
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
    Expression<String>? parentElementId,
    Expression<int>? parentElementType,
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
      if (parentElementId != null) 'parent_element_id': parentElementId,
      if (parentElementType != null) 'parent_element_type': parentElementType,
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
    Value<String?>? parentElementId,
    Value<int?>? parentElementType,
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
      parentElementId: parentElementId ?? this.parentElementId,
      parentElementType: parentElementType ?? this.parentElementType,
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
    if (parentElementId.present) {
      map['parent_element_id'] = Variable<String>(parentElementId.value);
    }
    if (parentElementType.present) {
      map['parent_element_type'] = Variable<int>(parentElementType.value);
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
          ..write('parentElementId: $parentElementId, ')
          ..write('parentElementType: $parentElementType, ')
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
    check: () => ComparableExpr(lifecycle).isBetweenValues(0, 2),
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
  static const VerificationMeta _rootIdMeta = const VerificationMeta('rootId');
  @override
  late final GeneratedColumn<String> rootId = GeneratedColumn<String>(
    'root_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentElementIdMeta = const VerificationMeta(
    'parentElementId',
  );
  @override
  late final GeneratedColumn<String> parentElementId = GeneratedColumn<String>(
    'parent_element_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
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
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    check: () => ComparableExpr(revision).isBiggerOrEqualValue(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _legacyDueProvenanceMeta =
      const VerificationMeta('legacyDueProvenance');
  @override
  late final GeneratedColumn<int> legacyDueProvenance = GeneratedColumn<int>(
    'legacy_due_provenance',
    aliasedName,
    false,
    check: () => ComparableExpr(legacyDueProvenance).isBetweenValues(0, 1),
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
    rootId,
    parentElementId,
    ordinal,
    createdAtUtc,
    updatedAtUtc,
    revision,
    legacyDueProvenance,
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
    if (data.containsKey('root_id')) {
      context.handle(
        _rootIdMeta,
        rootId.isAcceptableOrUnknown(data['root_id']!, _rootIdMeta),
      );
    }
    if (data.containsKey('parent_element_id')) {
      context.handle(
        _parentElementIdMeta,
        parentElementId.isAcceptableOrUnknown(
          data['parent_element_id']!,
          _parentElementIdMeta,
        ),
      );
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
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
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('legacy_due_provenance')) {
      context.handle(
        _legacyDueProvenanceMeta,
        legacyDueProvenance.isAcceptableOrUnknown(
          data['legacy_due_provenance']!,
          _legacyDueProvenanceMeta,
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
      rootId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_id'],
      ),
      parentElementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_element_id'],
      ),
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      ),
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      legacyDueProvenance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}legacy_due_provenance'],
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

  /// Index into the lifecycle enum: active (0), dismissed (1), deleted (2).
  ///
  /// The retired suspended and finished states are gone: SM20 knows only
  /// pending, memorized, dismissed, and deleted, and both of those states
  /// meant nothing more than "not scheduled, content kept".
  final int lifecycle;

  /// Days since the Unix epoch.
  final int dueDay;

  /// What the scheduler chose, preserved across postponement.
  final int originalDueDay;

  /// Source at the root of this element's provenance, denormalized.
  ///
  /// Walking up the tree on every queue build would be a needless join, and
  /// the queue needs it on every element to stop one article's subtree from
  /// taking over a session. Denormalizing also means a card keeps its
  /// citation if its source is ever removed.
  final String? rootId;

  /// Immediate learning-element parent; one coordinate for every kind.
  final String? parentElementId;

  /// Pending/user-visible order metadata, independent of priority and due.
  final int? ordinal;
  final int? createdAtUtc;
  final int? updatedAtUtc;
  final int revision;

  /// canonical (0) or legacy_due_unknown (1).
  final int legacyDueProvenance;
  final String zoneId;
  const ScheduleRow({
    required this.elementId,
    required this.elementType,
    required this.priorityKey,
    required this.lifecycle,
    required this.dueDay,
    required this.originalDueDay,
    this.rootId,
    this.parentElementId,
    this.ordinal,
    this.createdAtUtc,
    this.updatedAtUtc,
    required this.revision,
    required this.legacyDueProvenance,
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
    if (!nullToAbsent || rootId != null) {
      map['root_id'] = Variable<String>(rootId);
    }
    if (!nullToAbsent || parentElementId != null) {
      map['parent_element_id'] = Variable<String>(parentElementId);
    }
    if (!nullToAbsent || ordinal != null) {
      map['ordinal'] = Variable<int>(ordinal);
    }
    if (!nullToAbsent || createdAtUtc != null) {
      map['created_at_utc'] = Variable<int>(createdAtUtc);
    }
    if (!nullToAbsent || updatedAtUtc != null) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    }
    map['revision'] = Variable<int>(revision);
    map['legacy_due_provenance'] = Variable<int>(legacyDueProvenance);
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
      rootId: rootId == null && nullToAbsent
          ? const Value.absent()
          : Value(rootId),
      parentElementId: parentElementId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentElementId),
      ordinal: ordinal == null && nullToAbsent
          ? const Value.absent()
          : Value(ordinal),
      createdAtUtc: createdAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAtUtc),
      updatedAtUtc: updatedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAtUtc),
      revision: Value(revision),
      legacyDueProvenance: Value(legacyDueProvenance),
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
      rootId: serializer.fromJson<String?>(json['rootId']),
      parentElementId: serializer.fromJson<String?>(json['parentElementId']),
      ordinal: serializer.fromJson<int?>(json['ordinal']),
      createdAtUtc: serializer.fromJson<int?>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int?>(json['updatedAtUtc']),
      revision: serializer.fromJson<int>(json['revision']),
      legacyDueProvenance: serializer.fromJson<int>(
        json['legacyDueProvenance'],
      ),
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
      'rootId': serializer.toJson<String?>(rootId),
      'parentElementId': serializer.toJson<String?>(parentElementId),
      'ordinal': serializer.toJson<int?>(ordinal),
      'createdAtUtc': serializer.toJson<int?>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int?>(updatedAtUtc),
      'revision': serializer.toJson<int>(revision),
      'legacyDueProvenance': serializer.toJson<int>(legacyDueProvenance),
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
    Value<String?> rootId = const Value.absent(),
    Value<String?> parentElementId = const Value.absent(),
    Value<int?> ordinal = const Value.absent(),
    Value<int?> createdAtUtc = const Value.absent(),
    Value<int?> updatedAtUtc = const Value.absent(),
    int? revision,
    int? legacyDueProvenance,
    String? zoneId,
  }) => ScheduleRow(
    elementId: elementId ?? this.elementId,
    elementType: elementType ?? this.elementType,
    priorityKey: priorityKey ?? this.priorityKey,
    lifecycle: lifecycle ?? this.lifecycle,
    dueDay: dueDay ?? this.dueDay,
    originalDueDay: originalDueDay ?? this.originalDueDay,
    rootId: rootId.present ? rootId.value : this.rootId,
    parentElementId: parentElementId.present
        ? parentElementId.value
        : this.parentElementId,
    ordinal: ordinal.present ? ordinal.value : this.ordinal,
    createdAtUtc: createdAtUtc.present ? createdAtUtc.value : this.createdAtUtc,
    updatedAtUtc: updatedAtUtc.present ? updatedAtUtc.value : this.updatedAtUtc,
    revision: revision ?? this.revision,
    legacyDueProvenance: legacyDueProvenance ?? this.legacyDueProvenance,
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
      rootId: data.rootId.present ? data.rootId.value : this.rootId,
      parentElementId: data.parentElementId.present
          ? data.parentElementId.value
          : this.parentElementId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      revision: data.revision.present ? data.revision.value : this.revision,
      legacyDueProvenance: data.legacyDueProvenance.present
          ? data.legacyDueProvenance.value
          : this.legacyDueProvenance,
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
          ..write('rootId: $rootId, ')
          ..write('parentElementId: $parentElementId, ')
          ..write('ordinal: $ordinal, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('revision: $revision, ')
          ..write('legacyDueProvenance: $legacyDueProvenance, ')
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
    rootId,
    parentElementId,
    ordinal,
    createdAtUtc,
    updatedAtUtc,
    revision,
    legacyDueProvenance,
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
          other.rootId == this.rootId &&
          other.parentElementId == this.parentElementId &&
          other.ordinal == this.ordinal &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.revision == this.revision &&
          other.legacyDueProvenance == this.legacyDueProvenance &&
          other.zoneId == this.zoneId);
}

class ElementSchedulesCompanion extends UpdateCompanion<ScheduleRow> {
  final Value<String> elementId;
  final Value<int> elementType;
  final Value<String> priorityKey;
  final Value<int> lifecycle;
  final Value<int> dueDay;
  final Value<int> originalDueDay;
  final Value<String?> rootId;
  final Value<String?> parentElementId;
  final Value<int?> ordinal;
  final Value<int?> createdAtUtc;
  final Value<int?> updatedAtUtc;
  final Value<int> revision;
  final Value<int> legacyDueProvenance;
  final Value<String> zoneId;
  final Value<int> rowid;
  const ElementSchedulesCompanion({
    this.elementId = const Value.absent(),
    this.elementType = const Value.absent(),
    this.priorityKey = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.originalDueDay = const Value.absent(),
    this.rootId = const Value.absent(),
    this.parentElementId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.revision = const Value.absent(),
    this.legacyDueProvenance = const Value.absent(),
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
    this.rootId = const Value.absent(),
    this.parentElementId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.revision = const Value.absent(),
    this.legacyDueProvenance = const Value.absent(),
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
    Expression<String>? rootId,
    Expression<String>? parentElementId,
    Expression<int>? ordinal,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? revision,
    Expression<int>? legacyDueProvenance,
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
      if (rootId != null) 'root_id': rootId,
      if (parentElementId != null) 'parent_element_id': parentElementId,
      if (ordinal != null) 'ordinal': ordinal,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (revision != null) 'revision': revision,
      if (legacyDueProvenance != null)
        'legacy_due_provenance': legacyDueProvenance,
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
    Value<String?>? rootId,
    Value<String?>? parentElementId,
    Value<int?>? ordinal,
    Value<int?>? createdAtUtc,
    Value<int?>? updatedAtUtc,
    Value<int>? revision,
    Value<int>? legacyDueProvenance,
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
      rootId: rootId ?? this.rootId,
      parentElementId: parentElementId ?? this.parentElementId,
      ordinal: ordinal ?? this.ordinal,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      revision: revision ?? this.revision,
      legacyDueProvenance: legacyDueProvenance ?? this.legacyDueProvenance,
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
    if (rootId.present) {
      map['root_id'] = Variable<String>(rootId.value);
    }
    if (parentElementId.present) {
      map['parent_element_id'] = Variable<String>(parentElementId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (legacyDueProvenance.present) {
      map['legacy_due_provenance'] = Variable<int>(legacyDueProvenance.value);
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
          ..write('rootId: $rootId, ')
          ..write('parentElementId: $parentElementId, ')
          ..write('ordinal: $ordinal, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('revision: $revision, ')
          ..write('legacyDueProvenance: $legacyDueProvenance, ')
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    check: () => ComparableExpr(status).isBetweenValues(0, 3),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repetitionCountMeta = const VerificationMeta(
    'repetitionCount',
  );
  @override
  late final GeneratedColumn<int> repetitionCount = GeneratedColumn<int>(
    'repetition_count',
    aliasedName,
    false,
    check: () => ComparableExpr(repetitionCount).isBetweenValues(0, 65535),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapseCountMeta = const VerificationMeta(
    'lapseCount',
  );
  @override
  late final GeneratedColumn<int> lapseCount = GeneratedColumn<int>(
    'lapse_count',
    aliasedName,
    false,
    check: () => ComparableExpr(lapseCount).isBetweenValues(0, 65535),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _storedIntervalMeta = const VerificationMeta(
    'storedInterval',
  );
  @override
  late final GeneratedColumn<int> storedInterval = GeneratedColumn<int>(
    'stored_interval',
    aliasedName,
    false,
    check: () => ComparableExpr(storedInterval).isBetweenValues(0, 44530),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReviewDayMeta = const VerificationMeta(
    'lastReviewDay',
  );
  @override
  late final GeneratedColumn<int> lastReviewDay = GeneratedColumn<int>(
    'last_review_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aFactorRawMeta = const VerificationMeta(
    'aFactorRaw',
  );
  @override
  late final GeneratedColumn<String> aFactorRaw = GeneratedColumn<String>(
    'a_factor_raw',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('819a99999919'),
  );
  static const VerificationMeta _lastIntervalRatioRawMeta =
      const VerificationMeta('lastIntervalRatioRaw');
  @override
  late final GeneratedColumn<String> lastIntervalRatioRaw =
      GeneratedColumn<String>(
        'last_interval_ratio_raw',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('000000000000'),
      );
  static const VerificationMeta _historyBlockIdMeta = const VerificationMeta(
    'historyBlockId',
  );
  @override
  late final GeneratedColumn<int> historyBlockId = GeneratedColumn<int>(
    'history_block_id',
    aliasedName,
    false,
    check: () => ComparableExpr(historyBlockId).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _recentPostponementCountMeta =
      const VerificationMeta('recentPostponementCount');
  @override
  late final GeneratedColumn<int> recentPostponementCount =
      GeneratedColumn<int>(
        'recent_postponement_count',
        aliasedName,
        false,
        check: () =>
            ComparableExpr(recentPostponementCount).isBiggerOrEqualValue(0),
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _totalPostponementCountMeta =
      const VerificationMeta('totalPostponementCount');
  @override
  late final GeneratedColumn<int> totalPostponementCount = GeneratedColumn<int>(
    'total_postponement_count',
    aliasedName,
    false,
    check: () => ComparableExpr(totalPostponementCount).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _learningControlMeta = const VerificationMeta(
    'learningControl',
  );
  @override
  late final GeneratedColumn<int> learningControl = GeneratedColumn<int>(
    'learning_control',
    aliasedName,
    false,
    check: () => ComparableExpr(learningControl).isBetweenValues(0, 255),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _encountersSinceLastCardMeta =
      const VerificationMeta('encountersSinceLastCard');
  @override
  late final GeneratedColumn<int> encountersSinceLastCard =
      GeneratedColumn<int>(
        'encounters_since_last_card',
        aliasedName,
        false,
        check: () =>
            ComparableExpr(encountersSinceLastCard).isBiggerOrEqualValue(0),
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    check: () => ComparableExpr(revision).isBiggerOrEqualValue(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    elementId,
    elementType,
    status,
    repetitionCount,
    lapseCount,
    storedInterval,
    lastReviewDay,
    aFactorRaw,
    lastIntervalRatioRaw,
    historyBlockId,
    recentPostponementCount,
    totalPostponementCount,
    learningControl,
    encountersSinceLastCard,
    revision,
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
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('repetition_count')) {
      context.handle(
        _repetitionCountMeta,
        repetitionCount.isAcceptableOrUnknown(
          data['repetition_count']!,
          _repetitionCountMeta,
        ),
      );
    }
    if (data.containsKey('lapse_count')) {
      context.handle(
        _lapseCountMeta,
        lapseCount.isAcceptableOrUnknown(data['lapse_count']!, _lapseCountMeta),
      );
    }
    if (data.containsKey('stored_interval')) {
      context.handle(
        _storedIntervalMeta,
        storedInterval.isAcceptableOrUnknown(
          data['stored_interval']!,
          _storedIntervalMeta,
        ),
      );
    }
    if (data.containsKey('last_review_day')) {
      context.handle(
        _lastReviewDayMeta,
        lastReviewDay.isAcceptableOrUnknown(
          data['last_review_day']!,
          _lastReviewDayMeta,
        ),
      );
    }
    if (data.containsKey('a_factor_raw')) {
      context.handle(
        _aFactorRawMeta,
        aFactorRaw.isAcceptableOrUnknown(
          data['a_factor_raw']!,
          _aFactorRawMeta,
        ),
      );
    }
    if (data.containsKey('last_interval_ratio_raw')) {
      context.handle(
        _lastIntervalRatioRawMeta,
        lastIntervalRatioRaw.isAcceptableOrUnknown(
          data['last_interval_ratio_raw']!,
          _lastIntervalRatioRawMeta,
        ),
      );
    }
    if (data.containsKey('history_block_id')) {
      context.handle(
        _historyBlockIdMeta,
        historyBlockId.isAcceptableOrUnknown(
          data['history_block_id']!,
          _historyBlockIdMeta,
        ),
      );
    }
    if (data.containsKey('recent_postponement_count')) {
      context.handle(
        _recentPostponementCountMeta,
        recentPostponementCount.isAcceptableOrUnknown(
          data['recent_postponement_count']!,
          _recentPostponementCountMeta,
        ),
      );
    }
    if (data.containsKey('total_postponement_count')) {
      context.handle(
        _totalPostponementCountMeta,
        totalPostponementCount.isAcceptableOrUnknown(
          data['total_postponement_count']!,
          _totalPostponementCountMeta,
        ),
      );
    }
    if (data.containsKey('learning_control')) {
      context.handle(
        _learningControlMeta,
        learningControl.isAcceptableOrUnknown(
          data['learning_control']!,
          _learningControlMeta,
        ),
      );
    }
    if (data.containsKey('encounters_since_last_card')) {
      context.handle(
        _encountersSinceLastCardMeta,
        encountersSinceLastCard.isAcceptableOrUnknown(
          data['encounters_since_last_card']!,
          _encountersSinceLastCardMeta,
        ),
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
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      repetitionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repetition_count'],
      )!,
      lapseCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapse_count'],
      )!,
      storedInterval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stored_interval'],
      )!,
      lastReviewDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_review_day'],
      ),
      aFactorRaw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}a_factor_raw'],
      )!,
      lastIntervalRatioRaw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_interval_ratio_raw'],
      )!,
      historyBlockId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}history_block_id'],
      )!,
      recentPostponementCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recent_postponement_count'],
      )!,
      totalPostponementCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_postponement_count'],
      )!,
      learningControl: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}learning_control'],
      )!,
      encountersSinceLastCard: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encounters_since_last_card'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
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

  /// SM20 record status: pending, memorized, dismissed, or deleted.
  final int status;
  final int repetitionCount;
  final int lapseCount;
  final int storedInterval;

  /// Signed collection day. Null before the first review.
  final int? lastReviewDay;

  /// Raw little-endian Delphi Real48 bytes, encoded as twelve hex characters.
  final String aFactorRaw;

  /// Raw little-endian Delphi Real48 interval-ratio bytes.
  final String lastIntervalRatioRaw;
  final int historyBlockId;
  final int recentPostponementCount;
  final int totalPostponementCount;
  final int learningControl;

  /// Encounters since the last card was formulated from this element.
  final int encountersSinceLastCard;
  final int revision;
  const TopicStateRow({
    required this.elementId,
    required this.elementType,
    required this.status,
    required this.repetitionCount,
    required this.lapseCount,
    required this.storedInterval,
    this.lastReviewDay,
    required this.aFactorRaw,
    required this.lastIntervalRatioRaw,
    required this.historyBlockId,
    required this.recentPostponementCount,
    required this.totalPostponementCount,
    required this.learningControl,
    required this.encountersSinceLastCard,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['element_id'] = Variable<String>(elementId);
    map['element_type'] = Variable<int>(elementType);
    map['status'] = Variable<int>(status);
    map['repetition_count'] = Variable<int>(repetitionCount);
    map['lapse_count'] = Variable<int>(lapseCount);
    map['stored_interval'] = Variable<int>(storedInterval);
    if (!nullToAbsent || lastReviewDay != null) {
      map['last_review_day'] = Variable<int>(lastReviewDay);
    }
    map['a_factor_raw'] = Variable<String>(aFactorRaw);
    map['last_interval_ratio_raw'] = Variable<String>(lastIntervalRatioRaw);
    map['history_block_id'] = Variable<int>(historyBlockId);
    map['recent_postponement_count'] = Variable<int>(recentPostponementCount);
    map['total_postponement_count'] = Variable<int>(totalPostponementCount);
    map['learning_control'] = Variable<int>(learningControl);
    map['encounters_since_last_card'] = Variable<int>(encountersSinceLastCard);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  TopicStatesCompanion toCompanion(bool nullToAbsent) {
    return TopicStatesCompanion(
      elementId: Value(elementId),
      elementType: Value(elementType),
      status: Value(status),
      repetitionCount: Value(repetitionCount),
      lapseCount: Value(lapseCount),
      storedInterval: Value(storedInterval),
      lastReviewDay: lastReviewDay == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewDay),
      aFactorRaw: Value(aFactorRaw),
      lastIntervalRatioRaw: Value(lastIntervalRatioRaw),
      historyBlockId: Value(historyBlockId),
      recentPostponementCount: Value(recentPostponementCount),
      totalPostponementCount: Value(totalPostponementCount),
      learningControl: Value(learningControl),
      encountersSinceLastCard: Value(encountersSinceLastCard),
      revision: Value(revision),
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
      status: serializer.fromJson<int>(json['status']),
      repetitionCount: serializer.fromJson<int>(json['repetitionCount']),
      lapseCount: serializer.fromJson<int>(json['lapseCount']),
      storedInterval: serializer.fromJson<int>(json['storedInterval']),
      lastReviewDay: serializer.fromJson<int?>(json['lastReviewDay']),
      aFactorRaw: serializer.fromJson<String>(json['aFactorRaw']),
      lastIntervalRatioRaw: serializer.fromJson<String>(
        json['lastIntervalRatioRaw'],
      ),
      historyBlockId: serializer.fromJson<int>(json['historyBlockId']),
      recentPostponementCount: serializer.fromJson<int>(
        json['recentPostponementCount'],
      ),
      totalPostponementCount: serializer.fromJson<int>(
        json['totalPostponementCount'],
      ),
      learningControl: serializer.fromJson<int>(json['learningControl']),
      encountersSinceLastCard: serializer.fromJson<int>(
        json['encountersSinceLastCard'],
      ),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'elementId': serializer.toJson<String>(elementId),
      'elementType': serializer.toJson<int>(elementType),
      'status': serializer.toJson<int>(status),
      'repetitionCount': serializer.toJson<int>(repetitionCount),
      'lapseCount': serializer.toJson<int>(lapseCount),
      'storedInterval': serializer.toJson<int>(storedInterval),
      'lastReviewDay': serializer.toJson<int?>(lastReviewDay),
      'aFactorRaw': serializer.toJson<String>(aFactorRaw),
      'lastIntervalRatioRaw': serializer.toJson<String>(lastIntervalRatioRaw),
      'historyBlockId': serializer.toJson<int>(historyBlockId),
      'recentPostponementCount': serializer.toJson<int>(
        recentPostponementCount,
      ),
      'totalPostponementCount': serializer.toJson<int>(totalPostponementCount),
      'learningControl': serializer.toJson<int>(learningControl),
      'encountersSinceLastCard': serializer.toJson<int>(
        encountersSinceLastCard,
      ),
      'revision': serializer.toJson<int>(revision),
    };
  }

  TopicStateRow copyWith({
    String? elementId,
    int? elementType,
    int? status,
    int? repetitionCount,
    int? lapseCount,
    int? storedInterval,
    Value<int?> lastReviewDay = const Value.absent(),
    String? aFactorRaw,
    String? lastIntervalRatioRaw,
    int? historyBlockId,
    int? recentPostponementCount,
    int? totalPostponementCount,
    int? learningControl,
    int? encountersSinceLastCard,
    int? revision,
  }) => TopicStateRow(
    elementId: elementId ?? this.elementId,
    elementType: elementType ?? this.elementType,
    status: status ?? this.status,
    repetitionCount: repetitionCount ?? this.repetitionCount,
    lapseCount: lapseCount ?? this.lapseCount,
    storedInterval: storedInterval ?? this.storedInterval,
    lastReviewDay: lastReviewDay.present
        ? lastReviewDay.value
        : this.lastReviewDay,
    aFactorRaw: aFactorRaw ?? this.aFactorRaw,
    lastIntervalRatioRaw: lastIntervalRatioRaw ?? this.lastIntervalRatioRaw,
    historyBlockId: historyBlockId ?? this.historyBlockId,
    recentPostponementCount:
        recentPostponementCount ?? this.recentPostponementCount,
    totalPostponementCount:
        totalPostponementCount ?? this.totalPostponementCount,
    learningControl: learningControl ?? this.learningControl,
    encountersSinceLastCard:
        encountersSinceLastCard ?? this.encountersSinceLastCard,
    revision: revision ?? this.revision,
  );
  TopicStateRow copyWithCompanion(TopicStatesCompanion data) {
    return TopicStateRow(
      elementId: data.elementId.present ? data.elementId.value : this.elementId,
      elementType: data.elementType.present
          ? data.elementType.value
          : this.elementType,
      status: data.status.present ? data.status.value : this.status,
      repetitionCount: data.repetitionCount.present
          ? data.repetitionCount.value
          : this.repetitionCount,
      lapseCount: data.lapseCount.present
          ? data.lapseCount.value
          : this.lapseCount,
      storedInterval: data.storedInterval.present
          ? data.storedInterval.value
          : this.storedInterval,
      lastReviewDay: data.lastReviewDay.present
          ? data.lastReviewDay.value
          : this.lastReviewDay,
      aFactorRaw: data.aFactorRaw.present
          ? data.aFactorRaw.value
          : this.aFactorRaw,
      lastIntervalRatioRaw: data.lastIntervalRatioRaw.present
          ? data.lastIntervalRatioRaw.value
          : this.lastIntervalRatioRaw,
      historyBlockId: data.historyBlockId.present
          ? data.historyBlockId.value
          : this.historyBlockId,
      recentPostponementCount: data.recentPostponementCount.present
          ? data.recentPostponementCount.value
          : this.recentPostponementCount,
      totalPostponementCount: data.totalPostponementCount.present
          ? data.totalPostponementCount.value
          : this.totalPostponementCount,
      learningControl: data.learningControl.present
          ? data.learningControl.value
          : this.learningControl,
      encountersSinceLastCard: data.encountersSinceLastCard.present
          ? data.encountersSinceLastCard.value
          : this.encountersSinceLastCard,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TopicStateRow(')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('status: $status, ')
          ..write('repetitionCount: $repetitionCount, ')
          ..write('lapseCount: $lapseCount, ')
          ..write('storedInterval: $storedInterval, ')
          ..write('lastReviewDay: $lastReviewDay, ')
          ..write('aFactorRaw: $aFactorRaw, ')
          ..write('lastIntervalRatioRaw: $lastIntervalRatioRaw, ')
          ..write('historyBlockId: $historyBlockId, ')
          ..write('recentPostponementCount: $recentPostponementCount, ')
          ..write('totalPostponementCount: $totalPostponementCount, ')
          ..write('learningControl: $learningControl, ')
          ..write('encountersSinceLastCard: $encountersSinceLastCard, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    elementId,
    elementType,
    status,
    repetitionCount,
    lapseCount,
    storedInterval,
    lastReviewDay,
    aFactorRaw,
    lastIntervalRatioRaw,
    historyBlockId,
    recentPostponementCount,
    totalPostponementCount,
    learningControl,
    encountersSinceLastCard,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TopicStateRow &&
          other.elementId == this.elementId &&
          other.elementType == this.elementType &&
          other.status == this.status &&
          other.repetitionCount == this.repetitionCount &&
          other.lapseCount == this.lapseCount &&
          other.storedInterval == this.storedInterval &&
          other.lastReviewDay == this.lastReviewDay &&
          other.aFactorRaw == this.aFactorRaw &&
          other.lastIntervalRatioRaw == this.lastIntervalRatioRaw &&
          other.historyBlockId == this.historyBlockId &&
          other.recentPostponementCount == this.recentPostponementCount &&
          other.totalPostponementCount == this.totalPostponementCount &&
          other.learningControl == this.learningControl &&
          other.encountersSinceLastCard == this.encountersSinceLastCard &&
          other.revision == this.revision);
}

class TopicStatesCompanion extends UpdateCompanion<TopicStateRow> {
  final Value<String> elementId;
  final Value<int> elementType;
  final Value<int> status;
  final Value<int> repetitionCount;
  final Value<int> lapseCount;
  final Value<int> storedInterval;
  final Value<int?> lastReviewDay;
  final Value<String> aFactorRaw;
  final Value<String> lastIntervalRatioRaw;
  final Value<int> historyBlockId;
  final Value<int> recentPostponementCount;
  final Value<int> totalPostponementCount;
  final Value<int> learningControl;
  final Value<int> encountersSinceLastCard;
  final Value<int> revision;
  final Value<int> rowid;
  const TopicStatesCompanion({
    this.elementId = const Value.absent(),
    this.elementType = const Value.absent(),
    this.status = const Value.absent(),
    this.repetitionCount = const Value.absent(),
    this.lapseCount = const Value.absent(),
    this.storedInterval = const Value.absent(),
    this.lastReviewDay = const Value.absent(),
    this.aFactorRaw = const Value.absent(),
    this.lastIntervalRatioRaw = const Value.absent(),
    this.historyBlockId = const Value.absent(),
    this.recentPostponementCount = const Value.absent(),
    this.totalPostponementCount = const Value.absent(),
    this.learningControl = const Value.absent(),
    this.encountersSinceLastCard = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TopicStatesCompanion.insert({
    required String elementId,
    required int elementType,
    required int status,
    this.repetitionCount = const Value.absent(),
    this.lapseCount = const Value.absent(),
    this.storedInterval = const Value.absent(),
    this.lastReviewDay = const Value.absent(),
    this.aFactorRaw = const Value.absent(),
    this.lastIntervalRatioRaw = const Value.absent(),
    this.historyBlockId = const Value.absent(),
    this.recentPostponementCount = const Value.absent(),
    this.totalPostponementCount = const Value.absent(),
    this.learningControl = const Value.absent(),
    this.encountersSinceLastCard = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : elementId = Value(elementId),
       elementType = Value(elementType),
       status = Value(status);
  static Insertable<TopicStateRow> custom({
    Expression<String>? elementId,
    Expression<int>? elementType,
    Expression<int>? status,
    Expression<int>? repetitionCount,
    Expression<int>? lapseCount,
    Expression<int>? storedInterval,
    Expression<int>? lastReviewDay,
    Expression<String>? aFactorRaw,
    Expression<String>? lastIntervalRatioRaw,
    Expression<int>? historyBlockId,
    Expression<int>? recentPostponementCount,
    Expression<int>? totalPostponementCount,
    Expression<int>? learningControl,
    Expression<int>? encountersSinceLastCard,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (elementId != null) 'element_id': elementId,
      if (elementType != null) 'element_type': elementType,
      if (status != null) 'status': status,
      if (repetitionCount != null) 'repetition_count': repetitionCount,
      if (lapseCount != null) 'lapse_count': lapseCount,
      if (storedInterval != null) 'stored_interval': storedInterval,
      if (lastReviewDay != null) 'last_review_day': lastReviewDay,
      if (aFactorRaw != null) 'a_factor_raw': aFactorRaw,
      if (lastIntervalRatioRaw != null)
        'last_interval_ratio_raw': lastIntervalRatioRaw,
      if (historyBlockId != null) 'history_block_id': historyBlockId,
      if (recentPostponementCount != null)
        'recent_postponement_count': recentPostponementCount,
      if (totalPostponementCount != null)
        'total_postponement_count': totalPostponementCount,
      if (learningControl != null) 'learning_control': learningControl,
      if (encountersSinceLastCard != null)
        'encounters_since_last_card': encountersSinceLastCard,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TopicStatesCompanion copyWith({
    Value<String>? elementId,
    Value<int>? elementType,
    Value<int>? status,
    Value<int>? repetitionCount,
    Value<int>? lapseCount,
    Value<int>? storedInterval,
    Value<int?>? lastReviewDay,
    Value<String>? aFactorRaw,
    Value<String>? lastIntervalRatioRaw,
    Value<int>? historyBlockId,
    Value<int>? recentPostponementCount,
    Value<int>? totalPostponementCount,
    Value<int>? learningControl,
    Value<int>? encountersSinceLastCard,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return TopicStatesCompanion(
      elementId: elementId ?? this.elementId,
      elementType: elementType ?? this.elementType,
      status: status ?? this.status,
      repetitionCount: repetitionCount ?? this.repetitionCount,
      lapseCount: lapseCount ?? this.lapseCount,
      storedInterval: storedInterval ?? this.storedInterval,
      lastReviewDay: lastReviewDay ?? this.lastReviewDay,
      aFactorRaw: aFactorRaw ?? this.aFactorRaw,
      lastIntervalRatioRaw: lastIntervalRatioRaw ?? this.lastIntervalRatioRaw,
      historyBlockId: historyBlockId ?? this.historyBlockId,
      recentPostponementCount:
          recentPostponementCount ?? this.recentPostponementCount,
      totalPostponementCount:
          totalPostponementCount ?? this.totalPostponementCount,
      learningControl: learningControl ?? this.learningControl,
      encountersSinceLastCard:
          encountersSinceLastCard ?? this.encountersSinceLastCard,
      revision: revision ?? this.revision,
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
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (repetitionCount.present) {
      map['repetition_count'] = Variable<int>(repetitionCount.value);
    }
    if (lapseCount.present) {
      map['lapse_count'] = Variable<int>(lapseCount.value);
    }
    if (storedInterval.present) {
      map['stored_interval'] = Variable<int>(storedInterval.value);
    }
    if (lastReviewDay.present) {
      map['last_review_day'] = Variable<int>(lastReviewDay.value);
    }
    if (aFactorRaw.present) {
      map['a_factor_raw'] = Variable<String>(aFactorRaw.value);
    }
    if (lastIntervalRatioRaw.present) {
      map['last_interval_ratio_raw'] = Variable<String>(
        lastIntervalRatioRaw.value,
      );
    }
    if (historyBlockId.present) {
      map['history_block_id'] = Variable<int>(historyBlockId.value);
    }
    if (recentPostponementCount.present) {
      map['recent_postponement_count'] = Variable<int>(
        recentPostponementCount.value,
      );
    }
    if (totalPostponementCount.present) {
      map['total_postponement_count'] = Variable<int>(
        totalPostponementCount.value,
      );
    }
    if (learningControl.present) {
      map['learning_control'] = Variable<int>(learningControl.value);
    }
    if (encountersSinceLastCard.present) {
      map['encounters_since_last_card'] = Variable<int>(
        encountersSinceLastCard.value,
      );
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
    return (StringBuffer('TopicStatesCompanion(')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('status: $status, ')
          ..write('repetitionCount: $repetitionCount, ')
          ..write('lapseCount: $lapseCount, ')
          ..write('storedInterval: $storedInterval, ')
          ..write('lastReviewDay: $lastReviewDay, ')
          ..write('aFactorRaw: $aFactorRaw, ')
          ..write('lastIntervalRatioRaw: $lastIntervalRatioRaw, ')
          ..write('historyBlockId: $historyBlockId, ')
          ..write('recentPostponementCount: $recentPostponementCount, ')
          ..write('totalPostponementCount: $totalPostponementCount, ')
          ..write('learningControl: $learningControl, ')
          ..write('encountersSinceLastCard: $encountersSinceLastCard, ')
          ..write('revision: $revision, ')
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
      'REFERENCES cards (id) ON DELETE RESTRICT',
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
  static const VerificationMeta _postponeCountMeta = const VerificationMeta(
    'postponeCount',
  );
  @override
  late final GeneratedColumn<int> postponeCount = GeneratedColumn<int>(
    'postpone_count',
    aliasedName,
    false,
    check: () => ComparableExpr(postponeCount).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _schedulerNameMeta = const VerificationMeta(
    'schedulerName',
  );
  @override
  late final GeneratedColumn<String> schedulerName = GeneratedColumn<String>(
    'scheduler_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('dart-fsrs'),
  );
  static const VerificationMeta _scheduledDaysMeta = const VerificationMeta(
    'scheduledDays',
  );
  @override
  late final GeneratedColumn<double> scheduledDays = GeneratedColumn<double>(
    'scheduled_days',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fsrsStateJsonMeta = const VerificationMeta(
    'fsrsStateJson',
  );
  @override
  late final GeneratedColumn<String> fsrsStateJson = GeneratedColumn<String>(
    'fsrs_state_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    check: () => ComparableExpr(revision).isBiggerOrEqualValue(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    postponeCount,
    schedulerVersion,
    parametersVersion,
    schedulerName,
    scheduledDays,
    fsrsStateJson,
    revision,
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
    if (data.containsKey('postpone_count')) {
      context.handle(
        _postponeCountMeta,
        postponeCount.isAcceptableOrUnknown(
          data['postpone_count']!,
          _postponeCountMeta,
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
    if (data.containsKey('scheduler_name')) {
      context.handle(
        _schedulerNameMeta,
        schedulerName.isAcceptableOrUnknown(
          data['scheduler_name']!,
          _schedulerNameMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_days')) {
      context.handle(
        _scheduledDaysMeta,
        scheduledDays.isAcceptableOrUnknown(
          data['scheduled_days']!,
          _scheduledDaysMeta,
        ),
      );
    }
    if (data.containsKey('fsrs_state_json')) {
      context.handle(
        _fsrsStateJsonMeta,
        fsrsStateJson.isAcceptableOrUnknown(
          data['fsrs_state_json']!,
          _fsrsStateJsonMeta,
        ),
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
      postponeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}postpone_count'],
      )!,
      schedulerVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduler_version'],
      )!,
      parametersVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameters_version'],
      )!,
      schedulerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduler_name'],
      )!,
      scheduledDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}scheduled_days'],
      ),
      fsrsStateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fsrs_state_json'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
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

  /// Deferrals so far. Never a review, so it lives apart from [reps].
  final int postponeCount;

  /// Pinned scheduler build and parameter set, recorded so history stays
  /// interpretable after either changes.
  final String schedulerVersion;
  final String parametersVersion;
  final String schedulerName;
  final double? scheduledDays;

  /// Exact serialized state consumed by the pinned adapter. Nullable only for
  /// legacy rows while a migration is validating/backfilling them.
  final String? fsrsStateJson;
  final int revision;
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
    required this.postponeCount,
    required this.schedulerVersion,
    required this.parametersVersion,
    required this.schedulerName,
    this.scheduledDays,
    this.fsrsStateJson,
    required this.revision,
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
    map['postpone_count'] = Variable<int>(postponeCount);
    map['scheduler_version'] = Variable<String>(schedulerVersion);
    map['parameters_version'] = Variable<String>(parametersVersion);
    map['scheduler_name'] = Variable<String>(schedulerName);
    if (!nullToAbsent || scheduledDays != null) {
      map['scheduled_days'] = Variable<double>(scheduledDays);
    }
    if (!nullToAbsent || fsrsStateJson != null) {
      map['fsrs_state_json'] = Variable<String>(fsrsStateJson);
    }
    map['revision'] = Variable<int>(revision);
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
      postponeCount: Value(postponeCount),
      schedulerVersion: Value(schedulerVersion),
      parametersVersion: Value(parametersVersion),
      schedulerName: Value(schedulerName),
      scheduledDays: scheduledDays == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledDays),
      fsrsStateJson: fsrsStateJson == null && nullToAbsent
          ? const Value.absent()
          : Value(fsrsStateJson),
      revision: Value(revision),
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
      postponeCount: serializer.fromJson<int>(json['postponeCount']),
      schedulerVersion: serializer.fromJson<String>(json['schedulerVersion']),
      parametersVersion: serializer.fromJson<String>(json['parametersVersion']),
      schedulerName: serializer.fromJson<String>(json['schedulerName']),
      scheduledDays: serializer.fromJson<double?>(json['scheduledDays']),
      fsrsStateJson: serializer.fromJson<String?>(json['fsrsStateJson']),
      revision: serializer.fromJson<int>(json['revision']),
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
      'postponeCount': serializer.toJson<int>(postponeCount),
      'schedulerVersion': serializer.toJson<String>(schedulerVersion),
      'parametersVersion': serializer.toJson<String>(parametersVersion),
      'schedulerName': serializer.toJson<String>(schedulerName),
      'scheduledDays': serializer.toJson<double?>(scheduledDays),
      'fsrsStateJson': serializer.toJson<String?>(fsrsStateJson),
      'revision': serializer.toJson<int>(revision),
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
    int? postponeCount,
    String? schedulerVersion,
    String? parametersVersion,
    String? schedulerName,
    Value<double?> scheduledDays = const Value.absent(),
    Value<String?> fsrsStateJson = const Value.absent(),
    int? revision,
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
    postponeCount: postponeCount ?? this.postponeCount,
    schedulerVersion: schedulerVersion ?? this.schedulerVersion,
    parametersVersion: parametersVersion ?? this.parametersVersion,
    schedulerName: schedulerName ?? this.schedulerName,
    scheduledDays: scheduledDays.present
        ? scheduledDays.value
        : this.scheduledDays,
    fsrsStateJson: fsrsStateJson.present
        ? fsrsStateJson.value
        : this.fsrsStateJson,
    revision: revision ?? this.revision,
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
      postponeCount: data.postponeCount.present
          ? data.postponeCount.value
          : this.postponeCount,
      schedulerVersion: data.schedulerVersion.present
          ? data.schedulerVersion.value
          : this.schedulerVersion,
      parametersVersion: data.parametersVersion.present
          ? data.parametersVersion.value
          : this.parametersVersion,
      schedulerName: data.schedulerName.present
          ? data.schedulerName.value
          : this.schedulerName,
      scheduledDays: data.scheduledDays.present
          ? data.scheduledDays.value
          : this.scheduledDays,
      fsrsStateJson: data.fsrsStateJson.present
          ? data.fsrsStateJson.value
          : this.fsrsStateJson,
      revision: data.revision.present ? data.revision.value : this.revision,
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
          ..write('postponeCount: $postponeCount, ')
          ..write('schedulerVersion: $schedulerVersion, ')
          ..write('parametersVersion: $parametersVersion, ')
          ..write('schedulerName: $schedulerName, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('fsrsStateJson: $fsrsStateJson, ')
          ..write('revision: $revision')
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
    postponeCount,
    schedulerVersion,
    parametersVersion,
    schedulerName,
    scheduledDays,
    fsrsStateJson,
    revision,
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
          other.postponeCount == this.postponeCount &&
          other.schedulerVersion == this.schedulerVersion &&
          other.parametersVersion == this.parametersVersion &&
          other.schedulerName == this.schedulerName &&
          other.scheduledDays == this.scheduledDays &&
          other.fsrsStateJson == this.fsrsStateJson &&
          other.revision == this.revision);
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
  final Value<int> postponeCount;
  final Value<String> schedulerVersion;
  final Value<String> parametersVersion;
  final Value<String> schedulerName;
  final Value<double?> scheduledDays;
  final Value<String?> fsrsStateJson;
  final Value<int> revision;
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
    this.postponeCount = const Value.absent(),
    this.schedulerVersion = const Value.absent(),
    this.parametersVersion = const Value.absent(),
    this.schedulerName = const Value.absent(),
    this.scheduledDays = const Value.absent(),
    this.fsrsStateJson = const Value.absent(),
    this.revision = const Value.absent(),
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
    this.postponeCount = const Value.absent(),
    required String schedulerVersion,
    required String parametersVersion,
    this.schedulerName = const Value.absent(),
    this.scheduledDays = const Value.absent(),
    this.fsrsStateJson = const Value.absent(),
    this.revision = const Value.absent(),
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
    Expression<int>? postponeCount,
    Expression<String>? schedulerVersion,
    Expression<String>? parametersVersion,
    Expression<String>? schedulerName,
    Expression<double>? scheduledDays,
    Expression<String>? fsrsStateJson,
    Expression<int>? revision,
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
      if (postponeCount != null) 'postpone_count': postponeCount,
      if (schedulerVersion != null) 'scheduler_version': schedulerVersion,
      if (parametersVersion != null) 'parameters_version': parametersVersion,
      if (schedulerName != null) 'scheduler_name': schedulerName,
      if (scheduledDays != null) 'scheduled_days': scheduledDays,
      if (fsrsStateJson != null) 'fsrs_state_json': fsrsStateJson,
      if (revision != null) 'revision': revision,
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
    Value<int>? postponeCount,
    Value<String>? schedulerVersion,
    Value<String>? parametersVersion,
    Value<String>? schedulerName,
    Value<double?>? scheduledDays,
    Value<String?>? fsrsStateJson,
    Value<int>? revision,
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
      postponeCount: postponeCount ?? this.postponeCount,
      schedulerVersion: schedulerVersion ?? this.schedulerVersion,
      parametersVersion: parametersVersion ?? this.parametersVersion,
      schedulerName: schedulerName ?? this.schedulerName,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      fsrsStateJson: fsrsStateJson ?? this.fsrsStateJson,
      revision: revision ?? this.revision,
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
    if (postponeCount.present) {
      map['postpone_count'] = Variable<int>(postponeCount.value);
    }
    if (schedulerVersion.present) {
      map['scheduler_version'] = Variable<String>(schedulerVersion.value);
    }
    if (parametersVersion.present) {
      map['parameters_version'] = Variable<String>(parametersVersion.value);
    }
    if (schedulerName.present) {
      map['scheduler_name'] = Variable<String>(schedulerName.value);
    }
    if (scheduledDays.present) {
      map['scheduled_days'] = Variable<double>(scheduledDays.value);
    }
    if (fsrsStateJson.present) {
      map['fsrs_state_json'] = Variable<String>(fsrsStateJson.value);
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
          ..write('postponeCount: $postponeCount, ')
          ..write('schedulerVersion: $schedulerVersion, ')
          ..write('parametersVersion: $parametersVersion, ')
          ..write('schedulerName: $schedulerName, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('fsrsStateJson: $fsrsStateJson, ')
          ..write('revision: $revision, ')
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
      'REFERENCES cards (id) ON DELETE RESTRICT',
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

class $RevlogEntriesTable extends RevlogEntries
    with TableInfo<$RevlogEntriesTable, RevlogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RevlogEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<int> eventType = GeneratedColumn<int>(
    'event_type',
    aliasedName,
    false,
    check: () => ComparableExpr(eventType).isBetweenValues(1, 15),
    type: DriftSqlType.int,
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
  static const VerificationMeta _gradeMeta = const VerificationMeta('grade');
  @override
  late final GeneratedColumn<int> grade = GeneratedColumn<int>(
    'grade',
    aliasedName,
    true,
    check: () => ComparableExpr(grade).isBetweenValues(1, 4),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elapsedDaysMeta = const VerificationMeta(
    'elapsedDays',
  );
  @override
  late final GeneratedColumn<double> elapsedDays = GeneratedColumn<double>(
    'elapsed_days',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledDaysMeta = const VerificationMeta(
    'scheduledDays',
  );
  @override
  late final GeneratedColumn<double> scheduledDays = GeneratedColumn<double>(
    'scheduled_days',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
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
  static const VerificationMeta _postponeCountMeta = const VerificationMeta(
    'postponeCount',
  );
  @override
  late final GeneratedColumn<int> postponeCount = GeneratedColumn<int>(
    'postpone_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueBeforeUtcMeta = const VerificationMeta(
    'dueBeforeUtc',
  );
  @override
  late final GeneratedColumn<int> dueBeforeUtc = GeneratedColumn<int>(
    'due_before_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueAfterUtcMeta = const VerificationMeta(
    'dueAfterUtc',
  );
  @override
  late final GeneratedColumn<int> dueAfterUtc = GeneratedColumn<int>(
    'due_after_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intervalBeforeMeta = const VerificationMeta(
    'intervalBefore',
  );
  @override
  late final GeneratedColumn<double> intervalBefore = GeneratedColumn<double>(
    'interval_before',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intervalAfterMeta = const VerificationMeta(
    'intervalAfter',
  );
  @override
  late final GeneratedColumn<double> intervalAfter = GeneratedColumn<double>(
    'interval_after',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aFactorBeforeMeta = const VerificationMeta(
    'aFactorBefore',
  );
  @override
  late final GeneratedColumn<double> aFactorBefore = GeneratedColumn<double>(
    'a_factor_before',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aFactorAfterMeta = const VerificationMeta(
    'aFactorAfter',
  );
  @override
  late final GeneratedColumn<double> aFactorAfter = GeneratedColumn<double>(
    'a_factor_after',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stabilityBeforeMeta = const VerificationMeta(
    'stabilityBefore',
  );
  @override
  late final GeneratedColumn<double> stabilityBefore = GeneratedColumn<double>(
    'stability_before',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stabilityAfterMeta = const VerificationMeta(
    'stabilityAfter',
  );
  @override
  late final GeneratedColumn<double> stabilityAfter = GeneratedColumn<double>(
    'stability_after',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultyBeforeMeta = const VerificationMeta(
    'difficultyBefore',
  );
  @override
  late final GeneratedColumn<double> difficultyBefore = GeneratedColumn<double>(
    'difficulty_before',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultyAfterMeta = const VerificationMeta(
    'difficultyAfter',
  );
  @override
  late final GeneratedColumn<double> difficultyAfter = GeneratedColumn<double>(
    'difficulty_after',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateBeforeMeta = const VerificationMeta(
    'stateBefore',
  );
  @override
  late final GeneratedColumn<int> stateBefore = GeneratedColumn<int>(
    'state_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateAfterMeta = const VerificationMeta(
    'stateAfter',
  );
  @override
  late final GeneratedColumn<int> stateAfter = GeneratedColumn<int>(
    'state_after',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repsBeforeMeta = const VerificationMeta(
    'repsBefore',
  );
  @override
  late final GeneratedColumn<int> repsBefore = GeneratedColumn<int>(
    'reps_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lapsesBeforeMeta = const VerificationMeta(
    'lapsesBefore',
  );
  @override
  late final GeneratedColumn<int> lapsesBefore = GeneratedColumn<int>(
    'lapses_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityBeforeMeta = const VerificationMeta(
    'priorityBefore',
  );
  @override
  late final GeneratedColumn<String> priorityBefore = GeneratedColumn<String>(
    'priority_before',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityAfterMeta = const VerificationMeta(
    'priorityAfter',
  );
  @override
  late final GeneratedColumn<String> priorityAfter = GeneratedColumn<String>(
    'priority_after',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pressureBeforeMeta = const VerificationMeta(
    'pressureBefore',
  );
  @override
  late final GeneratedColumn<double> pressureBefore = GeneratedColumn<double>(
    'pressure_before',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pressureAfterMeta = const VerificationMeta(
    'pressureAfter',
  );
  @override
  late final GeneratedColumn<double> pressureAfter = GeneratedColumn<double>(
    'pressure_after',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readFractionBeforeMeta =
      const VerificationMeta('readFractionBefore');
  @override
  late final GeneratedColumn<double> readFractionBefore =
      GeneratedColumn<double>(
        'read_fraction_before',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _readFractionAfterMeta = const VerificationMeta(
    'readFractionAfter',
  );
  @override
  late final GeneratedColumn<double> readFractionAfter =
      GeneratedColumn<double>(
        'read_fraction_after',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lifecycleBeforeMeta = const VerificationMeta(
    'lifecycleBefore',
  );
  @override
  late final GeneratedColumn<int> lifecycleBefore = GeneratedColumn<int>(
    'lifecycle_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lifecycleAfterMeta = const VerificationMeta(
    'lifecycleAfter',
  );
  @override
  late final GeneratedColumn<int> lifecycleAfter = GeneratedColumn<int>(
    'lifecycle_after',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parametersVersionMeta = const VerificationMeta(
    'parametersVersion',
  );
  @override
  late final GeneratedColumn<String> parametersVersion =
      GeneratedColumn<String>(
        'parameters_version',
        aliasedName,
        true,
        type: DriftSqlType.string,
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
    eventType,
    atUtc,
    grade,
    elapsedDays,
    scheduledDays,
    durationMs,
    postponeCount,
    dueBeforeUtc,
    dueAfterUtc,
    intervalBefore,
    intervalAfter,
    aFactorBefore,
    aFactorAfter,
    stabilityBefore,
    stabilityAfter,
    difficultyBefore,
    difficultyAfter,
    stateBefore,
    stateAfter,
    repsBefore,
    lapsesBefore,
    priorityBefore,
    priorityAfter,
    pressureBefore,
    pressureAfter,
    readFractionBefore,
    readFractionAfter,
    lifecycleBefore,
    lifecycleAfter,
    schedulerVersion,
    parametersVersion,
    metadataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'revlog_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<RevlogRow> instance, {
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
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('at_utc')) {
      context.handle(
        _atUtcMeta,
        atUtc.isAcceptableOrUnknown(data['at_utc']!, _atUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_atUtcMeta);
    }
    if (data.containsKey('grade')) {
      context.handle(
        _gradeMeta,
        grade.isAcceptableOrUnknown(data['grade']!, _gradeMeta),
      );
    }
    if (data.containsKey('elapsed_days')) {
      context.handle(
        _elapsedDaysMeta,
        elapsedDays.isAcceptableOrUnknown(
          data['elapsed_days']!,
          _elapsedDaysMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_days')) {
      context.handle(
        _scheduledDaysMeta,
        scheduledDays.isAcceptableOrUnknown(
          data['scheduled_days']!,
          _scheduledDaysMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('postpone_count')) {
      context.handle(
        _postponeCountMeta,
        postponeCount.isAcceptableOrUnknown(
          data['postpone_count']!,
          _postponeCountMeta,
        ),
      );
    }
    if (data.containsKey('due_before_utc')) {
      context.handle(
        _dueBeforeUtcMeta,
        dueBeforeUtc.isAcceptableOrUnknown(
          data['due_before_utc']!,
          _dueBeforeUtcMeta,
        ),
      );
    }
    if (data.containsKey('due_after_utc')) {
      context.handle(
        _dueAfterUtcMeta,
        dueAfterUtc.isAcceptableOrUnknown(
          data['due_after_utc']!,
          _dueAfterUtcMeta,
        ),
      );
    }
    if (data.containsKey('interval_before')) {
      context.handle(
        _intervalBeforeMeta,
        intervalBefore.isAcceptableOrUnknown(
          data['interval_before']!,
          _intervalBeforeMeta,
        ),
      );
    }
    if (data.containsKey('interval_after')) {
      context.handle(
        _intervalAfterMeta,
        intervalAfter.isAcceptableOrUnknown(
          data['interval_after']!,
          _intervalAfterMeta,
        ),
      );
    }
    if (data.containsKey('a_factor_before')) {
      context.handle(
        _aFactorBeforeMeta,
        aFactorBefore.isAcceptableOrUnknown(
          data['a_factor_before']!,
          _aFactorBeforeMeta,
        ),
      );
    }
    if (data.containsKey('a_factor_after')) {
      context.handle(
        _aFactorAfterMeta,
        aFactorAfter.isAcceptableOrUnknown(
          data['a_factor_after']!,
          _aFactorAfterMeta,
        ),
      );
    }
    if (data.containsKey('stability_before')) {
      context.handle(
        _stabilityBeforeMeta,
        stabilityBefore.isAcceptableOrUnknown(
          data['stability_before']!,
          _stabilityBeforeMeta,
        ),
      );
    }
    if (data.containsKey('stability_after')) {
      context.handle(
        _stabilityAfterMeta,
        stabilityAfter.isAcceptableOrUnknown(
          data['stability_after']!,
          _stabilityAfterMeta,
        ),
      );
    }
    if (data.containsKey('difficulty_before')) {
      context.handle(
        _difficultyBeforeMeta,
        difficultyBefore.isAcceptableOrUnknown(
          data['difficulty_before']!,
          _difficultyBeforeMeta,
        ),
      );
    }
    if (data.containsKey('difficulty_after')) {
      context.handle(
        _difficultyAfterMeta,
        difficultyAfter.isAcceptableOrUnknown(
          data['difficulty_after']!,
          _difficultyAfterMeta,
        ),
      );
    }
    if (data.containsKey('state_before')) {
      context.handle(
        _stateBeforeMeta,
        stateBefore.isAcceptableOrUnknown(
          data['state_before']!,
          _stateBeforeMeta,
        ),
      );
    }
    if (data.containsKey('state_after')) {
      context.handle(
        _stateAfterMeta,
        stateAfter.isAcceptableOrUnknown(data['state_after']!, _stateAfterMeta),
      );
    }
    if (data.containsKey('reps_before')) {
      context.handle(
        _repsBeforeMeta,
        repsBefore.isAcceptableOrUnknown(data['reps_before']!, _repsBeforeMeta),
      );
    }
    if (data.containsKey('lapses_before')) {
      context.handle(
        _lapsesBeforeMeta,
        lapsesBefore.isAcceptableOrUnknown(
          data['lapses_before']!,
          _lapsesBeforeMeta,
        ),
      );
    }
    if (data.containsKey('priority_before')) {
      context.handle(
        _priorityBeforeMeta,
        priorityBefore.isAcceptableOrUnknown(
          data['priority_before']!,
          _priorityBeforeMeta,
        ),
      );
    }
    if (data.containsKey('priority_after')) {
      context.handle(
        _priorityAfterMeta,
        priorityAfter.isAcceptableOrUnknown(
          data['priority_after']!,
          _priorityAfterMeta,
        ),
      );
    }
    if (data.containsKey('pressure_before')) {
      context.handle(
        _pressureBeforeMeta,
        pressureBefore.isAcceptableOrUnknown(
          data['pressure_before']!,
          _pressureBeforeMeta,
        ),
      );
    }
    if (data.containsKey('pressure_after')) {
      context.handle(
        _pressureAfterMeta,
        pressureAfter.isAcceptableOrUnknown(
          data['pressure_after']!,
          _pressureAfterMeta,
        ),
      );
    }
    if (data.containsKey('read_fraction_before')) {
      context.handle(
        _readFractionBeforeMeta,
        readFractionBefore.isAcceptableOrUnknown(
          data['read_fraction_before']!,
          _readFractionBeforeMeta,
        ),
      );
    }
    if (data.containsKey('read_fraction_after')) {
      context.handle(
        _readFractionAfterMeta,
        readFractionAfter.isAcceptableOrUnknown(
          data['read_fraction_after']!,
          _readFractionAfterMeta,
        ),
      );
    }
    if (data.containsKey('lifecycle_before')) {
      context.handle(
        _lifecycleBeforeMeta,
        lifecycleBefore.isAcceptableOrUnknown(
          data['lifecycle_before']!,
          _lifecycleBeforeMeta,
        ),
      );
    }
    if (data.containsKey('lifecycle_after')) {
      context.handle(
        _lifecycleAfterMeta,
        lifecycleAfter.isAcceptableOrUnknown(
          data['lifecycle_after']!,
          _lifecycleAfterMeta,
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
    }
    if (data.containsKey('parameters_version')) {
      context.handle(
        _parametersVersionMeta,
        parametersVersion.isAcceptableOrUnknown(
          data['parameters_version']!,
          _parametersVersionMeta,
        ),
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
  RevlogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RevlogRow(
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
      )!,
      elementType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}element_type'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_type'],
      )!,
      atUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_utc'],
      )!,
      grade: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grade'],
      ),
      elapsedDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}elapsed_days'],
      ),
      scheduledDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}scheduled_days'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      postponeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}postpone_count'],
      ),
      dueBeforeUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_before_utc'],
      ),
      dueAfterUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_after_utc'],
      ),
      intervalBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}interval_before'],
      ),
      intervalAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}interval_after'],
      ),
      aFactorBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}a_factor_before'],
      ),
      aFactorAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}a_factor_after'],
      ),
      stabilityBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability_before'],
      ),
      stabilityAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability_after'],
      ),
      difficultyBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty_before'],
      ),
      difficultyAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty_after'],
      ),
      stateBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}state_before'],
      ),
      stateAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}state_after'],
      ),
      repsBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps_before'],
      ),
      lapsesBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses_before'],
      ),
      priorityBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority_before'],
      ),
      priorityAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority_after'],
      ),
      pressureBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pressure_before'],
      ),
      pressureAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pressure_after'],
      ),
      readFractionBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}read_fraction_before'],
      ),
      readFractionAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}read_fraction_after'],
      ),
      lifecycleBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lifecycle_before'],
      ),
      lifecycleAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lifecycle_after'],
      ),
      schedulerVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduler_version'],
      ),
      parametersVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameters_version'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
    );
  }

  @override
  $RevlogEntriesTable createAlias(String alias) {
    return $RevlogEntriesTable(attachedDatabase, alias);
  }
}

class RevlogRow extends DataClass implements Insertable<RevlogRow> {
  final String id;
  final String operationId;
  final String elementId;
  final int elementType;

  /// Stable `RevlogEventType` value. Never the enum index.
  final int eventType;
  final int atUtc;

  /// 1–4 on review and practice rows, null everywhere else. A postpone has no
  /// grade because it was never a retention test.
  final int? grade;

  /// Days that actually passed since the previous repetition.
  final double? elapsedDays;

  /// Days the interval had been set to. The gap between this and
  /// [elapsedDays] is the signal an optimizer needs.
  final double? scheduledDays;
  final int? durationMs;
  final int? postponeCount;
  final int? dueBeforeUtc;
  final int? dueAfterUtc;
  final double? intervalBefore;
  final double? intervalAfter;
  final double? aFactorBefore;
  final double? aFactorAfter;
  final double? stabilityBefore;
  final double? stabilityAfter;
  final double? difficultyBefore;
  final double? difficultyAfter;
  final int? stateBefore;
  final int? stateAfter;
  final int? repsBefore;
  final int? lapsesBefore;
  final String? priorityBefore;
  final String? priorityAfter;

  /// Priority pressure at the moment of the event, stored rather than
  /// recomputed: the collection's order moves, and what mattered to the
  /// decision is where the element stood then.
  final double? pressureBefore;
  final double? pressureAfter;
  final double? readFractionBefore;
  final double? readFractionAfter;
  final int? lifecycleBefore;
  final int? lifecycleAfter;
  final String? schedulerVersion;
  final String? parametersVersion;

  /// Free-form detail: the A-factor's terms, a delay formula's inputs, the
  /// cap that triggered a deferral. Never element content.
  final String? metadataJson;
  const RevlogRow({
    required this.id,
    required this.operationId,
    required this.elementId,
    required this.elementType,
    required this.eventType,
    required this.atUtc,
    this.grade,
    this.elapsedDays,
    this.scheduledDays,
    this.durationMs,
    this.postponeCount,
    this.dueBeforeUtc,
    this.dueAfterUtc,
    this.intervalBefore,
    this.intervalAfter,
    this.aFactorBefore,
    this.aFactorAfter,
    this.stabilityBefore,
    this.stabilityAfter,
    this.difficultyBefore,
    this.difficultyAfter,
    this.stateBefore,
    this.stateAfter,
    this.repsBefore,
    this.lapsesBefore,
    this.priorityBefore,
    this.priorityAfter,
    this.pressureBefore,
    this.pressureAfter,
    this.readFractionBefore,
    this.readFractionAfter,
    this.lifecycleBefore,
    this.lifecycleAfter,
    this.schedulerVersion,
    this.parametersVersion,
    this.metadataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['operation_id'] = Variable<String>(operationId);
    map['element_id'] = Variable<String>(elementId);
    map['element_type'] = Variable<int>(elementType);
    map['event_type'] = Variable<int>(eventType);
    map['at_utc'] = Variable<int>(atUtc);
    if (!nullToAbsent || grade != null) {
      map['grade'] = Variable<int>(grade);
    }
    if (!nullToAbsent || elapsedDays != null) {
      map['elapsed_days'] = Variable<double>(elapsedDays);
    }
    if (!nullToAbsent || scheduledDays != null) {
      map['scheduled_days'] = Variable<double>(scheduledDays);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || postponeCount != null) {
      map['postpone_count'] = Variable<int>(postponeCount);
    }
    if (!nullToAbsent || dueBeforeUtc != null) {
      map['due_before_utc'] = Variable<int>(dueBeforeUtc);
    }
    if (!nullToAbsent || dueAfterUtc != null) {
      map['due_after_utc'] = Variable<int>(dueAfterUtc);
    }
    if (!nullToAbsent || intervalBefore != null) {
      map['interval_before'] = Variable<double>(intervalBefore);
    }
    if (!nullToAbsent || intervalAfter != null) {
      map['interval_after'] = Variable<double>(intervalAfter);
    }
    if (!nullToAbsent || aFactorBefore != null) {
      map['a_factor_before'] = Variable<double>(aFactorBefore);
    }
    if (!nullToAbsent || aFactorAfter != null) {
      map['a_factor_after'] = Variable<double>(aFactorAfter);
    }
    if (!nullToAbsent || stabilityBefore != null) {
      map['stability_before'] = Variable<double>(stabilityBefore);
    }
    if (!nullToAbsent || stabilityAfter != null) {
      map['stability_after'] = Variable<double>(stabilityAfter);
    }
    if (!nullToAbsent || difficultyBefore != null) {
      map['difficulty_before'] = Variable<double>(difficultyBefore);
    }
    if (!nullToAbsent || difficultyAfter != null) {
      map['difficulty_after'] = Variable<double>(difficultyAfter);
    }
    if (!nullToAbsent || stateBefore != null) {
      map['state_before'] = Variable<int>(stateBefore);
    }
    if (!nullToAbsent || stateAfter != null) {
      map['state_after'] = Variable<int>(stateAfter);
    }
    if (!nullToAbsent || repsBefore != null) {
      map['reps_before'] = Variable<int>(repsBefore);
    }
    if (!nullToAbsent || lapsesBefore != null) {
      map['lapses_before'] = Variable<int>(lapsesBefore);
    }
    if (!nullToAbsent || priorityBefore != null) {
      map['priority_before'] = Variable<String>(priorityBefore);
    }
    if (!nullToAbsent || priorityAfter != null) {
      map['priority_after'] = Variable<String>(priorityAfter);
    }
    if (!nullToAbsent || pressureBefore != null) {
      map['pressure_before'] = Variable<double>(pressureBefore);
    }
    if (!nullToAbsent || pressureAfter != null) {
      map['pressure_after'] = Variable<double>(pressureAfter);
    }
    if (!nullToAbsent || readFractionBefore != null) {
      map['read_fraction_before'] = Variable<double>(readFractionBefore);
    }
    if (!nullToAbsent || readFractionAfter != null) {
      map['read_fraction_after'] = Variable<double>(readFractionAfter);
    }
    if (!nullToAbsent || lifecycleBefore != null) {
      map['lifecycle_before'] = Variable<int>(lifecycleBefore);
    }
    if (!nullToAbsent || lifecycleAfter != null) {
      map['lifecycle_after'] = Variable<int>(lifecycleAfter);
    }
    if (!nullToAbsent || schedulerVersion != null) {
      map['scheduler_version'] = Variable<String>(schedulerVersion);
    }
    if (!nullToAbsent || parametersVersion != null) {
      map['parameters_version'] = Variable<String>(parametersVersion);
    }
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    return map;
  }

  RevlogEntriesCompanion toCompanion(bool nullToAbsent) {
    return RevlogEntriesCompanion(
      id: Value(id),
      operationId: Value(operationId),
      elementId: Value(elementId),
      elementType: Value(elementType),
      eventType: Value(eventType),
      atUtc: Value(atUtc),
      grade: grade == null && nullToAbsent
          ? const Value.absent()
          : Value(grade),
      elapsedDays: elapsedDays == null && nullToAbsent
          ? const Value.absent()
          : Value(elapsedDays),
      scheduledDays: scheduledDays == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledDays),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      postponeCount: postponeCount == null && nullToAbsent
          ? const Value.absent()
          : Value(postponeCount),
      dueBeforeUtc: dueBeforeUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(dueBeforeUtc),
      dueAfterUtc: dueAfterUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAfterUtc),
      intervalBefore: intervalBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(intervalBefore),
      intervalAfter: intervalAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(intervalAfter),
      aFactorBefore: aFactorBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(aFactorBefore),
      aFactorAfter: aFactorAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(aFactorAfter),
      stabilityBefore: stabilityBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(stabilityBefore),
      stabilityAfter: stabilityAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(stabilityAfter),
      difficultyBefore: difficultyBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(difficultyBefore),
      difficultyAfter: difficultyAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(difficultyAfter),
      stateBefore: stateBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(stateBefore),
      stateAfter: stateAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(stateAfter),
      repsBefore: repsBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(repsBefore),
      lapsesBefore: lapsesBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(lapsesBefore),
      priorityBefore: priorityBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(priorityBefore),
      priorityAfter: priorityAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(priorityAfter),
      pressureBefore: pressureBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(pressureBefore),
      pressureAfter: pressureAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(pressureAfter),
      readFractionBefore: readFractionBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(readFractionBefore),
      readFractionAfter: readFractionAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(readFractionAfter),
      lifecycleBefore: lifecycleBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(lifecycleBefore),
      lifecycleAfter: lifecycleAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(lifecycleAfter),
      schedulerVersion: schedulerVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(schedulerVersion),
      parametersVersion: parametersVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(parametersVersion),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
    );
  }

  factory RevlogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RevlogRow(
      id: serializer.fromJson<String>(json['id']),
      operationId: serializer.fromJson<String>(json['operationId']),
      elementId: serializer.fromJson<String>(json['elementId']),
      elementType: serializer.fromJson<int>(json['elementType']),
      eventType: serializer.fromJson<int>(json['eventType']),
      atUtc: serializer.fromJson<int>(json['atUtc']),
      grade: serializer.fromJson<int?>(json['grade']),
      elapsedDays: serializer.fromJson<double?>(json['elapsedDays']),
      scheduledDays: serializer.fromJson<double?>(json['scheduledDays']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      postponeCount: serializer.fromJson<int?>(json['postponeCount']),
      dueBeforeUtc: serializer.fromJson<int?>(json['dueBeforeUtc']),
      dueAfterUtc: serializer.fromJson<int?>(json['dueAfterUtc']),
      intervalBefore: serializer.fromJson<double?>(json['intervalBefore']),
      intervalAfter: serializer.fromJson<double?>(json['intervalAfter']),
      aFactorBefore: serializer.fromJson<double?>(json['aFactorBefore']),
      aFactorAfter: serializer.fromJson<double?>(json['aFactorAfter']),
      stabilityBefore: serializer.fromJson<double?>(json['stabilityBefore']),
      stabilityAfter: serializer.fromJson<double?>(json['stabilityAfter']),
      difficultyBefore: serializer.fromJson<double?>(json['difficultyBefore']),
      difficultyAfter: serializer.fromJson<double?>(json['difficultyAfter']),
      stateBefore: serializer.fromJson<int?>(json['stateBefore']),
      stateAfter: serializer.fromJson<int?>(json['stateAfter']),
      repsBefore: serializer.fromJson<int?>(json['repsBefore']),
      lapsesBefore: serializer.fromJson<int?>(json['lapsesBefore']),
      priorityBefore: serializer.fromJson<String?>(json['priorityBefore']),
      priorityAfter: serializer.fromJson<String?>(json['priorityAfter']),
      pressureBefore: serializer.fromJson<double?>(json['pressureBefore']),
      pressureAfter: serializer.fromJson<double?>(json['pressureAfter']),
      readFractionBefore: serializer.fromJson<double?>(
        json['readFractionBefore'],
      ),
      readFractionAfter: serializer.fromJson<double?>(
        json['readFractionAfter'],
      ),
      lifecycleBefore: serializer.fromJson<int?>(json['lifecycleBefore']),
      lifecycleAfter: serializer.fromJson<int?>(json['lifecycleAfter']),
      schedulerVersion: serializer.fromJson<String?>(json['schedulerVersion']),
      parametersVersion: serializer.fromJson<String?>(
        json['parametersVersion'],
      ),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'operationId': serializer.toJson<String>(operationId),
      'elementId': serializer.toJson<String>(elementId),
      'elementType': serializer.toJson<int>(elementType),
      'eventType': serializer.toJson<int>(eventType),
      'atUtc': serializer.toJson<int>(atUtc),
      'grade': serializer.toJson<int?>(grade),
      'elapsedDays': serializer.toJson<double?>(elapsedDays),
      'scheduledDays': serializer.toJson<double?>(scheduledDays),
      'durationMs': serializer.toJson<int?>(durationMs),
      'postponeCount': serializer.toJson<int?>(postponeCount),
      'dueBeforeUtc': serializer.toJson<int?>(dueBeforeUtc),
      'dueAfterUtc': serializer.toJson<int?>(dueAfterUtc),
      'intervalBefore': serializer.toJson<double?>(intervalBefore),
      'intervalAfter': serializer.toJson<double?>(intervalAfter),
      'aFactorBefore': serializer.toJson<double?>(aFactorBefore),
      'aFactorAfter': serializer.toJson<double?>(aFactorAfter),
      'stabilityBefore': serializer.toJson<double?>(stabilityBefore),
      'stabilityAfter': serializer.toJson<double?>(stabilityAfter),
      'difficultyBefore': serializer.toJson<double?>(difficultyBefore),
      'difficultyAfter': serializer.toJson<double?>(difficultyAfter),
      'stateBefore': serializer.toJson<int?>(stateBefore),
      'stateAfter': serializer.toJson<int?>(stateAfter),
      'repsBefore': serializer.toJson<int?>(repsBefore),
      'lapsesBefore': serializer.toJson<int?>(lapsesBefore),
      'priorityBefore': serializer.toJson<String?>(priorityBefore),
      'priorityAfter': serializer.toJson<String?>(priorityAfter),
      'pressureBefore': serializer.toJson<double?>(pressureBefore),
      'pressureAfter': serializer.toJson<double?>(pressureAfter),
      'readFractionBefore': serializer.toJson<double?>(readFractionBefore),
      'readFractionAfter': serializer.toJson<double?>(readFractionAfter),
      'lifecycleBefore': serializer.toJson<int?>(lifecycleBefore),
      'lifecycleAfter': serializer.toJson<int?>(lifecycleAfter),
      'schedulerVersion': serializer.toJson<String?>(schedulerVersion),
      'parametersVersion': serializer.toJson<String?>(parametersVersion),
      'metadataJson': serializer.toJson<String?>(metadataJson),
    };
  }

  RevlogRow copyWith({
    String? id,
    String? operationId,
    String? elementId,
    int? elementType,
    int? eventType,
    int? atUtc,
    Value<int?> grade = const Value.absent(),
    Value<double?> elapsedDays = const Value.absent(),
    Value<double?> scheduledDays = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<int?> postponeCount = const Value.absent(),
    Value<int?> dueBeforeUtc = const Value.absent(),
    Value<int?> dueAfterUtc = const Value.absent(),
    Value<double?> intervalBefore = const Value.absent(),
    Value<double?> intervalAfter = const Value.absent(),
    Value<double?> aFactorBefore = const Value.absent(),
    Value<double?> aFactorAfter = const Value.absent(),
    Value<double?> stabilityBefore = const Value.absent(),
    Value<double?> stabilityAfter = const Value.absent(),
    Value<double?> difficultyBefore = const Value.absent(),
    Value<double?> difficultyAfter = const Value.absent(),
    Value<int?> stateBefore = const Value.absent(),
    Value<int?> stateAfter = const Value.absent(),
    Value<int?> repsBefore = const Value.absent(),
    Value<int?> lapsesBefore = const Value.absent(),
    Value<String?> priorityBefore = const Value.absent(),
    Value<String?> priorityAfter = const Value.absent(),
    Value<double?> pressureBefore = const Value.absent(),
    Value<double?> pressureAfter = const Value.absent(),
    Value<double?> readFractionBefore = const Value.absent(),
    Value<double?> readFractionAfter = const Value.absent(),
    Value<int?> lifecycleBefore = const Value.absent(),
    Value<int?> lifecycleAfter = const Value.absent(),
    Value<String?> schedulerVersion = const Value.absent(),
    Value<String?> parametersVersion = const Value.absent(),
    Value<String?> metadataJson = const Value.absent(),
  }) => RevlogRow(
    id: id ?? this.id,
    operationId: operationId ?? this.operationId,
    elementId: elementId ?? this.elementId,
    elementType: elementType ?? this.elementType,
    eventType: eventType ?? this.eventType,
    atUtc: atUtc ?? this.atUtc,
    grade: grade.present ? grade.value : this.grade,
    elapsedDays: elapsedDays.present ? elapsedDays.value : this.elapsedDays,
    scheduledDays: scheduledDays.present
        ? scheduledDays.value
        : this.scheduledDays,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    postponeCount: postponeCount.present
        ? postponeCount.value
        : this.postponeCount,
    dueBeforeUtc: dueBeforeUtc.present ? dueBeforeUtc.value : this.dueBeforeUtc,
    dueAfterUtc: dueAfterUtc.present ? dueAfterUtc.value : this.dueAfterUtc,
    intervalBefore: intervalBefore.present
        ? intervalBefore.value
        : this.intervalBefore,
    intervalAfter: intervalAfter.present
        ? intervalAfter.value
        : this.intervalAfter,
    aFactorBefore: aFactorBefore.present
        ? aFactorBefore.value
        : this.aFactorBefore,
    aFactorAfter: aFactorAfter.present ? aFactorAfter.value : this.aFactorAfter,
    stabilityBefore: stabilityBefore.present
        ? stabilityBefore.value
        : this.stabilityBefore,
    stabilityAfter: stabilityAfter.present
        ? stabilityAfter.value
        : this.stabilityAfter,
    difficultyBefore: difficultyBefore.present
        ? difficultyBefore.value
        : this.difficultyBefore,
    difficultyAfter: difficultyAfter.present
        ? difficultyAfter.value
        : this.difficultyAfter,
    stateBefore: stateBefore.present ? stateBefore.value : this.stateBefore,
    stateAfter: stateAfter.present ? stateAfter.value : this.stateAfter,
    repsBefore: repsBefore.present ? repsBefore.value : this.repsBefore,
    lapsesBefore: lapsesBefore.present ? lapsesBefore.value : this.lapsesBefore,
    priorityBefore: priorityBefore.present
        ? priorityBefore.value
        : this.priorityBefore,
    priorityAfter: priorityAfter.present
        ? priorityAfter.value
        : this.priorityAfter,
    pressureBefore: pressureBefore.present
        ? pressureBefore.value
        : this.pressureBefore,
    pressureAfter: pressureAfter.present
        ? pressureAfter.value
        : this.pressureAfter,
    readFractionBefore: readFractionBefore.present
        ? readFractionBefore.value
        : this.readFractionBefore,
    readFractionAfter: readFractionAfter.present
        ? readFractionAfter.value
        : this.readFractionAfter,
    lifecycleBefore: lifecycleBefore.present
        ? lifecycleBefore.value
        : this.lifecycleBefore,
    lifecycleAfter: lifecycleAfter.present
        ? lifecycleAfter.value
        : this.lifecycleAfter,
    schedulerVersion: schedulerVersion.present
        ? schedulerVersion.value
        : this.schedulerVersion,
    parametersVersion: parametersVersion.present
        ? parametersVersion.value
        : this.parametersVersion,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
  );
  RevlogRow copyWithCompanion(RevlogEntriesCompanion data) {
    return RevlogRow(
      id: data.id.present ? data.id.value : this.id,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      elementId: data.elementId.present ? data.elementId.value : this.elementId,
      elementType: data.elementType.present
          ? data.elementType.value
          : this.elementType,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      atUtc: data.atUtc.present ? data.atUtc.value : this.atUtc,
      grade: data.grade.present ? data.grade.value : this.grade,
      elapsedDays: data.elapsedDays.present
          ? data.elapsedDays.value
          : this.elapsedDays,
      scheduledDays: data.scheduledDays.present
          ? data.scheduledDays.value
          : this.scheduledDays,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      postponeCount: data.postponeCount.present
          ? data.postponeCount.value
          : this.postponeCount,
      dueBeforeUtc: data.dueBeforeUtc.present
          ? data.dueBeforeUtc.value
          : this.dueBeforeUtc,
      dueAfterUtc: data.dueAfterUtc.present
          ? data.dueAfterUtc.value
          : this.dueAfterUtc,
      intervalBefore: data.intervalBefore.present
          ? data.intervalBefore.value
          : this.intervalBefore,
      intervalAfter: data.intervalAfter.present
          ? data.intervalAfter.value
          : this.intervalAfter,
      aFactorBefore: data.aFactorBefore.present
          ? data.aFactorBefore.value
          : this.aFactorBefore,
      aFactorAfter: data.aFactorAfter.present
          ? data.aFactorAfter.value
          : this.aFactorAfter,
      stabilityBefore: data.stabilityBefore.present
          ? data.stabilityBefore.value
          : this.stabilityBefore,
      stabilityAfter: data.stabilityAfter.present
          ? data.stabilityAfter.value
          : this.stabilityAfter,
      difficultyBefore: data.difficultyBefore.present
          ? data.difficultyBefore.value
          : this.difficultyBefore,
      difficultyAfter: data.difficultyAfter.present
          ? data.difficultyAfter.value
          : this.difficultyAfter,
      stateBefore: data.stateBefore.present
          ? data.stateBefore.value
          : this.stateBefore,
      stateAfter: data.stateAfter.present
          ? data.stateAfter.value
          : this.stateAfter,
      repsBefore: data.repsBefore.present
          ? data.repsBefore.value
          : this.repsBefore,
      lapsesBefore: data.lapsesBefore.present
          ? data.lapsesBefore.value
          : this.lapsesBefore,
      priorityBefore: data.priorityBefore.present
          ? data.priorityBefore.value
          : this.priorityBefore,
      priorityAfter: data.priorityAfter.present
          ? data.priorityAfter.value
          : this.priorityAfter,
      pressureBefore: data.pressureBefore.present
          ? data.pressureBefore.value
          : this.pressureBefore,
      pressureAfter: data.pressureAfter.present
          ? data.pressureAfter.value
          : this.pressureAfter,
      readFractionBefore: data.readFractionBefore.present
          ? data.readFractionBefore.value
          : this.readFractionBefore,
      readFractionAfter: data.readFractionAfter.present
          ? data.readFractionAfter.value
          : this.readFractionAfter,
      lifecycleBefore: data.lifecycleBefore.present
          ? data.lifecycleBefore.value
          : this.lifecycleBefore,
      lifecycleAfter: data.lifecycleAfter.present
          ? data.lifecycleAfter.value
          : this.lifecycleAfter,
      schedulerVersion: data.schedulerVersion.present
          ? data.schedulerVersion.value
          : this.schedulerVersion,
      parametersVersion: data.parametersVersion.present
          ? data.parametersVersion.value
          : this.parametersVersion,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RevlogRow(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('eventType: $eventType, ')
          ..write('atUtc: $atUtc, ')
          ..write('grade: $grade, ')
          ..write('elapsedDays: $elapsedDays, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('durationMs: $durationMs, ')
          ..write('postponeCount: $postponeCount, ')
          ..write('dueBeforeUtc: $dueBeforeUtc, ')
          ..write('dueAfterUtc: $dueAfterUtc, ')
          ..write('intervalBefore: $intervalBefore, ')
          ..write('intervalAfter: $intervalAfter, ')
          ..write('aFactorBefore: $aFactorBefore, ')
          ..write('aFactorAfter: $aFactorAfter, ')
          ..write('stabilityBefore: $stabilityBefore, ')
          ..write('stabilityAfter: $stabilityAfter, ')
          ..write('difficultyBefore: $difficultyBefore, ')
          ..write('difficultyAfter: $difficultyAfter, ')
          ..write('stateBefore: $stateBefore, ')
          ..write('stateAfter: $stateAfter, ')
          ..write('repsBefore: $repsBefore, ')
          ..write('lapsesBefore: $lapsesBefore, ')
          ..write('priorityBefore: $priorityBefore, ')
          ..write('priorityAfter: $priorityAfter, ')
          ..write('pressureBefore: $pressureBefore, ')
          ..write('pressureAfter: $pressureAfter, ')
          ..write('readFractionBefore: $readFractionBefore, ')
          ..write('readFractionAfter: $readFractionAfter, ')
          ..write('lifecycleBefore: $lifecycleBefore, ')
          ..write('lifecycleAfter: $lifecycleAfter, ')
          ..write('schedulerVersion: $schedulerVersion, ')
          ..write('parametersVersion: $parametersVersion, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    operationId,
    elementId,
    elementType,
    eventType,
    atUtc,
    grade,
    elapsedDays,
    scheduledDays,
    durationMs,
    postponeCount,
    dueBeforeUtc,
    dueAfterUtc,
    intervalBefore,
    intervalAfter,
    aFactorBefore,
    aFactorAfter,
    stabilityBefore,
    stabilityAfter,
    difficultyBefore,
    difficultyAfter,
    stateBefore,
    stateAfter,
    repsBefore,
    lapsesBefore,
    priorityBefore,
    priorityAfter,
    pressureBefore,
    pressureAfter,
    readFractionBefore,
    readFractionAfter,
    lifecycleBefore,
    lifecycleAfter,
    schedulerVersion,
    parametersVersion,
    metadataJson,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RevlogRow &&
          other.id == this.id &&
          other.operationId == this.operationId &&
          other.elementId == this.elementId &&
          other.elementType == this.elementType &&
          other.eventType == this.eventType &&
          other.atUtc == this.atUtc &&
          other.grade == this.grade &&
          other.elapsedDays == this.elapsedDays &&
          other.scheduledDays == this.scheduledDays &&
          other.durationMs == this.durationMs &&
          other.postponeCount == this.postponeCount &&
          other.dueBeforeUtc == this.dueBeforeUtc &&
          other.dueAfterUtc == this.dueAfterUtc &&
          other.intervalBefore == this.intervalBefore &&
          other.intervalAfter == this.intervalAfter &&
          other.aFactorBefore == this.aFactorBefore &&
          other.aFactorAfter == this.aFactorAfter &&
          other.stabilityBefore == this.stabilityBefore &&
          other.stabilityAfter == this.stabilityAfter &&
          other.difficultyBefore == this.difficultyBefore &&
          other.difficultyAfter == this.difficultyAfter &&
          other.stateBefore == this.stateBefore &&
          other.stateAfter == this.stateAfter &&
          other.repsBefore == this.repsBefore &&
          other.lapsesBefore == this.lapsesBefore &&
          other.priorityBefore == this.priorityBefore &&
          other.priorityAfter == this.priorityAfter &&
          other.pressureBefore == this.pressureBefore &&
          other.pressureAfter == this.pressureAfter &&
          other.readFractionBefore == this.readFractionBefore &&
          other.readFractionAfter == this.readFractionAfter &&
          other.lifecycleBefore == this.lifecycleBefore &&
          other.lifecycleAfter == this.lifecycleAfter &&
          other.schedulerVersion == this.schedulerVersion &&
          other.parametersVersion == this.parametersVersion &&
          other.metadataJson == this.metadataJson);
}

class RevlogEntriesCompanion extends UpdateCompanion<RevlogRow> {
  final Value<String> id;
  final Value<String> operationId;
  final Value<String> elementId;
  final Value<int> elementType;
  final Value<int> eventType;
  final Value<int> atUtc;
  final Value<int?> grade;
  final Value<double?> elapsedDays;
  final Value<double?> scheduledDays;
  final Value<int?> durationMs;
  final Value<int?> postponeCount;
  final Value<int?> dueBeforeUtc;
  final Value<int?> dueAfterUtc;
  final Value<double?> intervalBefore;
  final Value<double?> intervalAfter;
  final Value<double?> aFactorBefore;
  final Value<double?> aFactorAfter;
  final Value<double?> stabilityBefore;
  final Value<double?> stabilityAfter;
  final Value<double?> difficultyBefore;
  final Value<double?> difficultyAfter;
  final Value<int?> stateBefore;
  final Value<int?> stateAfter;
  final Value<int?> repsBefore;
  final Value<int?> lapsesBefore;
  final Value<String?> priorityBefore;
  final Value<String?> priorityAfter;
  final Value<double?> pressureBefore;
  final Value<double?> pressureAfter;
  final Value<double?> readFractionBefore;
  final Value<double?> readFractionAfter;
  final Value<int?> lifecycleBefore;
  final Value<int?> lifecycleAfter;
  final Value<String?> schedulerVersion;
  final Value<String?> parametersVersion;
  final Value<String?> metadataJson;
  final Value<int> rowid;
  const RevlogEntriesCompanion({
    this.id = const Value.absent(),
    this.operationId = const Value.absent(),
    this.elementId = const Value.absent(),
    this.elementType = const Value.absent(),
    this.eventType = const Value.absent(),
    this.atUtc = const Value.absent(),
    this.grade = const Value.absent(),
    this.elapsedDays = const Value.absent(),
    this.scheduledDays = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.postponeCount = const Value.absent(),
    this.dueBeforeUtc = const Value.absent(),
    this.dueAfterUtc = const Value.absent(),
    this.intervalBefore = const Value.absent(),
    this.intervalAfter = const Value.absent(),
    this.aFactorBefore = const Value.absent(),
    this.aFactorAfter = const Value.absent(),
    this.stabilityBefore = const Value.absent(),
    this.stabilityAfter = const Value.absent(),
    this.difficultyBefore = const Value.absent(),
    this.difficultyAfter = const Value.absent(),
    this.stateBefore = const Value.absent(),
    this.stateAfter = const Value.absent(),
    this.repsBefore = const Value.absent(),
    this.lapsesBefore = const Value.absent(),
    this.priorityBefore = const Value.absent(),
    this.priorityAfter = const Value.absent(),
    this.pressureBefore = const Value.absent(),
    this.pressureAfter = const Value.absent(),
    this.readFractionBefore = const Value.absent(),
    this.readFractionAfter = const Value.absent(),
    this.lifecycleBefore = const Value.absent(),
    this.lifecycleAfter = const Value.absent(),
    this.schedulerVersion = const Value.absent(),
    this.parametersVersion = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RevlogEntriesCompanion.insert({
    required String id,
    required String operationId,
    required String elementId,
    required int elementType,
    required int eventType,
    required int atUtc,
    this.grade = const Value.absent(),
    this.elapsedDays = const Value.absent(),
    this.scheduledDays = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.postponeCount = const Value.absent(),
    this.dueBeforeUtc = const Value.absent(),
    this.dueAfterUtc = const Value.absent(),
    this.intervalBefore = const Value.absent(),
    this.intervalAfter = const Value.absent(),
    this.aFactorBefore = const Value.absent(),
    this.aFactorAfter = const Value.absent(),
    this.stabilityBefore = const Value.absent(),
    this.stabilityAfter = const Value.absent(),
    this.difficultyBefore = const Value.absent(),
    this.difficultyAfter = const Value.absent(),
    this.stateBefore = const Value.absent(),
    this.stateAfter = const Value.absent(),
    this.repsBefore = const Value.absent(),
    this.lapsesBefore = const Value.absent(),
    this.priorityBefore = const Value.absent(),
    this.priorityAfter = const Value.absent(),
    this.pressureBefore = const Value.absent(),
    this.pressureAfter = const Value.absent(),
    this.readFractionBefore = const Value.absent(),
    this.readFractionAfter = const Value.absent(),
    this.lifecycleBefore = const Value.absent(),
    this.lifecycleAfter = const Value.absent(),
    this.schedulerVersion = const Value.absent(),
    this.parametersVersion = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       operationId = Value(operationId),
       elementId = Value(elementId),
       elementType = Value(elementType),
       eventType = Value(eventType),
       atUtc = Value(atUtc);
  static Insertable<RevlogRow> custom({
    Expression<String>? id,
    Expression<String>? operationId,
    Expression<String>? elementId,
    Expression<int>? elementType,
    Expression<int>? eventType,
    Expression<int>? atUtc,
    Expression<int>? grade,
    Expression<double>? elapsedDays,
    Expression<double>? scheduledDays,
    Expression<int>? durationMs,
    Expression<int>? postponeCount,
    Expression<int>? dueBeforeUtc,
    Expression<int>? dueAfterUtc,
    Expression<double>? intervalBefore,
    Expression<double>? intervalAfter,
    Expression<double>? aFactorBefore,
    Expression<double>? aFactorAfter,
    Expression<double>? stabilityBefore,
    Expression<double>? stabilityAfter,
    Expression<double>? difficultyBefore,
    Expression<double>? difficultyAfter,
    Expression<int>? stateBefore,
    Expression<int>? stateAfter,
    Expression<int>? repsBefore,
    Expression<int>? lapsesBefore,
    Expression<String>? priorityBefore,
    Expression<String>? priorityAfter,
    Expression<double>? pressureBefore,
    Expression<double>? pressureAfter,
    Expression<double>? readFractionBefore,
    Expression<double>? readFractionAfter,
    Expression<int>? lifecycleBefore,
    Expression<int>? lifecycleAfter,
    Expression<String>? schedulerVersion,
    Expression<String>? parametersVersion,
    Expression<String>? metadataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationId != null) 'operation_id': operationId,
      if (elementId != null) 'element_id': elementId,
      if (elementType != null) 'element_type': elementType,
      if (eventType != null) 'event_type': eventType,
      if (atUtc != null) 'at_utc': atUtc,
      if (grade != null) 'grade': grade,
      if (elapsedDays != null) 'elapsed_days': elapsedDays,
      if (scheduledDays != null) 'scheduled_days': scheduledDays,
      if (durationMs != null) 'duration_ms': durationMs,
      if (postponeCount != null) 'postpone_count': postponeCount,
      if (dueBeforeUtc != null) 'due_before_utc': dueBeforeUtc,
      if (dueAfterUtc != null) 'due_after_utc': dueAfterUtc,
      if (intervalBefore != null) 'interval_before': intervalBefore,
      if (intervalAfter != null) 'interval_after': intervalAfter,
      if (aFactorBefore != null) 'a_factor_before': aFactorBefore,
      if (aFactorAfter != null) 'a_factor_after': aFactorAfter,
      if (stabilityBefore != null) 'stability_before': stabilityBefore,
      if (stabilityAfter != null) 'stability_after': stabilityAfter,
      if (difficultyBefore != null) 'difficulty_before': difficultyBefore,
      if (difficultyAfter != null) 'difficulty_after': difficultyAfter,
      if (stateBefore != null) 'state_before': stateBefore,
      if (stateAfter != null) 'state_after': stateAfter,
      if (repsBefore != null) 'reps_before': repsBefore,
      if (lapsesBefore != null) 'lapses_before': lapsesBefore,
      if (priorityBefore != null) 'priority_before': priorityBefore,
      if (priorityAfter != null) 'priority_after': priorityAfter,
      if (pressureBefore != null) 'pressure_before': pressureBefore,
      if (pressureAfter != null) 'pressure_after': pressureAfter,
      if (readFractionBefore != null)
        'read_fraction_before': readFractionBefore,
      if (readFractionAfter != null) 'read_fraction_after': readFractionAfter,
      if (lifecycleBefore != null) 'lifecycle_before': lifecycleBefore,
      if (lifecycleAfter != null) 'lifecycle_after': lifecycleAfter,
      if (schedulerVersion != null) 'scheduler_version': schedulerVersion,
      if (parametersVersion != null) 'parameters_version': parametersVersion,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RevlogEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? operationId,
    Value<String>? elementId,
    Value<int>? elementType,
    Value<int>? eventType,
    Value<int>? atUtc,
    Value<int?>? grade,
    Value<double?>? elapsedDays,
    Value<double?>? scheduledDays,
    Value<int?>? durationMs,
    Value<int?>? postponeCount,
    Value<int?>? dueBeforeUtc,
    Value<int?>? dueAfterUtc,
    Value<double?>? intervalBefore,
    Value<double?>? intervalAfter,
    Value<double?>? aFactorBefore,
    Value<double?>? aFactorAfter,
    Value<double?>? stabilityBefore,
    Value<double?>? stabilityAfter,
    Value<double?>? difficultyBefore,
    Value<double?>? difficultyAfter,
    Value<int?>? stateBefore,
    Value<int?>? stateAfter,
    Value<int?>? repsBefore,
    Value<int?>? lapsesBefore,
    Value<String?>? priorityBefore,
    Value<String?>? priorityAfter,
    Value<double?>? pressureBefore,
    Value<double?>? pressureAfter,
    Value<double?>? readFractionBefore,
    Value<double?>? readFractionAfter,
    Value<int?>? lifecycleBefore,
    Value<int?>? lifecycleAfter,
    Value<String?>? schedulerVersion,
    Value<String?>? parametersVersion,
    Value<String?>? metadataJson,
    Value<int>? rowid,
  }) {
    return RevlogEntriesCompanion(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      elementId: elementId ?? this.elementId,
      elementType: elementType ?? this.elementType,
      eventType: eventType ?? this.eventType,
      atUtc: atUtc ?? this.atUtc,
      grade: grade ?? this.grade,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      durationMs: durationMs ?? this.durationMs,
      postponeCount: postponeCount ?? this.postponeCount,
      dueBeforeUtc: dueBeforeUtc ?? this.dueBeforeUtc,
      dueAfterUtc: dueAfterUtc ?? this.dueAfterUtc,
      intervalBefore: intervalBefore ?? this.intervalBefore,
      intervalAfter: intervalAfter ?? this.intervalAfter,
      aFactorBefore: aFactorBefore ?? this.aFactorBefore,
      aFactorAfter: aFactorAfter ?? this.aFactorAfter,
      stabilityBefore: stabilityBefore ?? this.stabilityBefore,
      stabilityAfter: stabilityAfter ?? this.stabilityAfter,
      difficultyBefore: difficultyBefore ?? this.difficultyBefore,
      difficultyAfter: difficultyAfter ?? this.difficultyAfter,
      stateBefore: stateBefore ?? this.stateBefore,
      stateAfter: stateAfter ?? this.stateAfter,
      repsBefore: repsBefore ?? this.repsBefore,
      lapsesBefore: lapsesBefore ?? this.lapsesBefore,
      priorityBefore: priorityBefore ?? this.priorityBefore,
      priorityAfter: priorityAfter ?? this.priorityAfter,
      pressureBefore: pressureBefore ?? this.pressureBefore,
      pressureAfter: pressureAfter ?? this.pressureAfter,
      readFractionBefore: readFractionBefore ?? this.readFractionBefore,
      readFractionAfter: readFractionAfter ?? this.readFractionAfter,
      lifecycleBefore: lifecycleBefore ?? this.lifecycleBefore,
      lifecycleAfter: lifecycleAfter ?? this.lifecycleAfter,
      schedulerVersion: schedulerVersion ?? this.schedulerVersion,
      parametersVersion: parametersVersion ?? this.parametersVersion,
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
    if (eventType.present) {
      map['event_type'] = Variable<int>(eventType.value);
    }
    if (atUtc.present) {
      map['at_utc'] = Variable<int>(atUtc.value);
    }
    if (grade.present) {
      map['grade'] = Variable<int>(grade.value);
    }
    if (elapsedDays.present) {
      map['elapsed_days'] = Variable<double>(elapsedDays.value);
    }
    if (scheduledDays.present) {
      map['scheduled_days'] = Variable<double>(scheduledDays.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (postponeCount.present) {
      map['postpone_count'] = Variable<int>(postponeCount.value);
    }
    if (dueBeforeUtc.present) {
      map['due_before_utc'] = Variable<int>(dueBeforeUtc.value);
    }
    if (dueAfterUtc.present) {
      map['due_after_utc'] = Variable<int>(dueAfterUtc.value);
    }
    if (intervalBefore.present) {
      map['interval_before'] = Variable<double>(intervalBefore.value);
    }
    if (intervalAfter.present) {
      map['interval_after'] = Variable<double>(intervalAfter.value);
    }
    if (aFactorBefore.present) {
      map['a_factor_before'] = Variable<double>(aFactorBefore.value);
    }
    if (aFactorAfter.present) {
      map['a_factor_after'] = Variable<double>(aFactorAfter.value);
    }
    if (stabilityBefore.present) {
      map['stability_before'] = Variable<double>(stabilityBefore.value);
    }
    if (stabilityAfter.present) {
      map['stability_after'] = Variable<double>(stabilityAfter.value);
    }
    if (difficultyBefore.present) {
      map['difficulty_before'] = Variable<double>(difficultyBefore.value);
    }
    if (difficultyAfter.present) {
      map['difficulty_after'] = Variable<double>(difficultyAfter.value);
    }
    if (stateBefore.present) {
      map['state_before'] = Variable<int>(stateBefore.value);
    }
    if (stateAfter.present) {
      map['state_after'] = Variable<int>(stateAfter.value);
    }
    if (repsBefore.present) {
      map['reps_before'] = Variable<int>(repsBefore.value);
    }
    if (lapsesBefore.present) {
      map['lapses_before'] = Variable<int>(lapsesBefore.value);
    }
    if (priorityBefore.present) {
      map['priority_before'] = Variable<String>(priorityBefore.value);
    }
    if (priorityAfter.present) {
      map['priority_after'] = Variable<String>(priorityAfter.value);
    }
    if (pressureBefore.present) {
      map['pressure_before'] = Variable<double>(pressureBefore.value);
    }
    if (pressureAfter.present) {
      map['pressure_after'] = Variable<double>(pressureAfter.value);
    }
    if (readFractionBefore.present) {
      map['read_fraction_before'] = Variable<double>(readFractionBefore.value);
    }
    if (readFractionAfter.present) {
      map['read_fraction_after'] = Variable<double>(readFractionAfter.value);
    }
    if (lifecycleBefore.present) {
      map['lifecycle_before'] = Variable<int>(lifecycleBefore.value);
    }
    if (lifecycleAfter.present) {
      map['lifecycle_after'] = Variable<int>(lifecycleAfter.value);
    }
    if (schedulerVersion.present) {
      map['scheduler_version'] = Variable<String>(schedulerVersion.value);
    }
    if (parametersVersion.present) {
      map['parameters_version'] = Variable<String>(parametersVersion.value);
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
    return (StringBuffer('RevlogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('eventType: $eventType, ')
          ..write('atUtc: $atUtc, ')
          ..write('grade: $grade, ')
          ..write('elapsedDays: $elapsedDays, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('durationMs: $durationMs, ')
          ..write('postponeCount: $postponeCount, ')
          ..write('dueBeforeUtc: $dueBeforeUtc, ')
          ..write('dueAfterUtc: $dueAfterUtc, ')
          ..write('intervalBefore: $intervalBefore, ')
          ..write('intervalAfter: $intervalAfter, ')
          ..write('aFactorBefore: $aFactorBefore, ')
          ..write('aFactorAfter: $aFactorAfter, ')
          ..write('stabilityBefore: $stabilityBefore, ')
          ..write('stabilityAfter: $stabilityAfter, ')
          ..write('difficultyBefore: $difficultyBefore, ')
          ..write('difficultyAfter: $difficultyAfter, ')
          ..write('stateBefore: $stateBefore, ')
          ..write('stateAfter: $stateAfter, ')
          ..write('repsBefore: $repsBefore, ')
          ..write('lapsesBefore: $lapsesBefore, ')
          ..write('priorityBefore: $priorityBefore, ')
          ..write('priorityAfter: $priorityAfter, ')
          ..write('pressureBefore: $pressureBefore, ')
          ..write('pressureAfter: $pressureAfter, ')
          ..write('readFractionBefore: $readFractionBefore, ')
          ..write('readFractionAfter: $readFractionAfter, ')
          ..write('lifecycleBefore: $lifecycleBefore, ')
          ..write('lifecycleAfter: $lifecycleAfter, ')
          ..write('schedulerVersion: $schedulerVersion, ')
          ..write('parametersVersion: $parametersVersion, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SchedulerEventsTable extends SchedulerEvents
    with TableInfo<$SchedulerEventsTable, SchedulerEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchedulerEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtUtcMeta = const VerificationMeta(
    'occurredAtUtc',
  );
  @override
  late final GeneratedColumn<int> occurredAtUtc = GeneratedColumn<int>(
    'occurred_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studyDayMeta = const VerificationMeta(
    'studyDay',
  );
  @override
  late final GeneratedColumn<int> studyDay = GeneratedColumn<int>(
    'study_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studyDayZoneIdMeta = const VerificationMeta(
    'studyDayZoneId',
  );
  @override
  late final GeneratedColumn<String> studyDayZoneId = GeneratedColumn<String>(
    'study_day_zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schedulerNameMeta = const VerificationMeta(
    'schedulerName',
  );
  @override
  late final GeneratedColumn<String> schedulerName = GeneratedColumn<String>(
    'scheduler_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schedulerVersionMeta = const VerificationMeta(
    'schedulerVersion',
  );
  @override
  late final GeneratedColumn<String> schedulerVersion = GeneratedColumn<String>(
    'scheduler_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _policyVersionMeta = const VerificationMeta(
    'policyVersion',
  );
  @override
  late final GeneratedColumn<String> policyVersion = GeneratedColumn<String>(
    'policy_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateBeforeMeta = const VerificationMeta(
    'stateBefore',
  );
  @override
  late final GeneratedColumn<String> stateBefore = GeneratedColumn<String>(
    'state_before',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateAfterMeta = const VerificationMeta(
    'stateAfter',
  );
  @override
  late final GeneratedColumn<String> stateAfter = GeneratedColumn<String>(
    'state_after',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _algorithmicDueBeforeMeta =
      const VerificationMeta('algorithmicDueBefore');
  @override
  late final GeneratedColumn<String> algorithmicDueBefore =
      GeneratedColumn<String>(
        'algorithmic_due_before',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _algorithmicDueAfterMeta =
      const VerificationMeta('algorithmicDueAfter');
  @override
  late final GeneratedColumn<String> algorithmicDueAfter =
      GeneratedColumn<String>(
        'algorithmic_due_after',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _undoesEventIdMeta = const VerificationMeta(
    'undoesEventId',
  );
  @override
  late final GeneratedColumn<String> undoesEventId = GeneratedColumn<String>(
    'undoes_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _batchIdMeta = const VerificationMeta(
    'batchId',
  );
  @override
  late final GeneratedColumn<String> batchId = GeneratedColumn<String>(
    'batch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    eventType,
    occurredAtUtc,
    studyDay,
    studyDayZoneId,
    schedulerName,
    schedulerVersion,
    policyVersion,
    stateBefore,
    stateAfter,
    algorithmicDueBefore,
    algorithmicDueAfter,
    undoesEventId,
    batchId,
    metadataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduler_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<SchedulerEventRow> instance, {
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
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('occurred_at_utc')) {
      context.handle(
        _occurredAtUtcMeta,
        occurredAtUtc.isAcceptableOrUnknown(
          data['occurred_at_utc']!,
          _occurredAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurredAtUtcMeta);
    }
    if (data.containsKey('study_day')) {
      context.handle(
        _studyDayMeta,
        studyDay.isAcceptableOrUnknown(data['study_day']!, _studyDayMeta),
      );
    } else if (isInserting) {
      context.missing(_studyDayMeta);
    }
    if (data.containsKey('study_day_zone_id')) {
      context.handle(
        _studyDayZoneIdMeta,
        studyDayZoneId.isAcceptableOrUnknown(
          data['study_day_zone_id']!,
          _studyDayZoneIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_studyDayZoneIdMeta);
    }
    if (data.containsKey('scheduler_name')) {
      context.handle(
        _schedulerNameMeta,
        schedulerName.isAcceptableOrUnknown(
          data['scheduler_name']!,
          _schedulerNameMeta,
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
    }
    if (data.containsKey('policy_version')) {
      context.handle(
        _policyVersionMeta,
        policyVersion.isAcceptableOrUnknown(
          data['policy_version']!,
          _policyVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_policyVersionMeta);
    }
    if (data.containsKey('state_before')) {
      context.handle(
        _stateBeforeMeta,
        stateBefore.isAcceptableOrUnknown(
          data['state_before']!,
          _stateBeforeMeta,
        ),
      );
    }
    if (data.containsKey('state_after')) {
      context.handle(
        _stateAfterMeta,
        stateAfter.isAcceptableOrUnknown(data['state_after']!, _stateAfterMeta),
      );
    }
    if (data.containsKey('algorithmic_due_before')) {
      context.handle(
        _algorithmicDueBeforeMeta,
        algorithmicDueBefore.isAcceptableOrUnknown(
          data['algorithmic_due_before']!,
          _algorithmicDueBeforeMeta,
        ),
      );
    }
    if (data.containsKey('algorithmic_due_after')) {
      context.handle(
        _algorithmicDueAfterMeta,
        algorithmicDueAfter.isAcceptableOrUnknown(
          data['algorithmic_due_after']!,
          _algorithmicDueAfterMeta,
        ),
      );
    }
    if (data.containsKey('undoes_event_id')) {
      context.handle(
        _undoesEventIdMeta,
        undoesEventId.isAcceptableOrUnknown(
          data['undoes_event_id']!,
          _undoesEventIdMeta,
        ),
      );
    }
    if (data.containsKey('batch_id')) {
      context.handle(
        _batchIdMeta,
        batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta),
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
  SchedulerEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SchedulerEventRow(
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
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      occurredAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at_utc'],
      )!,
      studyDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}study_day'],
      )!,
      studyDayZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}study_day_zone_id'],
      )!,
      schedulerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduler_name'],
      ),
      schedulerVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduler_version'],
      ),
      policyVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}policy_version'],
      )!,
      stateBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_before'],
      ),
      stateAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_after'],
      ),
      algorithmicDueBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithmic_due_before'],
      ),
      algorithmicDueAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithmic_due_after'],
      ),
      undoesEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}undoes_event_id'],
      ),
      batchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}batch_id'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
    );
  }

  @override
  $SchedulerEventsTable createAlias(String alias) {
    return $SchedulerEventsTable(attachedDatabase, alias);
  }
}

class SchedulerEventRow extends DataClass
    implements Insertable<SchedulerEventRow> {
  final String id;
  final String operationId;
  final String? elementId;
  final int? elementType;
  final String eventType;
  final int occurredAtUtc;
  final int studyDay;
  final String studyDayZoneId;
  final String? schedulerName;
  final String? schedulerVersion;
  final String policyVersion;
  final String? stateBefore;
  final String? stateAfter;
  final String? algorithmicDueBefore;
  final String? algorithmicDueAfter;
  final String? undoesEventId;
  final String? batchId;
  final String? metadataJson;
  const SchedulerEventRow({
    required this.id,
    required this.operationId,
    this.elementId,
    this.elementType,
    required this.eventType,
    required this.occurredAtUtc,
    required this.studyDay,
    required this.studyDayZoneId,
    this.schedulerName,
    this.schedulerVersion,
    required this.policyVersion,
    this.stateBefore,
    this.stateAfter,
    this.algorithmicDueBefore,
    this.algorithmicDueAfter,
    this.undoesEventId,
    this.batchId,
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
    map['event_type'] = Variable<String>(eventType);
    map['occurred_at_utc'] = Variable<int>(occurredAtUtc);
    map['study_day'] = Variable<int>(studyDay);
    map['study_day_zone_id'] = Variable<String>(studyDayZoneId);
    if (!nullToAbsent || schedulerName != null) {
      map['scheduler_name'] = Variable<String>(schedulerName);
    }
    if (!nullToAbsent || schedulerVersion != null) {
      map['scheduler_version'] = Variable<String>(schedulerVersion);
    }
    map['policy_version'] = Variable<String>(policyVersion);
    if (!nullToAbsent || stateBefore != null) {
      map['state_before'] = Variable<String>(stateBefore);
    }
    if (!nullToAbsent || stateAfter != null) {
      map['state_after'] = Variable<String>(stateAfter);
    }
    if (!nullToAbsent || algorithmicDueBefore != null) {
      map['algorithmic_due_before'] = Variable<String>(algorithmicDueBefore);
    }
    if (!nullToAbsent || algorithmicDueAfter != null) {
      map['algorithmic_due_after'] = Variable<String>(algorithmicDueAfter);
    }
    if (!nullToAbsent || undoesEventId != null) {
      map['undoes_event_id'] = Variable<String>(undoesEventId);
    }
    if (!nullToAbsent || batchId != null) {
      map['batch_id'] = Variable<String>(batchId);
    }
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    return map;
  }

  SchedulerEventsCompanion toCompanion(bool nullToAbsent) {
    return SchedulerEventsCompanion(
      id: Value(id),
      operationId: Value(operationId),
      elementId: elementId == null && nullToAbsent
          ? const Value.absent()
          : Value(elementId),
      elementType: elementType == null && nullToAbsent
          ? const Value.absent()
          : Value(elementType),
      eventType: Value(eventType),
      occurredAtUtc: Value(occurredAtUtc),
      studyDay: Value(studyDay),
      studyDayZoneId: Value(studyDayZoneId),
      schedulerName: schedulerName == null && nullToAbsent
          ? const Value.absent()
          : Value(schedulerName),
      schedulerVersion: schedulerVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(schedulerVersion),
      policyVersion: Value(policyVersion),
      stateBefore: stateBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(stateBefore),
      stateAfter: stateAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(stateAfter),
      algorithmicDueBefore: algorithmicDueBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(algorithmicDueBefore),
      algorithmicDueAfter: algorithmicDueAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(algorithmicDueAfter),
      undoesEventId: undoesEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(undoesEventId),
      batchId: batchId == null && nullToAbsent
          ? const Value.absent()
          : Value(batchId),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
    );
  }

  factory SchedulerEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SchedulerEventRow(
      id: serializer.fromJson<String>(json['id']),
      operationId: serializer.fromJson<String>(json['operationId']),
      elementId: serializer.fromJson<String?>(json['elementId']),
      elementType: serializer.fromJson<int?>(json['elementType']),
      eventType: serializer.fromJson<String>(json['eventType']),
      occurredAtUtc: serializer.fromJson<int>(json['occurredAtUtc']),
      studyDay: serializer.fromJson<int>(json['studyDay']),
      studyDayZoneId: serializer.fromJson<String>(json['studyDayZoneId']),
      schedulerName: serializer.fromJson<String?>(json['schedulerName']),
      schedulerVersion: serializer.fromJson<String?>(json['schedulerVersion']),
      policyVersion: serializer.fromJson<String>(json['policyVersion']),
      stateBefore: serializer.fromJson<String?>(json['stateBefore']),
      stateAfter: serializer.fromJson<String?>(json['stateAfter']),
      algorithmicDueBefore: serializer.fromJson<String?>(
        json['algorithmicDueBefore'],
      ),
      algorithmicDueAfter: serializer.fromJson<String?>(
        json['algorithmicDueAfter'],
      ),
      undoesEventId: serializer.fromJson<String?>(json['undoesEventId']),
      batchId: serializer.fromJson<String?>(json['batchId']),
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
      'eventType': serializer.toJson<String>(eventType),
      'occurredAtUtc': serializer.toJson<int>(occurredAtUtc),
      'studyDay': serializer.toJson<int>(studyDay),
      'studyDayZoneId': serializer.toJson<String>(studyDayZoneId),
      'schedulerName': serializer.toJson<String?>(schedulerName),
      'schedulerVersion': serializer.toJson<String?>(schedulerVersion),
      'policyVersion': serializer.toJson<String>(policyVersion),
      'stateBefore': serializer.toJson<String?>(stateBefore),
      'stateAfter': serializer.toJson<String?>(stateAfter),
      'algorithmicDueBefore': serializer.toJson<String?>(algorithmicDueBefore),
      'algorithmicDueAfter': serializer.toJson<String?>(algorithmicDueAfter),
      'undoesEventId': serializer.toJson<String?>(undoesEventId),
      'batchId': serializer.toJson<String?>(batchId),
      'metadataJson': serializer.toJson<String?>(metadataJson),
    };
  }

  SchedulerEventRow copyWith({
    String? id,
    String? operationId,
    Value<String?> elementId = const Value.absent(),
    Value<int?> elementType = const Value.absent(),
    String? eventType,
    int? occurredAtUtc,
    int? studyDay,
    String? studyDayZoneId,
    Value<String?> schedulerName = const Value.absent(),
    Value<String?> schedulerVersion = const Value.absent(),
    String? policyVersion,
    Value<String?> stateBefore = const Value.absent(),
    Value<String?> stateAfter = const Value.absent(),
    Value<String?> algorithmicDueBefore = const Value.absent(),
    Value<String?> algorithmicDueAfter = const Value.absent(),
    Value<String?> undoesEventId = const Value.absent(),
    Value<String?> batchId = const Value.absent(),
    Value<String?> metadataJson = const Value.absent(),
  }) => SchedulerEventRow(
    id: id ?? this.id,
    operationId: operationId ?? this.operationId,
    elementId: elementId.present ? elementId.value : this.elementId,
    elementType: elementType.present ? elementType.value : this.elementType,
    eventType: eventType ?? this.eventType,
    occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
    studyDay: studyDay ?? this.studyDay,
    studyDayZoneId: studyDayZoneId ?? this.studyDayZoneId,
    schedulerName: schedulerName.present
        ? schedulerName.value
        : this.schedulerName,
    schedulerVersion: schedulerVersion.present
        ? schedulerVersion.value
        : this.schedulerVersion,
    policyVersion: policyVersion ?? this.policyVersion,
    stateBefore: stateBefore.present ? stateBefore.value : this.stateBefore,
    stateAfter: stateAfter.present ? stateAfter.value : this.stateAfter,
    algorithmicDueBefore: algorithmicDueBefore.present
        ? algorithmicDueBefore.value
        : this.algorithmicDueBefore,
    algorithmicDueAfter: algorithmicDueAfter.present
        ? algorithmicDueAfter.value
        : this.algorithmicDueAfter,
    undoesEventId: undoesEventId.present
        ? undoesEventId.value
        : this.undoesEventId,
    batchId: batchId.present ? batchId.value : this.batchId,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
  );
  SchedulerEventRow copyWithCompanion(SchedulerEventsCompanion data) {
    return SchedulerEventRow(
      id: data.id.present ? data.id.value : this.id,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      elementId: data.elementId.present ? data.elementId.value : this.elementId,
      elementType: data.elementType.present
          ? data.elementType.value
          : this.elementType,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      occurredAtUtc: data.occurredAtUtc.present
          ? data.occurredAtUtc.value
          : this.occurredAtUtc,
      studyDay: data.studyDay.present ? data.studyDay.value : this.studyDay,
      studyDayZoneId: data.studyDayZoneId.present
          ? data.studyDayZoneId.value
          : this.studyDayZoneId,
      schedulerName: data.schedulerName.present
          ? data.schedulerName.value
          : this.schedulerName,
      schedulerVersion: data.schedulerVersion.present
          ? data.schedulerVersion.value
          : this.schedulerVersion,
      policyVersion: data.policyVersion.present
          ? data.policyVersion.value
          : this.policyVersion,
      stateBefore: data.stateBefore.present
          ? data.stateBefore.value
          : this.stateBefore,
      stateAfter: data.stateAfter.present
          ? data.stateAfter.value
          : this.stateAfter,
      algorithmicDueBefore: data.algorithmicDueBefore.present
          ? data.algorithmicDueBefore.value
          : this.algorithmicDueBefore,
      algorithmicDueAfter: data.algorithmicDueAfter.present
          ? data.algorithmicDueAfter.value
          : this.algorithmicDueAfter,
      undoesEventId: data.undoesEventId.present
          ? data.undoesEventId.value
          : this.undoesEventId,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SchedulerEventRow(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('eventType: $eventType, ')
          ..write('occurredAtUtc: $occurredAtUtc, ')
          ..write('studyDay: $studyDay, ')
          ..write('studyDayZoneId: $studyDayZoneId, ')
          ..write('schedulerName: $schedulerName, ')
          ..write('schedulerVersion: $schedulerVersion, ')
          ..write('policyVersion: $policyVersion, ')
          ..write('stateBefore: $stateBefore, ')
          ..write('stateAfter: $stateAfter, ')
          ..write('algorithmicDueBefore: $algorithmicDueBefore, ')
          ..write('algorithmicDueAfter: $algorithmicDueAfter, ')
          ..write('undoesEventId: $undoesEventId, ')
          ..write('batchId: $batchId, ')
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
    eventType,
    occurredAtUtc,
    studyDay,
    studyDayZoneId,
    schedulerName,
    schedulerVersion,
    policyVersion,
    stateBefore,
    stateAfter,
    algorithmicDueBefore,
    algorithmicDueAfter,
    undoesEventId,
    batchId,
    metadataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SchedulerEventRow &&
          other.id == this.id &&
          other.operationId == this.operationId &&
          other.elementId == this.elementId &&
          other.elementType == this.elementType &&
          other.eventType == this.eventType &&
          other.occurredAtUtc == this.occurredAtUtc &&
          other.studyDay == this.studyDay &&
          other.studyDayZoneId == this.studyDayZoneId &&
          other.schedulerName == this.schedulerName &&
          other.schedulerVersion == this.schedulerVersion &&
          other.policyVersion == this.policyVersion &&
          other.stateBefore == this.stateBefore &&
          other.stateAfter == this.stateAfter &&
          other.algorithmicDueBefore == this.algorithmicDueBefore &&
          other.algorithmicDueAfter == this.algorithmicDueAfter &&
          other.undoesEventId == this.undoesEventId &&
          other.batchId == this.batchId &&
          other.metadataJson == this.metadataJson);
}

class SchedulerEventsCompanion extends UpdateCompanion<SchedulerEventRow> {
  final Value<String> id;
  final Value<String> operationId;
  final Value<String?> elementId;
  final Value<int?> elementType;
  final Value<String> eventType;
  final Value<int> occurredAtUtc;
  final Value<int> studyDay;
  final Value<String> studyDayZoneId;
  final Value<String?> schedulerName;
  final Value<String?> schedulerVersion;
  final Value<String> policyVersion;
  final Value<String?> stateBefore;
  final Value<String?> stateAfter;
  final Value<String?> algorithmicDueBefore;
  final Value<String?> algorithmicDueAfter;
  final Value<String?> undoesEventId;
  final Value<String?> batchId;
  final Value<String?> metadataJson;
  final Value<int> rowid;
  const SchedulerEventsCompanion({
    this.id = const Value.absent(),
    this.operationId = const Value.absent(),
    this.elementId = const Value.absent(),
    this.elementType = const Value.absent(),
    this.eventType = const Value.absent(),
    this.occurredAtUtc = const Value.absent(),
    this.studyDay = const Value.absent(),
    this.studyDayZoneId = const Value.absent(),
    this.schedulerName = const Value.absent(),
    this.schedulerVersion = const Value.absent(),
    this.policyVersion = const Value.absent(),
    this.stateBefore = const Value.absent(),
    this.stateAfter = const Value.absent(),
    this.algorithmicDueBefore = const Value.absent(),
    this.algorithmicDueAfter = const Value.absent(),
    this.undoesEventId = const Value.absent(),
    this.batchId = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SchedulerEventsCompanion.insert({
    required String id,
    required String operationId,
    this.elementId = const Value.absent(),
    this.elementType = const Value.absent(),
    required String eventType,
    required int occurredAtUtc,
    required int studyDay,
    required String studyDayZoneId,
    this.schedulerName = const Value.absent(),
    this.schedulerVersion = const Value.absent(),
    required String policyVersion,
    this.stateBefore = const Value.absent(),
    this.stateAfter = const Value.absent(),
    this.algorithmicDueBefore = const Value.absent(),
    this.algorithmicDueAfter = const Value.absent(),
    this.undoesEventId = const Value.absent(),
    this.batchId = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       operationId = Value(operationId),
       eventType = Value(eventType),
       occurredAtUtc = Value(occurredAtUtc),
       studyDay = Value(studyDay),
       studyDayZoneId = Value(studyDayZoneId),
       policyVersion = Value(policyVersion);
  static Insertable<SchedulerEventRow> custom({
    Expression<String>? id,
    Expression<String>? operationId,
    Expression<String>? elementId,
    Expression<int>? elementType,
    Expression<String>? eventType,
    Expression<int>? occurredAtUtc,
    Expression<int>? studyDay,
    Expression<String>? studyDayZoneId,
    Expression<String>? schedulerName,
    Expression<String>? schedulerVersion,
    Expression<String>? policyVersion,
    Expression<String>? stateBefore,
    Expression<String>? stateAfter,
    Expression<String>? algorithmicDueBefore,
    Expression<String>? algorithmicDueAfter,
    Expression<String>? undoesEventId,
    Expression<String>? batchId,
    Expression<String>? metadataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationId != null) 'operation_id': operationId,
      if (elementId != null) 'element_id': elementId,
      if (elementType != null) 'element_type': elementType,
      if (eventType != null) 'event_type': eventType,
      if (occurredAtUtc != null) 'occurred_at_utc': occurredAtUtc,
      if (studyDay != null) 'study_day': studyDay,
      if (studyDayZoneId != null) 'study_day_zone_id': studyDayZoneId,
      if (schedulerName != null) 'scheduler_name': schedulerName,
      if (schedulerVersion != null) 'scheduler_version': schedulerVersion,
      if (policyVersion != null) 'policy_version': policyVersion,
      if (stateBefore != null) 'state_before': stateBefore,
      if (stateAfter != null) 'state_after': stateAfter,
      if (algorithmicDueBefore != null)
        'algorithmic_due_before': algorithmicDueBefore,
      if (algorithmicDueAfter != null)
        'algorithmic_due_after': algorithmicDueAfter,
      if (undoesEventId != null) 'undoes_event_id': undoesEventId,
      if (batchId != null) 'batch_id': batchId,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SchedulerEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? operationId,
    Value<String?>? elementId,
    Value<int?>? elementType,
    Value<String>? eventType,
    Value<int>? occurredAtUtc,
    Value<int>? studyDay,
    Value<String>? studyDayZoneId,
    Value<String?>? schedulerName,
    Value<String?>? schedulerVersion,
    Value<String>? policyVersion,
    Value<String?>? stateBefore,
    Value<String?>? stateAfter,
    Value<String?>? algorithmicDueBefore,
    Value<String?>? algorithmicDueAfter,
    Value<String?>? undoesEventId,
    Value<String?>? batchId,
    Value<String?>? metadataJson,
    Value<int>? rowid,
  }) {
    return SchedulerEventsCompanion(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      elementId: elementId ?? this.elementId,
      elementType: elementType ?? this.elementType,
      eventType: eventType ?? this.eventType,
      occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
      studyDay: studyDay ?? this.studyDay,
      studyDayZoneId: studyDayZoneId ?? this.studyDayZoneId,
      schedulerName: schedulerName ?? this.schedulerName,
      schedulerVersion: schedulerVersion ?? this.schedulerVersion,
      policyVersion: policyVersion ?? this.policyVersion,
      stateBefore: stateBefore ?? this.stateBefore,
      stateAfter: stateAfter ?? this.stateAfter,
      algorithmicDueBefore: algorithmicDueBefore ?? this.algorithmicDueBefore,
      algorithmicDueAfter: algorithmicDueAfter ?? this.algorithmicDueAfter,
      undoesEventId: undoesEventId ?? this.undoesEventId,
      batchId: batchId ?? this.batchId,
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
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (occurredAtUtc.present) {
      map['occurred_at_utc'] = Variable<int>(occurredAtUtc.value);
    }
    if (studyDay.present) {
      map['study_day'] = Variable<int>(studyDay.value);
    }
    if (studyDayZoneId.present) {
      map['study_day_zone_id'] = Variable<String>(studyDayZoneId.value);
    }
    if (schedulerName.present) {
      map['scheduler_name'] = Variable<String>(schedulerName.value);
    }
    if (schedulerVersion.present) {
      map['scheduler_version'] = Variable<String>(schedulerVersion.value);
    }
    if (policyVersion.present) {
      map['policy_version'] = Variable<String>(policyVersion.value);
    }
    if (stateBefore.present) {
      map['state_before'] = Variable<String>(stateBefore.value);
    }
    if (stateAfter.present) {
      map['state_after'] = Variable<String>(stateAfter.value);
    }
    if (algorithmicDueBefore.present) {
      map['algorithmic_due_before'] = Variable<String>(
        algorithmicDueBefore.value,
      );
    }
    if (algorithmicDueAfter.present) {
      map['algorithmic_due_after'] = Variable<String>(
        algorithmicDueAfter.value,
      );
    }
    if (undoesEventId.present) {
      map['undoes_event_id'] = Variable<String>(undoesEventId.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<String>(batchId.value);
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
    return (StringBuffer('SchedulerEventsCompanion(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('eventType: $eventType, ')
          ..write('occurredAtUtc: $occurredAtUtc, ')
          ..write('studyDay: $studyDay, ')
          ..write('studyDayZoneId: $studyDayZoneId, ')
          ..write('schedulerName: $schedulerName, ')
          ..write('schedulerVersion: $schedulerVersion, ')
          ..write('policyVersion: $policyVersion, ')
          ..write('stateBefore: $stateBefore, ')
          ..write('stateAfter: $stateAfter, ')
          ..write('algorithmicDueBefore: $algorithmicDueBefore, ')
          ..write('algorithmicDueAfter: $algorithmicDueAfter, ')
          ..write('undoesEventId: $undoesEventId, ')
          ..write('batchId: $batchId, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MercyBatchesTable extends MercyBatches
    with TableInfo<$MercyBatchesTable, MercyBatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MercyBatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _batchIdMeta = const VerificationMeta(
    'batchId',
  );
  @override
  late final GeneratedColumn<String> batchId = GeneratedColumn<String>(
    'batch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previewOperationIdMeta =
      const VerificationMeta('previewOperationId');
  @override
  late final GeneratedColumn<String> previewOperationId =
      GeneratedColumn<String>(
        'preview_operation_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _applyOperationIdMeta = const VerificationMeta(
    'applyOperationId',
  );
  @override
  late final GeneratedColumn<String> applyOperationId = GeneratedColumn<String>(
    'apply_operation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _undoOperationIdMeta = const VerificationMeta(
    'undoOperationId',
  );
  @override
  late final GeneratedColumn<String> undoOperationId = GeneratedColumn<String>(
    'undo_operation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _policyVersionMeta = const VerificationMeta(
    'policyVersion',
  );
  @override
  late final GeneratedColumn<String> policyVersion = GeneratedColumn<String>(
    'policy_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previewJsonMeta = const VerificationMeta(
    'previewJson',
  );
  @override
  late final GeneratedColumn<String> previewJson = GeneratedColumn<String>(
    'preview_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appliedSnapshotJsonMeta =
      const VerificationMeta('appliedSnapshotJson');
  @override
  late final GeneratedColumn<String> appliedSnapshotJson =
      GeneratedColumn<String>(
        'applied_snapshot_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
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
  static const VerificationMeta _appliedAtUtcMeta = const VerificationMeta(
    'appliedAtUtc',
  );
  @override
  late final GeneratedColumn<int> appliedAtUtc = GeneratedColumn<int>(
    'applied_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _undoneAtUtcMeta = const VerificationMeta(
    'undoneAtUtc',
  );
  @override
  late final GeneratedColumn<int> undoneAtUtc = GeneratedColumn<int>(
    'undone_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    batchId,
    previewOperationId,
    applyOperationId,
    undoOperationId,
    policyVersion,
    previewJson,
    appliedSnapshotJson,
    createdAtUtc,
    appliedAtUtc,
    undoneAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mercy_batches';
  @override
  VerificationContext validateIntegrity(
    Insertable<MercyBatchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('batch_id')) {
      context.handle(
        _batchIdMeta,
        batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_batchIdMeta);
    }
    if (data.containsKey('preview_operation_id')) {
      context.handle(
        _previewOperationIdMeta,
        previewOperationId.isAcceptableOrUnknown(
          data['preview_operation_id']!,
          _previewOperationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previewOperationIdMeta);
    }
    if (data.containsKey('apply_operation_id')) {
      context.handle(
        _applyOperationIdMeta,
        applyOperationId.isAcceptableOrUnknown(
          data['apply_operation_id']!,
          _applyOperationIdMeta,
        ),
      );
    }
    if (data.containsKey('undo_operation_id')) {
      context.handle(
        _undoOperationIdMeta,
        undoOperationId.isAcceptableOrUnknown(
          data['undo_operation_id']!,
          _undoOperationIdMeta,
        ),
      );
    }
    if (data.containsKey('policy_version')) {
      context.handle(
        _policyVersionMeta,
        policyVersion.isAcceptableOrUnknown(
          data['policy_version']!,
          _policyVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_policyVersionMeta);
    }
    if (data.containsKey('preview_json')) {
      context.handle(
        _previewJsonMeta,
        previewJson.isAcceptableOrUnknown(
          data['preview_json']!,
          _previewJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previewJsonMeta);
    }
    if (data.containsKey('applied_snapshot_json')) {
      context.handle(
        _appliedSnapshotJsonMeta,
        appliedSnapshotJson.isAcceptableOrUnknown(
          data['applied_snapshot_json']!,
          _appliedSnapshotJsonMeta,
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
    if (data.containsKey('applied_at_utc')) {
      context.handle(
        _appliedAtUtcMeta,
        appliedAtUtc.isAcceptableOrUnknown(
          data['applied_at_utc']!,
          _appliedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('undone_at_utc')) {
      context.handle(
        _undoneAtUtcMeta,
        undoneAtUtc.isAcceptableOrUnknown(
          data['undone_at_utc']!,
          _undoneAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {batchId};
  @override
  MercyBatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MercyBatchRow(
      batchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}batch_id'],
      )!,
      previewOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_operation_id'],
      )!,
      applyOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}apply_operation_id'],
      ),
      undoOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}undo_operation_id'],
      ),
      policyVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}policy_version'],
      )!,
      previewJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_json'],
      )!,
      appliedSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}applied_snapshot_json'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      appliedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}applied_at_utc'],
      ),
      undoneAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}undone_at_utc'],
      ),
    );
  }

  @override
  $MercyBatchesTable createAlias(String alias) {
    return $MercyBatchesTable(attachedDatabase, alias);
  }
}

class MercyBatchRow extends DataClass implements Insertable<MercyBatchRow> {
  final String batchId;
  final String previewOperationId;
  final String? applyOperationId;
  final String? undoOperationId;
  final String policyVersion;
  final String previewJson;

  /// Exact per-element canonical states needed to validate and undo an apply.
  final String? appliedSnapshotJson;
  final int createdAtUtc;
  final int? appliedAtUtc;
  final int? undoneAtUtc;
  const MercyBatchRow({
    required this.batchId,
    required this.previewOperationId,
    this.applyOperationId,
    this.undoOperationId,
    required this.policyVersion,
    required this.previewJson,
    this.appliedSnapshotJson,
    required this.createdAtUtc,
    this.appliedAtUtc,
    this.undoneAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['batch_id'] = Variable<String>(batchId);
    map['preview_operation_id'] = Variable<String>(previewOperationId);
    if (!nullToAbsent || applyOperationId != null) {
      map['apply_operation_id'] = Variable<String>(applyOperationId);
    }
    if (!nullToAbsent || undoOperationId != null) {
      map['undo_operation_id'] = Variable<String>(undoOperationId);
    }
    map['policy_version'] = Variable<String>(policyVersion);
    map['preview_json'] = Variable<String>(previewJson);
    if (!nullToAbsent || appliedSnapshotJson != null) {
      map['applied_snapshot_json'] = Variable<String>(appliedSnapshotJson);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    if (!nullToAbsent || appliedAtUtc != null) {
      map['applied_at_utc'] = Variable<int>(appliedAtUtc);
    }
    if (!nullToAbsent || undoneAtUtc != null) {
      map['undone_at_utc'] = Variable<int>(undoneAtUtc);
    }
    return map;
  }

  MercyBatchesCompanion toCompanion(bool nullToAbsent) {
    return MercyBatchesCompanion(
      batchId: Value(batchId),
      previewOperationId: Value(previewOperationId),
      applyOperationId: applyOperationId == null && nullToAbsent
          ? const Value.absent()
          : Value(applyOperationId),
      undoOperationId: undoOperationId == null && nullToAbsent
          ? const Value.absent()
          : Value(undoOperationId),
      policyVersion: Value(policyVersion),
      previewJson: Value(previewJson),
      appliedSnapshotJson: appliedSnapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(appliedSnapshotJson),
      createdAtUtc: Value(createdAtUtc),
      appliedAtUtc: appliedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(appliedAtUtc),
      undoneAtUtc: undoneAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(undoneAtUtc),
    );
  }

  factory MercyBatchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MercyBatchRow(
      batchId: serializer.fromJson<String>(json['batchId']),
      previewOperationId: serializer.fromJson<String>(
        json['previewOperationId'],
      ),
      applyOperationId: serializer.fromJson<String?>(json['applyOperationId']),
      undoOperationId: serializer.fromJson<String?>(json['undoOperationId']),
      policyVersion: serializer.fromJson<String>(json['policyVersion']),
      previewJson: serializer.fromJson<String>(json['previewJson']),
      appliedSnapshotJson: serializer.fromJson<String?>(
        json['appliedSnapshotJson'],
      ),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      appliedAtUtc: serializer.fromJson<int?>(json['appliedAtUtc']),
      undoneAtUtc: serializer.fromJson<int?>(json['undoneAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'batchId': serializer.toJson<String>(batchId),
      'previewOperationId': serializer.toJson<String>(previewOperationId),
      'applyOperationId': serializer.toJson<String?>(applyOperationId),
      'undoOperationId': serializer.toJson<String?>(undoOperationId),
      'policyVersion': serializer.toJson<String>(policyVersion),
      'previewJson': serializer.toJson<String>(previewJson),
      'appliedSnapshotJson': serializer.toJson<String?>(appliedSnapshotJson),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'appliedAtUtc': serializer.toJson<int?>(appliedAtUtc),
      'undoneAtUtc': serializer.toJson<int?>(undoneAtUtc),
    };
  }

  MercyBatchRow copyWith({
    String? batchId,
    String? previewOperationId,
    Value<String?> applyOperationId = const Value.absent(),
    Value<String?> undoOperationId = const Value.absent(),
    String? policyVersion,
    String? previewJson,
    Value<String?> appliedSnapshotJson = const Value.absent(),
    int? createdAtUtc,
    Value<int?> appliedAtUtc = const Value.absent(),
    Value<int?> undoneAtUtc = const Value.absent(),
  }) => MercyBatchRow(
    batchId: batchId ?? this.batchId,
    previewOperationId: previewOperationId ?? this.previewOperationId,
    applyOperationId: applyOperationId.present
        ? applyOperationId.value
        : this.applyOperationId,
    undoOperationId: undoOperationId.present
        ? undoOperationId.value
        : this.undoOperationId,
    policyVersion: policyVersion ?? this.policyVersion,
    previewJson: previewJson ?? this.previewJson,
    appliedSnapshotJson: appliedSnapshotJson.present
        ? appliedSnapshotJson.value
        : this.appliedSnapshotJson,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    appliedAtUtc: appliedAtUtc.present ? appliedAtUtc.value : this.appliedAtUtc,
    undoneAtUtc: undoneAtUtc.present ? undoneAtUtc.value : this.undoneAtUtc,
  );
  MercyBatchRow copyWithCompanion(MercyBatchesCompanion data) {
    return MercyBatchRow(
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      previewOperationId: data.previewOperationId.present
          ? data.previewOperationId.value
          : this.previewOperationId,
      applyOperationId: data.applyOperationId.present
          ? data.applyOperationId.value
          : this.applyOperationId,
      undoOperationId: data.undoOperationId.present
          ? data.undoOperationId.value
          : this.undoOperationId,
      policyVersion: data.policyVersion.present
          ? data.policyVersion.value
          : this.policyVersion,
      previewJson: data.previewJson.present
          ? data.previewJson.value
          : this.previewJson,
      appliedSnapshotJson: data.appliedSnapshotJson.present
          ? data.appliedSnapshotJson.value
          : this.appliedSnapshotJson,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      appliedAtUtc: data.appliedAtUtc.present
          ? data.appliedAtUtc.value
          : this.appliedAtUtc,
      undoneAtUtc: data.undoneAtUtc.present
          ? data.undoneAtUtc.value
          : this.undoneAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MercyBatchRow(')
          ..write('batchId: $batchId, ')
          ..write('previewOperationId: $previewOperationId, ')
          ..write('applyOperationId: $applyOperationId, ')
          ..write('undoOperationId: $undoOperationId, ')
          ..write('policyVersion: $policyVersion, ')
          ..write('previewJson: $previewJson, ')
          ..write('appliedSnapshotJson: $appliedSnapshotJson, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('appliedAtUtc: $appliedAtUtc, ')
          ..write('undoneAtUtc: $undoneAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    batchId,
    previewOperationId,
    applyOperationId,
    undoOperationId,
    policyVersion,
    previewJson,
    appliedSnapshotJson,
    createdAtUtc,
    appliedAtUtc,
    undoneAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MercyBatchRow &&
          other.batchId == this.batchId &&
          other.previewOperationId == this.previewOperationId &&
          other.applyOperationId == this.applyOperationId &&
          other.undoOperationId == this.undoOperationId &&
          other.policyVersion == this.policyVersion &&
          other.previewJson == this.previewJson &&
          other.appliedSnapshotJson == this.appliedSnapshotJson &&
          other.createdAtUtc == this.createdAtUtc &&
          other.appliedAtUtc == this.appliedAtUtc &&
          other.undoneAtUtc == this.undoneAtUtc);
}

class MercyBatchesCompanion extends UpdateCompanion<MercyBatchRow> {
  final Value<String> batchId;
  final Value<String> previewOperationId;
  final Value<String?> applyOperationId;
  final Value<String?> undoOperationId;
  final Value<String> policyVersion;
  final Value<String> previewJson;
  final Value<String?> appliedSnapshotJson;
  final Value<int> createdAtUtc;
  final Value<int?> appliedAtUtc;
  final Value<int?> undoneAtUtc;
  final Value<int> rowid;
  const MercyBatchesCompanion({
    this.batchId = const Value.absent(),
    this.previewOperationId = const Value.absent(),
    this.applyOperationId = const Value.absent(),
    this.undoOperationId = const Value.absent(),
    this.policyVersion = const Value.absent(),
    this.previewJson = const Value.absent(),
    this.appliedSnapshotJson = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.appliedAtUtc = const Value.absent(),
    this.undoneAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MercyBatchesCompanion.insert({
    required String batchId,
    required String previewOperationId,
    this.applyOperationId = const Value.absent(),
    this.undoOperationId = const Value.absent(),
    required String policyVersion,
    required String previewJson,
    this.appliedSnapshotJson = const Value.absent(),
    required int createdAtUtc,
    this.appliedAtUtc = const Value.absent(),
    this.undoneAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : batchId = Value(batchId),
       previewOperationId = Value(previewOperationId),
       policyVersion = Value(policyVersion),
       previewJson = Value(previewJson),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<MercyBatchRow> custom({
    Expression<String>? batchId,
    Expression<String>? previewOperationId,
    Expression<String>? applyOperationId,
    Expression<String>? undoOperationId,
    Expression<String>? policyVersion,
    Expression<String>? previewJson,
    Expression<String>? appliedSnapshotJson,
    Expression<int>? createdAtUtc,
    Expression<int>? appliedAtUtc,
    Expression<int>? undoneAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (batchId != null) 'batch_id': batchId,
      if (previewOperationId != null)
        'preview_operation_id': previewOperationId,
      if (applyOperationId != null) 'apply_operation_id': applyOperationId,
      if (undoOperationId != null) 'undo_operation_id': undoOperationId,
      if (policyVersion != null) 'policy_version': policyVersion,
      if (previewJson != null) 'preview_json': previewJson,
      if (appliedSnapshotJson != null)
        'applied_snapshot_json': appliedSnapshotJson,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (appliedAtUtc != null) 'applied_at_utc': appliedAtUtc,
      if (undoneAtUtc != null) 'undone_at_utc': undoneAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MercyBatchesCompanion copyWith({
    Value<String>? batchId,
    Value<String>? previewOperationId,
    Value<String?>? applyOperationId,
    Value<String?>? undoOperationId,
    Value<String>? policyVersion,
    Value<String>? previewJson,
    Value<String?>? appliedSnapshotJson,
    Value<int>? createdAtUtc,
    Value<int?>? appliedAtUtc,
    Value<int?>? undoneAtUtc,
    Value<int>? rowid,
  }) {
    return MercyBatchesCompanion(
      batchId: batchId ?? this.batchId,
      previewOperationId: previewOperationId ?? this.previewOperationId,
      applyOperationId: applyOperationId ?? this.applyOperationId,
      undoOperationId: undoOperationId ?? this.undoOperationId,
      policyVersion: policyVersion ?? this.policyVersion,
      previewJson: previewJson ?? this.previewJson,
      appliedSnapshotJson: appliedSnapshotJson ?? this.appliedSnapshotJson,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      appliedAtUtc: appliedAtUtc ?? this.appliedAtUtc,
      undoneAtUtc: undoneAtUtc ?? this.undoneAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (batchId.present) {
      map['batch_id'] = Variable<String>(batchId.value);
    }
    if (previewOperationId.present) {
      map['preview_operation_id'] = Variable<String>(previewOperationId.value);
    }
    if (applyOperationId.present) {
      map['apply_operation_id'] = Variable<String>(applyOperationId.value);
    }
    if (undoOperationId.present) {
      map['undo_operation_id'] = Variable<String>(undoOperationId.value);
    }
    if (policyVersion.present) {
      map['policy_version'] = Variable<String>(policyVersion.value);
    }
    if (previewJson.present) {
      map['preview_json'] = Variable<String>(previewJson.value);
    }
    if (appliedSnapshotJson.present) {
      map['applied_snapshot_json'] = Variable<String>(
        appliedSnapshotJson.value,
      );
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (appliedAtUtc.present) {
      map['applied_at_utc'] = Variable<int>(appliedAtUtc.value);
    }
    if (undoneAtUtc.present) {
      map['undone_at_utc'] = Variable<int>(undoneAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MercyBatchesCompanion(')
          ..write('batchId: $batchId, ')
          ..write('previewOperationId: $previewOperationId, ')
          ..write('applyOperationId: $applyOperationId, ')
          ..write('undoOperationId: $undoOperationId, ')
          ..write('policyVersion: $policyVersion, ')
          ..write('previewJson: $previewJson, ')
          ..write('appliedSnapshotJson: $appliedSnapshotJson, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('appliedAtUtc: $appliedAtUtc, ')
          ..write('undoneAtUtc: $undoneAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchDocumentsTable extends SearchDocuments
    with TableInfo<$SearchDocumentsTable, SearchDocumentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchDocumentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    elementId,
    elementType,
    title,
    body,
    sourceId,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchDocumentRow> instance, {
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
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {elementId, elementType};
  @override
  SearchDocumentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchDocumentRow(
      elementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}element_id'],
      )!,
      elementType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}element_type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $SearchDocumentsTable createAlias(String alias) {
    return $SearchDocumentsTable(attachedDatabase, alias);
  }
}

class SearchDocumentRow extends DataClass
    implements Insertable<SearchDocumentRow> {
  final String elementId;
  final int elementType;
  final String title;
  final String body;

  /// Root source, so results can be grouped by article without a join.
  final String? sourceId;
  final int updatedAtUtc;
  const SearchDocumentRow({
    required this.elementId,
    required this.elementType,
    required this.title,
    required this.body,
    this.sourceId,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['element_id'] = Variable<String>(elementId);
    map['element_type'] = Variable<int>(elementType);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    return map;
  }

  SearchDocumentsCompanion toCompanion(bool nullToAbsent) {
    return SearchDocumentsCompanion(
      elementId: Value(elementId),
      elementType: Value(elementType),
      title: Value(title),
      body: Value(body),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory SearchDocumentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchDocumentRow(
      elementId: serializer.fromJson<String>(json['elementId']),
      elementType: serializer.fromJson<int>(json['elementType']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'elementId': serializer.toJson<String>(elementId),
      'elementType': serializer.toJson<int>(elementType),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'sourceId': serializer.toJson<String?>(sourceId),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
    };
  }

  SearchDocumentRow copyWith({
    String? elementId,
    int? elementType,
    String? title,
    String? body,
    Value<String?> sourceId = const Value.absent(),
    int? updatedAtUtc,
  }) => SearchDocumentRow(
    elementId: elementId ?? this.elementId,
    elementType: elementType ?? this.elementType,
    title: title ?? this.title,
    body: body ?? this.body,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  SearchDocumentRow copyWithCompanion(SearchDocumentsCompanion data) {
    return SearchDocumentRow(
      elementId: data.elementId.present ? data.elementId.value : this.elementId,
      elementType: data.elementType.present
          ? data.elementType.value
          : this.elementType,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchDocumentRow(')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('sourceId: $sourceId, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(elementId, elementType, title, body, sourceId, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchDocumentRow &&
          other.elementId == this.elementId &&
          other.elementType == this.elementType &&
          other.title == this.title &&
          other.body == this.body &&
          other.sourceId == this.sourceId &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class SearchDocumentsCompanion extends UpdateCompanion<SearchDocumentRow> {
  final Value<String> elementId;
  final Value<int> elementType;
  final Value<String> title;
  final Value<String> body;
  final Value<String?> sourceId;
  final Value<int> updatedAtUtc;
  final Value<int> rowid;
  const SearchDocumentsCompanion({
    this.elementId = const Value.absent(),
    this.elementType = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchDocumentsCompanion.insert({
    required String elementId,
    required int elementType,
    required String title,
    required String body,
    this.sourceId = const Value.absent(),
    required int updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : elementId = Value(elementId),
       elementType = Value(elementType),
       title = Value(title),
       body = Value(body),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<SearchDocumentRow> custom({
    Expression<String>? elementId,
    Expression<int>? elementType,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? sourceId,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (elementId != null) 'element_id': elementId,
      if (elementType != null) 'element_type': elementType,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (sourceId != null) 'source_id': sourceId,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchDocumentsCompanion copyWith({
    Value<String>? elementId,
    Value<int>? elementType,
    Value<String>? title,
    Value<String>? body,
    Value<String?>? sourceId,
    Value<int>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return SearchDocumentsCompanion(
      elementId: elementId ?? this.elementId,
      elementType: elementType ?? this.elementType,
      title: title ?? this.title,
      body: body ?? this.body,
      sourceId: sourceId ?? this.sourceId,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchDocumentsCompanion(')
          ..write('elementId: $elementId, ')
          ..write('elementType: $elementType, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('sourceId: $sourceId, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
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
  late final $RevlogEntriesTable revlogEntries = $RevlogEntriesTable(this);
  late final $SchedulerEventsTable schedulerEvents = $SchedulerEventsTable(
    this,
  );
  late final $MercyBatchesTable mercyBatches = $MercyBatchesTable(this);
  late final $SearchDocumentsTable searchDocuments = $SearchDocumentsTable(
    this,
  );
  late final $ActivityEventsTable activityEvents = $ActivityEventsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $DatasetMetaTable datasetMeta = $DatasetMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sources,
    blocks,
    extracts,
    cards,
    elementSchedules,
    topicStates,
    cardMemories,
    reviewEvents,
    revlogEntries,
    schedulerEvents,
    mercyBatches,
    searchDocuments,
    activityEvents,
    settings,
    datasetMeta,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('blocks', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SourcesTableCreateCompanionBuilder =
    SourcesCompanion Function({
      required String id,
      required String title,
      required String markdown,
      required String contentHash,
      required int wordCount,
      required int importedAtUtc,
      Value<String?> markerBlockId,
      Value<int?> markerOffset,
      Value<String?> softBlockId,
      Value<int?> softOffset,
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
      Value<String?> markerBlockId,
      Value<int?> markerOffset,
      Value<String?> softBlockId,
      Value<int?> softOffset,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$SourcesTableReferences
    extends BaseReferences<_$AppDatabase, $SourcesTable, SourceRow> {
  $$SourcesTableReferences(super.$_db, super.$_table, super.$_typedResult);

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
          PrefetchHooks Function({bool blocksRefs, bool extractsRefs})
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
                Value<String?> markerBlockId = const Value.absent(),
                Value<int?> markerOffset = const Value.absent(),
                Value<String?> softBlockId = const Value.absent(),
                Value<int?> softOffset = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion(
                id: id,
                title: title,
                markdown: markdown,
                contentHash: contentHash,
                wordCount: wordCount,
                importedAtUtc: importedAtUtc,
                markerBlockId: markerBlockId,
                markerOffset: markerOffset,
                softBlockId: softBlockId,
                softOffset: softOffset,
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
                Value<String?> markerBlockId = const Value.absent(),
                Value<int?> markerOffset = const Value.absent(),
                Value<String?> softBlockId = const Value.absent(),
                Value<int?> softOffset = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion.insert(
                id: id,
                title: title,
                markdown: markdown,
                contentHash: contentHash,
                wordCount: wordCount,
                importedAtUtc: importedAtUtc,
                markerBlockId: markerBlockId,
                markerOffset: markerOffset,
                softBlockId: softBlockId,
                softOffset: softOffset,
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
          prefetchHooksCallback: ({blocksRefs = false, extractsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (blocksRefs) db.blocks,
                if (extractsRefs) db.extracts,
              ],
              addJoins: null,
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
                          $$SourcesTableReferences(db, table, p0).blocksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sourceId == item.id),
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
                          $$SourcesTableReferences(db, table, p0).extractsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sourceId == item.id),
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
      PrefetchHooks Function({bool blocksRefs, bool extractsRefs})
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
          PrefetchHooks Function({bool sourceId})
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
                return [];
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
      PrefetchHooks Function({bool sourceId})
    >;
typedef $$CardsTableCreateCompanionBuilder =
    CardsCompanion Function({
      required String id,
      Value<String?> parentElementId,
      Value<int?> parentElementType,
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
      Value<String?> parentElementId,
      Value<int?> parentElementType,
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

  ColumnFilters<String> get parentElementId => $composableBuilder(
    column: $table.parentElementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentElementType => $composableBuilder(
    column: $table.parentElementType,
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

  ColumnOrderings<String> get parentElementId => $composableBuilder(
    column: $table.parentElementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentElementType => $composableBuilder(
    column: $table.parentElementType,
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

  GeneratedColumn<String> get parentElementId => $composableBuilder(
    column: $table.parentElementId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get parentElementType => $composableBuilder(
    column: $table.parentElementType,
    builder: (column) => column,
  );

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
          PrefetchHooks Function({bool cardMemoriesRefs, bool reviewEventsRefs})
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
                Value<String?> parentElementId = const Value.absent(),
                Value<int?> parentElementType = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String> front = const Value.absent(),
                Value<String> back = const Value.absent(),
                Value<int?> clozeOrdinal = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int?> editedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                parentElementId: parentElementId,
                parentElementType: parentElementType,
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
                Value<String?> parentElementId = const Value.absent(),
                Value<int?> parentElementType = const Value.absent(),
                required int kind,
                required String front,
                required String back,
                Value<int?> clozeOrdinal = const Value.absent(),
                required int createdAtUtc,
                Value<int?> editedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                parentElementId: parentElementId,
                parentElementType: parentElementType,
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
              ({cardMemoriesRefs = false, reviewEventsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cardMemoriesRefs) db.cardMemories,
                    if (reviewEventsRefs) db.reviewEvents,
                  ],
                  addJoins: null,
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
      PrefetchHooks Function({bool cardMemoriesRefs, bool reviewEventsRefs})
    >;
typedef $$ElementSchedulesTableCreateCompanionBuilder =
    ElementSchedulesCompanion Function({
      required String elementId,
      required int elementType,
      required String priorityKey,
      required int lifecycle,
      required int dueDay,
      required int originalDueDay,
      Value<String?> rootId,
      Value<String?> parentElementId,
      Value<int?> ordinal,
      Value<int?> createdAtUtc,
      Value<int?> updatedAtUtc,
      Value<int> revision,
      Value<int> legacyDueProvenance,
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
      Value<String?> rootId,
      Value<String?> parentElementId,
      Value<int?> ordinal,
      Value<int?> createdAtUtc,
      Value<int?> updatedAtUtc,
      Value<int> revision,
      Value<int> legacyDueProvenance,
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

  ColumnFilters<String> get rootId => $composableBuilder(
    column: $table.rootId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentElementId => $composableBuilder(
    column: $table.parentElementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get legacyDueProvenance => $composableBuilder(
    column: $table.legacyDueProvenance,
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

  ColumnOrderings<String> get rootId => $composableBuilder(
    column: $table.rootId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentElementId => $composableBuilder(
    column: $table.parentElementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get legacyDueProvenance => $composableBuilder(
    column: $table.legacyDueProvenance,
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

  GeneratedColumn<String> get rootId =>
      $composableBuilder(column: $table.rootId, builder: (column) => column);

  GeneratedColumn<String> get parentElementId => $composableBuilder(
    column: $table.parentElementId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get legacyDueProvenance => $composableBuilder(
    column: $table.legacyDueProvenance,
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
                Value<String?> rootId = const Value.absent(),
                Value<String?> parentElementId = const Value.absent(),
                Value<int?> ordinal = const Value.absent(),
                Value<int?> createdAtUtc = const Value.absent(),
                Value<int?> updatedAtUtc = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> legacyDueProvenance = const Value.absent(),
                Value<String> zoneId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ElementSchedulesCompanion(
                elementId: elementId,
                elementType: elementType,
                priorityKey: priorityKey,
                lifecycle: lifecycle,
                dueDay: dueDay,
                originalDueDay: originalDueDay,
                rootId: rootId,
                parentElementId: parentElementId,
                ordinal: ordinal,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                revision: revision,
                legacyDueProvenance: legacyDueProvenance,
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
                Value<String?> rootId = const Value.absent(),
                Value<String?> parentElementId = const Value.absent(),
                Value<int?> ordinal = const Value.absent(),
                Value<int?> createdAtUtc = const Value.absent(),
                Value<int?> updatedAtUtc = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> legacyDueProvenance = const Value.absent(),
                required String zoneId,
                Value<int> rowid = const Value.absent(),
              }) => ElementSchedulesCompanion.insert(
                elementId: elementId,
                elementType: elementType,
                priorityKey: priorityKey,
                lifecycle: lifecycle,
                dueDay: dueDay,
                originalDueDay: originalDueDay,
                rootId: rootId,
                parentElementId: parentElementId,
                ordinal: ordinal,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                revision: revision,
                legacyDueProvenance: legacyDueProvenance,
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
      required int status,
      Value<int> repetitionCount,
      Value<int> lapseCount,
      Value<int> storedInterval,
      Value<int?> lastReviewDay,
      Value<String> aFactorRaw,
      Value<String> lastIntervalRatioRaw,
      Value<int> historyBlockId,
      Value<int> recentPostponementCount,
      Value<int> totalPostponementCount,
      Value<int> learningControl,
      Value<int> encountersSinceLastCard,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$TopicStatesTableUpdateCompanionBuilder =
    TopicStatesCompanion Function({
      Value<String> elementId,
      Value<int> elementType,
      Value<int> status,
      Value<int> repetitionCount,
      Value<int> lapseCount,
      Value<int> storedInterval,
      Value<int?> lastReviewDay,
      Value<String> aFactorRaw,
      Value<String> lastIntervalRatioRaw,
      Value<int> historyBlockId,
      Value<int> recentPostponementCount,
      Value<int> totalPostponementCount,
      Value<int> learningControl,
      Value<int> encountersSinceLastCard,
      Value<int> revision,
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

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repetitionCount => $composableBuilder(
    column: $table.repetitionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapseCount => $composableBuilder(
    column: $table.lapseCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storedInterval => $composableBuilder(
    column: $table.storedInterval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReviewDay => $composableBuilder(
    column: $table.lastReviewDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aFactorRaw => $composableBuilder(
    column: $table.aFactorRaw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastIntervalRatioRaw => $composableBuilder(
    column: $table.lastIntervalRatioRaw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get historyBlockId => $composableBuilder(
    column: $table.historyBlockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recentPostponementCount => $composableBuilder(
    column: $table.recentPostponementCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPostponementCount => $composableBuilder(
    column: $table.totalPostponementCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get learningControl => $composableBuilder(
    column: $table.learningControl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encountersSinceLastCard => $composableBuilder(
    column: $table.encountersSinceLastCard,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
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

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repetitionCount => $composableBuilder(
    column: $table.repetitionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapseCount => $composableBuilder(
    column: $table.lapseCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storedInterval => $composableBuilder(
    column: $table.storedInterval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReviewDay => $composableBuilder(
    column: $table.lastReviewDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aFactorRaw => $composableBuilder(
    column: $table.aFactorRaw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastIntervalRatioRaw => $composableBuilder(
    column: $table.lastIntervalRatioRaw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get historyBlockId => $composableBuilder(
    column: $table.historyBlockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recentPostponementCount => $composableBuilder(
    column: $table.recentPostponementCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPostponementCount => $composableBuilder(
    column: $table.totalPostponementCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get learningControl => $composableBuilder(
    column: $table.learningControl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encountersSinceLastCard => $composableBuilder(
    column: $table.encountersSinceLastCard,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
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

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get repetitionCount => $composableBuilder(
    column: $table.repetitionCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lapseCount => $composableBuilder(
    column: $table.lapseCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get storedInterval => $composableBuilder(
    column: $table.storedInterval,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastReviewDay => $composableBuilder(
    column: $table.lastReviewDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aFactorRaw => $composableBuilder(
    column: $table.aFactorRaw,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastIntervalRatioRaw => $composableBuilder(
    column: $table.lastIntervalRatioRaw,
    builder: (column) => column,
  );

  GeneratedColumn<int> get historyBlockId => $composableBuilder(
    column: $table.historyBlockId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recentPostponementCount => $composableBuilder(
    column: $table.recentPostponementCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPostponementCount => $composableBuilder(
    column: $table.totalPostponementCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get learningControl => $composableBuilder(
    column: $table.learningControl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get encountersSinceLastCard => $composableBuilder(
    column: $table.encountersSinceLastCard,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
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
                Value<int> status = const Value.absent(),
                Value<int> repetitionCount = const Value.absent(),
                Value<int> lapseCount = const Value.absent(),
                Value<int> storedInterval = const Value.absent(),
                Value<int?> lastReviewDay = const Value.absent(),
                Value<String> aFactorRaw = const Value.absent(),
                Value<String> lastIntervalRatioRaw = const Value.absent(),
                Value<int> historyBlockId = const Value.absent(),
                Value<int> recentPostponementCount = const Value.absent(),
                Value<int> totalPostponementCount = const Value.absent(),
                Value<int> learningControl = const Value.absent(),
                Value<int> encountersSinceLastCard = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TopicStatesCompanion(
                elementId: elementId,
                elementType: elementType,
                status: status,
                repetitionCount: repetitionCount,
                lapseCount: lapseCount,
                storedInterval: storedInterval,
                lastReviewDay: lastReviewDay,
                aFactorRaw: aFactorRaw,
                lastIntervalRatioRaw: lastIntervalRatioRaw,
                historyBlockId: historyBlockId,
                recentPostponementCount: recentPostponementCount,
                totalPostponementCount: totalPostponementCount,
                learningControl: learningControl,
                encountersSinceLastCard: encountersSinceLastCard,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String elementId,
                required int elementType,
                required int status,
                Value<int> repetitionCount = const Value.absent(),
                Value<int> lapseCount = const Value.absent(),
                Value<int> storedInterval = const Value.absent(),
                Value<int?> lastReviewDay = const Value.absent(),
                Value<String> aFactorRaw = const Value.absent(),
                Value<String> lastIntervalRatioRaw = const Value.absent(),
                Value<int> historyBlockId = const Value.absent(),
                Value<int> recentPostponementCount = const Value.absent(),
                Value<int> totalPostponementCount = const Value.absent(),
                Value<int> learningControl = const Value.absent(),
                Value<int> encountersSinceLastCard = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TopicStatesCompanion.insert(
                elementId: elementId,
                elementType: elementType,
                status: status,
                repetitionCount: repetitionCount,
                lapseCount: lapseCount,
                storedInterval: storedInterval,
                lastReviewDay: lastReviewDay,
                aFactorRaw: aFactorRaw,
                lastIntervalRatioRaw: lastIntervalRatioRaw,
                historyBlockId: historyBlockId,
                recentPostponementCount: recentPostponementCount,
                totalPostponementCount: totalPostponementCount,
                learningControl: learningControl,
                encountersSinceLastCard: encountersSinceLastCard,
                revision: revision,
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
      Value<int> postponeCount,
      required String schedulerVersion,
      required String parametersVersion,
      Value<String> schedulerName,
      Value<double?> scheduledDays,
      Value<String?> fsrsStateJson,
      Value<int> revision,
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
      Value<int> postponeCount,
      Value<String> schedulerVersion,
      Value<String> parametersVersion,
      Value<String> schedulerName,
      Value<double?> scheduledDays,
      Value<String?> fsrsStateJson,
      Value<int> revision,
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

  ColumnFilters<int> get postponeCount => $composableBuilder(
    column: $table.postponeCount,
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

  ColumnFilters<String> get schedulerName => $composableBuilder(
    column: $table.schedulerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fsrsStateJson => $composableBuilder(
    column: $table.fsrsStateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
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

  ColumnOrderings<int> get postponeCount => $composableBuilder(
    column: $table.postponeCount,
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

  ColumnOrderings<String> get schedulerName => $composableBuilder(
    column: $table.schedulerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fsrsStateJson => $composableBuilder(
    column: $table.fsrsStateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
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

  GeneratedColumn<int> get postponeCount => $composableBuilder(
    column: $table.postponeCount,
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

  GeneratedColumn<String> get schedulerName => $composableBuilder(
    column: $table.schedulerName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fsrsStateJson => $composableBuilder(
    column: $table.fsrsStateJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

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
                Value<int> postponeCount = const Value.absent(),
                Value<String> schedulerVersion = const Value.absent(),
                Value<String> parametersVersion = const Value.absent(),
                Value<String> schedulerName = const Value.absent(),
                Value<double?> scheduledDays = const Value.absent(),
                Value<String?> fsrsStateJson = const Value.absent(),
                Value<int> revision = const Value.absent(),
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
                postponeCount: postponeCount,
                schedulerVersion: schedulerVersion,
                parametersVersion: parametersVersion,
                schedulerName: schedulerName,
                scheduledDays: scheduledDays,
                fsrsStateJson: fsrsStateJson,
                revision: revision,
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
                Value<int> postponeCount = const Value.absent(),
                required String schedulerVersion,
                required String parametersVersion,
                Value<String> schedulerName = const Value.absent(),
                Value<double?> scheduledDays = const Value.absent(),
                Value<String?> fsrsStateJson = const Value.absent(),
                Value<int> revision = const Value.absent(),
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
                postponeCount: postponeCount,
                schedulerVersion: schedulerVersion,
                parametersVersion: parametersVersion,
                schedulerName: schedulerName,
                scheduledDays: scheduledDays,
                fsrsStateJson: fsrsStateJson,
                revision: revision,
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
typedef $$RevlogEntriesTableCreateCompanionBuilder =
    RevlogEntriesCompanion Function({
      required String id,
      required String operationId,
      required String elementId,
      required int elementType,
      required int eventType,
      required int atUtc,
      Value<int?> grade,
      Value<double?> elapsedDays,
      Value<double?> scheduledDays,
      Value<int?> durationMs,
      Value<int?> postponeCount,
      Value<int?> dueBeforeUtc,
      Value<int?> dueAfterUtc,
      Value<double?> intervalBefore,
      Value<double?> intervalAfter,
      Value<double?> aFactorBefore,
      Value<double?> aFactorAfter,
      Value<double?> stabilityBefore,
      Value<double?> stabilityAfter,
      Value<double?> difficultyBefore,
      Value<double?> difficultyAfter,
      Value<int?> stateBefore,
      Value<int?> stateAfter,
      Value<int?> repsBefore,
      Value<int?> lapsesBefore,
      Value<String?> priorityBefore,
      Value<String?> priorityAfter,
      Value<double?> pressureBefore,
      Value<double?> pressureAfter,
      Value<double?> readFractionBefore,
      Value<double?> readFractionAfter,
      Value<int?> lifecycleBefore,
      Value<int?> lifecycleAfter,
      Value<String?> schedulerVersion,
      Value<String?> parametersVersion,
      Value<String?> metadataJson,
      Value<int> rowid,
    });
typedef $$RevlogEntriesTableUpdateCompanionBuilder =
    RevlogEntriesCompanion Function({
      Value<String> id,
      Value<String> operationId,
      Value<String> elementId,
      Value<int> elementType,
      Value<int> eventType,
      Value<int> atUtc,
      Value<int?> grade,
      Value<double?> elapsedDays,
      Value<double?> scheduledDays,
      Value<int?> durationMs,
      Value<int?> postponeCount,
      Value<int?> dueBeforeUtc,
      Value<int?> dueAfterUtc,
      Value<double?> intervalBefore,
      Value<double?> intervalAfter,
      Value<double?> aFactorBefore,
      Value<double?> aFactorAfter,
      Value<double?> stabilityBefore,
      Value<double?> stabilityAfter,
      Value<double?> difficultyBefore,
      Value<double?> difficultyAfter,
      Value<int?> stateBefore,
      Value<int?> stateAfter,
      Value<int?> repsBefore,
      Value<int?> lapsesBefore,
      Value<String?> priorityBefore,
      Value<String?> priorityAfter,
      Value<double?> pressureBefore,
      Value<double?> pressureAfter,
      Value<double?> readFractionBefore,
      Value<double?> readFractionAfter,
      Value<int?> lifecycleBefore,
      Value<int?> lifecycleAfter,
      Value<String?> schedulerVersion,
      Value<String?> parametersVersion,
      Value<String?> metadataJson,
      Value<int> rowid,
    });

class $$RevlogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $RevlogEntriesTable> {
  $$RevlogEntriesTableFilterComposer({
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

  ColumnFilters<int> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atUtc => $composableBuilder(
    column: $table.atUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get postponeCount => $composableBuilder(
    column: $table.postponeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueBeforeUtc => $composableBuilder(
    column: $table.dueBeforeUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueAfterUtc => $composableBuilder(
    column: $table.dueAfterUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get intervalBefore => $composableBuilder(
    column: $table.intervalBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get intervalAfter => $composableBuilder(
    column: $table.intervalAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aFactorBefore => $composableBuilder(
    column: $table.aFactorBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aFactorAfter => $composableBuilder(
    column: $table.aFactorAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stabilityBefore => $composableBuilder(
    column: $table.stabilityBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stabilityAfter => $composableBuilder(
    column: $table.stabilityAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficultyBefore => $composableBuilder(
    column: $table.difficultyBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficultyAfter => $composableBuilder(
    column: $table.difficultyAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stateAfter => $composableBuilder(
    column: $table.stateAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repsBefore => $composableBuilder(
    column: $table.repsBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapsesBefore => $composableBuilder(
    column: $table.lapsesBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priorityBefore => $composableBuilder(
    column: $table.priorityBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priorityAfter => $composableBuilder(
    column: $table.priorityAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pressureBefore => $composableBuilder(
    column: $table.pressureBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pressureAfter => $composableBuilder(
    column: $table.pressureAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get readFractionBefore => $composableBuilder(
    column: $table.readFractionBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get readFractionAfter => $composableBuilder(
    column: $table.readFractionAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lifecycleBefore => $composableBuilder(
    column: $table.lifecycleBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lifecycleAfter => $composableBuilder(
    column: $table.lifecycleAfter,
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

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RevlogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $RevlogEntriesTable> {
  $$RevlogEntriesTableOrderingComposer({
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

  ColumnOrderings<int> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atUtc => $composableBuilder(
    column: $table.atUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get postponeCount => $composableBuilder(
    column: $table.postponeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueBeforeUtc => $composableBuilder(
    column: $table.dueBeforeUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueAfterUtc => $composableBuilder(
    column: $table.dueAfterUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get intervalBefore => $composableBuilder(
    column: $table.intervalBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get intervalAfter => $composableBuilder(
    column: $table.intervalAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aFactorBefore => $composableBuilder(
    column: $table.aFactorBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aFactorAfter => $composableBuilder(
    column: $table.aFactorAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stabilityBefore => $composableBuilder(
    column: $table.stabilityBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stabilityAfter => $composableBuilder(
    column: $table.stabilityAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficultyBefore => $composableBuilder(
    column: $table.difficultyBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficultyAfter => $composableBuilder(
    column: $table.difficultyAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stateAfter => $composableBuilder(
    column: $table.stateAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repsBefore => $composableBuilder(
    column: $table.repsBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapsesBefore => $composableBuilder(
    column: $table.lapsesBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priorityBefore => $composableBuilder(
    column: $table.priorityBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priorityAfter => $composableBuilder(
    column: $table.priorityAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pressureBefore => $composableBuilder(
    column: $table.pressureBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pressureAfter => $composableBuilder(
    column: $table.pressureAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get readFractionBefore => $composableBuilder(
    column: $table.readFractionBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get readFractionAfter => $composableBuilder(
    column: $table.readFractionAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lifecycleBefore => $composableBuilder(
    column: $table.lifecycleBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lifecycleAfter => $composableBuilder(
    column: $table.lifecycleAfter,
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

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RevlogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RevlogEntriesTable> {
  $$RevlogEntriesTableAnnotationComposer({
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

  GeneratedColumn<int> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<int> get atUtc =>
      $composableBuilder(column: $table.atUtc, builder: (column) => column);

  GeneratedColumn<int> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);

  GeneratedColumn<double> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get postponeCount => $composableBuilder(
    column: $table.postponeCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueBeforeUtc => $composableBuilder(
    column: $table.dueBeforeUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueAfterUtc => $composableBuilder(
    column: $table.dueAfterUtc,
    builder: (column) => column,
  );

  GeneratedColumn<double> get intervalBefore => $composableBuilder(
    column: $table.intervalBefore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get intervalAfter => $composableBuilder(
    column: $table.intervalAfter,
    builder: (column) => column,
  );

  GeneratedColumn<double> get aFactorBefore => $composableBuilder(
    column: $table.aFactorBefore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get aFactorAfter => $composableBuilder(
    column: $table.aFactorAfter,
    builder: (column) => column,
  );

  GeneratedColumn<double> get stabilityBefore => $composableBuilder(
    column: $table.stabilityBefore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get stabilityAfter => $composableBuilder(
    column: $table.stabilityAfter,
    builder: (column) => column,
  );

  GeneratedColumn<double> get difficultyBefore => $composableBuilder(
    column: $table.difficultyBefore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get difficultyAfter => $composableBuilder(
    column: $table.difficultyAfter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stateAfter => $composableBuilder(
    column: $table.stateAfter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repsBefore => $composableBuilder(
    column: $table.repsBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lapsesBefore => $composableBuilder(
    column: $table.lapsesBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priorityBefore => $composableBuilder(
    column: $table.priorityBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priorityAfter => $composableBuilder(
    column: $table.priorityAfter,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pressureBefore => $composableBuilder(
    column: $table.pressureBefore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pressureAfter => $composableBuilder(
    column: $table.pressureAfter,
    builder: (column) => column,
  );

  GeneratedColumn<double> get readFractionBefore => $composableBuilder(
    column: $table.readFractionBefore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get readFractionAfter => $composableBuilder(
    column: $table.readFractionAfter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lifecycleBefore => $composableBuilder(
    column: $table.lifecycleBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lifecycleAfter => $composableBuilder(
    column: $table.lifecycleAfter,
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

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );
}

class $$RevlogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RevlogEntriesTable,
          RevlogRow,
          $$RevlogEntriesTableFilterComposer,
          $$RevlogEntriesTableOrderingComposer,
          $$RevlogEntriesTableAnnotationComposer,
          $$RevlogEntriesTableCreateCompanionBuilder,
          $$RevlogEntriesTableUpdateCompanionBuilder,
          (
            RevlogRow,
            BaseReferences<_$AppDatabase, $RevlogEntriesTable, RevlogRow>,
          ),
          RevlogRow,
          PrefetchHooks Function()
        > {
  $$RevlogEntriesTableTableManager(_$AppDatabase db, $RevlogEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RevlogEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RevlogEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RevlogEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> elementId = const Value.absent(),
                Value<int> elementType = const Value.absent(),
                Value<int> eventType = const Value.absent(),
                Value<int> atUtc = const Value.absent(),
                Value<int?> grade = const Value.absent(),
                Value<double?> elapsedDays = const Value.absent(),
                Value<double?> scheduledDays = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> postponeCount = const Value.absent(),
                Value<int?> dueBeforeUtc = const Value.absent(),
                Value<int?> dueAfterUtc = const Value.absent(),
                Value<double?> intervalBefore = const Value.absent(),
                Value<double?> intervalAfter = const Value.absent(),
                Value<double?> aFactorBefore = const Value.absent(),
                Value<double?> aFactorAfter = const Value.absent(),
                Value<double?> stabilityBefore = const Value.absent(),
                Value<double?> stabilityAfter = const Value.absent(),
                Value<double?> difficultyBefore = const Value.absent(),
                Value<double?> difficultyAfter = const Value.absent(),
                Value<int?> stateBefore = const Value.absent(),
                Value<int?> stateAfter = const Value.absent(),
                Value<int?> repsBefore = const Value.absent(),
                Value<int?> lapsesBefore = const Value.absent(),
                Value<String?> priorityBefore = const Value.absent(),
                Value<String?> priorityAfter = const Value.absent(),
                Value<double?> pressureBefore = const Value.absent(),
                Value<double?> pressureAfter = const Value.absent(),
                Value<double?> readFractionBefore = const Value.absent(),
                Value<double?> readFractionAfter = const Value.absent(),
                Value<int?> lifecycleBefore = const Value.absent(),
                Value<int?> lifecycleAfter = const Value.absent(),
                Value<String?> schedulerVersion = const Value.absent(),
                Value<String?> parametersVersion = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RevlogEntriesCompanion(
                id: id,
                operationId: operationId,
                elementId: elementId,
                elementType: elementType,
                eventType: eventType,
                atUtc: atUtc,
                grade: grade,
                elapsedDays: elapsedDays,
                scheduledDays: scheduledDays,
                durationMs: durationMs,
                postponeCount: postponeCount,
                dueBeforeUtc: dueBeforeUtc,
                dueAfterUtc: dueAfterUtc,
                intervalBefore: intervalBefore,
                intervalAfter: intervalAfter,
                aFactorBefore: aFactorBefore,
                aFactorAfter: aFactorAfter,
                stabilityBefore: stabilityBefore,
                stabilityAfter: stabilityAfter,
                difficultyBefore: difficultyBefore,
                difficultyAfter: difficultyAfter,
                stateBefore: stateBefore,
                stateAfter: stateAfter,
                repsBefore: repsBefore,
                lapsesBefore: lapsesBefore,
                priorityBefore: priorityBefore,
                priorityAfter: priorityAfter,
                pressureBefore: pressureBefore,
                pressureAfter: pressureAfter,
                readFractionBefore: readFractionBefore,
                readFractionAfter: readFractionAfter,
                lifecycleBefore: lifecycleBefore,
                lifecycleAfter: lifecycleAfter,
                schedulerVersion: schedulerVersion,
                parametersVersion: parametersVersion,
                metadataJson: metadataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String operationId,
                required String elementId,
                required int elementType,
                required int eventType,
                required int atUtc,
                Value<int?> grade = const Value.absent(),
                Value<double?> elapsedDays = const Value.absent(),
                Value<double?> scheduledDays = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> postponeCount = const Value.absent(),
                Value<int?> dueBeforeUtc = const Value.absent(),
                Value<int?> dueAfterUtc = const Value.absent(),
                Value<double?> intervalBefore = const Value.absent(),
                Value<double?> intervalAfter = const Value.absent(),
                Value<double?> aFactorBefore = const Value.absent(),
                Value<double?> aFactorAfter = const Value.absent(),
                Value<double?> stabilityBefore = const Value.absent(),
                Value<double?> stabilityAfter = const Value.absent(),
                Value<double?> difficultyBefore = const Value.absent(),
                Value<double?> difficultyAfter = const Value.absent(),
                Value<int?> stateBefore = const Value.absent(),
                Value<int?> stateAfter = const Value.absent(),
                Value<int?> repsBefore = const Value.absent(),
                Value<int?> lapsesBefore = const Value.absent(),
                Value<String?> priorityBefore = const Value.absent(),
                Value<String?> priorityAfter = const Value.absent(),
                Value<double?> pressureBefore = const Value.absent(),
                Value<double?> pressureAfter = const Value.absent(),
                Value<double?> readFractionBefore = const Value.absent(),
                Value<double?> readFractionAfter = const Value.absent(),
                Value<int?> lifecycleBefore = const Value.absent(),
                Value<int?> lifecycleAfter = const Value.absent(),
                Value<String?> schedulerVersion = const Value.absent(),
                Value<String?> parametersVersion = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RevlogEntriesCompanion.insert(
                id: id,
                operationId: operationId,
                elementId: elementId,
                elementType: elementType,
                eventType: eventType,
                atUtc: atUtc,
                grade: grade,
                elapsedDays: elapsedDays,
                scheduledDays: scheduledDays,
                durationMs: durationMs,
                postponeCount: postponeCount,
                dueBeforeUtc: dueBeforeUtc,
                dueAfterUtc: dueAfterUtc,
                intervalBefore: intervalBefore,
                intervalAfter: intervalAfter,
                aFactorBefore: aFactorBefore,
                aFactorAfter: aFactorAfter,
                stabilityBefore: stabilityBefore,
                stabilityAfter: stabilityAfter,
                difficultyBefore: difficultyBefore,
                difficultyAfter: difficultyAfter,
                stateBefore: stateBefore,
                stateAfter: stateAfter,
                repsBefore: repsBefore,
                lapsesBefore: lapsesBefore,
                priorityBefore: priorityBefore,
                priorityAfter: priorityAfter,
                pressureBefore: pressureBefore,
                pressureAfter: pressureAfter,
                readFractionBefore: readFractionBefore,
                readFractionAfter: readFractionAfter,
                lifecycleBefore: lifecycleBefore,
                lifecycleAfter: lifecycleAfter,
                schedulerVersion: schedulerVersion,
                parametersVersion: parametersVersion,
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

typedef $$RevlogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RevlogEntriesTable,
      RevlogRow,
      $$RevlogEntriesTableFilterComposer,
      $$RevlogEntriesTableOrderingComposer,
      $$RevlogEntriesTableAnnotationComposer,
      $$RevlogEntriesTableCreateCompanionBuilder,
      $$RevlogEntriesTableUpdateCompanionBuilder,
      (
        RevlogRow,
        BaseReferences<_$AppDatabase, $RevlogEntriesTable, RevlogRow>,
      ),
      RevlogRow,
      PrefetchHooks Function()
    >;
typedef $$SchedulerEventsTableCreateCompanionBuilder =
    SchedulerEventsCompanion Function({
      required String id,
      required String operationId,
      Value<String?> elementId,
      Value<int?> elementType,
      required String eventType,
      required int occurredAtUtc,
      required int studyDay,
      required String studyDayZoneId,
      Value<String?> schedulerName,
      Value<String?> schedulerVersion,
      required String policyVersion,
      Value<String?> stateBefore,
      Value<String?> stateAfter,
      Value<String?> algorithmicDueBefore,
      Value<String?> algorithmicDueAfter,
      Value<String?> undoesEventId,
      Value<String?> batchId,
      Value<String?> metadataJson,
      Value<int> rowid,
    });
typedef $$SchedulerEventsTableUpdateCompanionBuilder =
    SchedulerEventsCompanion Function({
      Value<String> id,
      Value<String> operationId,
      Value<String?> elementId,
      Value<int?> elementType,
      Value<String> eventType,
      Value<int> occurredAtUtc,
      Value<int> studyDay,
      Value<String> studyDayZoneId,
      Value<String?> schedulerName,
      Value<String?> schedulerVersion,
      Value<String> policyVersion,
      Value<String?> stateBefore,
      Value<String?> stateAfter,
      Value<String?> algorithmicDueBefore,
      Value<String?> algorithmicDueAfter,
      Value<String?> undoesEventId,
      Value<String?> batchId,
      Value<String?> metadataJson,
      Value<int> rowid,
    });

class $$SchedulerEventsTableFilterComposer
    extends Composer<_$AppDatabase, $SchedulerEventsTable> {
  $$SchedulerEventsTableFilterComposer({
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

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAtUtc => $composableBuilder(
    column: $table.occurredAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get studyDay => $composableBuilder(
    column: $table.studyDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studyDayZoneId => $composableBuilder(
    column: $table.studyDayZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schedulerName => $composableBuilder(
    column: $table.schedulerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schedulerVersion => $composableBuilder(
    column: $table.schedulerVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get policyVersion => $composableBuilder(
    column: $table.policyVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateAfter => $composableBuilder(
    column: $table.stateAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmicDueBefore => $composableBuilder(
    column: $table.algorithmicDueBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmicDueAfter => $composableBuilder(
    column: $table.algorithmicDueAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get undoesEventId => $composableBuilder(
    column: $table.undoesEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get batchId => $composableBuilder(
    column: $table.batchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SchedulerEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $SchedulerEventsTable> {
  $$SchedulerEventsTableOrderingComposer({
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

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAtUtc => $composableBuilder(
    column: $table.occurredAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get studyDay => $composableBuilder(
    column: $table.studyDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studyDayZoneId => $composableBuilder(
    column: $table.studyDayZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schedulerName => $composableBuilder(
    column: $table.schedulerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schedulerVersion => $composableBuilder(
    column: $table.schedulerVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get policyVersion => $composableBuilder(
    column: $table.policyVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateAfter => $composableBuilder(
    column: $table.stateAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmicDueBefore => $composableBuilder(
    column: $table.algorithmicDueBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmicDueAfter => $composableBuilder(
    column: $table.algorithmicDueAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get undoesEventId => $composableBuilder(
    column: $table.undoesEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get batchId => $composableBuilder(
    column: $table.batchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SchedulerEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SchedulerEventsTable> {
  $$SchedulerEventsTableAnnotationComposer({
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

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<int> get occurredAtUtc => $composableBuilder(
    column: $table.occurredAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get studyDay =>
      $composableBuilder(column: $table.studyDay, builder: (column) => column);

  GeneratedColumn<String> get studyDayZoneId => $composableBuilder(
    column: $table.studyDayZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get schedulerName => $composableBuilder(
    column: $table.schedulerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get schedulerVersion => $composableBuilder(
    column: $table.schedulerVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get policyVersion => $composableBuilder(
    column: $table.policyVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stateAfter => $composableBuilder(
    column: $table.stateAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get algorithmicDueBefore => $composableBuilder(
    column: $table.algorithmicDueBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get algorithmicDueAfter => $composableBuilder(
    column: $table.algorithmicDueAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get undoesEventId => $composableBuilder(
    column: $table.undoesEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get batchId =>
      $composableBuilder(column: $table.batchId, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );
}

class $$SchedulerEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SchedulerEventsTable,
          SchedulerEventRow,
          $$SchedulerEventsTableFilterComposer,
          $$SchedulerEventsTableOrderingComposer,
          $$SchedulerEventsTableAnnotationComposer,
          $$SchedulerEventsTableCreateCompanionBuilder,
          $$SchedulerEventsTableUpdateCompanionBuilder,
          (
            SchedulerEventRow,
            BaseReferences<
              _$AppDatabase,
              $SchedulerEventsTable,
              SchedulerEventRow
            >,
          ),
          SchedulerEventRow,
          PrefetchHooks Function()
        > {
  $$SchedulerEventsTableTableManager(
    _$AppDatabase db,
    $SchedulerEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchedulerEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchedulerEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchedulerEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String?> elementId = const Value.absent(),
                Value<int?> elementType = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<int> occurredAtUtc = const Value.absent(),
                Value<int> studyDay = const Value.absent(),
                Value<String> studyDayZoneId = const Value.absent(),
                Value<String?> schedulerName = const Value.absent(),
                Value<String?> schedulerVersion = const Value.absent(),
                Value<String> policyVersion = const Value.absent(),
                Value<String?> stateBefore = const Value.absent(),
                Value<String?> stateAfter = const Value.absent(),
                Value<String?> algorithmicDueBefore = const Value.absent(),
                Value<String?> algorithmicDueAfter = const Value.absent(),
                Value<String?> undoesEventId = const Value.absent(),
                Value<String?> batchId = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchedulerEventsCompanion(
                id: id,
                operationId: operationId,
                elementId: elementId,
                elementType: elementType,
                eventType: eventType,
                occurredAtUtc: occurredAtUtc,
                studyDay: studyDay,
                studyDayZoneId: studyDayZoneId,
                schedulerName: schedulerName,
                schedulerVersion: schedulerVersion,
                policyVersion: policyVersion,
                stateBefore: stateBefore,
                stateAfter: stateAfter,
                algorithmicDueBefore: algorithmicDueBefore,
                algorithmicDueAfter: algorithmicDueAfter,
                undoesEventId: undoesEventId,
                batchId: batchId,
                metadataJson: metadataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String operationId,
                Value<String?> elementId = const Value.absent(),
                Value<int?> elementType = const Value.absent(),
                required String eventType,
                required int occurredAtUtc,
                required int studyDay,
                required String studyDayZoneId,
                Value<String?> schedulerName = const Value.absent(),
                Value<String?> schedulerVersion = const Value.absent(),
                required String policyVersion,
                Value<String?> stateBefore = const Value.absent(),
                Value<String?> stateAfter = const Value.absent(),
                Value<String?> algorithmicDueBefore = const Value.absent(),
                Value<String?> algorithmicDueAfter = const Value.absent(),
                Value<String?> undoesEventId = const Value.absent(),
                Value<String?> batchId = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchedulerEventsCompanion.insert(
                id: id,
                operationId: operationId,
                elementId: elementId,
                elementType: elementType,
                eventType: eventType,
                occurredAtUtc: occurredAtUtc,
                studyDay: studyDay,
                studyDayZoneId: studyDayZoneId,
                schedulerName: schedulerName,
                schedulerVersion: schedulerVersion,
                policyVersion: policyVersion,
                stateBefore: stateBefore,
                stateAfter: stateAfter,
                algorithmicDueBefore: algorithmicDueBefore,
                algorithmicDueAfter: algorithmicDueAfter,
                undoesEventId: undoesEventId,
                batchId: batchId,
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

typedef $$SchedulerEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SchedulerEventsTable,
      SchedulerEventRow,
      $$SchedulerEventsTableFilterComposer,
      $$SchedulerEventsTableOrderingComposer,
      $$SchedulerEventsTableAnnotationComposer,
      $$SchedulerEventsTableCreateCompanionBuilder,
      $$SchedulerEventsTableUpdateCompanionBuilder,
      (
        SchedulerEventRow,
        BaseReferences<_$AppDatabase, $SchedulerEventsTable, SchedulerEventRow>,
      ),
      SchedulerEventRow,
      PrefetchHooks Function()
    >;
typedef $$MercyBatchesTableCreateCompanionBuilder =
    MercyBatchesCompanion Function({
      required String batchId,
      required String previewOperationId,
      Value<String?> applyOperationId,
      Value<String?> undoOperationId,
      required String policyVersion,
      required String previewJson,
      Value<String?> appliedSnapshotJson,
      required int createdAtUtc,
      Value<int?> appliedAtUtc,
      Value<int?> undoneAtUtc,
      Value<int> rowid,
    });
typedef $$MercyBatchesTableUpdateCompanionBuilder =
    MercyBatchesCompanion Function({
      Value<String> batchId,
      Value<String> previewOperationId,
      Value<String?> applyOperationId,
      Value<String?> undoOperationId,
      Value<String> policyVersion,
      Value<String> previewJson,
      Value<String?> appliedSnapshotJson,
      Value<int> createdAtUtc,
      Value<int?> appliedAtUtc,
      Value<int?> undoneAtUtc,
      Value<int> rowid,
    });

class $$MercyBatchesTableFilterComposer
    extends Composer<_$AppDatabase, $MercyBatchesTable> {
  $$MercyBatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get batchId => $composableBuilder(
    column: $table.batchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewOperationId => $composableBuilder(
    column: $table.previewOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get applyOperationId => $composableBuilder(
    column: $table.applyOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get undoOperationId => $composableBuilder(
    column: $table.undoOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get policyVersion => $composableBuilder(
    column: $table.policyVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewJson => $composableBuilder(
    column: $table.previewJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appliedSnapshotJson => $composableBuilder(
    column: $table.appliedSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get appliedAtUtc => $composableBuilder(
    column: $table.appliedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get undoneAtUtc => $composableBuilder(
    column: $table.undoneAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MercyBatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $MercyBatchesTable> {
  $$MercyBatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get batchId => $composableBuilder(
    column: $table.batchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewOperationId => $composableBuilder(
    column: $table.previewOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get applyOperationId => $composableBuilder(
    column: $table.applyOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get undoOperationId => $composableBuilder(
    column: $table.undoOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get policyVersion => $composableBuilder(
    column: $table.policyVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewJson => $composableBuilder(
    column: $table.previewJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appliedSnapshotJson => $composableBuilder(
    column: $table.appliedSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get appliedAtUtc => $composableBuilder(
    column: $table.appliedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get undoneAtUtc => $composableBuilder(
    column: $table.undoneAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MercyBatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MercyBatchesTable> {
  $$MercyBatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get batchId =>
      $composableBuilder(column: $table.batchId, builder: (column) => column);

  GeneratedColumn<String> get previewOperationId => $composableBuilder(
    column: $table.previewOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get applyOperationId => $composableBuilder(
    column: $table.applyOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get undoOperationId => $composableBuilder(
    column: $table.undoOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get policyVersion => $composableBuilder(
    column: $table.policyVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previewJson => $composableBuilder(
    column: $table.previewJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appliedSnapshotJson => $composableBuilder(
    column: $table.appliedSnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get appliedAtUtc => $composableBuilder(
    column: $table.appliedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get undoneAtUtc => $composableBuilder(
    column: $table.undoneAtUtc,
    builder: (column) => column,
  );
}

class $$MercyBatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MercyBatchesTable,
          MercyBatchRow,
          $$MercyBatchesTableFilterComposer,
          $$MercyBatchesTableOrderingComposer,
          $$MercyBatchesTableAnnotationComposer,
          $$MercyBatchesTableCreateCompanionBuilder,
          $$MercyBatchesTableUpdateCompanionBuilder,
          (
            MercyBatchRow,
            BaseReferences<_$AppDatabase, $MercyBatchesTable, MercyBatchRow>,
          ),
          MercyBatchRow,
          PrefetchHooks Function()
        > {
  $$MercyBatchesTableTableManager(_$AppDatabase db, $MercyBatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MercyBatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MercyBatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MercyBatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> batchId = const Value.absent(),
                Value<String> previewOperationId = const Value.absent(),
                Value<String?> applyOperationId = const Value.absent(),
                Value<String?> undoOperationId = const Value.absent(),
                Value<String> policyVersion = const Value.absent(),
                Value<String> previewJson = const Value.absent(),
                Value<String?> appliedSnapshotJson = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int?> appliedAtUtc = const Value.absent(),
                Value<int?> undoneAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MercyBatchesCompanion(
                batchId: batchId,
                previewOperationId: previewOperationId,
                applyOperationId: applyOperationId,
                undoOperationId: undoOperationId,
                policyVersion: policyVersion,
                previewJson: previewJson,
                appliedSnapshotJson: appliedSnapshotJson,
                createdAtUtc: createdAtUtc,
                appliedAtUtc: appliedAtUtc,
                undoneAtUtc: undoneAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String batchId,
                required String previewOperationId,
                Value<String?> applyOperationId = const Value.absent(),
                Value<String?> undoOperationId = const Value.absent(),
                required String policyVersion,
                required String previewJson,
                Value<String?> appliedSnapshotJson = const Value.absent(),
                required int createdAtUtc,
                Value<int?> appliedAtUtc = const Value.absent(),
                Value<int?> undoneAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MercyBatchesCompanion.insert(
                batchId: batchId,
                previewOperationId: previewOperationId,
                applyOperationId: applyOperationId,
                undoOperationId: undoOperationId,
                policyVersion: policyVersion,
                previewJson: previewJson,
                appliedSnapshotJson: appliedSnapshotJson,
                createdAtUtc: createdAtUtc,
                appliedAtUtc: appliedAtUtc,
                undoneAtUtc: undoneAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MercyBatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MercyBatchesTable,
      MercyBatchRow,
      $$MercyBatchesTableFilterComposer,
      $$MercyBatchesTableOrderingComposer,
      $$MercyBatchesTableAnnotationComposer,
      $$MercyBatchesTableCreateCompanionBuilder,
      $$MercyBatchesTableUpdateCompanionBuilder,
      (
        MercyBatchRow,
        BaseReferences<_$AppDatabase, $MercyBatchesTable, MercyBatchRow>,
      ),
      MercyBatchRow,
      PrefetchHooks Function()
    >;
typedef $$SearchDocumentsTableCreateCompanionBuilder =
    SearchDocumentsCompanion Function({
      required String elementId,
      required int elementType,
      required String title,
      required String body,
      Value<String?> sourceId,
      required int updatedAtUtc,
      Value<int> rowid,
    });
typedef $$SearchDocumentsTableUpdateCompanionBuilder =
    SearchDocumentsCompanion Function({
      Value<String> elementId,
      Value<int> elementType,
      Value<String> title,
      Value<String> body,
      Value<String?> sourceId,
      Value<int> updatedAtUtc,
      Value<int> rowid,
    });

class $$SearchDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $SearchDocumentsTable> {
  $$SearchDocumentsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchDocumentsTable> {
  $$SearchDocumentsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchDocumentsTable> {
  $$SearchDocumentsTableAnnotationComposer({
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

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$SearchDocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchDocumentsTable,
          SearchDocumentRow,
          $$SearchDocumentsTableFilterComposer,
          $$SearchDocumentsTableOrderingComposer,
          $$SearchDocumentsTableAnnotationComposer,
          $$SearchDocumentsTableCreateCompanionBuilder,
          $$SearchDocumentsTableUpdateCompanionBuilder,
          (
            SearchDocumentRow,
            BaseReferences<
              _$AppDatabase,
              $SearchDocumentsTable,
              SearchDocumentRow
            >,
          ),
          SearchDocumentRow,
          PrefetchHooks Function()
        > {
  $$SearchDocumentsTableTableManager(
    _$AppDatabase db,
    $SearchDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> elementId = const Value.absent(),
                Value<int> elementType = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchDocumentsCompanion(
                elementId: elementId,
                elementType: elementType,
                title: title,
                body: body,
                sourceId: sourceId,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String elementId,
                required int elementType,
                required String title,
                required String body,
                Value<String?> sourceId = const Value.absent(),
                required int updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => SearchDocumentsCompanion.insert(
                elementId: elementId,
                elementType: elementType,
                title: title,
                body: body,
                sourceId: sourceId,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchDocumentsTable,
      SearchDocumentRow,
      $$SearchDocumentsTableFilterComposer,
      $$SearchDocumentsTableOrderingComposer,
      $$SearchDocumentsTableAnnotationComposer,
      $$SearchDocumentsTableCreateCompanionBuilder,
      $$SearchDocumentsTableUpdateCompanionBuilder,
      (
        SearchDocumentRow,
        BaseReferences<_$AppDatabase, $SearchDocumentsTable, SearchDocumentRow>,
      ),
      SearchDocumentRow,
      PrefetchHooks Function()
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
  $$RevlogEntriesTableTableManager get revlogEntries =>
      $$RevlogEntriesTableTableManager(_db, _db.revlogEntries);
  $$SchedulerEventsTableTableManager get schedulerEvents =>
      $$SchedulerEventsTableTableManager(_db, _db.schedulerEvents);
  $$MercyBatchesTableTableManager get mercyBatches =>
      $$MercyBatchesTableTableManager(_db, _db.mercyBatches);
  $$SearchDocumentsTableTableManager get searchDocuments =>
      $$SearchDocumentsTableTableManager(_db, _db.searchDocuments);
  $$ActivityEventsTableTableManager get activityEvents =>
      $$ActivityEventsTableTableManager(_db, _db.activityEvents);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$DatasetMetaTableTableManager get datasetMeta =>
      $$DatasetMetaTableTableManager(_db, _db.datasetMeta);
}
