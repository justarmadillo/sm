/// The topic state machine: sources and extracts.
///
/// Every transition here is pure — `(state, command, today, profiles)` in, new
/// state plus events out — so the rules that decide when reading continues can
/// be tested exhaustively without a database, a widget, or a real clock.
///
/// The distinction this file exists to protect: **only completing an encounter
/// advances the sequence.** Opening, scrolling, extracting, formulating,
/// navigating away, backgrounding, and crashing all leave the schedule exactly
/// where it was. Postponing shifts eligibility without advancing anything.
library;

import 'package:meta/meta.dart';

import 'element.dart';
import 'interval_profile.dart';
import 'study_day.dart';

/// Full scheduling state of one topic.
@immutable
final class TopicState {
  const TopicState({
    required this.schedule,
    required this.profileId,
    required this.stepIndex,
  });

  final ElementSchedule schedule;

  /// Which interval sequence paces this topic.
  final String profileId;

  /// Position in that sequence.
  final int stepIndex;

  ElementRef get ref => schedule.ref;

  TopicState copyWith({
    ElementSchedule? schedule,
    String? profileId,
    int? stepIndex,
  }) => TopicState(
    schedule: schedule ?? this.schedule,
    profileId: profileId ?? this.profileId,
    stepIndex: stepIndex ?? this.stepIndex,
  );

  @override
  bool operator ==(Object other) =>
      other is TopicState &&
      other.schedule.ref == schedule.ref &&
      other.schedule.dueDay == schedule.dueDay &&
      other.schedule.deferredUntil == schedule.deferredUntil &&
      other.schedule.lifecycle == schedule.lifecycle &&
      other.profileId == profileId &&
      other.stepIndex == stepIndex;

  @override
  int get hashCode => Object.hash(
    schedule.ref,
    schedule.dueDay,
    schedule.deferredUntil,
    schedule.lifecycle,
    profileId,
    stepIndex,
  );

  @override
  String toString() =>
      'TopicState(${schedule.ref} $profileId step=$stepIndex '
      'due=${schedule.effectiveDueDay} ${schedule.lifecycle.name})';
}

/// Something that happened to a topic, for the activity log.
@immutable
sealed class TopicEvent {
  const TopicEvent(this.ref);

  final ElementRef ref;

  /// Stable dotted name used as the activity-log kind.
  String get kind;
}

/// One encounter was completed and the sequence advanced.
final class TopicEncounterCompleted extends TopicEvent {
  const TopicEncounterCompleted(
    super.ref, {
    required this.fromStep,
    required this.toStep,
    required this.intervalDays,
    required this.nextDueDay,
  });

  final int fromStep;
  final int toStep;
  final int intervalDays;
  final StudyDay nextDueDay;

  @override
  String get kind => 'topic.encounter_completed';
}

/// Eligibility moved without the sequence advancing.
final class TopicPostponed extends TopicEvent {
  const TopicPostponed(
    super.ref, {
    required this.until,
    required this.deferralKind,
  });

  final StudyDay until;
  final DeferralKind deferralKind;

  @override
  String get kind => 'topic.postponed';
}

/// Lifecycle changed.
final class TopicLifecycleChanged extends TopicEvent {
  const TopicLifecycleChanged(
    super.ref, {
    required this.from,
    required this.to,
  });

  final ElementLifecycle from;
  final ElementLifecycle to;

  @override
  String get kind => 'topic.lifecycle_changed';
}

/// The result of a transition: the new state and what happened.
@immutable
final class TopicTransition {
  const TopicTransition(this.state, this.events);

  /// A transition that changed nothing.
  const TopicTransition.unchanged(this.state) : events = const <TopicEvent>[];

  final TopicState state;
  final List<TopicEvent> events;

  /// Whether anything actually changed.
  bool get isChange => events.isNotEmpty;
}

/// Pure transitions over [TopicState].
@immutable
final class TopicScheduler {
  const TopicScheduler(this.profiles);

  final IntervalProfiles profiles;

  /// State for a newly created topic.
  ///
  /// A new source is due today — it is work waiting to start. A new extract is
  /// due on the next study day, because the user just read the passage and
  /// re-reading it minutes later teaches nothing.
  TopicState createFor({
    required ElementRef ref,
    required String profileId,
    required StudyDay today,
    required ElementSchedule Function(StudyDay due) buildSchedule,
  }) {
    final due = ref.type == ElementType.extract ? today.addDays(1) : today;
    return TopicState(
      schedule: buildSchedule(due),
      profileId: profileId,
      stepIndex: 0,
    );
  }

  /// Done: the user processed a portion and wants the next thing.
  ///
  /// Advances the sequence exactly once and clears any deferral, because the
  /// element has now been dealt with. Zero-progress Done is legal: deciding
  /// there is nothing more to do right now is itself a decision.
  TopicTransition complete(TopicState state, StudyDay today) {
    if (!state.schedule.lifecycle.isSchedulable) {
      // Completing a dismissed, suspended, or finished topic is a no-op
      // rather than an error: a stale queue entry must not corrupt state.
      return TopicTransition.unchanged(state);
    }
    final profile = profiles.byId(state.profileId);
    final interval = profile.intervalAt(state.stepIndex);
    final nextDue = today.addDays(interval);
    final nextStep = profile.nextStep(state.stepIndex);

    return TopicTransition(
      state.copyWith(
        stepIndex: nextStep,
        schedule: state.schedule.copyWith(
          dueDay: nextDue,
          originalDueDay: nextDue,
          clearDeferral: true,
        ),
      ),
      <TopicEvent>[
        TopicEncounterCompleted(
          state.ref,
          fromStep: state.stepIndex,
          toStep: nextStep,
          intervalDays: interval,
          nextDueDay: nextDue,
        ),
      ],
    );
  }

  /// Later: wrong task right now.
  ///
  /// Moves eligibility only. The interval sequence does not advance, and the
  /// original due day is untouched so the element still reads as overdue by
  /// the amount it really is.
  TopicTransition postpone(
    TopicState state, {
    required StudyDay until,
    DeferralKind kind = DeferralKind.manual,
  }) {
    if (!state.schedule.lifecycle.isSchedulable) {
      return TopicTransition.unchanged(state);
    }
    if (state.schedule.deferredUntil == until &&
        state.schedule.deferralKind == kind) {
      // Idempotent: postponing to the same day twice is one postponement.
      return TopicTransition.unchanged(state);
    }
    return TopicTransition(
      state.copyWith(
        schedule: state.schedule.copyWith(
          deferredUntil: until,
          deferralKind: kind,
        ),
      ),
      <TopicEvent>[TopicPostponed(state.ref, until: until, deferralKind: kind)],
    );
  }

  /// Finish: the user declares a source done.
  ///
  /// Reaching the end of the text does not do this on its own — a source can
  /// be read to the end and still deserve another pass. Descendants keep their
  /// own schedules.
  TopicTransition finish(TopicState state) =>
      _changeLifecycle(state, ElementLifecycle.finished);

  /// Dismiss: keep the content, stop scheduling it.
  TopicTransition dismiss(TopicState state) =>
      _changeLifecycle(state, ElementLifecycle.dismissed);

  /// Suspend: temporary removal.
  TopicTransition suspend(TopicState state) =>
      _changeLifecycle(state, ElementLifecycle.suspended);

  /// Soft-delete content while preserving it and all independent descendants.
  TopicTransition delete(TopicState state) =>
      _changeLifecycle(state, ElementLifecycle.deleted);

  /// Resume a suspended topic.
  ///
  /// Due today, but the interval step is preserved: a pause is not a reset,
  /// and the user has not forgotten where they were.
  TopicTransition resume(TopicState state, StudyDay today) {
    if (state.schedule.lifecycle != ElementLifecycle.suspended) {
      return TopicTransition.unchanged(state);
    }
    return TopicTransition(
      state.copyWith(
        schedule: state.schedule.copyWith(
          lifecycle: ElementLifecycle.active,
          dueDay: today,
          originalDueDay: today,
          clearDeferral: true,
        ),
      ),
      <TopicEvent>[
        TopicLifecycleChanged(
          state.ref,
          from: ElementLifecycle.suspended,
          to: ElementLifecycle.active,
        ),
      ],
    );
  }

  /// Reopen a finished or dismissed topic, due today.
  TopicTransition reactivate(TopicState state, StudyDay today) {
    if (state.schedule.lifecycle == ElementLifecycle.active) {
      return TopicTransition.unchanged(state);
    }
    return TopicTransition(
      state.copyWith(
        schedule: state.schedule.copyWith(
          lifecycle: ElementLifecycle.active,
          dueDay: today,
          originalDueDay: today,
          clearDeferral: true,
        ),
      ),
      <TopicEvent>[
        TopicLifecycleChanged(
          state.ref,
          from: state.schedule.lifecycle,
          to: ElementLifecycle.active,
        ),
      ],
    );
  }

  TopicTransition _changeLifecycle(TopicState state, ElementLifecycle to) {
    if (state.schedule.lifecycle == to) {
      return TopicTransition.unchanged(state);
    }
    return TopicTransition(
      state.copyWith(schedule: state.schedule.copyWith(lifecycle: to)),
      <TopicEvent>[
        TopicLifecycleChanged(
          state.ref,
          from: state.schedule.lifecycle,
          to: to,
        ),
      ],
    );
  }
}
