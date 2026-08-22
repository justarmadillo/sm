import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/priority_rank.dart';
import 'package:incremental_reader/src/domain/scheduling/schedule_adjustment.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:test/test.dart';

/// A zone that jumps forward one hour at a fixed instant, standing in for a
/// DST transition without pulling in a timezone database.
final class _DstZone implements TimeZoneRules {
  const _DstZone(this.switchInstant);

  final DateTime switchInstant;

  @override
  String get zoneId => 'Test/Dst';

  @override
  int offsetMinutesAt(DateTime instantUtc) =>
      instantUtc.isBefore(switchInstant) ? 60 : 120;
}

void main() {
  group('StudyDay', () {
    const zone = FixedOffsetZone(zoneId: 'Test/Plus2', offsetMinutes: 120);
    const calendar = StudyDayCalendar(zone: zone);

    test('an instant before rollover still belongs to the previous day', () {
      // 02:30 local on the 5th is before the 04:00 rollover.
      final instant = DateTime.utc(2026, 3, 5, 0, 30);
      expect(calendar.dayOf(instant).toString(), '2026-03-04');
    });

    test('an instant after rollover belongs to the new day', () {
      final instant = DateTime.utc(2026, 3, 5, 2, 30); // 04:30 local
      expect(calendar.dayOf(instant).toString(), '2026-03-05');
    });

    test('day boundaries are exact and contiguous', () {
      final day = StudyDay.parse('2026-03-05', zoneId: zone.zoneId);
      final start = calendar.startOfDayUtc(day);
      final end = calendar.endOfDayUtc(day);
      expect(calendar.dayOf(start), day);
      expect(
        calendar.dayOf(end),
        StudyDay.parse('2026-03-06', zoneId: zone.zoneId),
      );
      expect(calendar.contains(day, start), isTrue);
      expect(
        calendar.contains(day, end.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(calendar.contains(day, end), isFalse);
    });

    test('day arithmetic crosses month and year ends', () {
      final day = StudyDay.parse('2026-12-31', zoneId: 'UTC');
      expect(day.addDays(1).toString(), '2027-01-01');
      expect(day.addDays(-1).toString(), '2026-12-30');
      expect(day.daysUntil(day.addDays(45)), 45);
      expect(day.addDays(45).daysUntil(day), -45);
    });

    test('a DST jump does not shift the study day', () {
      // The zone moves from +01:00 to +02:00 mid-day on 2026-03-29.
      final zone = _DstZone(DateTime.utc(2026, 3, 29, 1));
      final calendar = StudyDayCalendar(zone: zone);
      final before = DateTime.utc(2026, 3, 29, 0, 30); // 01:30 local, +01:00
      final after = DateTime.utc(2026, 3, 29, 5); // 07:00 local, +02:00
      expect(calendar.dayOf(before).toString(), '2026-03-28');
      expect(calendar.dayOf(after).toString(), '2026-03-29');

      final day = StudyDay.parse('2026-03-29', zoneId: zone.zoneId);
      // 04:00 local on the 29th is after the switch, so it is 02:00 UTC.
      expect(calendar.startOfDayUtc(day), DateTime.utc(2026, 3, 29, 2));
      expect(calendar.dayOf(calendar.startOfDayUtc(day)), day);
    });

    test('parses and prints its own format', () {
      final day = StudyDay.parse('2026-01-09', zoneId: 'UTC');
      expect(day.toString(), '2026-01-09');
      expect(day.year, 2026);
      expect(day.month, 1);
      expect(day.day, 9);
    });
  });

  group('PriorityRank', () {
    test('a key between two keys sorts strictly between them', () {
      final a = PriorityRank.middle;
      final b = PriorityRank.below(a);
      final mid = PriorityRank.between(a, b);
      expect(a < mid, isTrue);
      expect(mid < b, isTrue);
    });

    test('repeated insertion at the same point stays ordered', () {
      var low = PriorityRank.middle;
      final high = PriorityRank.below(low);
      final inserted = <PriorityRank>[];
      for (var i = 0; i < 50; i++) {
        final next = PriorityRank.between(low, high);
        inserted.add(next);
        low = next;
      }
      final sorted = List<PriorityRank>.of(inserted)..sort();
      expect(sorted, inserted, reason: 'insertion order must be sort order');
      expect(inserted.last < high, isTrue);
    });

    test('above and below extend the range in both directions', () {
      final start = PriorityRank.middle;
      var top = start;
      var bottom = start;
      for (var i = 0; i < 20; i++) {
        top = PriorityRank.above(top);
        bottom = PriorityRank.below(bottom);
      }
      expect(top < start, isTrue);
      expect(start < bottom, isTrue);
    });

    test('spread produces evenly ordered keys for bulk reprioritization', () {
      final ranks = PriorityRank.spread(count: 10);
      expect(ranks, hasLength(10));
      final sorted = List<PriorityRank>.of(ranks)..sort();
      expect(sorted, ranks);
    });

    test('bounds must be ascending', () {
      final a = PriorityRank.middle;
      final b = PriorityRank.below(a);
      expect(() => PriorityRank.between(b, a), throwsArgumentError);
      expect(() => PriorityRank.between(a, a), throwsArgumentError);
    });

    test('position derives a SuperMemo-style percent', () {
      expect(const PriorityPosition(index: 0, total: 101).percent, 0);
      expect(const PriorityPosition(index: 100, total: 101).percent, 100);
      expect(const PriorityPosition(index: 50, total: 101).percent, 50);
      expect(const PriorityPosition(index: 0, total: 1).percent, 0);
    });
  });

  group('ElementSchedule', () {
    final today = StudyDay.parse('2026-03-05', zoneId: 'UTC');
    ElementSchedule scheduleOn(
      String due, {
      String? original,
      ElementLifecycle lifecycle = ElementLifecycle.active,
    }) => ElementSchedule(
      ref: const ElementRef(id: 'e1', type: ElementType.source),
      priority: PriorityRank.middle,
      lifecycle: lifecycle,
      dueDay: StudyDay.parse(due, zoneId: 'UTC'),
      originalDueDay: StudyDay.parse(original ?? due, zoneId: 'UTC'),
    );


    ScheduleAdjustmentSet lowerBound(ElementRef ref, String day) =>
        ScheduleAdjustmentSet(<ScheduleAdjustment>[
          ScheduleAdjustment(
            id: 'a1',
            element: ref,
            mode: ScheduleAdjustmentMode.lowerBound,
            reason: ScheduleAdjustmentReason.manualLater,
            notBeforeStudyDay: StudyDay.parse(day, zoneId: 'UTC'),
            operationId: 'op',
            policyVersion: 'test',
            createdAtUtc: DateTime.utc(2026, 3, 5),
            createdStudyDay: today,
          ),
        ]);

    StudyDay effectiveDue(
      ElementSchedule schedule, [
      ScheduleAdjustmentSet? adjustments,
    ]) => const EffectiveDueService().topicDueStudyDay(
      topic: schedule.ref,
      algorithmicDueStudyDay: schedule.algorithmicDueDay,
      adjustments: adjustments ?? ScheduleAdjustmentSet.empty,
    );

    bool isEligible(
      ElementSchedule schedule, [
      ScheduleAdjustmentSet? adjustments,
    ]) =>
        schedule.lifecycle.isSchedulable &&
        effectiveDue(schedule, adjustments) <= today;

    test('a due element is eligible today', () {
      expect(isEligible(scheduleOn('2026-03-05')), isTrue);
      expect(isEligible(scheduleOn('2026-03-01')), isTrue);
      expect(isEligible(scheduleOn('2026-03-06')), isFalse);
    });

    test('a lower bound delays eligibility without rewriting the due day', () {
      final schedule = scheduleOn('2026-03-01');
      final adjustments = lowerBound(schedule.ref, '2026-03-08');
      expect(isEligible(schedule, adjustments), isFalse);
      expect(schedule.algorithmicDueDay.toString(), '2026-03-01');
      expect(effectiveDue(schedule, adjustments).toString(), '2026-03-08');
    });

    test('a lower bound in the past never pulls an element forward', () {
      final schedule = scheduleOn('2026-03-10');
      final adjustments = lowerBound(schedule.ref, '2026-03-02');
      expect(effectiveDue(schedule, adjustments).toString(), '2026-03-10');
      expect(isEligible(schedule, adjustments), isFalse);
    });

    test('overdue days are measured against the original due day', () {
      final schedule = scheduleOn('2026-03-05', original: '2026-03-01');
      expect(schedule.overdueDaysOn(today), 4);
      expect(scheduleOn('2026-03-09').overdueDaysOn(today), 0);
    });

    test('non-active lifecycles are never eligible', () {
      for (final lifecycle in <ElementLifecycle>[
        ElementLifecycle.suspended,
        ElementLifecycle.dismissed,
        ElementLifecycle.finished,
        ElementLifecycle.deleted,
      ]) {
        expect(
          isEligible(scheduleOn('2026-03-01', lifecycle: lifecycle)),
          isFalse,
          reason: '${lifecycle.name} must not be eligible',
        );
      }
    });

    test('sources and extracts are topics, cards are not', () {
      expect(ElementType.source.isTopic, isTrue);
      expect(ElementType.extract.isTopic, isTrue);
      expect(ElementType.card.isTopic, isFalse);
    });
  });
}
