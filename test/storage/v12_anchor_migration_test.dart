/// The v11 to v12 upgrade: block-relative anchors become document offsets.
///
/// The upgrade has to be exact for rows it can resolve, and honest about the
/// ones it cannot. Inventing a plausible position for an anchor whose block is
/// missing would be worse than leaving none, because the user has no way to
/// tell an invented position from a real one.
library;

import 'dart:io';

import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/markdown_block_parser.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:test/test.dart';

const String _markdown = '''
# Chlorophyll

Photosynthesis converts light into chemical energy.

Chlorophyll absorbs blue and red light most strongly.
''';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir-v12-');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  Future<AppDatabase> openFileDatabase() async {
    final AppDatabase db = openDatabaseAt(
      File('${workspace.path}/db/$kDatabaseFileName'),
    );
    await db.customSelect('SELECT 1').getSingle();
    return db;
  }

  /// Puts a v11-shaped collection in place: block-relative anchor columns on
  /// `sources` and `extracts`, and no `source_edits` table.
  ///
  /// The current tables are rebuilt back into their v11 shape rather than
  /// stamped over, so the upgrade under test reads a schema that really
  /// existed instead of one this test invented.
  Future<void> seedV11(AppDatabase db) async {
    await db.customStatement('DROP TABLE IF EXISTS source_edits');

    for (final String statement in <String>[
      'ALTER TABLE sources ADD COLUMN marker_block_id TEXT NULL',
      'ALTER TABLE sources ADD COLUMN marker_offset INTEGER NULL',
      'ALTER TABLE sources ADD COLUMN soft_block_id TEXT NULL',
      'ALTER TABLE sources ADD COLUMN soft_offset INTEGER NULL',
      'ALTER TABLE extracts ADD COLUMN start_block_id TEXT NULL',
      'ALTER TABLE extracts ADD COLUMN start_offset INTEGER NULL',
      'ALTER TABLE extracts ADD COLUMN end_block_id TEXT NULL',
      'ALTER TABLE extracts ADD COLUMN end_offset INTEGER NULL',
    ]) {
      await db.customStatement(statement);
    }

    final Document document = Document.parse(
      sourceId: 's1',
      markdown: normalizeMarkdown(_markdown),
    );

    await db.customStatement(
      'INSERT INTO sources (id, title, markdown, content_hash, word_count, '
      'imported_at_utc, revision, content_revision, marker_block_id, '
      'marker_offset, soft_block_id, soft_offset) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        's1',
        'Chlorophyll',
        document.markdown,
        'a' * 64,
        document.markdown.split(RegExp(r'\s+')).length,
        1000,
        1,
        1,
        document.blocks[2].id,
        11,
        document.blocks[1].id,
        0,
      ],
    );
    for (final block in document.blocks) {
      await db.customStatement(
        'INSERT INTO blocks (id, source_id, idx, type, raw, start_utf8, '
        'end_utf8, start_utf16, content_spans) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          block.id,
          's1',
          block.index,
          block.type.index,
          block.raw,
          block.sourceStartUtf8,
          block.sourceEndUtf8,
          block.sourceStartUtf16,
          '[[0,${block.raw.length}]]',
        ],
      );
    }

    // One extract whose text is still exactly there, and one whose block no
    // longer exists at all.
    final block = document.blocks[2];
    final String passage = block.raw.substring(0, 19);
    await db.customStatement(
      'INSERT INTO extracts (id, markdown, source_id, parent_id, '
      'parent_is_source, start_block_id, start_offset, end_block_id, '
      'end_offset, selected_text_hash, created_at_utc, anchor_revision, '
      'provenance_state, content_revision, start_utf8, end_utf8) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        'x-intact',
        passage,
        's1',
        's1',
        1,
        block.id,
        0,
        block.id,
        19,
        hashSelection(passage),
        1100,
        1,
        0,
        1,
        // Placeholders: the upgrade overwrites both from the block columns.
        0,
        0,
      ],
    );
    await db.customStatement(
      'INSERT INTO extracts (id, markdown, source_id, parent_id, '
      'parent_is_source, start_block_id, start_offset, end_block_id, '
      'end_offset, selected_text_hash, created_at_utc, anchor_revision, '
      'provenance_state, content_revision, start_utf8, end_utf8) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        'x-lost',
        'a passage whose block is gone',
        's1',
        's1',
        1,
        's1:99',
        0,
        's1:99',
        5,
        'b' * 64,
        1200,
        1,
        0,
        1,
        0,
        0,
      ],
    );

    // Only now drop the v12 columns, so the seed could use them to satisfy
    // the current NOT NULL definitions while inserting.
    await db.customStatement('PRAGMA user_version = 11');
  }

  test('resolvable anchors become exact document offsets', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV11(seeded);
    final Document document = Document.parse(
      sourceId: 's1',
      markdown: normalizeMarkdown(_markdown),
    );
    final int expectedMarker = document.blocks[2].sourceStartUtf8 + 11;
    final int expectedSoft = document.blocks[1].sourceStartUtf8;
    await seeded.close();

    final AppDatabase upgraded = await openFileDatabase();
    addTearDown(upgraded.close);

    final row =
        (await upgraded
                .customSelect(
                  'SELECT marker_utf8, marker_revision, soft_utf8, '
                  "soft_revision, content_revision FROM sources WHERE id = 's1'",
                )
                .get())
            .single;

    expect(row.read<int>('marker_utf8'), expectedMarker);
    expect(row.read<int>('marker_revision'), kInitialContentRevision);
    expect(row.read<int>('soft_utf8'), expectedSoft);
    expect(row.read<int>('content_revision'), kInitialContentRevision);
  });

  test('an extract whose text still matches is graded verbatim', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV11(seeded);
    await seeded.close();

    final AppDatabase upgraded = await openFileDatabase();
    addTearDown(upgraded.close);

    final row =
        (await upgraded
                .customSelect(
                  'SELECT start_utf8, end_utf8, provenance_state, '
                  "anchor_revision FROM extracts WHERE id = 'x-intact'",
                )
                .get())
            .single;

    final Document document = Document.parse(
      sourceId: 's1',
      markdown: normalizeMarkdown(_markdown),
    );
    expect(row.read<int>('start_utf8'), document.blocks[2].sourceStartUtf8);
    expect(
      row.read<int>('provenance_state'),
      ProvenanceState.verbatim.index,
    );
    expect(row.read<int>('anchor_revision'), kInitialContentRevision);
    expect(
      document.markdownSlice(
        row.read<int>('start_utf8'),
        row.read<int>('end_utf8'),
      ),
      'Chlorophyll absorbs',
      reason: 'the converted range covers exactly the extracted words',
    );
  });

  test('an anchor whose block is gone becomes an orphan, never a guess', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV11(seeded);
    await seeded.close();

    final AppDatabase upgraded = await openFileDatabase();
    addTearDown(upgraded.close);

    final row =
        (await upgraded
                .customSelect(
                  'SELECT start_utf8, end_utf8, provenance_state, markdown '
                  "FROM extracts WHERE id = 'x-lost'",
                )
                .get())
            .single;

    expect(row.read<int>('provenance_state'), ProvenanceState.orphaned.index);
    expect(row.read<int>('start_utf8'), 0);
    expect(row.read<int>('end_utf8'), 0);
    expect(
      row.read<String>('markdown'),
      'a passage whose block is gone',
      reason: 'the extract keeps its own text whatever happened to the link',
    );
  });

  test('the retired columns are gone and the journal exists', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV11(seeded);
    await seeded.close();

    final AppDatabase upgraded = await openFileDatabase();
    addTearDown(upgraded.close);

    Future<Set<String>> columnsOf(String table) async => <String>{
      for (final row in await upgraded
          .customSelect('PRAGMA table_info($table)')
          .get())
        row.read<String>('name'),
    };

    final sources = await columnsOf('sources');
    expect(sources, isNot(contains('marker_block_id')));
    expect(sources, isNot(contains('soft_offset')));
    expect(sources, contains('content_revision'));

    final extracts = await columnsOf('extracts');
    expect(extracts, isNot(contains('start_block_id')));
    expect(extracts, containsAll(<String>['start_utf8', 'provenance_state']));

    final tables = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'source_edits'",
        )
        .get();
    expect(tables, hasLength(1));

    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.first, kSchemaVersion);
  });

  test('is re-runnable, so an interrupted upgrade is not fatal', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV11(seeded);
    await seeded.close();

    final AppDatabase once = await openFileDatabase();
    await once.close();

    // Stamping the version back and reopening runs the step over a file that
    // has already been converted. It must be a no-op rather than a corruption.
    final AppDatabase again = await openFileDatabase();
    await again.customStatement('PRAGMA user_version = 11');
    await again.close();

    final AppDatabase third = await openFileDatabase();
    addTearDown(third.close);

    final row =
        (await third
                .customSelect(
                  "SELECT provenance_state FROM extracts WHERE id = 'x-intact'",
                )
                .get())
            .single;
    expect(row.read<int>('provenance_state'), ProvenanceState.verbatim.index);
  });
}
