/// Assembles the schedulers from live settings and the live priority order.
///
/// Two things every scheduling decision needs are not constants and are not
/// state on the element:
///
/// * the user's current [AppSettings], because every coefficient is editable;
/// * the collection's current priority order, because priority is *relative*
///   and a percentile only exists in relation to everything else.
///
/// Handlers therefore depend on this one object rather than on a calendar, a
/// profile set, and a scheduler each. It is a factory, not a cache of domain
/// state: the priority scale is rebuilt per call, because a queue built from a
/// stale order would place elements where they no longer belong.
library;

import '../../core/clock.dart';
import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/interval_profile.dart';
import '../../domain/scheduling/overload.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/queue_policy.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../../domain/settings/app_settings.dart';
import '../ports/repositories.dart';
import '../settings/settings_store.dart';

/// Resolves a stored zone identifier into offset rules.
///
/// Injected rather than imported so the domain and application layers stay
/// free of platform timezone code, and so a test can hand in a fake zone with
/// a known DST transition.
typedef TimeZoneResolver = TimeZoneRules Function(String zoneId);

/// Builds schedulers, the calendar, and the priority scale on demand.
final class SchedulingContext {
  SchedulingContext({
    required SettingsStore settings,
    required LearningRepository learning,
    required Clock clock,
    required TimeZoneResolver resolveZone,
  }) : _settings = settings,
       _learning = learning,
       _clock = clock,
       _resolveZone = resolveZone;

  final SettingsStore _settings;
  final LearningRepository _learning;
  final Clock _clock;
  final TimeZoneResolver _resolveZone;

  /// The user's current configuration.
  Future<AppSettings> settings() => _settings.load();

  /// The study-day rules: home zone plus rollover.
  Future<StudyDayCalendar> calendar() async {
    final AppSettings current = await settings();
    return StudyDayCalendar(
      zone: _resolveZone(current.studyDay.zoneId),
      rollover: Duration(minutes: current.studyDay.rolloverMinutes),
    );
  }

  /// The study day the clock currently falls in.
  Future<StudyDay> today() async => (await calendar()).dayOf(_clock.nowUtc());

  /// The interval sequences as the user has edited them.
  Future<IntervalProfiles> profiles() async =>
      IntervalProfiles.fromDays((await settings()).intervalProfiles);

  /// The topic state machine, configured.
  Future<TopicScheduler> topicScheduler() async {
    final AppSettings current = await settings();
    return TopicScheduler(
      IntervalProfiles.fromDays(current.intervalProfiles),
      settings: current.topics,
    );
  }

  /// The FSRS adapter, configured.
  ///
  /// The parameter vector stays pinned even though retention and steps are
  /// editable: a hand-edited weight would silently reinterpret every review
  /// already in the log.
  Future<CardScheduler> cardScheduler() async {
    final AppSettings current = await settings();
    return CardScheduler(
      calendar: await calendar(),
      settings: CardSchedulerSettings.fromUserSettings(current.cards),
    );
  }

  /// The postponement arithmetic, configured.
  Future<OverloadValve> overloadValve() async =>
      OverloadValve(settings: (await settings()).postpone);

  /// The collection's live priority order.
  Future<PriorityScale> priorityScale() async =>
      PriorityScale.sorted(await _learning.listActivePriorities());

  /// The queue builder, configured and bound to the current order.
  Future<QueuePolicy> queuePolicy() async {
    final AppSettings current = await settings();
    return QueuePolicy(settings: current.queue, scale: await priorityScale());
  }

  /// Where [ref] currently sits in the collection, or null when it has no
  /// schedule of its own yet.
  Future<PriorityPosition?> positionOf(ElementRef ref) async {
    final ElementSchedule? schedule = await _learning.findSchedule(ref);
    if (schedule == null) return null;
    return (await priorityScale()).positionOf(schedule.priority);
  }

  /// Priority pressure for [rank] against the live order: `0` at the top.
  Future<double> pressureOf(PriorityRank rank) async =>
      (await priorityScale()).pressureOf(rank);
}
