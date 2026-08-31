/// Saving FSRS settings and rescheduling existing cards as one transaction.
library;

import 'package:incremental_reader/documents/card.dart' as documents;
import 'package:incremental_reader/features/settings/fsrs_settings_rescheduler.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

void main() {
  test('parameter policy changes update eligible card schedules', () async {
    final harness = AppHarness();
    addTearDown(harness.close);
    final previous = await harness.settingsStore.load();
    final calendar = await harness.context.calendar();
    final reviewedAt = harness.clock.nowUtc().subtract(const Duration(days: 2));
    final lastDay = calendar.dayOf(reviewedAt);
    final dueDay = lastDay.addDays(100);
    final dueAt = calendar.startOfDayUtc(dueDay);
    final memory = CardMemory(
      cardId: 'settings-card',
      state: CardLearningState.review,
      step: null,
      stability: 100,
      difficulty: 5,
      repetitionCount: 1,
      lapses: 0,
      lastReviewAtUtc: reviewedAt,
      dueAtUtc: dueAt,
      originalDueAtUtc: dueAt,
      schedulerVersion: kCardSchedulerVersion,
      parametersVersion: kCardParametersVersion,
      scheduledDays: 100,
    );
    final state = CardState(
      schedule: ElementSchedule(
        ref: const ElementRef(id: 'settings-card', type: ElementType.card),
        priority: PriorityRank.middle,
        lifecycle: ElementLifecycle.active,
        dueDay: dueDay,
        originalDueDay: dueDay,
      ),
      memory: memory,
    );
    await harness.content.insertCards(<documents.Card>[
      documents.Card.qa(
        id: 'settings-card',
        parent: null,
        question: 'Question',
        answer: 'Answer',
        createdAtUtc: reviewedAt,
      ),
    ]);
    await harness.learning.insertCardState(state);
    await harness.learning.appendReview(
      ReviewRecord(
        operationId: 'settings-review',
        cardId: 'settings-card',
        rating: CardRating.good,
        reviewedAtUtc: reviewedAt,
        elapsedMs: null,
        preStateJson: memory.toJson(),
        postStateJson: memory.toJson(),
        schedulerVersion: kCardSchedulerVersion,
        parametersVersion: kCardParametersVersion,
      ),
    );
    final replacement = previous.copyWith(
      cards: previous.cards.copyWith(
        desiredRetention: 0.99,
        maximumIntervalDays: 30,
      ),
    );

    final result = await FsrsSettingsRescheduler(
      settings: harness.settingsStore,
      context: harness.context,
      learning: harness.learning,
      transactions: harness.transactions,
    ).save(previous: previous, replacement: replacement);

    expect(result.settings.unwrap(), replacement);
    expect(result.cardsUpdated, 1);
    final updated = await harness.learning.findCardState('settings-card');
    expect(updated!.memory.lastReviewAtUtc, reviewedAt);
    expect(updated.memory.scheduledDays, lessThanOrEqualTo(30));
    expect(updated.schedule.dueDay, calendar.dayOf(updated.memory.dueAtUtc));
  });
}
