import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/interval_profile.dart';
import 'package:incremental_reader/src/domain/scheduling/priority_rank.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:incremental_reader/src/domain/scheduling/topic_scheduler.dart';
import 'package:incremental_reader/src/domain/settings/app_settings.dart';
import 'package:test/test.dart';

void main() {
  // This suite pins the fixed-sequence model. The A-factor model has its own
  // suite; keeping them apart means a change to one cannot quietly rewrite
  // the other's expectations.
  final scheduler = TopicScheduler(
    IntervalProfiles.defaults(),
    settings: const TopicSchedulerSettings(
      pacing: TopicPacingMode.intervalProfile,
    ),
  );
  final today = StudyDay.parse('2026-03-05', zoneId: 'UTC');

  TopicState topic({
    String profileId = 'normal',
    int stepIndex = 0,
    ElementType type = ElementType.source,
    ElementLifecycle lifecycle = ElementLifecycle.active,
    String due = '2026-03-05',
    String? deferred,
    DeferralKind deferralKind = DeferralKind.none,
  }) => TopicState(
    schedule: ElementSchedule(
      ref: ElementRef(id: 'e1', type: type),
      priority: PriorityRank.middle,
      lifecycle: lifecycle,
      dueDay: StudyDay.parse(due, zoneId: 'UTC'),
      originalDueDay: StudyDay.parse(due, zoneId: 'UTC'),
      deferredUntil: deferred == null
          ? null
          : StudyDay.parse(deferred, zoneId: 'UTC'),
      deferralKind: deferralKind,
    ),
    profileId: profileId,
    stepIndex: stepIndex,
  );

  group('interval profiles', () {
    test('carry the sequences the plan specifies', () {
      final profiles = IntervalProfiles.defaults();
      expect(profiles.byId('focused').days, <int>[
        1,
        2,
        3,
        5,
        7,
        10,
        14,
        21,
        30,
      ]);
      expect(profiles.byId('normal').days, <int>[
        1,
        3,
        7,
        14,
        30,
        60,
        120,
        240,
        365,
      ]);
      expect(profiles.byId('slow').days, <int>[
        7,
        14,
        30,
        60,
        120,
        240,
        365,
        730,
      ]);
      expect(profiles.byId(kExtractProfileId).days, <int>[
        1,
        3,
        7,
        14,
        30,
        60,
        120,
      ]);
    });

    test('the final interval repeats forever', () {
      final normal = IntervalProfiles.defaults().byId('normal');
      expect(normal.intervalAt(8), 365);
      expect(normal.intervalAt(99), 365);
      expect(normal.nextStep(8), 8);
    });

    test(
      'an unknown profile degrades to normal rather than stranding work',
      () {
        expect(
          IntervalProfiles.defaults().byId('deleted-profile').id,
          'normal',
        );
      },
    );
  });

  group('creation', () {
    ElementSchedule build(StudyDay due) => ElementSchedule(
      ref: const ElementRef(id: 'e1', type: ElementType.source),
      priority: PriorityRank.middle,
      lifecycle: ElementLifecycle.active,
      dueDay: due,
      originalDueDay: due,
    );

    test('a new source is due today', () {
      final state = scheduler.createFor(
        ref: const ElementRef(id: 's1', type: ElementType.source),
        profileId: 'normal',
        today: today,
        buildSchedule: build,
      );
      expect(state.schedule.dueDay, today);
      expect(state.stepIndex, 0);
    });

    test('a new extract is due on the next study day', () {
      final state = scheduler.createFor(
        ref: const ElementRef(id: 'x1', type: ElementType.extract),
        profileId: kExtractProfileId,
        today: today,
        buildSchedule: build,
      );
      expect(state.schedule.dueDay.toString(), '2026-03-06');
    });
  });

  group('Done advances the sequence exactly once', () {
    test('walks the normal sequence one step per encounter', () {
      var state = topic();
      final intervals = <int>[];
      var day = today;
      for (var i = 0; i < 6; i++) {
        final transition = scheduler.complete(state, day);
        final event = transition.events.single as TopicEncounterCompleted;
        intervals.add(event.intervalDays);
        state = transition.state;
        day = state.schedule.dueDay;
      }
      expect(intervals, <int>[1, 3, 7, 14, 30, 60]);
      expect(state.stepIndex, 6);
    });

    test('a focused source moves faster than a slow one', () {
      final focused = scheduler.complete(topic(profileId: 'focused'), today);
      final slow = scheduler.complete(topic(profileId: 'slow'), today);
      expect(focused.state.schedule.dueDay.toString(), '2026-03-06');
      expect(slow.state.schedule.dueDay.toString(), '2026-03-12');
    });

    test('intervals count from the day of the encounter, not the due day', () {
      // An overdue source completed today gets its interval from today, so
      // lateness does not compound into an immediately-overdue next date.
      final overdue = topic(due: '2026-02-01');
      final transition = scheduler.complete(overdue, today);
      expect(transition.state.schedule.dueDay.toString(), '2026-03-06');
    });

    test(
      'resets the original due day so the next encounter is not overdue',
      () {
        final transition = scheduler.complete(topic(due: '2026-02-01'), today);
        expect(
          transition.state.schedule.originalDueDay.toString(),
          '2026-03-06',
        );
        expect(transition.state.schedule.overdueDaysOn(today), 0);
      },
    );

    test('clears a pending deferral', () {
      final deferred = topic(
        deferred: '2026-03-20',
        deferralKind: DeferralKind.manual,
      );
      final transition = scheduler.complete(deferred, today);
      expect(transition.state.schedule.deferredUntil, isNull);
      expect(transition.state.schedule.deferralKind, DeferralKind.none);
    });

    test('zero-progress Done is legal and still advances', () {
      final transition = scheduler.complete(topic(), today);
      expect(transition.isChange, isTrue);
      expect(transition.state.stepIndex, 1);
    });

    test('is a no-op on a topic that is not schedulable', () {
      for (final lifecycle in <ElementLifecycle>[
        ElementLifecycle.dismissed,
        ElementLifecycle.suspended,
        ElementLifecycle.finished,
        ElementLifecycle.deleted,
      ]) {
        final state = topic(lifecycle: lifecycle);
        final transition = scheduler.complete(state, today);
        expect(transition.isChange, isFalse, reason: lifecycle.name);
        expect(transition.state, state, reason: lifecycle.name);
      }
    });
  });

  group('Later moves eligibility only', () {
    test('does not advance the sequence or rewrite the due day', () {
      final state = topic(stepIndex: 3);
      final transition = scheduler.postpone(
        state,
        until: StudyDay.parse('2026-03-09', zoneId: 'UTC'),
      );
      expect(transition.state.stepIndex, 3);
      expect(transition.state.schedule.dueDay.toString(), '2026-03-05');
      expect(
        transition.state.schedule.effectiveDueDay.toString(),
        '2026-03-09',
      );
      expect(transition.state.schedule.originalDueDay.toString(), '2026-03-05');
    });

    test('keeps the element counted as overdue by its real lateness', () {
      final transition = scheduler.postpone(
        topic(due: '2026-03-01'),
        until: StudyDay.parse('2026-03-08', zoneId: 'UTC'),
      );
      expect(transition.state.schedule.overdueDaysOn(today), 4);
    });

    test('is idempotent for the same target day', () {
      final until = StudyDay.parse('2026-03-09', zoneId: 'UTC');
      final first = scheduler.postpone(topic(), until: until);
      final second = scheduler.postpone(first.state, until: until);
      expect(first.isChange, isTrue);
      expect(second.isChange, isFalse);
      expect(second.state, first.state);
    });

    test('records who deferred it', () {
      final manual = scheduler.postpone(topic(), until: today.addDays(1));
      final automatic = scheduler.postpone(
        topic(),
        until: today.addDays(1),
        kind: DeferralKind.automatic,
      );
      expect(manual.state.schedule.deferralKind, DeferralKind.manual);
      expect(automatic.state.schedule.deferralKind, DeferralKind.automatic);
    });

    test('recalling automatic deferrals leaves manual ones alone', () {
      final manual = scheduler
          .postpone(topic(), until: today.addDays(3))
          .state
          .schedule;
      final automatic = scheduler
          .postpone(
            topic(),
            until: today.addDays(3),
            kind: DeferralKind.automatic,
          )
          .state
          .schedule;

      expect(manual.withAutomaticDeferralRecalled().deferredUntil, isNotNull);
      expect(automatic.withAutomaticDeferralRecalled().deferredUntil, isNull);
    });
  });

  group('lifecycle', () {
    test('finish keeps the content but stops scheduling', () {
      final transition = scheduler.finish(topic());
      expect(transition.state.schedule.lifecycle, ElementLifecycle.finished);
      expect(transition.state.schedule.isEligibleOn(today), isFalse);
      expect(transition.state.stepIndex, 0);
    });

    test('dismiss stops scheduling without touching the step', () {
      final transition = scheduler.dismiss(topic(stepIndex: 4));
      expect(transition.state.schedule.lifecycle, ElementLifecycle.dismissed);
      expect(transition.state.stepIndex, 4);
    });

    test('resume makes a suspended topic due today at the same step', () {
      final suspended = scheduler.suspend(topic(stepIndex: 5)).state;
      final resumed = scheduler.resume(suspended, today);
      expect(resumed.state.schedule.lifecycle, ElementLifecycle.active);
      expect(resumed.state.schedule.dueDay, today);
      expect(resumed.state.stepIndex, 5, reason: 'a pause is not a reset');
    });

    test('resume only applies to suspended topics', () {
      expect(scheduler.resume(topic(), today).isChange, isFalse);
      expect(
        scheduler.resume(scheduler.dismiss(topic()).state, today).isChange,
        isFalse,
      );
    });

    test('reactivate reopens a finished source due today', () {
      final finished = scheduler.finish(topic(stepIndex: 2)).state;
      final reopened = scheduler.reactivate(finished, today);
      expect(reopened.state.schedule.lifecycle, ElementLifecycle.active);
      expect(reopened.state.schedule.dueDay, today);
      expect(reopened.state.stepIndex, 2);
    });

    test('repeating a lifecycle change is a no-op', () {
      final dismissed = scheduler.dismiss(topic()).state;
      expect(scheduler.dismiss(dismissed).isChange, isFalse);
    });
  });

  group('events describe what happened', () {
    test('completion reports the step it moved between', () {
      final event =
          scheduler.complete(topic(stepIndex: 2), today).events.single
              as TopicEncounterCompleted;
      expect(event.kind, 'topic.encounter_completed');
      expect(event.fromStep, 2);
      expect(event.toStep, 3);
      expect(event.intervalDays, 7);
      expect(event.nextDueDay.toString(), '2026-03-12');
    });

    test('postponement reports its target and origin', () {
      final event =
          scheduler.postpone(topic(), until: today.addDays(2)).events.single
              as TopicPostponed;
      expect(event.kind, 'topic.postponed');
      expect(event.until.toString(), '2026-03-07');
      expect(event.deferralKind, DeferralKind.manual);
    });

    test('lifecycle changes report both ends', () {
      final event =
          scheduler.finish(topic()).events.single as TopicLifecycleChanged;
      expect(event.from, ElementLifecycle.active);
      expect(event.to, ElementLifecycle.finished);
    });
  });
}
