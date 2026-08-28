import 'dart:io';

import 'package:drift/drift.dart' show QueryRow;
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/drift/drift_content_repository.dart';
import 'package:incremental_reader/storage/drift/drift_learning_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

void main() {
  late Directory workspace;
  late File databaseFile;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir_m3_schema_');
    databaseFile = File('${workspace.path}/db/$kDatabaseFileName');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  Future<AppDatabase> open() async {
    final database = openDatabaseAt(databaseFile);
    await database.customSelect('SELECT 1').getSingle();
    return database;
  }

  group('schema version 3 card memory', () {
    test(
      'accepts the FSRS new-card shape and rejects impossible states',
      () async {
        final database = await open();
        addTearDown(database.close);
        await _seedCardParents(database, count: 7);

        await _insertMemory(
          database,
          cardId: 'c1',
          state: 1,
          step: 0,
          stability: null,
          difficulty: null,
          reps: 0,
          lapses: 0,
        );
        final stored = await DriftLearningRepository(
          database,
        ).findCardState('c1');
        expect(stored, isNotNull);
        expect(
          stored!.memory,
          CardMemory.newCard(
            cardId: 'c1',
            dueAtUtc: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
          ),
        );

        await expectLater(
          _insertMemory(
            database,
            cardId: 'c2',
            state: 0,
            step: 0,
            stability: null,
            difficulty: null,
            reps: 0,
            lapses: 0,
          ),
          throwsA(isA<Object>()),
          reason: 'the retired scaffold state 0 is not a persisted FSRS state',
        );
        await expectLater(
          _insertMemory(
            database,
            cardId: 'c3',
            state: 1,
            step: -1,
            stability: null,
            difficulty: null,
            reps: 0,
            lapses: 0,
          ),
          throwsA(isA<Object>()),
        );
        await expectLater(
          _insertMemory(
            database,
            cardId: 'c4',
            state: 1,
            step: null,
            stability: null,
            difficulty: null,
            reps: 0,
            lapses: 0,
          ),
          throwsA(isA<Object>()),
          reason: 'learning and relearning always carry an intraday step',
        );
        await expectLater(
          _insertMemory(
            database,
            cardId: 'c5',
            state: 2,
            step: 0,
            stability: 2,
            difficulty: 5,
            reps: 1,
            lapses: 0,
          ),
          throwsA(isA<Object>()),
          reason: 'review-state cards do not carry a learning step',
        );
        await expectLater(
          _insertMemory(
            database,
            cardId: 'c6',
            state: 1,
            step: 0,
            stability: 1,
            difficulty: null,
            reps: 1,
            lapses: 0,
          ),
          throwsA(isA<Object>()),
          reason: 'stability and difficulty are an atomic pair',
        );
        await expectLater(
          _insertMemory(
            database,
            cardId: 'c7',
            state: 3,
            step: 0,
            stability: 1,
            difficulty: 5,
            reps: 1,
            lapses: 2,
          ),
          throwsA(isA<Object>()),
          reason: 'lapses cannot exceed total reviews',
        );
      },
    );

    test('review operation id has a durable uniqueness constraint', () async {
      final database = await open();
      addTearDown(database.close);
      await _seedCardParents(database, count: 1);

      Future<void> insert(String id) => database.customStatement(
        'INSERT INTO review_events (id, card_id, reviewed_at_utc, rating, '
        'pre_state_json, post_state_json, elapsed_ms, scheduler_version, '
        'parameters_version, is_practice, operation_id) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          id,
          'c1',
          1000,
          3,
          '{}',
          '{}',
          null,
          kCardSchedulerVersion,
          kCardParametersVersion,
          0,
          'same-operation',
        ],
      );

      await insert('r1');
      await expectLater(insert('r2'), throwsA(isA<Object>()));
    });
  });

  test(
    'version 2 migration preserves rows as reconstructable FSRS state',
    () async {
      var database = await open();
      await _seedCardParents(database, count: 2);
      await database.close();

      final legacy = sqlite.sqlite3.open(databaseFile.path);
      legacy.execute('DROP TABLE card_memories');
      legacy.execute('''
      CREATE TABLE card_memories (
        card_id TEXT NOT NULL PRIMARY KEY
          REFERENCES cards(id) ON DELETE CASCADE,
        stability REAL NOT NULL,
        difficulty REAL NOT NULL,
        state INTEGER NOT NULL CHECK (state BETWEEN 0 AND 3),
        reps INTEGER NOT NULL DEFAULT 0,
        lapses INTEGER NOT NULL DEFAULT 0,
        last_review_utc INTEGER NULL,
        due_at_utc INTEGER NOT NULL,
        original_due_at_utc INTEGER NOT NULL,
        deferred_until_utc INTEGER NULL,
        scheduler_version TEXT NOT NULL,
        parameters_version TEXT NOT NULL
      )
    ''');
      legacy.execute(
        'INSERT INTO card_memories VALUES '
        "('c1', 0.0, 0.0, 0, 0, 0, NULL, 1000, 1000, NULL, "
        "'legacy', 'legacy'), "
        "('c2', 2.5, 5.5, 2, 3, 0, 500, 2000, 2000, NULL, "
        "'legacy', 'legacy')",
      );
      legacy.execute('DROP INDEX IF EXISTS idx_reviews_operation');
      legacy.userVersion = 2;
      legacy.close();

      database = await open();
      addTearDown(database.close);
      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data.values.single, kSchemaVersion);

      final learning = DriftLearningRepository(database);
      final promotedNew = await learning.findCardState('c1');
      expect(promotedNew, isNotNull);
      expect(promotedNew!.memory.state, CardLearningState.learning);
      expect(promotedNew.memory.step, 0);
      expect(promotedNew.memory.reps, 0);
      expect(promotedNew.memory.stability, isNull);
      expect(promotedNew.memory.difficulty, isNull);

      final review = await learning.findCardState('c2');
      expect(review, isNotNull);
      expect(review!.memory.state, CardLearningState.review);
      expect(review.memory.step, isNull);
      expect(review.memory.stability, 2.5);
      expect(review.memory.difficulty, 5.5);
      expect(review.memory.reps, 3);

      final operationIndex = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_reviews_operation'",
          )
          .get();
      expect(operationIndex, hasLength(1));
    },
  );

  group('card parentage', () {
    test('a card can hang off a source, an extract, or nothing', () async {
      final database = await open();
      addTearDown(database.close);
      await _seedCardParents(database, count: 0);
      final content = DriftContentRepository(database);

      await content.insertCards(<Card>[
        Card.qa(
          id: 'from-extract',
          parent: const CardParent.extract('e1'),
          question: 'q',
          answer: 'a',
          createdAtUtc: DateTime.utc(2026),
        ),
        Card.qa(
          id: 'from-source',
          parent: const CardParent.source('s1'),
          question: 'q',
          answer: 'a',
          createdAtUtc: DateTime.utc(2026),
        ),
        Card.qa(
          id: 'standalone',
          parent: null,
          question: 'q',
          answer: 'a',
          createdAtUtc: DateTime.utc(2026),
        ),
      ]);

      expect(
        (await content.findCard('from-extract'))!.parent,
        const CardParent.extract('e1'),
      );
      expect(
        (await content.findCard('from-source'))!.parent,
        const CardParent.source('s1'),
      );
      expect((await content.findCard('standalone'))!.parent, isNull);
      expect(
        (await content.listCardsOfSource('s1')).map((Card c) => c.id),
        <String>['from-source'],
        reason: 'a source lists only the cards made directly from it',
      );
      expect(
        (await content.listCardsOfExtract('e1')).map((Card c) => c.id),
        <String>['from-extract'],
      );
    });

    test('a card names exactly one parent, or none at all', () async {
      final database = await open();
      addTearDown(database.close);
      await _seedCardParents(database, count: 0);

      // The old pair of nullable foreign keys could express "both parents at
      // once"; one typed coordinate cannot. What remains to enforce is that
      // the id and its type travel together.
      await expectLater(
        database.customStatement(
          'INSERT INTO cards (id, parent_element_id, kind, front, back, '
          'created_at_utc) VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>['halfParent', 'e1', 0, 'q', 'a', 0],
        ),
        throwsA(isA<Object>()),
      );
      await expectLater(
        database.customStatement(
          'INSERT INTO cards (id, parent_element_type, kind, front, back, '
          'created_at_utc) VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>['halfType', 1, 0, 'q', 'a', 0],
        ),
        throwsA(isA<Object>()),
      );
    });

    test('the version-3 migration keeps every card on its extract', () async {
      final database = await open();
      await _seedCardParents(database, count: 1);
      await database.customStatement('PRAGMA user_version = 3');
      await database.close();

      final migrated = await open();
      addTearDown(migrated.close);
      final card = await DriftContentRepository(migrated).findCard('c1');
      expect(card, isNotNull);
      expect(card!.parent, const CardParent.extract('e1'));
      expect(
        (await migrated.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        kSchemaVersion,
      );
    });
  });
}

/// Restores the retired `extract_id`/`source_id` pair so a suite can seed the
/// pre-v6 shape these migrations were written against. The v6 step rebuilds
/// the table and drops them again, which is exactly what is under test.
Future<void> _addLegacyCardParentColumns(AppDatabase database) async {
  for (final String column in <String>['extract_id', 'source_id']) {
    final List<QueryRow> info = await database
        .customSelect('PRAGMA table_info(cards)')
        .get();
    final bool present = info.any(
      (QueryRow row) => row.read<String>('name') == column,
    );
    if (!present) {
      await database.customStatement(
        'ALTER TABLE cards ADD COLUMN $column TEXT NULL',
      );
    }
  }
  // The indexes the old schema carried over those columns. A rebuild replays
  // every index attached to the table, so leaving them out of the fixture
  // hides the exact failure that upgrading a real collection produces.
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_cards_extract ON cards (extract_id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_cards_source ON cards (source_id)',
  );
}

Future<void> _seedCardParents(
  AppDatabase database, {
  required int count,
}) async {
  await _addLegacyCardParentColumns(database);
  await database.customStatement(
    'INSERT INTO sources (id, title, markdown, content_hash, word_count, '
    'imported_at_utc, revision) VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>['s1', 'Fixture', 'text', 'a' * 64, 1, 0, 1],
  );
  await database.customStatement(
    'INSERT INTO extracts (id, markdown, source_id, parent_id, '
    'parent_is_source, start_utf8, end_utf8, selected_text_hash, '
    'created_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>['e1', 'text', 's1', 's1', 1, 0, 4, 'b' * 64, 0],
  );
  for (var index = 1; index <= count; index++) {
    final id = 'c$index';
    await database.customStatement(
      'INSERT INTO cards (id, extract_id, kind, front, back, created_at_utc) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      <Object?>[id, 'e1', 0, 'q$index', 'a$index', 0],
    );
    await database.customStatement(
      'INSERT INTO element_schedules (element_id, element_type, priority_key, '
      'lifecycle, due_day, original_due_day, zone_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>[id, 2, 'V', 0, 20000, 20000, 'UTC'],
    );
  }
}

Future<void> _insertMemory(
  AppDatabase database, {
  required String cardId,
  required int state,
  required int? step,
  required double? stability,
  required double? difficulty,
  required int reps,
  required int lapses,
}) => database.customStatement(
  'INSERT INTO card_memories (card_id, stability, difficulty, state, step, '
  'reps, lapses, due_at_utc, original_due_at_utc, scheduler_version, '
  'parameters_version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
  <Object?>[
    cardId,
    stability,
    difficulty,
    state,
    step,
    reps,
    lapses,
    1000,
    1000,
    kCardSchedulerVersion,
    kCardParametersVersion,
  ],
);
