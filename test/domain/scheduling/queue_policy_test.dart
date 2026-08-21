import 'package:incremental_reader/src/domain/scheduling/card_scheduler.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/priority_rank.dart';
import 'package:incremental_reader/src/domain/scheduling/queue_policy.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:incremental_reader/src/domain/scheduling/topic_scheduler.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 3, 5, 12);
  const today = StudyDay(year: 2026, month: 3, day: 5, zoneId: 'UTC');

  group('minimal heterogeneous queue', () {
    test('interleaves four cards then one topic and drains either stream', () {
      final policy = const MinimalQueuePolicy();
      final candidates = <QueueCandidate>[
        for (var i = 1; i <= 10; i++) _card('c$i', dueAt: now, today: today),
        _topic('t1', today: today),
        _topic('t2', today: today),
      ];

      final result = policy.build(
        candidates: candidates.reversed,
        nowUtc: now,
        today: today,
      );

      expect(result.map((candidate) => candidate.ref.id), <String>[
        'c1',
        'c10',
        'c2',
        'c3',
        't1',
        'c4',
        'c5',
        'c6',
        'c7',
        't2',
        'c8',
        'c9',
      ]);
    });

    test('uses exact UTC due time for intraday card eligibility', () {
      final result = const MinimalQueuePolicy().build(
        candidates: <QueueCandidate>[
          _card('due-now', dueAt: now, today: today),
          _card(
            'due-later',
            dueAt: now.add(const Duration(seconds: 1)),
            today: today,
          ),
          _topic('topic-due', today: today),
        ],
        nowUtc: now,
        today: today,
      );

      expect(result.map((candidate) => candidate.ref.id), <String>[
        'due-now',
        'topic-due',
      ]);
    });

    test('filters lifecycle and deferral before mixing', () {
      final tomorrow = today.addDays(1);
      final result = const MinimalQueuePolicy().build(
        candidates: <QueueCandidate>[
          _card(
            'suspended-card',
            dueAt: now,
            today: today,
            lifecycle: ElementLifecycle.suspended,
          ),
          _topic(
            'dismissed-topic',
            today: today,
            lifecycle: ElementLifecycle.dismissed,
          ),
          _topic('deferred-topic', today: today, deferredUntil: tomorrow),
          _card('eligible-card', dueAt: now, today: today),
        ],
        nowUtc: now,
        today: today,
      );

      expect(result.map((candidate) => candidate.ref.id), <String>[
        'eligible-card',
      ]);
    });

    test('orders each stream by priority, original due, then stable id', () {
      final high = PriorityRank.above(PriorityRank.middle);
      final yesterday = today.addDays(-1);
      final result = const MinimalQueuePolicy().build(
        candidates: <QueueCandidate>[
          _card(
            'c-middle',
            dueAt: now,
            today: today,
            priority: PriorityRank.middle,
          ),
          _card('c-later-id', dueAt: now, today: today, priority: high),
          _card('c-earlier-id', dueAt: now, today: today, priority: high),
          _topic(
            't-newer',
            today: today,
            priority: high,
            originalDueDay: today,
          ),
          _topic(
            't-overdue',
            today: today,
            priority: high,
            originalDueDay: yesterday,
          ),
        ],
        nowUtc: now,
        today: today,
      );

      expect(result.map((candidate) => candidate.ref.id), <String>[
        'c-earlier-id',
        'c-later-id',
        'c-middle',
        't-overdue',
        't-newer',
      ]);
    });
  });
}

QueueCandidate _card(
  String id, {
  required DateTime dueAt,
  required StudyDay today,
  PriorityRank priority = PriorityRank.middle,
  ElementLifecycle lifecycle = ElementLifecycle.active,
}) {
  final schedule = ElementSchedule(
    ref: ElementRef(id: id, type: ElementType.card),
    priority: priority,
    lifecycle: lifecycle,
    dueDay: today,
    originalDueDay: today,
  );
  return QueueCandidate.card(
    CardState(
      schedule: schedule,
      memory: CardMemory.newCard(cardId: id, dueAtUtc: dueAt),
    ),
  );
}

QueueCandidate _topic(
  String id, {
  required StudyDay today,
  PriorityRank priority = PriorityRank.middle,
  ElementLifecycle lifecycle = ElementLifecycle.active,
  StudyDay? originalDueDay,
  StudyDay? deferredUntil,
}) => QueueCandidate.topic(
  TopicState(
    schedule: ElementSchedule(
      ref: ElementRef(id: id, type: ElementType.extract),
      priority: priority,
      lifecycle: lifecycle,
      dueDay: today,
      originalDueDay: originalDueDay ?? today,
      deferredUntil: deferredUntil,
      deferralKind: deferredUntil == null
          ? DeferralKind.none
          : DeferralKind.manual,
    ),
    profileId: 'extract-v1',
    stepIndex: 0,
  ),
);
