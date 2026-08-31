/// Personalized FSRS memory replay under a replacement parameter vector.
library;

import 'package:fsrs_dart/fsrs.dart' as fsrs;
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/cards/fsrs_memory_recomputer.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:test/test.dart';

void main() {
  const calendar = StudyDayCalendar(
    zone: FixedOffsetZone.utc,
    rollover: Duration(hours: 4),
  );
  final first = DateTime.utc(2026, 3, 1, 23, 30);
  final second = DateTime.utc(2026, 3, 2, 3, 30);
  final third = DateTime.utc(2026, 3, 3, 5);

  ReviewRecord review(String id, CardRating rating, DateTime at) =>
      ReviewRecord(
        operationId: id,
        cardId: 'card',
        rating: rating,
        reviewedAtUtc: at,
        elapsedMs: null,
        preStateJson: '{}',
        postStateJson: '{}',
        schedulerVersion: 'old',
        parametersVersion: 'old',
      );

  test('replays ratings by study day and preserves application state', () {
    final due = calendar.startOfDayUtc(calendar.dayOf(third).addDays(20));
    final before = CardState(
      schedule: ElementSchedule(
        ref: const ElementRef(id: 'card', type: ElementType.card),
        priority: PriorityRank.middle,
        lifecycle: ElementLifecycle.active,
        dueDay: calendar.dayOf(due),
        originalDueDay: calendar.dayOf(due),
      ),
      memory: CardMemory(
        cardId: 'card',
        state: CardLearningState.review,
        step: null,
        stability: 999,
        difficulty: 9,
        repetitionCount: 3,
        lapses: 1,
        lastReviewAtUtc: third,
        dueAtUtc: due,
        originalDueAtUtc: due,
        schedulerVersion: 'old',
        parametersVersion: 'old',
        scheduledDays: 20,
      ),
    );

    final after = const FsrsMemoryRecomputer(calendar: calendar).recompute(
      before,
      reviews: <ReviewRecord>[
        review('3', CardRating.again, third),
        review('1', CardRating.good, first),
        review('2', CardRating.easy, second),
      ],
      parameters: fsrs.defaultW,
      parametersVersion: 'new',
    );

    expect(after.memory.stability, isNot(999));
    expect(after.memory.difficulty, isNot(9));
    expect(after.memory.parametersVersion, 'new');
    expect(after.memory.lastReviewAtUtc, third);
    expect(after.memory.dueAtUtc, due);
    expect(after.memory.repetitionCount, 3);
    expect(after.memory.lapses, 1);
    expect(after.schedule, before.schedule);
  });
}
