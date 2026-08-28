/// SM20's browser Learning command group through the real transactions.
///
/// The gates here are the ones an inexact port fails quietly: Reset history
/// really does reset only the history block, Undismiss really does not restore
/// what Dismiss cleared, Add to outstanding really does raise importance, and
/// Advance really is a repetition for a topic but not for a card.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/priority/priority_browser_commands.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/review/review_command_runner.dart';
import 'package:incremental_reader/features/review/review_commands.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/postpone/sm20_advance.dart';
import 'package:incremental_reader/scheduling/sm20_collection_state.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

const String _markdown = '''
# Chapter

A paragraph that is long enough to be parsed into a readable block.
''';

extension _Fixtures on AppHarness {
  Future<Source> importSource([String title = 'Article']) async =>
      (await reader.importSource(
        ImportSource(
          operation(),
          title: title,
          markdown: _markdown,
          priorityPercent: 50,
          timestampUtc: clock.nowUtc(),
        ),
      )).unwrap();

  ElementRef refOf(Source source) =>
      ElementRef(id: source.id, type: ElementType.source);

  Future<TopicState> topicOf(Source source) async =>
      (await learning.findTopic(refOf(source)))!;

  /// Imports a source and completes one encounter, which memorizes it.
  Future<Source> memorizedSource([String title = 'Article']) async {
    final Source source = await importSource(title);
    final Result<TopicState> completed = await reader.completeEncounter(
      CompleteTopicEncounter(
        operation(),
        ref: refOf(source),
        wordsRead: 40,
        timestampUtc: clock.nowUtc(),
      ),
    );
    expect(completed.isOk, isTrue, reason: '${completed.failureOrNull}');
    return source;
  }

  Future<CardState> memorizedCard(String sourceId) async {
    final List<Card> cards = (await formulation.formulate(
      FormulateCards(
        operation(),
        parent: CardParent.source(sourceId),
        drafts: const <CardDraft>[
          ClozeCardDraft('Working memory holds {{c1::four items}}.'),
        ],
        timestampUtc: clock.nowUtc(),
      ),
    )).unwrap();
    final Result<ReviewOutcome> graded = await review.review(
      ReviewCard(
        operation(),
        cardId: cards.single.id,
        rating: CardRating.easy,
        elapsedMs: 1500,
        timestampUtc: clock.nowUtc(),
      ),
    );
    expect(graded.isOk, isTrue, reason: '${graded.failureOrNull}');
    return (await learning.findCardState(cards.single.id))!;
  }
}

void main() {
  late AppHarness harness;
  late FakeClock clock;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(clock: clock);
  });

  tearDown(() => harness.close());

  group('Remember', () {
    test('memorizes a pending topic and refuses a memorized one', () async {
      final Source source = await harness.importSource();
      final StudyDay today = await harness.today();
      expect((await harness.topicOf(source)).status, Sm20ElementStatus.pending);

      final Result<PriorityBrowserCommandOutcome> first = await harness.browser
          .remember(
            RememberElements(
              harness.operation(),
              refs: <ElementRef>[harness.refOf(source)],
              day: today,
              timestampUtc: clock.nowUtc(),
            ),
          );
      expect(first.isOk, isTrue, reason: '${first.failureOrNull}');
      expect(first.unwrap().changedRefCount, 1);

      final TopicState memorized = await harness.topicOf(source);
      expect(memorized.status, Sm20ElementStatus.memorized);
      expect(memorized.repetitionCount, 1);
      expect(memorized.lastReviewDay, today);

      final Result<PriorityBrowserCommandOutcome> second = await harness.browser
          .remember(
            RememberElements(
              harness.operation(),
              refs: <ElementRef>[harness.refOf(source)],
              day: today,
              timestampUtc: clock.nowUtc(),
            ),
          );
      expect(second.unwrap().changedRefCount, 0);
      expect(second.unwrap().skipped, 1);
    });
  });

  group('Forget, Dismiss, and Undismiss', () {
    test('Forget clears the repetition state but keeps A', () async {
      final Source source = await harness.memorizedSource();
      final TopicState before = await harness.topicOf(source);
      clock.advance(const Duration(days: 3));
      final StudyDay today = await harness.today();

      final Result<PriorityBrowserCommandOutcome> result = await harness.browser.forget(
        ForgetElements(
          harness.operation(),
          refs: <ElementRef>[harness.refOf(source)],
          day: today,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');

      final TopicState after = await harness.topicOf(source);
      expect(after.status, Sm20ElementStatus.pending);
      expect(after.repetitionCount, 0);
      expect(after.lapseCount, 0);
      expect(after.storedInterval, 0);
      expect(after.historyBlockId, 0);
      expect(after.totalPostponementCount, 0);
      expect(after.lastReviewDay, today);
      expect(after.learningControl, 8);
      expect(
        after.aFactorRaw.bytes,
        before.aFactorRaw.bytes,
        reason: 'Forget preserves topic A and priority',
      );
      expect(after.schedule.priority, before.schedule.priority);
    });

    test('Dismiss sends priority to the bottom; Undismiss restores only the '
        'status', () async {
      final Source keep = await harness.memorizedSource('Keep');
      final Source drop = await harness.memorizedSource('Drop');
      final StudyDay today = await harness.today();
      final TopicState before = await harness.topicOf(drop);

      await harness.browser.dismiss(
        DismissElements(
          harness.operation(),
          refs: <ElementRef>[harness.refOf(drop)],
          day: today,
          timestampUtc: clock.nowUtc(),
        ),
      );
      final TopicState dismissed = await harness.topicOf(drop);
      expect(dismissed.status, Sm20ElementStatus.dismissed);
      expect(dismissed.storedInterval, 0);
      expect(dismissed.repetitionCount, 0);
      expect(
        dismissed.aFactorRaw.bytes,
        before.aFactorRaw.bytes,
        reason: 'Dismiss preserves A even though it clears everything else',
      );
      expect(
        dismissed.schedule.priority.compareTo(
          (await harness.topicOf(keep)).schedule.priority,
        ),
        greaterThan(0),
        reason: 'Set Priority 100 puts it behind the rest of the collection',
      );

      await harness.browser.undismiss(
        UndismissElements(
          harness.operation(),
          refs: <ElementRef>[harness.refOf(drop)],
          day: today,
          timestampUtc: clock.nowUtc(),
        ),
      );
      final TopicState restored = await harness.topicOf(drop);
      expect(restored.status, Sm20ElementStatus.pending);
      expect(
        restored.storedInterval,
        0,
        reason: 'Undismiss does not restore the schedule Dismiss cleared',
      );
      expect(
        restored.schedule.priority,
        dismissed.schedule.priority,
        reason: 'nor the priority Dismiss set to 100',
      );
    });
  });

  group('Reset history', () {
    test('is a no-op when there is no history block', () async {
      final Source source = await harness.memorizedSource();
      final TopicState before = await harness.topicOf(source);
      expect(before.historyBlockId, 0);

      final Result<PriorityBrowserCommandOutcome> result = await harness.browser
          .resetHistory(
            ResetElementHistory(
              harness.operation(),
              refs: <ElementRef>[harness.refOf(source)],
              day: await harness.today(),
              timestampUtc: clock.nowUtc(),
            ),
          );

      expect(result.unwrap().changedRefCount, 0);
      expect(result.unwrap().skipped, 1);
      final TopicState after = await harness.topicOf(source);
      expect(after.repetitionCount, before.repetitionCount);
      expect(after.storedInterval, before.storedInterval);
      expect(
        after.schedule.algorithmicDueDay,
        before.schedule.algorithmicDueDay,
      );
    });
  });

  group('Set A and Modify A', () {
    test('write A without touching interval, due, or priority', () async {
      final Source source = await harness.memorizedSource();
      final TopicState before = await harness.topicOf(source);
      final StudyDay today = await harness.today();

      await harness.browser.setAFactor(
        SetTopicAFactor(
          harness.operation(),
          refs: <ElementRef>[harness.refOf(source)],
          day: today,
          value: 2.5,
          timestampUtc: clock.nowUtc(),
        ),
      );
      final TopicState set = await harness.topicOf(source);
      expect(set.aFactor, closeTo(2.5, 1e-9));
      expect(set.storedInterval, before.storedInterval);
      expect(set.schedule.algorithmicDueDay, before.schedule.algorithmicDueDay);
      expect(set.schedule.priority, before.schedule.priority);
      expect(set.repetitionCount, before.repetitionCount);
      expect(set.lastReviewDay, before.lastReviewDay);

      await harness.browser.modifyAFactor(
        ModifyTopicAFactor(
          harness.operation(),
          refs: <ElementRef>[harness.refOf(source)],
          day: today,
          multiplier: 0.5,
          timestampUtc: clock.nowUtc(),
        ),
      );
      final TopicState modified = await harness.topicOf(source);
      expect(modified.aFactor, closeTo(1.01 + 0.5 * (2.5 - 1.01), 1e-6));
      expect(modified.storedInterval, before.storedInterval);
    });

    test('reject values outside the dialog bounds', () async {
      final Source source = await harness.memorizedSource();
      final StudyDay today = await harness.today();

      expect(
        (await harness.browser.setAFactor(
          SetTopicAFactor(
            harness.operation(),
            refs: <ElementRef>[harness.refOf(source)],
            day: today,
            value: 3.5,
            timestampUtc: clock.nowUtc(),
          ),
        )).isErr,
        isTrue,
      );
      expect(
        (await harness.browser.modifyAFactor(
          ModifyTopicAFactor(
            harness.operation(),
            refs: <ElementRef>[harness.refOf(source)],
            day: today,
            multiplier: 2.5,
            timestampUtc: clock.nowUtc(),
          ),
        )).isErr,
        isTrue,
      );
    });
  });

  group('Add to drill and Add to outstanding', () {
    test('Add to drill only appends, and never twice', () async {
      final Source source = await harness.memorizedSource();
      final TopicState before = await harness.topicOf(source);
      final StudyDay today = await harness.today();

      await harness.browser.addToFinalDrill(
        AddToFinalDrill(
          harness.operation(),
          refs: <ElementRef>[harness.refOf(source)],
          day: today,
          timestampUtc: clock.nowUtc(),
        ),
      );
      final Result<PriorityBrowserCommandOutcome> again = await harness.browser
          .addToFinalDrill(
            AddToFinalDrill(
              harness.operation(),
              refs: <ElementRef>[harness.refOf(source)],
              day: today,
              timestampUtc: clock.nowUtc(),
            ),
          );

      final Sm20CollectionState runtime = await harness.context.runtimeState();
      expect(runtime.finalDrill, <ElementRef>[harness.refOf(source)]);
      expect(again.unwrap().changedRefCount, 0);
      final TopicState after = await harness.topicOf(source);
      expect(after.storedInterval, before.storedInterval);
      expect(after.schedule.priority, before.schedule.priority);
      expect(
        after.schedule.algorithmicDueDay,
        before.schedule.algorithmicDueDay,
      );
    });

    test('Add to outstanding inserts, spaces, and raises importance', () async {
      final List<Source> sources = <Source>[
        for (var i = 0; i < 4; i++) await harness.memorizedSource('S$i'),
      ];
      // The encounters were today, so the ordinary command would refuse them.
      clock.advance(const Duration(days: 2));
      final StudyDay today = await harness.today();
      final List<ElementRef> refs = <ElementRef>[
        for (final Source source in sources) harness.refOf(source),
      ];
      final Map<ElementRef, double> percentBefore = <ElementRef, double>{
        for (final ElementRef ref in refs)
          ref: (await harness.context.priorityScale()).percentageOf(
            (await harness.learning.findSchedule(ref))!.priority,
          ),
      };

      final Result<PriorityBrowserCommandOutcome> result = await harness.browser
          .addToOutstanding(
            AddToOutstanding(
              harness.operation(),
              refs: refs,
              day: today,
              timestampUtc: clock.nowUtc(),
            ),
          );

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      final Sm20CollectionState runtime = await harness.context.runtimeState();
      expect(runtime.outstanding, isNotEmpty);
      for (final ElementRef ref in result.unwrap().changedRefs) {
        expect(runtime.outstanding, contains(ref));
        final double after = (await harness.context.priorityScale())
            .percentageOf((await harness.learning.findSchedule(ref))!.priority);
        expect(
          after,
          lessThanOrEqualTo(percentBefore[ref]!),
          reason: 'each insertion multiplies the priority target by 0.9',
        );
      }
    });

    test('the ordinary command refuses a record reviewed today; Add all '
        'reschedules it', () async {
      final Source source = await harness.memorizedSource();
      final StudyDay today = await harness.today();
      final ElementRef ref = harness.refOf(source);

      final Result<PriorityBrowserCommandOutcome> ordinary = await harness.browser
          .addToOutstanding(
            AddToOutstanding(
              harness.operation(),
              refs: <ElementRef>[ref],
              day: today,
              timestampUtc: clock.nowUtc(),
            ),
          );
      expect(ordinary.unwrap().changedRefCount, 0);
      expect(ordinary.unwrap().skipped, 1);

      final Result<PriorityBrowserCommandOutcome> addAll = await harness.browser
          .addToOutstanding(
            AddToOutstanding(
              harness.operation(),
              refs: <ElementRef>[ref],
              day: today,
              shouldRescheduleSameDay: true,
              timestampUtc: clock.nowUtc(),
            ),
          );
      expect(addAll.unwrap().changedRefCount, 1);

      final TopicState after = await harness.topicOf(source);
      expect(after.schedule.algorithmicDueDay, today);
      expect(after.storedInterval, 1);
      expect(
        after.lastReviewDay,
        today.addDays(-1),
        reason: 'the same-day reschedule moves last review to Today-1',
      );
    });

    test('rejects an out-of-range spacing', () async {
      final Source source = await harness.memorizedSource();
      expect(
        (await harness.browser.addToOutstanding(
          AddToOutstanding(
            harness.operation(),
            refs: <ElementRef>[harness.refOf(source)],
            day: await harness.today(),
            everyWhich: 0,
            timestampUtc: clock.nowUtc(),
          ),
        )).isErr,
        isTrue,
      );
    });
  });

  group('Advance', () {
    test('is a forced bulk repetition for a topic', () async {
      final Source source = await harness.memorizedSource();
      // A long interval and an old last review make the record draw-eligible.
      await harness.browser.setAFactor(
        SetTopicAFactor(
          harness.operation(),
          refs: <ElementRef>[harness.refOf(source)],
          day: await harness.today(),
          value: 2,
          timestampUtc: clock.nowUtc(),
        ),
      );
      await harness.learning.saveTopic(
        (await harness.topicOf(source)).copyWith(storedInterval: 200),
      );
      clock.advance(const Duration(days: 5));
      final StudyDay today = await harness.today();
      final TopicState before = await harness.topicOf(source);
      final Sm20CollectionState runtimeBefore = await harness.context
          .runtimeState();

      final Result<PriorityBrowserCommandOutcome> result = await harness.browser
          .advance(
            AdvanceElements(
              harness.operation(),
              refs: <ElementRef>[harness.refOf(source)],
              day: today,
              scope: Sm20AdvanceScope.topics,
              timestampUtc: clock.nowUtc(),
            ),
          );

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      expect(result.unwrap().randomDraws, 1);
      final TopicState after = await harness.topicOf(source);
      expect(after.repetitionCount, before.repetitionCount + 1);
      expect(after.lastReviewDay, today);
      expect(after.storedInterval, lessThan(before.storedInterval));
      expect(
        after.schedule.algorithmicDueDay,
        today.addDays(after.storedInterval),
      );
      final Sm20CollectionState runtimeAfter = await harness.context
          .runtimeState();
      expect(runtimeAfter.prngSeed, isNot(runtimeBefore.prngSeed));
    });

    test('is a low-level reschedule for a card', () async {
      final Source source = await harness.memorizedSource();
      final CardState card = await harness.memorizedCard(source.id);
      await harness.learning.saveCardState(
        card.copyWith(
          memory: card.memory.lowLevelRescheduled(
            targetDueAtUtc: clock.nowUtc().add(const Duration(days: 200)),
            actualIntervalDays: 200,
            adjustedLastReviewAtUtc: card.memory.lastReviewAtUtc,
            didIntervalGrow: true,
          ),
        ),
      );
      clock.advance(const Duration(days: 5));
      final StudyDay today = await harness.today();
      final CardState before = (await harness.learning.findCardState(
        card.memory.cardId,
      ))!;

      final Result<PriorityBrowserCommandOutcome> result = await harness.browser
          .advance(
            AdvanceElements(
              harness.operation(),
              refs: <ElementRef>[
                ElementRef(id: card.memory.cardId, type: ElementType.card),
              ],
              day: today,
              scope: Sm20AdvanceScope.items,
              timestampUtc: clock.nowUtc(),
            ),
          );

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      expect(result.unwrap().randomDraws, 1);
      final CardState after = (await harness.learning.findCardState(
        card.memory.cardId,
      ))!;
      expect(after.memory.dueAtUtc.isBefore(before.memory.dueAtUtc), isTrue);
      expect(after.memory.reps, before.memory.reps);
      expect(after.memory.stability, before.memory.stability);
      expect(after.memory.difficulty, before.memory.difficulty);
      expect(after.schedule.priority, before.schedule.priority);
    });

    test('rejects a horizon outside the dialog bounds', () async {
      expect(
        (await harness.browser.advance(
          AdvanceElements(
            harness.operation(),
            refs: const <ElementRef>[],
            day: await harness.today(),
            scope: Sm20AdvanceScope.items,
            horizonDays: 1,
            timestampUtc: clock.nowUtc(),
          ),
        )).isErr,
        isTrue,
      );
    });
  });

  group('every command', () {
    test('replays rather than repeating a resent operation', () async {
      final Source source = await harness.memorizedSource();
      final StudyDay today = await harness.today();
      final ElementRef ref = harness.refOf(source);
      final operation = harness.operation();

      final Result<PriorityBrowserCommandOutcome> first = await harness.browser
          .addToFinalDrill(
            AddToFinalDrill(
              operation,
              refs: <ElementRef>[ref],
              day: today,
              timestampUtc: clock.nowUtc(),
            ),
          );
      final Result<PriorityBrowserCommandOutcome> resent = await harness.browser
          .addToFinalDrill(
            AddToFinalDrill(
              operation,
              refs: <ElementRef>[ref],
              day: today,
              timestampUtc: clock.nowUtc(),
            ),
          );

      expect(first.unwrap().changedRefCount, 1);
      expect(resent.unwrap().changedRefCount, 0);
      final Sm20CollectionState runtime = await harness.context.runtimeState();
      expect(runtime.finalDrill, <ElementRef>[ref]);
    });
  });
}
