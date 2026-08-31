/// Assembles the schedulers from live settings and the live priority order.
///
/// Two things every scheduling decision needs are not constants and are not
/// state on the element:
///
/// * the user's current [AppSettings], because every coefficient is editable;
/// * the collection's current priority order, because priority is *relative*
///   and a percentile only exists in relation to everything else.
///
/// Command runners therefore depend on this one object rather than on a
/// calendar, a profile set, and a scheduler each. It is a factory, not a cache: the priority scale is rebuilt per call, because a queue built from a
/// stale order would place elements where they no longer belong.
library;

import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/daily_queue/queue_policy.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/sm20_collection_state.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/sm20_runtime_store.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/settings_store.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';

/// Resolves a stored zone identifier into offset rules.
///
/// Injected rather than imported so scheduling/ stays free of platform
/// timezone code, and so a test can hand in a fake zone with
/// a known DST transition.
typedef TimeZoneResolver = TimeZoneRules Function(String zoneId);

/// Builds schedulers, the calendar, and the priority scale on demand.
final class SchedulingContext {
  SchedulingContext({
    required SettingsStore settings,
    required LearningRepository learning,
    required Sm20RuntimeStore runtime,
    required Clock clock,
    required TimeZoneResolver resolveZone,
  }) : _settings = settings,
       _learning = learning,
       _runtime = runtime,
       _clock = clock,
       _resolveZone = resolveZone;

  final SettingsStore _settings;
  final LearningRepository _learning;
  final Sm20RuntimeStore _runtime;
  final Clock _clock;
  final TimeZoneResolver _resolveZone;

  /// The user's current configuration.
  Future<AppSettings> settings() => _settings.load();

  /// Persists a complete canonical settings value.
  ///
  /// Scheduler transactions use this when executable behavior changes a
  /// setting itself, such as disabling automatic postponement after a stale
  /// collection is reopened.
  Future<Result<AppSettings>> saveSettings(AppSettings settings) =>
      _settings.save(settings);

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

  /// The topic state machine bound to the persisted global Delphi PRNG.
  Future<TopicScheduler> topicScheduler() async {
    final Sm20CollectionState state = await runtimeState();
    return TopicScheduler(
      randomNumbers: Sm20RandomNumberGenerator(seed: state.randomNumberSeed),
    );
  }

  Future<Sm20CollectionState> runtimeState() async {
    final AppSettings current = await settings();
    return _runtime.load(zoneId: current.studyDay.zoneId);
  }

  Future<void> saveRuntimeState(Sm20CollectionState state) =>
      _runtime.save(state);

  /// Persists the one global random stream after a stochastic transaction.
  Future<void> saveRandomNumberState(
    Sm20RandomNumberGeneratorState state,
  ) async {
    final Sm20CollectionState runtime = await runtimeState();
    await saveRuntimeState(runtime.copyWith(randomNumberSeed: state.seed));
  }

  /// The FSRS adapter, configured.
  ///
  /// The persisted parameter vector is versioned. Settings changes can replay
  /// genuine review history before this context begins producing new states.
  Future<CardScheduler> cardScheduler() async {
    final AppSettings current = await settings();
    return CardScheduler(
      calendar: await calendar(),
      settings: CardSchedulerSettings.fromUserSettings(current.cards),
    );
  }

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
