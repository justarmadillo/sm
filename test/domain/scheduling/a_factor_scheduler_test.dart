/// The canonical topic scheduler: `topic_afactor_v1`.
///
/// These are the acceptance tests the scheduling contract names for topic
/// transitions. The three the design cares about most are in the last group:
/// Later never grows an interval while Done does, priority decides how soon a
/// new topic first comes back, and a rounded interval can never stall.
///
/// The completion, extract-conversion, and extraction-yield modifiers that an
/// earlier exploration proposed are deliberately absent rather than disabled.
/// They compound, they have cold-start holes, and promoting any of them is a
/// new policy version with its own simulation gate — not a setting.
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
    int encounters = 1,
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
    encounters: encounters,
  );

  ElementSchedule scheduleFor(ElementRef ref, StudyDay due) => ElementSchedule(
    ref: ref,
    priority: PriorityRank.middle,
    lifecycle: ElementLifecycle.active,
    dueDay: due,
    originalDueDay: due,
  );

  group('the A-factor', () {
    test('is the priority term alone, clamped', () {
      // A = clamp(base × (floor + span × p), min, max), with p zero at the
      // top of the collection. Nothing else modulates it in v1.
      const TopicSchedulerSettings settings = TopicSchedulerSettings();
      for (final double p in <double>[0, 0.5, 1]) {
        final AFactorComputation computed = scheduler.policy.compute(
          priorityFraction: p,
        );
        expect(
          computed.value,
          closeTo(
            settings.baseAFactor *
                (settings.priorityFloor + settings.prioritySpan * p),
            1e-9,
          ),
          reason: 'at pressure $p',
        );
        expect(computed.completionTerm, 1);
        expect(computed.conversionTerm, 1);
        expect(computed.yieldTerm, 1);
      }
    });

    test('gives higher-priority topics the smaller A, so they return sooner', () {
      final double top = scheduler.policy.compute(priorityFraction: 0).value;
      final double middle = scheduler.policy
          .compute(priorityFraction: 0.5)
          .value;
      final double bottom = scheduler.policy.compute(priorityFraction: 1).value;
      expect(top, lessThan(middle));
      expect(middle, lessThan(bottom));
      // The direction the earlier plan had inverted: the top of the collection
      // must not be the value that lets material recede fastest.
      expect(top, closeTo(1.4, 1e-9));
      expect(bottom, closeTo(3.0, 1e-9));
    });

    test('never falls below the technical floor, so A cannot shrink time', () {
      final TopicScheduler floored = TopicScheduler(
        IntervalProfiles.defaults(),
        settings: const TopicSchedulerSettings(baseAFactor: 0.1),
      );
      expect(
        floored.policy.compute(priorityFraction: 0).value,
        greaterThanOrEqualTo(1.01),
      );
    });

    test('records the exact version that produced it', () {
      expect(
        scheduler.policy.compute(priorityFraction: 0.5).policyVersion,
        kTopicAFactorV1PolicyVersion,
      );
    });

    test('an unusable pressure falls back to the middle rather than throwing', () {
      expect(
        scheduler.policy.compute(priorityFraction: double.nan).value,
        scheduler.policy.compute(priorityFraction: 0.5).value,
      );
    });
  });

  group('first interval', () {
    test('is driven by priority, and squared so the top stays tight', () {
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
    });

    test('clamps an out-of-range pressure rather than extrapolating', () {
      expect(scheduler.firstIntervalDays(ElementType.source, -5), 1);
      expect(
        scheduler.firstIntervalDays(ElementType.source, 5),
        scheduler.firstIntervalDays(ElementType.source, 1),
      );
      expect(
        scheduler.firstIntervalDays(ElementType.extract, 5),
        scheduler.firstIntervalDays(ElementType.extract, 1),
      );
    });

    test('honours the configured upper clamp', () {
      final TopicScheduler wide = TopicScheduler(
        IntervalProfiles.defaults(),
        settings: const TopicSchedulerSettings(
          sourceFirstIntervalSpan: 400,
          extractFirstIntervalSpan: 400,
        ),
      );
      expect(wide.firstIntervalDays(ElementType.source, 1), 30);
      expect(wide.firstIntervalDays(ElementType.extract, 1), 14);
    });

    test('applies at the first genuine encounter, not at creation', () {
      final ElementRef ref = ElementRef(id: 's1', type: ElementType.source);
      final TopicState created = scheduler.createFor(
        ref: ref,
        profileId: 'normal',
        today: today,
        buildSchedule: (StudyDay due) => scheduleFor(ref, due),
        pressure: 1,
      );
      // Creation is introduction eligibility only: no interval, no A-factor,
      // and a bottom-priority article is still readable today.
      expect(created.schedule.dueDay, today);
      expect(created.intervalDays, 0);
      expect(created.aFactor, 0);

      final TopicTransition done = scheduler.complete(
        created,
        today,
        pressure: 1,
      );
      expect(done.state.intervalDays, 21);
      expect(done.state.schedule.dueDay, today.addDays(21));
    });
  });

  group('creation', () {
    test('a new source is eligible today however low its priority', () {
      for (final double pressure in <double>[0, 0.5, 1]) {
        final ElementRef ref = ElementRef(id: 's1', type: ElementType.source);
        expect(
          scheduler
              .createFor(
                ref: ref,
                profileId: 'normal',
                today: today,
                buildSchedule: (StudyDay due) => scheduleFor(ref, due),
                pressure: pressure,
              )
              .schedule
              .dueDay,
          today,
          reason: 'at pressure $pressure',
        );
      }
    });

    test('a new extract is eligible on the next study day', () {
      final ElementRef ref = ElementRef(id: 'x1', type: ElementType.extract);
      expect(
        scheduler
            .createFor(
              ref: ref,
              profileId: kExtractProfileId,
              today: today,
              buildSchedule: (StudyDay due) => scheduleFor(ref, due),
            )
            .schedule
            .dueDay,
        today.addDays(1),
      );
    });

    test('new topics carry the canonical scheduler family and version', () {
      final ElementRef ref = ElementRef(id: 's1', type: ElementType.source);
      final TopicState created = scheduler.createFor(
        ref: ref,
        profileId: 'normal',
        today: today,
        buildSchedule: (StudyDay due) => scheduleFor(ref, due),
      );
      expect(created.schedulerKind, TopicSchedulerKind.topicAFactorV1);
      expect(created.schedulerVersion, kTopicAFactorV1PolicyVersion);
    });
  });

  group('Done', () {
    test('multiplies the interval and records what produced it', () {
      final TopicTransition transition = scheduler.complete(
        topic(intervalDays: 10),
        today,
        pressure: 0.5,
      );
      // A at mid-priority is 2.2, so 10 days becomes 22.
      expect(transition.state.intervalDays, 22);
      expect(transition.state.schedule.dueDay, today.addDays(22));
      expect(transition.state.aFactor, closeTo(2.2, 1e-9));
      expect(
        transition.state.policyInputSnapshot,
        <String, Object?>{
          'priority_fraction': 0.5,
          'a_factor': transition.state.aFactor,
          'policy_version': kTopicAFactorV1PolicyVersion,
        },
      );
    });

    test('grows a one-day interval even when A rounds to a standstill', () {
      final TopicScheduler stalled = TopicScheduler(
        IntervalProfiles.defaults(),
        settings: const TopicSchedulerSettings(
          baseAFactor: 1.01,
          priorityFloor: 1,
          prioritySpan: 0,
          maxAFactor: 1.01,
        ),
      );
      // Without the plus-one guard, round(1 × 1.01) is 1 forever and the topic
      // is pinned to a daily repetition it can never leave.
      expect(
        stalled.complete(topic(intervalDays: 1), today).state.intervalDays,
        2,
      );
    });

    test('intervals count from the day of the encounter, not the due day', () {
      final StudyDay late = today.addDays(9);
      final TopicTransition transition = scheduler.complete(
        topic(intervalDays: 10),
        late,
        pressure: 0.5,
      );
      expect(transition.state.schedule.dueDay, late.addDays(22));
    });

    test('resets the original due day so the next encounter is not overdue', () {
      final TopicTransition transition = scheduler.complete(
        topic(intervalDays: 10),
        today,
      );
      expect(
        transition.state.schedule.originalDueDay,
        transition.state.schedule.dueDay,
      );
      expect(transition.state.schedule.overdueDaysOn(today), 0);
    });

    test('advances exactly once and bumps the revision', () {
      final TopicState before = topic(intervalDays: 10);
      final TopicTransition transition = scheduler.complete(before, today);
      expect(transition.state.encounters, before.encounters + 1);
      expect(transition.state.revision, before.revision + 1);
      expect(transition.events, hasLength(1));
    });

    test('counts encounters since the last card, for the finish nudge', () {
      final TopicState first = scheduler
          .complete(topic(type: ElementType.extract), today)
          .state;
      expect(first.encountersSinceLastCard, 1);
      expect(scheduler.notifyCardCreated(first).encountersSinceLastCard, 0);
    });

    test('is a no-op on an element that is not schedulable', () {
      for (final ElementLifecycle lifecycle in <ElementLifecycle>[
        ElementLifecycle.suspended,
        ElementLifecycle.dismissed,
        ElementLifecycle.finished,
      ]) {
        final TopicState before = topic(lifecycle: lifecycle);
        final TopicTransition transition = scheduler.complete(before, today);
        expect(transition.isChange, isFalse);
        expect(transition.state, same(before));
      }
    });
  });

  group('manual reschedule', () {
    test('sets the interval and the due date together', () {
      final TopicTransition transition = scheduler.reschedule(
        topic(intervalDays: 10),
        today: today,
        intervalDays: 3,
      );
      expect(transition.state.intervalDays, 3);
      expect(transition.state.schedule.dueDay, today.addDays(3));
      expect(transition.state.schedule.originalDueDay, today.addDays(3));
    });

    test('is a no-op on an element that is not schedulable', () {
      final TopicState before = topic(lifecycle: ElementLifecycle.finished);
      expect(
        scheduler
            .reschedule(before, today: today, intervalDays: 3)
            .isChange,
        isFalse,
      );
    });
  });

  group('the three verifications the design asks for', () {
    test('(a) Later leaves the interval alone while Done grows it', () {
      final TopicState start = topic(intervalDays: 10);
      final TopicState postponed = scheduler
          .postpone(start, until: today.addDays(3))
          .state;
      expect(postponed.intervalDays, start.intervalDays);
      expect(postponed.schedule.dueDay, start.schedule.dueDay);
      expect(postponed.encounters, start.encounters);

      // Five Later presses in a row still leave the schedule where it was:
      // avoidance must never be able to delete material by neglect.
      TopicState skipped = start;
      for (var i = 0; i < 5; i++) {
        skipped = scheduler
            .postpone(skipped, until: today.addDays(i + 1))
            .state;
      }
      expect(skipped.intervalDays, start.intervalDays);
      expect(skipped.schedule.dueDay, start.schedule.dueDay);

      expect(
        scheduler.complete(start, today).state.intervalDays,
        greaterThan(start.intervalDays),
      );
    });

    test('(b) a high-priority article returns in about a day and a low-priority one in about three weeks', () {
      final ElementRef ref = ElementRef(id: 's1', type: ElementType.source);
      TopicState created(double pressure) => scheduler.createFor(
        ref: ref,
        profileId: 'normal',
        today: today,
        buildSchedule: (StudyDay due) => scheduleFor(ref, due),
        pressure: pressure,
      );
      expect(
        scheduler.complete(created(0), today, pressure: 0).state.intervalDays,
        1,
      );
      expect(
        scheduler.complete(created(1), today, pressure: 1).state.intervalDays,
        21,
      );
    });

    test('(c) a lower-priority topic recedes faster than a higher-priority one', () {
      final double urgent = scheduler
          .complete(topic(intervalDays: 10), today, pressure: 0)
          .state
          .intervalDays;
      final double ordinary = scheduler
          .complete(topic(intervalDays: 10), today, pressure: 1)
          .state
          .intervalDays;
      expect(urgent, lessThan(ordinary));
    });
  });

  group('policy versioning', () {
    test('a settings change does not reinterpret a stored schedule', () {
      // The stored due day and interval belong to the row. Only the next
      // genuine encounter may read the new constants.
      final TopicState stored = topic(intervalDays: 10);
      final TopicScheduler retuned = TopicScheduler(
        IntervalProfiles.defaults(),
        settings: const TopicSchedulerSettings(baseAFactor: 5),
      );
      expect(stored.intervalDays, 10);
      expect(stored.schedule.dueDay, today);
      expect(
        retuned.complete(stored, today).state.intervalDays,
        greaterThan(scheduler.complete(stored, today).state.intervalDays),
      );
    });

    test('a legacy-sequence row keeps its family through an encounter', () {
      final TopicState legacy = TopicState(
        schedule: scheduleFor(
          ElementRef(id: 'e1', type: ElementType.source),
          today,
        ),
        profileId: 'normal',
        stepIndex: 0,
        schedulerKind: TopicSchedulerKind.legacySequence,
        schedulerVersion: 'legacy_sequence/1',
      );
      final TopicState after = scheduler.complete(legacy, today).state;
      expect(after.schedulerKind, TopicSchedulerKind.legacySequence);
      expect(after.schedulerVersion, 'legacy_sequence/1');
    });
  });
}
