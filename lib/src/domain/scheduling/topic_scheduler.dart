/// The topic state machine: sources and extracts.
///
/// Every transition here is pure — `(state, command, today, settings)` in, new
/// state plus events out — so the rules that decide when reading continues can
/// be tested exhaustively without a database, a widget, or a real clock.
///
/// The distinction this file exists to protect: **only completing an encounter
/// advances the interval.** Opening, scrolling, extracting, formulating,
/// navigating away, backgrounding, and crashing all leave the schedule exactly
/// where it was. Postponing shifts eligibility without advancing anything — if
/// Later grew the interval, skipping an article five times would push it years
/// into the future and silently delete it by neglect.
///
/// A topic is any element that is not graded. Articles and extracts are both
/// topics; an extract is simply a topic with a parent and less text. There is
/// no Again/Hard/Good/Easy here and no concept of failure, because you do not
/// fail a paragraph — you see it again and do more work on it.
///
/// Two interval models are supported and chosen in Settings:
///
/// * [TopicPacingMode.aFactor] — `next = interval × A`, where A is modulated
///   by priority pressure, by how much of a source is left to read, and by
///   whether an extract has produced any cards yet. This is the SuperMemo
///   model and the default.
/// * [TopicPacingMode.intervalProfile] — an explicit user-edited sequence of
///   day intervals whose last value repeats. Fully predictable, and the model
///   the collection was built with before M4.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../settings/app_settings.dart';
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
    this.intervalDays = 0,
    this.aFactor = 0,
    this.yieldEwma = 0,
    this.encounters = 0,
    this.postponeCount = 0,
    this.encountersSinceLastCard = 0,
    this.lastEncounterDay,
  });

  final ElementSchedule schedule;

  /// Which interval sequence paces this topic in profile mode. Retained in
  /// A-factor mode too: switching modes must not lose the user's choice.
  final String profileId;

  /// Position in that sequence.
  final int stepIndex;

  /// Current interval in days. `0` means none has been computed yet, in which
  /// case the priority-derived first interval applies.
  final double intervalDays;

  /// The A-factor last applied. `0` means none has been computed yet.
  final double aFactor;

  /// Smoothed extraction density, in extracts per thousand words read.
  final double yieldEwma;

  /// How many encounters have been completed in total.
  final int encounters;

  /// How many times this topic has been deferred, manually or automatically.
  /// Purely diagnostic: a high count means the element is being avoided and
  /// probably deserves a lower priority or a dismissal.
  final int postponeCount;

  /// Encounters since the last card was formulated from this element. Drives
  /// the nudge that offers to finish an extract that has stopped producing.
  final int encountersSinceLastCard;

  /// Day of the last completed encounter, for elapsed-time reporting.
  final StudyDay? lastEncounterDay;

  ElementRef get ref => schedule.ref;

  /// Whether this topic is an extract rather than a source.
  bool get isExtract => ref.type == ElementType.extract;

  TopicState copyWith({
    ElementSchedule? schedule,
    String? profileId,
    int? stepIndex,
    double? intervalDays,
    double? aFactor,
    double? yieldEwma,
    int? encounters,
    int? postponeCount,
    int? encountersSinceLastCard,
    StudyDay? lastEncounterDay,
  }) => TopicState(
    schedule: schedule ?? this.schedule,
    profileId: profileId ?? this.profileId,
    stepIndex: stepIndex ?? this.stepIndex,
    intervalDays: intervalDays ?? this.intervalDays,
    aFactor: aFactor ?? this.aFactor,
    yieldEwma: yieldEwma ?? this.yieldEwma,
    encounters: encounters ?? this.encounters,
    postponeCount: postponeCount ?? this.postponeCount,
    encountersSinceLastCard:
        encountersSinceLastCard ?? this.encountersSinceLastCard,
    lastEncounterDay: lastEncounterDay ?? this.lastEncounterDay,
  );

  @override
  bool operator ==(Object other) =>
      other is TopicState &&
      other.schedule.ref == schedule.ref &&
      other.schedule.dueDay == schedule.dueDay &&
      other.schedule.deferredUntil == schedule.deferredUntil &&
      other.schedule.lifecycle == schedule.lifecycle &&
      other.profileId == profileId &&
      other.stepIndex == stepIndex &&
      other.intervalDays == intervalDays &&
      other.aFactor == aFactor &&
      other.encounters == encounters &&
      other.postponeCount == postponeCount &&
      other.encountersSinceLastCard == encountersSinceLastCard;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    schedule.ref,
    schedule.dueDay,
    schedule.deferredUntil,
    schedule.lifecycle,
    profileId,
    stepIndex,
    intervalDays,
    aFactor,
    encounters,
    postponeCount,
    encountersSinceLastCard,
  ]);

  @override
  String toString() =>
      'TopicState(${schedule.ref} $profileId step=$stepIndex '
      'interval=$intervalDays a=$aFactor '
      'due=${schedule.effectiveDueDay} ${schedule.lifecycle.name})';
}

/// What the user actually did during one encounter.
///
/// These are the A-factor's inputs. They are supplied by the caller rather
/// than stored on [TopicState] because they describe a session, not the
/// element: how much was read this time, how many extracts came out of it,
/// and whether the element has produced any cards yet.
@immutable
final class TopicEncounter {
  const TopicEncounter({
    this.readFraction,
    this.hasChildItems = false,
    this.wordsRead = 0,
    this.extractsCreated = 0,
    this.reachedEnd = false,
    this.unprocessedTextRemains = true,
  });

  /// A session with nothing worth reporting. Zero-progress Done is legal.
  static const TopicEncounter none = TopicEncounter();

  /// How far through a source the resume marker now sits, `0` to `1`. Null
  /// for extracts, which have no reading frontier of their own.
  final double? readFraction;

  /// Whether the element has produced at least one card.
  ///
  /// The single most useful term in the extract model: an extract turned into
  /// three clozes has served its purpose and should quietly recede, while one
  /// sitting unconverted for two months should keep nagging.
  final bool hasChildItems;

  /// Words rendered between the session's opening position and its end.
  final int wordsRead;

  /// Extracts created during this session.
  final int extractsCreated;

  /// Whether the reading position reached the end of the text.
  final bool reachedEnd;

  /// Whether any text remains that has not been extracted or processed.
  final bool unprocessedTextRemains;

  /// Extraction density for this session, in extracts per thousand words.
  double get density =>
      wordsRead <= 0 ? 0 : extractsCreated / wordsRead * 1000;

  /// Whether the source can be closed without the user saying so.
  bool get isExhausted => reachedEnd && !unprocessedTextRemains;
}

/// The A-factor and the terms that produced it.
///
/// Returned and logged rather than merely applied: the design's constants are
/// admitted guesses, and only a record of every input alongside every result
/// makes it possible to replace them with measured values later.
@immutable
final class AFactorComputation {
  const AFactorComputation({
    required this.base,
    required this.priorityTerm,
    required this.completionTerm,
    required this.conversionTerm,
    required this.yieldTerm,
    required this.pressure,
    required this.yieldEwma,
    required this.value,
  });

  /// A before modulation.
  final double base;

  /// `priorityFloor + prioritySpan × pressure`.
  final double priorityTerm;

  /// `completionFloor + completionSpan × readFraction`, `1` for extracts.
  final double completionTerm;

  /// Extract conversion factor, `1` for sources.
  final double conversionTerm;

  /// `1 − yieldWeight × normalizedDensity`, `1` when the yield rule is off.
  final double yieldTerm;

  /// Priority pressure used, `0` at the top of the collection.
  final double pressure;

  /// Smoothed density carried forward to the next encounter.
  final double yieldEwma;

  /// The clamped result.
  final double value;

  /// Log-friendly form. Contains no element content.
  Map<String, Object?> toMetadata() => <String, Object?>{
    'a_base': base,
    'a_priority_term': priorityTerm,
    'a_completion_term': completionTerm,
    'a_conversion_term': conversionTerm,
    'a_yield_term': yieldTerm,
    'pressure': pressure,
    'yield_ewma': yieldEwma,
    'a_factor': value,
  };
}

/// Something that happened to a topic, for the activity log.
@immutable
sealed class TopicEvent {
  const TopicEvent(this.ref);

  final ElementRef ref;

  /// Stable dotted name used as the activity-log kind.
  String get kind;
}

/// One encounter was completed and the interval grew.
final class TopicEncounterCompleted extends TopicEvent {
  const TopicEncounterCompleted(
    super.ref, {
    required this.fromStep,
    required this.toStep,
    required this.intervalDays,
    required this.nextDueDay,
    this.previousIntervalDays = 0,
    this.exactIntervalDays = 0,
    this.aFactor,
  });

  final int fromStep;
  final int toStep;

  /// Whole days the next encounter was scheduled after.
  final int intervalDays;

  final StudyDay nextDueDay;

  /// The interval this encounter started from.
  final double previousIntervalDays;

  /// The unrounded product, kept so repeated small growth is not lost to
  /// rounding on every step.
  final double exactIntervalDays;

  /// The A-factor and its terms, absent in profile mode.
  final AFactorComputation? aFactor;

  @override
  String get kind => 'topic.encounter_completed';
}

/// Eligibility moved without the interval advancing.
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
    this.automatic = false,
  });

  final ElementLifecycle from;
  final ElementLifecycle to;

  /// Whether the app closed the element rather than the user.
  final bool automatic;

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
  const TopicScheduler(
    this.profiles, {
    this.settings = const TopicSchedulerSettings(),
  });

  /// Editable interval sequences, used in [TopicPacingMode.intervalProfile].
  final IntervalProfiles profiles;

  /// The tunables both models read.
  final TopicSchedulerSettings settings;

  /// The first interval for a new topic of [type] at [pressure], in days.
  ///
  /// Squared pressure, not linear: it keeps the top of the collection tight
  /// and lets the bottom spread out fast. Extracts use a shorter span because
  /// an unconverted extract is a debt — material committed to but not yet
  /// turned into anything durable.
  int firstIntervalDays(ElementType type, double pressure) {
    final double p = pressure.isNaN ? 0.5 : pressure.clamp(0, 1);
    final int span = type == ElementType.extract
        ? settings.extractFirstIntervalSpan
        : settings.sourceFirstIntervalSpan;
    final int max = type == ElementType.extract
        ? settings.extractFirstIntervalMax
        : settings.sourceFirstIntervalMax;
    final int raw = (1 + span * p * p).round();
    return raw < 1 ? 1 : (raw > max ? max : raw);
  }

  /// State for a newly created topic.
  ///
  /// A new source is due today in both models: unfinished reading is work
  /// waiting to start, not a bookmark, and that invariant is older than either
  /// pacing rule.
  ///
  /// A new extract is due after its priority-derived first interval under the
  /// A-factor model — at minimum the next study day, because the user just
  /// read the passage and re-reading it minutes later teaches nothing. Under
  /// fixed sequences the first appearance is simply the next study day, since
  /// deriving a first interval from priority is part of the A-factor model
  /// rather than a separate rule.
  TopicState createFor({
    required ElementRef ref,
    required String profileId,
    required StudyDay today,
    required ElementSchedule Function(StudyDay due) buildSchedule,
    double pressure = 0.5,
  }) {
    final int first = settings.pacing == TopicPacingMode.aFactor
        ? firstIntervalDays(ref.type, pressure)
        : profiles.byId(profileId).intervalAt(0);
    final StudyDay due = ref.type == ElementType.extract
        ? today.addDays(
            settings.pacing == TopicPacingMode.aFactor ? first : 1,
          )
        : today;
    return TopicState(
      schedule: buildSchedule(due),
      profileId: profileId,
      stepIndex: 0,
      intervalDays: first.toDouble(),
      aFactor: settings.baseAFactor,
    );
  }

  /// Computes A for [state] under [encounter], without applying it.
  ///
  /// Exposed so the diagnostics panel and Settings preview can show what the
  /// next interval would be before the user commits to an encounter.
  AFactorComputation computeAFactor(
    TopicState state,
    TopicEncounter encounter, {
    required double pressure,
  }) {
    final double p = pressure.isNaN ? 0.5 : pressure.clamp(0, 1);
    final double base = settings.baseAFactor;
    final double priorityTerm =
        settings.priorityFloor + settings.prioritySpan * p;

    double completionTerm = 1;
    double conversionTerm = 1;
    if (state.isExtract) {
      conversionTerm = encounter.hasChildItems
          ? settings.convertedExtractFactor
          : settings.unconvertedExtractFactor;
    } else {
      final double read = (encounter.readFraction ?? 0).clamp(0, 1);
      completionTerm =
          settings.completionFloor + settings.completionSpan * read;
    }

    var yieldTerm = 1.0;
    var yieldEwma = state.yieldEwma;
    if (settings.yieldEnabled && encounter.wordsRead > 0) {
      yieldEwma =
          (1 - settings.yieldSmoothing) * state.yieldEwma +
          settings.yieldSmoothing * encounter.density;
      final double normalized = (yieldEwma / settings.yieldReferenceDensity)
          .clamp(0, 1);
      yieldTerm = 1 - settings.yieldWeight * normalized;
    }

    final double raw =
        base * priorityTerm * completionTerm * conversionTerm * yieldTerm;
    final double clamped = raw.clamp(settings.minAFactor, settings.maxAFactor);
    return AFactorComputation(
      base: base,
      priorityTerm: priorityTerm,
      completionTerm: completionTerm,
      conversionTerm: conversionTerm,
      yieldTerm: yieldTerm,
      pressure: p,
      yieldEwma: yieldEwma,
      value: clamped,
    );
  }

  /// Done: the user processed a portion and wants the next thing.
  ///
  /// Grows the interval exactly once and clears any deferral, because the
  /// element has now been dealt with. Zero-progress Done is legal: deciding
  /// there is nothing more to do right now is itself a decision.
  ///
  /// When [TopicSchedulerSettings.autoFinishSources] is on and the encounter
  /// reports the text exhausted, the source finishes instead of being
  /// rescheduled — a dead article that lingers in the queue forever is a real
  /// SuperMemo annoyance and the fix belongs here, not in the user's memory.
  TopicTransition complete(
    TopicState state,
    StudyDay today, {
    TopicEncounter encounter = TopicEncounter.none,
    double pressure = 0.5,
  }) {
    if (!state.schedule.lifecycle.isSchedulable) {
      // Completing a dismissed, suspended, or finished topic is a no-op
      // rather than an error: a stale queue entry must not corrupt state.
      return TopicTransition.unchanged(state);
    }

    if (!state.isExtract &&
        settings.autoFinishSources &&
        encounter.isExhausted) {
      return TopicTransition(
        state.copyWith(
          schedule: state.schedule.copyWith(
            lifecycle: ElementLifecycle.finished,
          ),
          encounters: state.encounters + 1,
          lastEncounterDay: today,
        ),
        <TopicEvent>[
          TopicLifecycleChanged(
            state.ref,
            from: state.schedule.lifecycle,
            to: ElementLifecycle.finished,
            automatic: true,
          ),
        ],
      );
    }

    final (
      int wholeDays,
      double exactDays,
      AFactorComputation? computation,
      int nextStep,
    ) = _nextInterval(state, encounter, pressure);

    final StudyDay nextDue = today.addDays(wholeDays);
    return TopicTransition(
      state.copyWith(
        stepIndex: nextStep,
        intervalDays: exactDays,
        aFactor: computation?.value ?? state.aFactor,
        yieldEwma: computation?.yieldEwma ?? state.yieldEwma,
        encounters: state.encounters + 1,
        encountersSinceLastCard: state.encountersSinceLastCard + 1,
        lastEncounterDay: today,
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
          intervalDays: wholeDays,
          nextDueDay: nextDue,
          previousIntervalDays: state.intervalDays,
          exactIntervalDays: exactDays,
          aFactor: computation,
        ),
      ],
    );
  }

  /// Later: wrong task right now.
  ///
  /// Moves eligibility only. The interval does not grow, and the original due
  /// day is untouched so the element still reads as overdue by the amount it
  /// really is.
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
        postponeCount: state.postponeCount + 1,
        schedule: state.schedule.copyWith(
          deferredUntil: until,
          deferralKind: kind,
        ),
      ),
      <TopicEvent>[TopicPostponed(state.ref, until: until, deferralKind: kind)],
    );
  }

  /// Sets the interval by hand, and with it the next due date.
  ///
  /// SuperMemo treats a manual interval change as a priority signal — asking
  /// to see something sooner says it matters more — but the priority change
  /// is the caller's to make, because only it knows the collection's order.
  TopicTransition reschedule(
    TopicState state, {
    required StudyDay today,
    required int intervalDays,
  }) {
    if (!state.schedule.lifecycle.isSchedulable) {
      return TopicTransition.unchanged(state);
    }
    final int days = intervalDays < 0 ? 0 : intervalDays;
    final StudyDay next = today.addDays(days);
    if (state.schedule.dueDay == next &&
        state.schedule.deferredUntil == null) {
      return TopicTransition.unchanged(state);
    }
    return TopicTransition(
      state.copyWith(
        intervalDays: days.toDouble(),
        schedule: state.schedule.copyWith(
          dueDay: next,
          originalDueDay: next,
          clearDeferral: true,
        ),
      ),
      <TopicEvent>[
        TopicEncounterCompleted(
          state.ref,
          fromStep: state.stepIndex,
          toStep: state.stepIndex,
          intervalDays: days,
          nextDueDay: next,
          previousIntervalDays: state.intervalDays,
          exactIntervalDays: days.toDouble(),
        ),
      ],
    );
  }

  /// Records that a card was formulated, resetting the finish nudge.
  TopicState notifyCardCreated(TopicState state) =>
      state.copyWith(encountersSinceLastCard: 0);

  /// Whether the user should be offered "you have made cards from this and
  /// nothing since — finish it?".
  ///
  /// Without a nudge like this a collection fills with extracts the user
  /// mentally finished months ago but never formally closed.
  bool shouldPromptFinish(TopicState state, {required bool hasChildItems}) =>
      state.isExtract &&
      hasChildItems &&
      state.schedule.lifecycle.isSchedulable &&
      state.encountersSinceLastCard >= settings.extractFinishPromptAfter;

  /// Finish: nothing left to mine.
  ///
  /// Reaching the end of the text does not do this on its own unless
  /// auto-finish is enabled and no unprocessed text remains — a source can be
  /// read to the end and still deserve another pass. Descendants keep their
  /// own schedules, and the element stays in the tree, resurrectable.
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
  /// Due today, but the interval is preserved: a pause is not a reset, and
  /// the user has not forgotten where they were.
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

  (int, double, AFactorComputation?, int) _nextInterval(
    TopicState state,
    TopicEncounter encounter,
    double pressure,
  ) {
    switch (settings.pacing) {
      case TopicPacingMode.intervalProfile:
        final IntervalProfile profile = profiles.byId(state.profileId);
        final int interval = profile.intervalAt(state.stepIndex);
        return (
          interval,
          interval.toDouble(),
          null,
          profile.nextStep(state.stepIndex),
        );
      case TopicPacingMode.aFactor:
        final AFactorComputation computation = computeAFactor(
          state,
          encounter,
          pressure: pressure,
        );
        final double current = state.intervalDays > 0
            ? state.intervalDays
            : firstIntervalDays(state.ref.type, pressure).toDouble();
        // The unrounded product is carried forward so that an A only slightly
        // above 1.0 still accumulates instead of being rounded away each time.
        final double exact = math.max(1, current * computation.value);
        return (
          exact.round(),
          exact,
          computation,
          profiles.byId(state.profileId).nextStep(state.stepIndex),
        );
    }
  }

  TopicTransition _changeLifecycle(TopicState state, ElementLifecycle to) {
    if (state.schedule.lifecycle == to) {
      return TopicTransition.unchanged(state);
    }
    return TopicTransition(
      state.copyWith(schedule: state.schedule.copyWith(lifecycle: to)),
      <TopicEvent>[
        TopicLifecycleChanged(state.ref, from: state.schedule.lifecycle, to: to),
      ],
    );
  }
}
