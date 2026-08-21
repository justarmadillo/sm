/// The complete incremental-reading loop, over a real database file.
///
/// Import → extract → formulate → review → queue, with a genuine restart in
/// the middle, because the invariants this milestone protects are all about
/// what survives being closed and reopened.
library;

import 'dart:io';

import 'package:incremental_reader/src/application/extraction/extraction_commands.dart';
import 'package:incremental_reader/src/application/formulation/formulation_commands.dart';
import 'package:incremental_reader/src/application/priority/priority_commands.dart';
import 'package:incremental_reader/src/application/queue/queue_query.dart';
import 'package:incremental_reader/src/application/reader/reader_commands.dart';
import 'package:incremental_reader/src/application/review/review_commands.dart';
import 'package:incremental_reader/src/core/clock.dart';
import 'package:incremental_reader/src/core/result.dart';
import 'package:incremental_reader/src/data/database/app_database.dart';
import 'package:incremental_reader/src/data/database/connection.dart';
import 'package:incremental_reader/src/domain/content/block.dart';
import 'package:incremental_reader/src/domain/content/card.dart';
import 'package:incremental_reader/src/domain/content/document.dart';
import 'package:incremental_reader/src/domain/content/extract.dart';
import 'package:incremental_reader/src/domain/content/reader_anchor.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/domain/scheduling/card_scheduler.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/priority_rank.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:test/test.dart';

import '../support/app_harness.dart';

const String _markdown = '''
# Working memory

Working memory holds about four items while attention remains limited.
''';

/// This milestone's fixtures, over the shared stack.
extension _Fixtures on AppHarness {
  Future<(Source, Extract)> createFixture() async {
    final source = (await reader.importSource(
      ImportSource(
        operation(),
        title: 'Working memory',
        markdown: _markdown,
        timestampUtc: clock.nowUtc(),
      ),
    )).unwrap();
    final document = (await content.findDocument(source.id))!;
    final block = document.blocks.firstWhere(
      (Block candidate) => candidate.type == BlockType.paragraph,
    );
    final anchors = _wholeRenderedBlock(document, block);
    final extract = (await extraction.createExtract(
      CreateExtract(
        operation(),
        parentId: source.id,
        parentIsSource: true,
        range: SelectionRange.of(
          startAnchor: anchors.$1,
          endAnchor: anchors.$2,
          markdown: document.markdownBetween(anchors.$1, anchors.$2),
        ),
        timestampUtc: clock.nowUtc(),
      ),
    )).unwrap();
    return (source, extract);
  }

  Future<List<Card>> formulateFixture(String extractId) async =>
      (await formulation.formulate(
        FormulateCards(
          operation(),
          parent: CardParent.extract(extractId),
          drafts: const <CardDraft>[
            QaCardDraft(
              question: 'How many items does working memory hold?',
              answer: 'About four items.',
            ),
            QaCardDraft(
              question: 'What remains limited?',
              answer: 'Attention.',
            ),
            ClozeCardDraft(
              'Working memory holds {{c1::four items}} while '
              '{{c2::attention}} remains {{c2::limited}}.',
            ),
          ],
          timestampUtc: clock.nowUtc(),
        ),
      )).unwrap();

  /// Sets an exact rank, as the priority browser's drag ultimately does.
  Future<void> setRank(ElementRef ref, PriorityRank rank) async {
    final result = await priority.setRank(
      SetPriority(
        operation(),
        ref: ref,
        rank: rank,
        timestampUtc: clock.nowUtc(),
      ),
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
  }

  /// Makes [ref] due today without pretending anything was processed.
  Future<void> makeDueToday(ElementRef ref) async {
    final topic = (await learning.findTopic(ref))!;
    final StudyDay day = await today();
    await learning.saveTopic(
      topic.copyWith(
        schedule: topic.schedule.copyWith(dueDay: day, originalDueDay: day),
      ),
    );
  }
}

void main() {
  late Directory workspace;
  late File databaseFile;
  late AppDatabase database;
  late FakeClock clock;
  late AppHarness harness;

  setUp(() async {
    workspace = Directory.systemTemp.createTempSync('ir_m3_loop_');
    databaseFile = File('${workspace.path}/db/$kDatabaseFileName');
    database = openDatabaseAt(databaseFile);
    await database.customSelect('SELECT 1').getSingle();
    clock = FakeClock(DateTime.utc(2026, 3, 5, 12));
    harness = AppHarness(database: database, clock: clock);
  });

  tearDown(() async {
    await database.close();
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  test('a card can be formulated straight from an article, as in SuperMemo, '
      'without an extract in between', () async {
    final (source, _) = await harness.createFixture();
    final sourceRef = ElementRef(id: source.id, type: ElementType.source);
    final inherited = PriorityRank.above(PriorityRank.middle);
    await harness.setRank(sourceRef, inherited);
    final before = (await harness.learning.findTopic(sourceRef))!;

    final result = await harness.formulation.formulate(
      FormulateCards(
        harness.operation(),
        parent: CardParent.source(source.id),
        drafts: const <CardDraft>[
          ClozeCardDraft('Working memory holds about {{c1::four}} items.'),
        ],
        timestampUtc: clock.nowUtc(),
      ),
    );

    expect(result.isOk, isTrue, reason: result.failureOrNull?.message);
    final card = result.unwrap().single;
    expect(card.parent, CardParent.source(source.id));
    expect(card.extractId, isNull);
    expect(
      (await harness.content.listCardsOfSource(source.id)).single.id,
      card.id,
    );
    final state = (await harness.learning.findCardState(card.id))!;
    expect(
      state.schedule.priority,
      inherited,
      reason: 'a card inherits the priority of whatever element made it',
    );
    expect(
      state.schedule.rootId,
      source.id,
      reason: 'the root article is denormalized so the queue can cap its share',
    );

    final after = (await harness.learning.findTopic(sourceRef))!;
    expect(
      after.schedule.dueDay,
      before.schedule.dueDay,
      reason: 'formulating never reschedules the article it came from',
    );
    expect(after.intervalDays, before.intervalDays);
  });

  test('formulating from an article that does not exist fails without '
      'writing anything', () async {
    final result = await harness.formulation.formulate(
      FormulateCards(
        harness.operation(),
        parent: const CardParent.source('missing'),
        drafts: const <CardDraft>[QaCardDraft(question: 'Q?', answer: 'A.')],
        timestampUtc: clock.nowUtc(),
      ),
    );

    expect(result.isErr, isTrue);
    expect(result.failureOrNull, isA<NotFoundFailure>());
    expect(await harness.content.listCardsOfSource('missing'), isEmpty);
  });

  test('batch formulation creates independent Q&A and cloze cards without '
      'rescheduling the extract', () async {
    final (_, extract) = await harness.createFixture();
    final extractRef = ElementRef(id: extract.id, type: ElementType.extract);
    final inherited = PriorityRank.above(PriorityRank.middle);
    await harness.setRank(extractRef, inherited);
    final before = (await harness.learning.findTopic(extractRef))!;

    final operation = harness.operation();
    final result = await harness.formulation.formulate(
      FormulateCards(
        operation,
        parent: CardParent.extract(extract.id),
        drafts: const <CardDraft>[
          QaCardDraft(question: 'Question one?', answer: 'Answer one.'),
          QaCardDraft(question: 'Question two?', answer: 'Answer two.'),
          ClozeCardDraft(
            '{{c1::Alpha}} connects to {{c2::Beta}} and {{c1::Gamma}}.',
          ),
        ],
        timestampUtc: clock.nowUtc(),
      ),
    );

    final cards = result.unwrap();
    expect(cards, hasLength(4));
    expect(cards.map((Card card) => card.kind), <CardKind>[
      CardKind.qa,
      CardKind.qa,
      CardKind.cloze,
      CardKind.cloze,
    ]);
    expect(
      cards
          .where((Card card) => card.kind == CardKind.cloze)
          .map((Card card) => card.clozeOrdinal),
      <int?>[1, 2],
    );

    final after = (await harness.learning.findTopic(extractRef))!;
    expect(after.intervalDays, before.intervalDays);
    expect(after.schedule.dueDay, before.schedule.dueDay);
    expect(after.schedule.originalDueDay, before.schedule.originalDueDay);
    expect(after.schedule.lifecycle, before.schedule.lifecycle);
    expect(after.schedule.deferredUntil, before.schedule.deferredUntil);
    expect(
      after.encountersSinceLastCard,
      0,
      reason:
          'the extract has just produced cards, so the nudge counter '
          'restarts rather than the schedule moving',
    );

    for (final Card card in cards) {
      final state = (await harness.learning.findCardState(card.id))!;
      expect(state.schedule.priority, inherited);
      expect(state.memory.isNew, isTrue);
      expect(state.memory.state, CardLearningState.learning);
      expect(state.memory.step, 0);
      expect(state.memory.stability, isNull);
      expect(state.memory.difficulty, isNull);
      expect(state.memory.dueAtUtc, clock.nowUtc());
      expect(state.memory.schedulerVersion, kCardSchedulerVersion);
      expect(state.memory.parametersVersion, kCardParametersVersion);
    }

    await harness.setRank(extractRef, PriorityRank.below(PriorityRank.middle));
    for (final Card card in cards) {
      expect(
        (await harness.learning.findCardState(card.id))!.schedule.priority,
        inherited,
        reason: 'priority is inherited once, not linked to the extract',
      );
    }

    final retry = await harness.formulation.formulate(
      FormulateCards(
        operation,
        parent: CardParent.extract(extract.id),
        drafts: const <CardDraft>[
          QaCardDraft(question: 'Question one?', answer: 'Answer one.'),
        ],
        timestampUtc: clock.nowUtc(),
      ),
    );
    expect(retry.failureOrNull, isA<ConflictFailure>());
    expect(await harness.content.listCardsOfExtract(extract.id), hasLength(4));
  });

  test(
    'review is exactly-once and its full FSRS state survives a real restart',
    () async {
      final (_, extract) = await harness.createFixture();
      final card = (await harness.formulateFixture(extract.id)).first;
      final before = (await harness.learning.findCardState(card.id))!;
      final operation = harness.operation();
      final reviewedAt = clock.nowUtc();
      final command = ReviewCard(
        operation,
        cardId: card.id,
        rating: CardRating.good,
        elapsedMs: 2300,
        timestampUtc: reviewedAt,
      );

      final first = (await harness.review.review(command)).unwrap().state;
      expect(first.memory.reps, 1);
      expect(first.memory.lastReviewAtUtc, reviewedAt);
      expect(first.memory.stability, isNotNull);
      expect(first.memory.difficulty, isNotNull);
      expect(first.memory.dueAtUtc, isNot(reviewedAt));
      expect(first.memory.schedulerVersion, kCardSchedulerVersion);
      expect(first.memory.parametersVersion, kCardParametersVersion);

      final records = await harness.learning.listReviewsForCard(card.id);
      expect(records, hasLength(1));
      final record = records.single;
      expect(record.operationId, operation.value);
      expect(record.rating, CardRating.good);
      expect(record.reviewedAtUtc, reviewedAt);
      expect(record.elapsedMs, 2300);
      expect(record.preState, before.memory);
      expect(record.postState, first.memory);
      expect(record.schedulerVersion, kCardSchedulerVersion);
      expect(record.parametersVersion, kCardParametersVersion);

      final retry = await harness.review.review(command);
      expect(retry.failureOrNull, isA<ConflictFailure>());
      expect(await harness.learning.listReviewsForCard(card.id), hasLength(1));
      expect(
        (await harness.learning.findCardState(card.id))!.memory,
        first.memory,
      );

      await database.close();
      database = openDatabaseAt(databaseFile);
      await database.customSelect('SELECT 1').getSingle();
      harness = AppHarness(
        database: database,
        clock: clock,
        operationPrefix: 'after-restart',
      );

      final restored = (await harness.learning.findCardState(card.id))!;
      expect(restored.memory, first.memory);
      expect(restored.schedule.dueDay, first.schedule.dueDay);
      expect(await harness.learning.listReviewsForCard(card.id), hasLength(1));

      clock.setTo(restored.memory.dueAtUtc);
      expect(
        (await harness.learning.listDueCards(
          clock.nowUtc(),
        )).map((CardState state) => state.ref.id),
        contains(card.id),
      );
      final second = (await harness.review.review(
        ReviewCard(
          harness.operation(),
          cardId: card.id,
          rating: CardRating.good,
          elapsedMs: 1800,
          timestampUtc: clock.nowUtc(),
        ),
      )).unwrap().state;
      expect(second.memory.reps, 2);
      final afterRestartRecords = await harness.learning.listReviewsForCard(
        card.id,
      );
      expect(afterRestartRecords, hasLength(2));
      expect(afterRestartRecords.last.preState, first.memory);
      expect(afterRestartRecords.last.postState, second.memory);
    },
  );

  test(
    'queue projection mixes due cards and topics without leaking answers',
    () async {
      final (source, extract) = await harness.createFixture();
      final extractRef = ElementRef(id: extract.id, type: ElementType.extract);
      await harness.setRank(
        extractRef,
        PriorityRank.above(PriorityRank.middle),
      );
      final cards = await harness.formulateFixture(extract.id);
      await harness.makeDueToday(extractRef);
      // Sibling burying would push two of the three cards off today, which is
      // right in a session and wrong in a test about the mix itself.
      await harness.tuneSettings(
        (settings) => settings.copyWith(
          cards: settings.cards.copyWith(burySiblings: false),
        ),
      );

      final QueueProjection projection = await harness.queueQuery.load();
      final List<QueueEntry> entries = projection.entries;

      expect(
        entries.take(4).map((QueueEntry entry) => entry.ref.type),
        everyElement(ElementType.card),
        reason: 'four cards then a topic is the default proportion',
      );
      expect(
        entries.map((QueueEntry entry) => entry.ref),
        containsAll(<ElementRef>[
          extractRef,
          ElementRef(id: source.id, type: ElementType.source),
        ]),
      );
      expect(
        entries.where((QueueEntry e) => e.ref.type == ElementType.card),
        hasLength(cards.length),
      );
      expect(
        entries.map((QueueEntry entry) => entry.actionLabel).toSet(),
        <String>{'Review', 'Process', 'Read'},
      );
      expect(
        entries.every((QueueEntry entry) => entry.priorityPercent != null),
        isTrue,
        reason: 'every row carries its derived percentile',
      );

      final qa = entries.firstWhere(
        (QueueEntry entry) => entry.ref.id == cards.first.id,
      );
      expect(qa.preview, 'How many items does working memory hold?');
      expect(qa.preview, isNot(contains('About four items')));
      final cloze = entries.firstWhere(
        (QueueEntry entry) =>
            entry.ref.id ==
            cards.firstWhere((Card card) => card.kind == CardKind.cloze).id,
      );
      expect(cloze.preview, contains('[...]'));
      expect(cloze.preview, isNot(contains('four items')));
    },
  );
}

(ReaderAnchor, ReaderAnchor) _wholeRenderedBlock(
  Document document,
  Block block,
) {
  final (int start, int end) = block.sourceRangeForRendered(
    0,
    block.renderedText.length,
  );
  return (
    ReaderAnchor(blockId: block.id, utf8Offset: start),
    ReaderAnchor(blockId: block.id, utf8Offset: end),
  );
}
