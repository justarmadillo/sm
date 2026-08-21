/// The A-factor topic model.
///
/// The three checks the scheduling design asks for are the last group: Later
/// never grows an interval while Done does, priority decides how soon a new
/// topic first appears, and an extract that has produced cards recedes faster
/// than one that has not.
library;

import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/interval_profile.dart';
import 'package:incremental_reader/src/domain/scheduling/priority_rank.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:incremental_reader/src/domain/scheduling/topic_scheduler.dart';
import 'package:incremental_reader/src/domain/settings/app_settings.dart';
import 'package:test/test.dart';

void main() {
  final TopicScheduler scheduler = TopicScheduler(IntervalProfiles.defaults());
  final StudyDay today = StudyDay.parse('2026-03-05', zoneId: 'UTC');

  TopicState topic({
    ElementType type = ElementType.source,
    double intervalDays = 10,
    double yieldEwma = 0,
    int encountersSinceLastCard = 0,
    ElementLifecycle lifecycle = ElementLifecycle.active,
  }) => TopicState(
    schedule: ElementSchedule(
      ref: ElementRef(id: 'e1', type: type),
      priority: PriorityRank.middle,
      lifecycle: lifecycle,
      dueDay: today,
      originalDueDay: today,
    ),
    profileId: type == ElementType.extract ? kExtractProfileId : 'normal',
    stepIndex: 0,
    intervalDays: intervalDays,
    yieldEwma: yieldEwma,
    encountersSinceLastCard: encountersSinceLastCard,
  );

  group('first interval', () {
    test('is driven by priority, and squared so the top stays tight', () {
      // The design's own table: top 2% in about a day, the middle in about a
      // week, the bottom in about three.
      expect(scheduler.firstIntervalDays(ElementType.source, 0.02), 1);
      expect(scheduler.firstIntervalDays(ElementType.source, 0.25), 2);
      expect(scheduler.firstIntervalDays(ElementType.source, 0.50), 6);
      expect(scheduler.firstIntervalDays(ElementType.source, 0.75), 12);
      expect(scheduler.firstIntervalDays(ElementType.source, 0.98), 20);
    });

    test('extracts start shorter than articles, because they are a debt', () {
      for (final double pressure in <double>[0.25, 0.5, 0.75, 1.0]) {
        expect(
          scheduler.firstIntervalDays(ElementType.extract, pressure),
          lessThanOrEqualTo(
            scheduler.firstIntervalDays(ElementType.source, pressure),
          ),
          reason: 'at pressure $pressure',
        );
      }
      // Near the top the two round to the same day; the gap opens up as
      // priority falls, which is where it matters.
      for (final double pressure in <double>[0.5, 0.75, 1.0]) {
        expect(
          scheduler.firstIntervalDays(ElementType.extract, pressure),
          lessThan(scheduler.firstIntervalDays(ElementType.source, pressure)),
          reason: 'at pressure $pressure',
        );
      }
    });

    test('is clamped at both ends', () {
      expect(scheduler.firstIntervalDays(ElementType.source, 0), 1);
      expect(scheduler.firstIntervalDays(ElementType.source, 1), 21);
      expect(scheduler.firstIntervalDays(ElementType.extract, 1), 11);
    });

    test('a new source is due today however low its priority', () {
      final TopicState created = scheduler.createFor(
        ref: const ElementRef(id: 's1', type: ElementType.source),
        profileId: 'normal',
        today: today,
        pressure: 0.95,
        buildSchedule: (StudyDay due) => ElementSchedule(
          ref: const ElementRef(id: 's1', type: ElementType.source),
          priority: PriorityRank.middle,
          lifecycle: ElementLifecycle.active,
          dueDay: due,
          originalDueDay: due,
        ),
      );
      expect(
        created.schedule.dueDay,
        today,
        reason: 'unfinished reading is work waiting to start, not a bookmark',
      );
      expect(
        created.intervalDays,
        greaterThan(1),
        reason: 'but its first interval still follows from its priority',
      );
    });

    test('a new extract is never due the same day it was taken', () {
      final TopicState created = scheduler.createFor(
        ref: const ElementRef(id: 'x1', type: ElementType.extract),
        profileId: kExtractProfileId,
        today: today,
        pressure: 0,
        buildSchedule: (StudyDay due) => ElementSchedule(
          ref: const ElementRef(id: 'x1', type: ElementType.extract),
          priority: PriorityRank.middle,
          lifecycle: ElementLifecycle.active,
          dueDay: due,
          originalDueDay: due,
        ),
      );
      expect(created.schedule.dueDay.toString(), '2026-03-06');
    });
  });

  group('the A-factor', () {
    test('is the product of its terms, clamped', () {
      final AFactorComputation a = scheduler.computeAFactor(
        topic(),
        const TopicEncounter(readFraction: 1),
        pressure: 1,
      );
      expect(a.base, 2.0);
      expect(a.priorityTerm, closeTo(1.5, 1e-9));
      expect(a.completionTerm, closeTo(1.3, 1e-9));
      expect(a.conversionTerm, 1);
      expect(a.yieldTerm, 1);
      expect(a.value, closeTo(3.9, 1e-9));
    });

    test('never falls below its floor, so a repetition cannot shorten an '
        'interval by itself', () {
      final AFactorComputation a = scheduler.computeAFactor(
        topic(),
        const TopicEncounter(readFraction: 0),
        pressure: 0,
      );
      expect(a.value, 1.0, reason: '2.0 × 0.7 × 0.7 = 0.98, clamped up');
    });

    test('top priority returns sooner than bottom priority', () {
      final double top = scheduler
          .computeAFactor(topic(), const TopicEncounter(), pressure: 0)
          .value;
      final double bottom = scheduler
          .computeAFactor(topic(), const TopicEncounter(), pressure: 1)
          .value;
      expect(top, lessThan(bottom));
    });

    test('a barely-started article comes back sooner than a finished one', () {
      final double started = scheduler
          .computeAFactor(
            topic(),
            const TopicEncounter(readFraction: 0.1),
            pressure: 0.5,
          )
          .value;
      final double nearlyDone = scheduler
          .computeAFactor(
            topic(),
            const TopicEncounter(readFraction: 0.95),
            pressure: 0.5,
          )
          .value;
      expect(started, lessThan(nearlyDone));
    });

    test('the yield rule is off unless enabled', () {
      const TopicEncounter productive = TopicEncounter(
        wordsRead: 1000,
        extractsCreated: 8,
      );
      expect(
        scheduler.computeAFactor(topic(), productive, pressure: 0.5).yieldTerm,
        1,
      );

      final TopicScheduler tuned = TopicScheduler(
        IntervalProfiles.defaults(),
        settings: const TopicSchedulerSettings(yieldEnabled: true),
      );
      final AFactorComputation a = tuned.computeAFactor(
        topic(),
        productive,
        pressure: 0.5,
      );
      expect(a.yieldTerm, lessThan(1));
      expect(
        a.yieldEwma,
        closeTo(2.4, 1e-9),
        reason: 'the smoothed density carries into the next encounter',
      );
    });
  });

  group('Done', () {
    test('multiplies the interval and records the terms that produced it', () {
      final TopicTransition transition = scheduler.complete(
        topic(intervalDays: 4),
        today,
        encounter: const TopicEncounter(readFraction: 1),
        pressure: 1,
      );
      final TopicEncounterCompleted event =
          transition.events.single as TopicEncounterCompleted;

      expect(event.previousIntervalDays, 4);
      expect(event.exactIntervalDays, closeTo(15.6, 1e-9));
      expect(event.intervalDays, 16);
      expect(event.nextDueDay.toString(), '2026-03-21');
      expect(event.aFactor!.value, closeTo(3.9, 1e-9));
      expect(transition.state.encounters, 1);
      expect(transition.state.lastEncounterDay, today);
    });

    test('carries the unrounded interval forward so slow growth accumulates', () {
      // A = 1.05: rounding at every step would leave the interval at 4 days
      // forever, and the topic would never recede at all.
      final TopicScheduler gentle = TopicScheduler(
        IntervalProfiles.defaults(),
        settings: const TopicSchedulerSettings(
          baseAFactor: 1.05,
          priorityFloor: 1,
          prioritySpan: 0,
          completionFloor: 1,
          completionSpan: 0,
        ),
      );
      var state = topic(intervalDays: 4);
      for (var i = 0; i < 6; i++) {
        state = gentle.complete(state, today, pressure: 0).state;
      }
      expect(state.intervalDays, greaterThan(5));
    });

    test('an extract that produced cards recedes faster than one that has not',
        () {
      final TopicTransition converted = scheduler.complete(
        topic(type: ElementType.extract, intervalDays: 4),
        today,
        encounter: const TopicEncounter(hasChildItems: true),
        pressure: 0.5,
      );
      final TopicTransition unconverted = scheduler.complete(
        topic(type: ElementType.extract, intervalDays: 4),
        today,
        pressure: 0.5,
      );

      expect(
        converted.state.intervalDays,
        greaterThan(unconverted.state.intervalDays),
        reason: 'an unconverted extract is a debt and should keep nagging',
      );
    });

    test('counts encounters since the last card, for the finish nudge', () {
      var state = topic(type: ElementType.extract);
      for (var i = 0; i < 3; i++) {
        state = scheduler
            .complete(
              state,
              state.schedule.dueDay,
              encounter: const TopicEncounter(hasChildItems: true),
            )
            .state;
      }
      expect(state.encountersSinceLastCard, 3);
      expect(scheduler.shouldPromptFinish(state, hasChildItems: true), isTrue);
      expect(
        scheduler.shouldPromptFinish(state, hasChildItems: false),
        isFalse,
        reason: 'an extract that never produced a card has not stalled, it '
            'simply has not been converted yet',
      );

      final TopicState afterCard = scheduler.notifyCardCreated(state);
      expect(afterCard.encountersSinceLastCard, 0);
      expect(
        scheduler.shouldPromptFinish(afterCard, hasChildItems: true),
        isFalse,
      );
    });
  });

  group('auto-finish', () {
    test('closes an article only when it is read through and fully mined', () {
      final TopicTransition finished = scheduler.complete(
        topic(),
        today,
        encounter: const TopicEncounter(
          readFraction: 1,
          reachedEnd: true,
          unprocessedTextRemains: false,
        ),
      );
      expect(
        finished.state.schedule.lifecycle,
        ElementLifecycle.finished,
      );
      expect(
        (finished.events.single as TopicLifecycleChanged).automatic,
        isTrue,
      );
    });

    test('reaching the end alone is not enough', () {
      final TopicTransition transition = scheduler.complete(
        topic(),
        today,
        encounter: const TopicEncounter(readFraction: 1, reachedEnd: true),
      );
      expect(
        transition.state.schedule.lifecycle,
        ElementLifecycle.active,
        reason: 'an article can be read through and still deserve a pass',
      );
    });

    test('can be switched off entirely', () {
      final TopicScheduler manual = TopicScheduler(
        IntervalProfiles.defaults(),
        settings: const TopicSchedulerSettings(autoFinishSources: false),
      );
      final TopicTransition transition = manual.complete(
        topic(),
        today,
        encounter: const TopicEncounter(
          readFraction: 1,
          reachedEnd: true,
          unprocessedTextRemains: false,
        ),
      );
      expect(transition.state.schedule.lifecycle, ElementLifecycle.active);
    });
  });

  group('manual reschedule', () {
    test('sets the interval and the due date together', () {
      final TopicTransition transition = scheduler.reschedule(
        topic(intervalDays: 30),
        today: today,
        intervalDays: 11,
      );
      expect(transition.state.intervalDays, 11);
      expect(transition.state.schedule.dueDay.toString(), '2026-03-16');
      expect(transition.state.schedule.originalDueDay.toString(), '2026-03-16');
    });

    test('is a no-op on an element that is not schedulable', () {
      final TopicState dismissed = topic(
        lifecycle: ElementLifecycle.dismissed,
      );
      expect(
        scheduler.reschedule(dismissed, today: today, intervalDays: 3).isChange,
        isFalse,
      );
    });
  });

  group('the three verifications the design asks for', () {
    test('(a) Later leaves the interval alone while Done grows it', () {
      final TopicState start = topic(intervalDays: 8);

      final TopicState postponed = scheduler
          .postpone(start, until: today.addDays(3))
          .state;
      expect(postponed.intervalDays, 8);
      expect(postponed.encounters, 0);
      expect(postponed.schedule.dueDay, today);
      expect(postponed.schedule.effectiveDueDay.toString(), '2026-03-08');
      expect(postponed.postponeCount, 1);

      final TopicState completed = scheduler
          .complete(start, today, pressure: 0.5)
          .state;
      expect(completed.intervalDays, greaterThan(8));

      // Five skips in a row must not push the article years out.
      var skipped = start;
      for (var i = 0; i < 5; i++) {
        skipped = scheduler
            .postpone(skipped, until: today.addDays(i + 1))
            .state;
      }
      expect(skipped.intervalDays, 8);
    });

    test('(b) a high-priority new article appears in about a day and a '
        'low-priority one in about three weeks', () {
      expect(scheduler.firstIntervalDays(ElementType.source, 0.02), 1);
      expect(
        scheduler.firstIntervalDays(ElementType.source, 0.98),
        inInclusiveRange(19, 22),
      );
    });

    test('(c) an extract with clozes grows faster than one without', () {
      final double withCards = scheduler
          .complete(
            topic(type: ElementType.extract, intervalDays: 6),
            today,
            encounter: const TopicEncounter(hasChildItems: true),
            pressure: 0.4,
          )
          .state
          .intervalDays;
      final double without = scheduler
          .complete(
            topic(type: ElementType.extract, intervalDays: 6),
            today,
            pressure: 0.4,
          )
          .state
          .intervalDays;
      expect(withCards / without, closeTo(1.25 / 0.75, 1e-9));
    });
  });
}
