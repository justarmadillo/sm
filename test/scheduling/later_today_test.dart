/// Later Today, and why it cannot promise a return date.
///
/// Section 8.4 gives the command three branches, and only one of them touches
/// the schedule. The two that do not are the reason a `back on <date>` message
/// built from the canonical due can name a day in the past.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:test/test.dart';

StudyDay _day(String value) => StudyDay.parse(value, zoneId: 'UTC');

TopicState _topic({required StudyDay due, StudyDay? lastReview}) {
  const ElementRef ref = ElementRef(id: 'topic-1', type: ElementType.source);
  return TopicState(
    schedule: ElementSchedule(
      ref: ref,
      priority: PriorityRank.middle,
      dueDay: due,
      originalDueDay: due,
      lifecycle: ElementLifecycle.active,
    ),
    status: Sm20ElementStatus.memorized,
    repetitionCount: 1,
    lapseCount: 0,
    storedInterval: 3,
    lastReviewDay: lastReview,
    aFactorRaw: DelphiReal48.fromDouble(1.2),
    lastIntervalRatioRaw: DelphiReal48.fromDouble(1),
  );
}

void main() {
  final StudyDay today = _day('2026-08-27');
  final PriorityScale scale = PriorityScale(<PriorityRank>[
    PriorityRank.middle,
  ]);

  TopicScheduler scheduler() => TopicScheduler(prng: Sm20Prng(seed: 0));

  test('an Outstanding element is only shifted inside the queue', () {
    // Overdue by six days, which is the ordinary case for a backlog.
    final TopicState overdue = _topic(due: _day('2026-08-21'));
    final TopicTransition moved = scheduler().laterToday(
      overdue,
      today: today,
      isAlreadyOutstanding: true,
      priorityScale: scale,
    );

    expect(moved.isChange, isFalse);
    expect(
      moved.state.schedule.algorithmicDueDay,
      _day('2026-08-21'),
      reason: 'section 8.4 changes no due date on this branch',
    );
    // This is exactly why the toast cannot read the canonical due and call it
    // a return date: the element is still due, six days ago.
    expect(moved.state.schedule.algorithmicDueDay < today, isTrue);
  });

  test('an element already repeated today is left alone', () {
    final TopicState repeated = _topic(due: today, lastReview: today);
    final TopicTransition moved = scheduler().laterToday(
      repeated,
      today: today,
      isAlreadyOutstanding: false,
      priorityScale: scale,
    );
    expect(moved.isChange, isFalse);
  });

  test('otherwise it reschedules to today and stores the elapsed interval', () {
    final TopicState waiting = _topic(
      due: _day('2026-08-30'),
      lastReview: _day('2026-08-24'),
    );
    final TopicTransition moved = scheduler().laterToday(
      waiting,
      today: today,
      isAlreadyOutstanding: false,
      priorityScale: scale,
    );

    expect(moved.isChange, isTrue);
    expect(moved.state.schedule.algorithmicDueDay, today);
    // Section 8.4 routes this branch through JumpIntervalExt, which adapts A
    // from (old_stored_interval, 0). Priority is the thing it leaves alone,
    // and the repetition count is not advanced: this is still not a review.
    expect(moved.state.aFactorRaw.bytes, isNot(waiting.aFactorRaw.bytes));
    expect(moved.state.schedule.priority, waiting.schedule.priority);
    expect(moved.state.repetitionCount, waiting.repetitionCount);
  });
}
