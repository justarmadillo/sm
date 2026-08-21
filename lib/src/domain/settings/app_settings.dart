/// Every tunable the schedulers, the queue, and the overload valve read.
///
/// The constants in the scheduling design documents are starting points, not
/// derived values, so none of them is written into an algorithm. They live
/// here as one immutable value, are edited in Settings, and are persisted as
/// flat key/value pairs. Two consequences the rest of the app depends on: a
/// scheduler stays a pure function of `(state, command, today, settings)` and
/// is therefore exhaustively testable, and retuning a constant is a data
/// change rather than a code change.
///
/// Decoding is deliberately total: a missing, unknown, or malformed value
/// yields the shipped default instead of throwing, because a settings row
/// written by a newer build must never stop an older one from opening the
/// collection.
library;

import 'package:meta/meta.dart';

/// How a topic's next interval is computed.
enum TopicPacingMode {
  /// `next = interval × A`, with A modulated by priority, completion, and
  /// conversion status. This is the SuperMemo model.
  aFactor,

  /// A fixed, user-edited sequence of day intervals whose last value repeats.
  /// Simpler and fully predictable; the behaviour shipped in M0–M3.
  intervalProfile;

  /// Decodes the stored name, falling back to [aFactor].
  static TopicPacingMode parse(String? value) => switch (value) {
    'interval_profile' => TopicPacingMode.intervalProfile,
    _ => TopicPacingMode.aFactor,
  };

  /// Stable stored name. Never persist [index].
  String get storageName => switch (this) {
    TopicPacingMode.aFactor => 'a_factor',
    TopicPacingMode.intervalProfile => 'interval_profile',
  };
}

/// Which study day an instant belongs to.
@immutable
final class StudyDaySettings {
  const StudyDaySettings({this.zoneId = 'UTC', this.rolloverMinutes = 240});

  /// IANA identifier of the user's home timezone.
  final String zoneId;

  /// Minutes after local midnight at which the study day rolls over.
  final int rolloverMinutes;

  StudyDaySettings copyWith({String? zoneId, int? rolloverMinutes}) =>
      StudyDaySettings(
        zoneId: zoneId ?? this.zoneId,
        rolloverMinutes: rolloverMinutes ?? this.rolloverMinutes,
      );

  @override
  bool operator ==(Object other) =>
      other is StudyDaySettings &&
      other.zoneId == zoneId &&
      other.rolloverMinutes == rolloverMinutes;

  @override
  int get hashCode => Object.hash(zoneId, rolloverMinutes);
}

/// Admission caps, mixing, and sorting for the daily queue.
@immutable
final class QueueSettings {
  const QueueSettings({
    this.maxCards = 200,
    this.maxNewCards = 20,
    this.maxTopics = 50,
    this.cardsPerTopic = 4,
    this.minTopicEvery = 8,
    this.randomization = 0.05,
    this.priorityWeight = 0.75,
    this.overdueWeight = 0.20,
    this.protectedPercentile = 0.05,
    this.overloadTolerance = 1.2,
    this.maxSharePerRoot = 0.5,
    this.autoPostpone = true,
    this.autoSort = true,
    this.studyMoreStep = 20,
  });

  /// Most unique cards admitted on one study day.
  final int maxCards;

  /// How many of [maxCards] may be cards never reviewed before.
  final int maxNewCards;

  /// Most topics — sources and extracts together — admitted on one day.
  final int maxTopics;

  /// Cards served between topics. SuperMemo's healthy ratio is 4:1 or wider.
  final int cardsPerTopic;

  /// Hard interleave floor: at most this many elements may pass without a
  /// topic while topics remain due. Guards against items swamping reading.
  final int minTopicEvery;

  /// Degree of deterministic daily shuffle. `0` gives strict priority order.
  final double randomization;

  /// Weight of relative priority in the within-stream sort key.
  final double priorityWeight;

  /// Weight of capped overdue-ness in the within-stream sort key.
  final double overdueWeight;

  /// Top fraction of the collection that auto-postpone must never touch.
  final double protectedPercentile;

  /// Overshoot allowed before the valve engages, as a multiple of the cap.
  final double overloadTolerance;

  /// Largest share of one session a single source's subtree may occupy.
  final double maxSharePerRoot;

  /// Whether excess due material is deferred automatically at all.
  final bool autoPostpone;

  /// Whether the queue re-sorts by priority at the start of each study day.
  final bool autoSort;

  /// How many extra elements one Study More press admits.
  final int studyMoreStep;

  QueueSettings copyWith({
    int? maxCards,
    int? maxNewCards,
    int? maxTopics,
    int? cardsPerTopic,
    int? minTopicEvery,
    double? randomization,
    double? priorityWeight,
    double? overdueWeight,
    double? protectedPercentile,
    double? overloadTolerance,
    double? maxSharePerRoot,
    bool? autoPostpone,
    bool? autoSort,
    int? studyMoreStep,
  }) => QueueSettings(
    maxCards: maxCards ?? this.maxCards,
    maxNewCards: maxNewCards ?? this.maxNewCards,
    maxTopics: maxTopics ?? this.maxTopics,
    cardsPerTopic: cardsPerTopic ?? this.cardsPerTopic,
    minTopicEvery: minTopicEvery ?? this.minTopicEvery,
    randomization: randomization ?? this.randomization,
    priorityWeight: priorityWeight ?? this.priorityWeight,
    overdueWeight: overdueWeight ?? this.overdueWeight,
    protectedPercentile: protectedPercentile ?? this.protectedPercentile,
    overloadTolerance: overloadTolerance ?? this.overloadTolerance,
    maxSharePerRoot: maxSharePerRoot ?? this.maxSharePerRoot,
    autoPostpone: autoPostpone ?? this.autoPostpone,
    autoSort: autoSort ?? this.autoSort,
    studyMoreStep: studyMoreStep ?? this.studyMoreStep,
  );

  @override
  bool operator ==(Object other) =>
      other is QueueSettings &&
      other.maxCards == maxCards &&
      other.maxNewCards == maxNewCards &&
      other.maxTopics == maxTopics &&
      other.cardsPerTopic == cardsPerTopic &&
      other.minTopicEvery == minTopicEvery &&
      other.randomization == randomization &&
      other.priorityWeight == priorityWeight &&
      other.overdueWeight == overdueWeight &&
      other.protectedPercentile == protectedPercentile &&
      other.overloadTolerance == overloadTolerance &&
      other.maxSharePerRoot == maxSharePerRoot &&
      other.autoPostpone == autoPostpone &&
      other.autoSort == autoSort &&
      other.studyMoreStep == studyMoreStep;

  @override
  int get hashCode => Object.hashAll(<Object>[
    maxCards,
    maxNewCards,
    maxTopics,
    cardsPerTopic,
    minTopicEvery,
    randomization,
    priorityWeight,
    overdueWeight,
    protectedPercentile,
    overloadTolerance,
    maxSharePerRoot,
    autoPostpone,
    autoSort,
    studyMoreStep,
  ]);
}

/// The A-factor model that paces sources and extracts.
///
/// Every coefficient here appears in the worked examples of the scheduling
/// design. Naming them makes the arithmetic auditable and, once months of
/// logged inputs exist, tunable against real data instead of by guesswork.
@immutable
final class TopicSchedulerSettings {
  const TopicSchedulerSettings({
    this.pacing = TopicPacingMode.aFactor,
    this.baseAFactor = 2.0,
    this.priorityFloor = 0.7,
    this.prioritySpan = 0.8,
    this.completionFloor = 0.7,
    this.completionSpan = 0.6,
    this.unconvertedExtractFactor = 0.75,
    this.convertedExtractFactor = 1.25,
    this.yieldEnabled = false,
    this.yieldWeight = 0.6,
    this.yieldSmoothing = 0.3,
    this.yieldReferenceDensity = 4.0,
    this.minAFactor = 1.0,
    this.maxAFactor = 6.0,
    this.sourceFirstIntervalSpan = 20,
    this.sourceFirstIntervalMax = 30,
    this.extractFirstIntervalSpan = 10,
    this.extractFirstIntervalMax = 14,
    this.autoFinishSources = true,
    this.extractFinishPromptAfter = 3,
  });

  /// Which interval model applies to topics.
  final TopicPacingMode pacing;

  /// A before any modulation.
  final double baseAFactor;

  /// `A × (priorityFloor + prioritySpan × pressure)`: top priority shrinks A
  /// so the element returns often; the bottom grows it so it recedes fast.
  final double priorityFloor;

  /// Width of the priority modulation band. See [priorityFloor].
  final double prioritySpan;

  /// `A × (completionFloor + completionSpan × fractionRead)`, sources only.
  final double completionFloor;

  /// Width of the completion modulation band. See [completionFloor].
  final double completionSpan;

  /// An extract that still owes a card comes back sooner.
  final double unconvertedExtractFactor;

  /// An extract that has produced cards has done its job and recedes.
  final double convertedExtractFactor;

  /// Whether extraction density modulates A at all. Experimental by design.
  final bool yieldEnabled;

  /// `A × (1 − yieldWeight × normalizedYield)`.
  final double yieldWeight;

  /// Exponential smoothing applied to the newest density sample.
  final double yieldSmoothing;

  /// Extracts per thousand words treated as a fully productive session.
  final double yieldReferenceDensity;

  /// Lower clamp on A. A floor of 1.0 means a repetition never shortens an
  /// interval by itself; only the user can do that.
  final double minAFactor;

  /// Upper clamp on A.
  final double maxAFactor;

  /// `first = clamp(round(1 + span × pressure²), 1, max)` for sources.
  final int sourceFirstIntervalSpan;

  /// Upper clamp on a source's first interval, in days.
  final int sourceFirstIntervalMax;

  /// The same span for extracts, which start shorter because they are a debt.
  final int extractFirstIntervalSpan;

  /// Upper clamp on an extract's first interval, in days.
  final int extractFirstIntervalMax;

  /// Whether a fully read source with nothing left to mine finishes itself.
  final bool autoFinishSources;

  /// Encounters since the last card before an extract is offered Finish.
  final int extractFinishPromptAfter;

  TopicSchedulerSettings copyWith({
    TopicPacingMode? pacing,
    double? baseAFactor,
    double? priorityFloor,
    double? prioritySpan,
    double? completionFloor,
    double? completionSpan,
    double? unconvertedExtractFactor,
    double? convertedExtractFactor,
    bool? yieldEnabled,
    double? yieldWeight,
    double? yieldSmoothing,
    double? yieldReferenceDensity,
    double? minAFactor,
    double? maxAFactor,
    int? sourceFirstIntervalSpan,
    int? sourceFirstIntervalMax,
    int? extractFirstIntervalSpan,
    int? extractFirstIntervalMax,
    bool? autoFinishSources,
    int? extractFinishPromptAfter,
  }) => TopicSchedulerSettings(
    pacing: pacing ?? this.pacing,
    baseAFactor: baseAFactor ?? this.baseAFactor,
    priorityFloor: priorityFloor ?? this.priorityFloor,
    prioritySpan: prioritySpan ?? this.prioritySpan,
    completionFloor: completionFloor ?? this.completionFloor,
    completionSpan: completionSpan ?? this.completionSpan,
    unconvertedExtractFactor:
        unconvertedExtractFactor ?? this.unconvertedExtractFactor,
    convertedExtractFactor:
        convertedExtractFactor ?? this.convertedExtractFactor,
    yieldEnabled: yieldEnabled ?? this.yieldEnabled,
    yieldWeight: yieldWeight ?? this.yieldWeight,
    yieldSmoothing: yieldSmoothing ?? this.yieldSmoothing,
    yieldReferenceDensity: yieldReferenceDensity ?? this.yieldReferenceDensity,
    minAFactor: minAFactor ?? this.minAFactor,
    maxAFactor: maxAFactor ?? this.maxAFactor,
    sourceFirstIntervalSpan:
        sourceFirstIntervalSpan ?? this.sourceFirstIntervalSpan,
    sourceFirstIntervalMax:
        sourceFirstIntervalMax ?? this.sourceFirstIntervalMax,
    extractFirstIntervalSpan:
        extractFirstIntervalSpan ?? this.extractFirstIntervalSpan,
    extractFirstIntervalMax:
        extractFirstIntervalMax ?? this.extractFirstIntervalMax,
    autoFinishSources: autoFinishSources ?? this.autoFinishSources,
    extractFinishPromptAfter:
        extractFinishPromptAfter ?? this.extractFinishPromptAfter,
  );

  @override
  bool operator ==(Object other) =>
      other is TopicSchedulerSettings &&
      other.pacing == pacing &&
      other.baseAFactor == baseAFactor &&
      other.priorityFloor == priorityFloor &&
      other.prioritySpan == prioritySpan &&
      other.completionFloor == completionFloor &&
      other.completionSpan == completionSpan &&
      other.unconvertedExtractFactor == unconvertedExtractFactor &&
      other.convertedExtractFactor == convertedExtractFactor &&
      other.yieldEnabled == yieldEnabled &&
      other.yieldWeight == yieldWeight &&
      other.yieldSmoothing == yieldSmoothing &&
      other.yieldReferenceDensity == yieldReferenceDensity &&
      other.minAFactor == minAFactor &&
      other.maxAFactor == maxAFactor &&
      other.sourceFirstIntervalSpan == sourceFirstIntervalSpan &&
      other.sourceFirstIntervalMax == sourceFirstIntervalMax &&
      other.extractFirstIntervalSpan == extractFirstIntervalSpan &&
      other.extractFirstIntervalMax == extractFirstIntervalMax &&
      other.autoFinishSources == autoFinishSources &&
      other.extractFinishPromptAfter == extractFinishPromptAfter;

  @override
  int get hashCode => Object.hashAll(<Object>[
    pacing,
    baseAFactor,
    priorityFloor,
    prioritySpan,
    completionFloor,
    completionSpan,
    unconvertedExtractFactor,
    convertedExtractFactor,
    yieldEnabled,
    yieldWeight,
    yieldSmoothing,
    yieldReferenceDensity,
    minAFactor,
    maxAFactor,
    sourceFirstIntervalSpan,
    sourceFirstIntervalMax,
    extractFirstIntervalSpan,
    extractFirstIntervalMax,
    autoFinishSources,
    extractFinishPromptAfter,
  ]);
}

/// FSRS knobs plus the two item behaviours that are not FSRS's business.
@immutable
final class CardSettings {
  const CardSettings({
    this.desiredRetention = 0.90,
    this.learningStepMinutes = const <int>[1, 10],
    this.relearningStepMinutes = const <int>[10],
    this.maximumIntervalDays = 36500,
    this.enableFuzzing = true,
    this.leechLapses = 8,
    this.burySiblings = true,
  });

  /// Probability of recall FSRS aims for at the scheduled instant.
  final double desiredRetention;

  /// Intraday learning steps, in minutes.
  final List<int> learningStepMinutes;

  /// Intraday relearning steps, in minutes.
  final List<int> relearningStepMinutes;

  /// Upper clamp on any scheduled interval.
  final int maximumIntervalDays;

  /// Whether FSRS spreads due dates to avoid clumping.
  final bool enableFuzzing;

  /// Lapses after which a card is flagged and its source passage offered.
  /// Flagged, never auto-suspended: repeated failure usually means the card
  /// was written badly, and suspending it hides the evidence.
  final int leechLapses;

  /// Whether answering a card pushes same-day siblings to the next day.
  final bool burySiblings;

  CardSettings copyWith({
    double? desiredRetention,
    List<int>? learningStepMinutes,
    List<int>? relearningStepMinutes,
    int? maximumIntervalDays,
    bool? enableFuzzing,
    int? leechLapses,
    bool? burySiblings,
  }) => CardSettings(
    desiredRetention: desiredRetention ?? this.desiredRetention,
    learningStepMinutes: learningStepMinutes ?? this.learningStepMinutes,
    relearningStepMinutes: relearningStepMinutes ?? this.relearningStepMinutes,
    maximumIntervalDays: maximumIntervalDays ?? this.maximumIntervalDays,
    enableFuzzing: enableFuzzing ?? this.enableFuzzing,
    leechLapses: leechLapses ?? this.leechLapses,
    burySiblings: burySiblings ?? this.burySiblings,
  );

  @override
  bool operator ==(Object other) =>
      other is CardSettings &&
      other.desiredRetention == desiredRetention &&
      _sameInts(other.learningStepMinutes, learningStepMinutes) &&
      _sameInts(other.relearningStepMinutes, relearningStepMinutes) &&
      other.maximumIntervalDays == maximumIntervalDays &&
      other.enableFuzzing == enableFuzzing &&
      other.leechLapses == leechLapses &&
      other.burySiblings == burySiblings;

  @override
  int get hashCode => Object.hashAll(<Object>[
    desiredRetention,
    Object.hashAll(learningStepMinutes),
    Object.hashAll(relearningStepMinutes),
    maximumIntervalDays,
    enableFuzzing,
    leechLapses,
    burySiblings,
  ]);
}

/// The three postponement mechanisms, deliberately kept apart: a manual
/// Later, the daily overload valve, and a one-shot backlog spread.
@immutable
final class PostponeSettings {
  const PostponeSettings({
    this.laterMinFraction = 0.10,
    this.laterMaxFraction = 0.30,
    this.laterMaxDays = 365,
    this.autoBaseFraction = 0.10,
    this.autoPriorityMultiplier = 4.0,
    this.autoDispersal = 0.2,
    this.autoMaxDays = 1095,
    this.mercyHorizonDays = 14,
    this.mercyDailyCap = 100,
  });

  /// A manual Later delays by a fraction of the element's own interval, so
  /// "later" on a two-day topic is not the same as on a one-year card.
  final double laterMinFraction;

  /// Upper end of the manual Later fraction band.
  final double laterMaxFraction;

  /// Upper clamp on a manual Later delay, in days.
  final int laterMaxDays;

  /// Auto-postpone delay is `interval × base × (1 + multiplier × pressure)`.
  final double autoBaseFraction;

  /// How much further bottom-priority material is pushed than top.
  final double autoPriorityMultiplier;

  /// Random ± spread applied to each delay so a day's overflow does not land
  /// together on one future day and recreate the same overload.
  final double autoDispersal;

  /// Upper clamp on an automatic delay, in days.
  final int autoMaxDays;

  /// Mercy spreads a backlog over this many days.
  final int mercyHorizonDays;

  /// How many elements Mercy places on each day of the horizon.
  final int mercyDailyCap;

  PostponeSettings copyWith({
    double? laterMinFraction,
    double? laterMaxFraction,
    int? laterMaxDays,
    double? autoBaseFraction,
    double? autoPriorityMultiplier,
    double? autoDispersal,
    int? autoMaxDays,
    int? mercyHorizonDays,
    int? mercyDailyCap,
  }) => PostponeSettings(
    laterMinFraction: laterMinFraction ?? this.laterMinFraction,
    laterMaxFraction: laterMaxFraction ?? this.laterMaxFraction,
    laterMaxDays: laterMaxDays ?? this.laterMaxDays,
    autoBaseFraction: autoBaseFraction ?? this.autoBaseFraction,
    autoPriorityMultiplier:
        autoPriorityMultiplier ?? this.autoPriorityMultiplier,
    autoDispersal: autoDispersal ?? this.autoDispersal,
    autoMaxDays: autoMaxDays ?? this.autoMaxDays,
    mercyHorizonDays: mercyHorizonDays ?? this.mercyHorizonDays,
    mercyDailyCap: mercyDailyCap ?? this.mercyDailyCap,
  );

  @override
  bool operator ==(Object other) =>
      other is PostponeSettings &&
      other.laterMinFraction == laterMinFraction &&
      other.laterMaxFraction == laterMaxFraction &&
      other.laterMaxDays == laterMaxDays &&
      other.autoBaseFraction == autoBaseFraction &&
      other.autoPriorityMultiplier == autoPriorityMultiplier &&
      other.autoDispersal == autoDispersal &&
      other.autoMaxDays == autoMaxDays &&
      other.mercyHorizonDays == mercyHorizonDays &&
      other.mercyDailyCap == mercyDailyCap;

  @override
  int get hashCode => Object.hashAll(<Object>[
    laterMinFraction,
    laterMaxFraction,
    laterMaxDays,
    autoBaseFraction,
    autoPriorityMultiplier,
    autoDispersal,
    autoMaxDays,
    mercyHorizonDays,
    mercyDailyCap,
  ]);
}

/// Reader behaviour that is a preference rather than a scheduling rule.
@immutable
final class ReaderSettings {
  const ReaderSettings({this.reminderWords = 500, this.defaultLaterDays = 1});

  /// Words after the session's opening marker before the reminder line shows.
  final int reminderWords;

  /// Days a plain Later moves a topic when its interval is not yet known.
  final int defaultLaterDays;

  ReaderSettings copyWith({int? reminderWords, int? defaultLaterDays}) =>
      ReaderSettings(
        reminderWords: reminderWords ?? this.reminderWords,
        defaultLaterDays: defaultLaterDays ?? this.defaultLaterDays,
      );

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      other.reminderWords == reminderWords &&
      other.defaultLaterDays == defaultLaterDays;

  @override
  int get hashCode => Object.hash(reminderWords, defaultLaterDays);
}

/// The local rotating diagnostic log and the developer panel.
@immutable
final class DiagnosticsSettings {
  const DiagnosticsSettings({
    this.logEnabled = true,
    this.logMaxBytes = 2097152,
    this.logRetainedFiles = 5,
    this.showContentInPanel = false,
  });

  /// Whether structured diagnostics are written to disk at all.
  final bool logEnabled;

  /// Size at which the active log file rotates.
  final int logMaxBytes;

  /// How many rotated files are kept.
  final int logRetainedFiles;

  /// Whether the diagnostics panel may render element text. Off by default:
  /// a panel meant for scheduling bugs should not spill a collection.
  final bool showContentInPanel;

  DiagnosticsSettings copyWith({
    bool? logEnabled,
    int? logMaxBytes,
    int? logRetainedFiles,
    bool? showContentInPanel,
  }) => DiagnosticsSettings(
    logEnabled: logEnabled ?? this.logEnabled,
    logMaxBytes: logMaxBytes ?? this.logMaxBytes,
    logRetainedFiles: logRetainedFiles ?? this.logRetainedFiles,
    showContentInPanel: showContentInPanel ?? this.showContentInPanel,
  );

  @override
  bool operator ==(Object other) =>
      other is DiagnosticsSettings &&
      other.logEnabled == logEnabled &&
      other.logMaxBytes == logMaxBytes &&
      other.logRetainedFiles == logRetainedFiles &&
      other.showContentInPanel == showContentInPanel;

  @override
  int get hashCode => Object.hash(
    logEnabled,
    logMaxBytes,
    logRetainedFiles,
    showContentInPanel,
  );
}

/// The complete configuration of one collection.
@immutable
final class AppSettings {
  const AppSettings({
    this.studyDay = const StudyDaySettings(),
    this.queue = const QueueSettings(),
    this.topics = const TopicSchedulerSettings(),
    this.cards = const CardSettings(),
    this.postpone = const PostponeSettings(),
    this.reader = const ReaderSettings(),
    this.diagnostics = const DiagnosticsSettings(),
    this.intervalProfiles = defaultIntervalProfileDays,
  });

  /// Restores settings from the stored key/value rows.
  ///
  /// Never throws: a malformed or unknown value falls back to the shipped
  /// default so one bad row cannot make a collection unopenable.
  factory AppSettings.fromMap(Map<String, String> stored) {
    final profiles = <String, List<int>>{...defaultIntervalProfileDays};
    for (final MapEntry<String, String> entry in stored.entries) {
      if (!entry.key.startsWith(_profilePrefix)) continue;
      final List<int> days = _readIntList(entry.value);
      if (days.isNotEmpty) {
        profiles[entry.key.substring(_profilePrefix.length)] = days;
      }
    }

    const AppSettings fallback = AppSettings();
    return AppSettings(
      studyDay: StudyDaySettings(
        zoneId: stored['study.zone_id'] ?? fallback.studyDay.zoneId,
        rolloverMinutes: _int(
          stored['study.rollover_minutes'],
          fallback.studyDay.rolloverMinutes,
          min: 0,
          max: 1439,
        ),
      ),
      queue: QueueSettings(
        maxCards: _int(
          stored['queue.max_cards'],
          fallback.queue.maxCards,
          min: 0,
          max: 100000,
        ),
        maxNewCards: _int(
          stored['queue.max_new_cards'],
          fallback.queue.maxNewCards,
          min: 0,
          max: 100000,
        ),
        maxTopics: _int(
          stored['queue.max_topics'],
          fallback.queue.maxTopics,
          min: 0,
          max: 100000,
        ),
        cardsPerTopic: _int(
          stored['queue.cards_per_topic'],
          fallback.queue.cardsPerTopic,
          min: 1,
          max: 100,
        ),
        minTopicEvery: _int(
          stored['queue.min_topic_every'],
          fallback.queue.minTopicEvery,
          min: 1,
          max: 1000,
        ),
        randomization: _double(
          stored['queue.randomization'],
          fallback.queue.randomization,
          min: 0,
          max: 1,
        ),
        priorityWeight: _double(
          stored['queue.priority_weight'],
          fallback.queue.priorityWeight,
          min: 0,
          max: 1,
        ),
        overdueWeight: _double(
          stored['queue.overdue_weight'],
          fallback.queue.overdueWeight,
          min: 0,
          max: 1,
        ),
        protectedPercentile: _double(
          stored['queue.protected_percentile'],
          fallback.queue.protectedPercentile,
          min: 0,
          max: 0.5,
        ),
        overloadTolerance: _double(
          stored['queue.overload_tolerance'],
          fallback.queue.overloadTolerance,
          min: 1,
          max: 10,
        ),
        maxSharePerRoot: _double(
          stored['queue.max_share_per_root'],
          fallback.queue.maxSharePerRoot,
          min: 0.05,
          max: 1,
        ),
        autoPostpone: _bool(
          stored['queue.auto_postpone'],
          fallback.queue.autoPostpone,
        ),
        autoSort: _bool(stored['queue.auto_sort'], fallback.queue.autoSort),
        studyMoreStep: _int(
          stored['queue.study_more_step'],
          fallback.queue.studyMoreStep,
          min: 1,
          max: 10000,
        ),
      ),
      topics: TopicSchedulerSettings(
        pacing: TopicPacingMode.parse(stored['topic.pacing_mode']),
        baseAFactor: _double(
          stored['topic.base_a_factor'],
          fallback.topics.baseAFactor,
          min: 1,
          max: 10,
        ),
        priorityFloor: _double(
          stored['topic.priority_floor'],
          fallback.topics.priorityFloor,
          min: 0.1,
          max: 3,
        ),
        prioritySpan: _double(
          stored['topic.priority_span'],
          fallback.topics.prioritySpan,
          min: 0,
          max: 3,
        ),
        completionFloor: _double(
          stored['topic.completion_floor'],
          fallback.topics.completionFloor,
          min: 0.1,
          max: 3,
        ),
        completionSpan: _double(
          stored['topic.completion_span'],
          fallback.topics.completionSpan,
          min: 0,
          max: 3,
        ),
        unconvertedExtractFactor: _double(
          stored['topic.unconverted_extract_factor'],
          fallback.topics.unconvertedExtractFactor,
          min: 0.1,
          max: 3,
        ),
        convertedExtractFactor: _double(
          stored['topic.converted_extract_factor'],
          fallback.topics.convertedExtractFactor,
          min: 0.1,
          max: 3,
        ),
        yieldEnabled: _bool(
          stored['topic.yield_enabled'],
          fallback.topics.yieldEnabled,
        ),
        yieldWeight: _double(
          stored['topic.yield_weight'],
          fallback.topics.yieldWeight,
          min: 0,
          max: 1,
        ),
        yieldSmoothing: _double(
          stored['topic.yield_smoothing'],
          fallback.topics.yieldSmoothing,
          min: 0,
          max: 1,
        ),
        yieldReferenceDensity: _double(
          stored['topic.yield_reference_density'],
          fallback.topics.yieldReferenceDensity,
          min: 0.1,
          max: 100,
        ),
        minAFactor: _double(
          stored['topic.min_a_factor'],
          fallback.topics.minAFactor,
          min: 0.5,
          max: 3,
        ),
        maxAFactor: _double(
          stored['topic.max_a_factor'],
          fallback.topics.maxAFactor,
          min: 1,
          max: 20,
        ),
        sourceFirstIntervalSpan: _int(
          stored['topic.source_first_span'],
          fallback.topics.sourceFirstIntervalSpan,
          min: 0,
          max: 3650,
        ),
        sourceFirstIntervalMax: _int(
          stored['topic.source_first_max'],
          fallback.topics.sourceFirstIntervalMax,
          min: 1,
          max: 3650,
        ),
        extractFirstIntervalSpan: _int(
          stored['topic.extract_first_span'],
          fallback.topics.extractFirstIntervalSpan,
          min: 0,
          max: 3650,
        ),
        extractFirstIntervalMax: _int(
          stored['topic.extract_first_max'],
          fallback.topics.extractFirstIntervalMax,
          min: 1,
          max: 3650,
        ),
        autoFinishSources: _bool(
          stored['topic.auto_finish_sources'],
          fallback.topics.autoFinishSources,
        ),
        extractFinishPromptAfter: _int(
          stored['topic.extract_finish_prompt_after'],
          fallback.topics.extractFinishPromptAfter,
          min: 1,
          max: 100,
        ),
      ),
      cards: CardSettings(
        desiredRetention: _double(
          stored['card.desired_retention'],
          fallback.cards.desiredRetention,
          min: 0.7,
          max: 0.99,
        ),
        learningStepMinutes: _readIntListOr(
          stored['card.learning_steps'],
          fallback.cards.learningStepMinutes,
        ),
        relearningStepMinutes: _readIntListOr(
          stored['card.relearning_steps'],
          fallback.cards.relearningStepMinutes,
        ),
        maximumIntervalDays: _int(
          stored['card.maximum_interval_days'],
          fallback.cards.maximumIntervalDays,
          min: 1,
          max: 36500,
        ),
        enableFuzzing: _bool(
          stored['card.enable_fuzzing'],
          fallback.cards.enableFuzzing,
        ),
        leechLapses: _int(
          stored['card.leech_lapses'],
          fallback.cards.leechLapses,
          min: 1,
          max: 999,
        ),
        burySiblings: _bool(
          stored['card.bury_siblings'],
          fallback.cards.burySiblings,
        ),
      ),
      postpone: PostponeSettings(
        laterMinFraction: _double(
          stored['postpone.later_min_fraction'],
          fallback.postpone.laterMinFraction,
          min: 0,
          max: 5,
        ),
        laterMaxFraction: _double(
          stored['postpone.later_max_fraction'],
          fallback.postpone.laterMaxFraction,
          min: 0,
          max: 5,
        ),
        laterMaxDays: _int(
          stored['postpone.later_max_days'],
          fallback.postpone.laterMaxDays,
          min: 1,
          max: 36500,
        ),
        autoBaseFraction: _double(
          stored['postpone.auto_base_fraction'],
          fallback.postpone.autoBaseFraction,
          min: 0,
          max: 5,
        ),
        autoPriorityMultiplier: _double(
          stored['postpone.auto_priority_multiplier'],
          fallback.postpone.autoPriorityMultiplier,
          min: 0,
          max: 50,
        ),
        autoDispersal: _double(
          stored['postpone.auto_dispersal'],
          fallback.postpone.autoDispersal,
          min: 0,
          max: 0.9,
        ),
        autoMaxDays: _int(
          stored['postpone.auto_max_days'],
          fallback.postpone.autoMaxDays,
          min: 1,
          max: 36500,
        ),
        mercyHorizonDays: _int(
          stored['postpone.mercy_horizon_days'],
          fallback.postpone.mercyHorizonDays,
          min: 1,
          max: 365,
        ),
        mercyDailyCap: _int(
          stored['postpone.mercy_daily_cap'],
          fallback.postpone.mercyDailyCap,
          min: 1,
          max: 100000,
        ),
      ),
      reader: ReaderSettings(
        reminderWords: _int(
          stored['reader.reminder_words'],
          fallback.reader.reminderWords,
          min: 0,
          max: 100000,
        ),
        defaultLaterDays: _int(
          stored['reader.default_later_days'],
          fallback.reader.defaultLaterDays,
          min: 1,
          max: 3650,
        ),
      ),
      diagnostics: DiagnosticsSettings(
        logEnabled: _bool(
          stored['diagnostics.log_enabled'],
          fallback.diagnostics.logEnabled,
        ),
        logMaxBytes: _int(
          stored['diagnostics.log_max_bytes'],
          fallback.diagnostics.logMaxBytes,
          min: 4096,
          max: 536870912,
        ),
        logRetainedFiles: _int(
          stored['diagnostics.log_retained_files'],
          fallback.diagnostics.logRetainedFiles,
          min: 1,
          max: 100,
        ),
        showContentInPanel: _bool(
          stored['diagnostics.show_content'],
          fallback.diagnostics.showContentInPanel,
        ),
      ),
      intervalProfiles: Map<String, List<int>>.unmodifiable(profiles),
    );
  }

  /// The shipped topic interval sequences. The final value repeats forever.
  static const Map<String, List<int>> defaultIntervalProfileDays =
      <String, List<int>>{
        'focused': <int>[1, 2, 3, 5, 7, 10, 14, 21, 30],
        'normal': <int>[1, 3, 7, 14, 30, 60, 120, 240, 365],
        'slow': <int>[7, 14, 30, 60, 120, 240, 365, 730],
        'extract': <int>[1, 3, 7, 14, 30, 60, 120],
      };

  /// Timezone and rollover.
  final StudyDaySettings studyDay;

  /// Caps, mixing, and sorting.
  final QueueSettings queue;

  /// The A-factor topic model.
  final TopicSchedulerSettings topics;

  /// FSRS and item behaviour.
  final CardSettings cards;

  /// The three postponement mechanisms.
  final PostponeSettings postpone;

  /// Reader preferences.
  final ReaderSettings reader;

  /// Structured logging and the developer panel.
  final DiagnosticsSettings diagnostics;

  /// Editable interval sequences, keyed by profile id.
  final Map<String, List<int>> intervalProfiles;

  /// Flat storage form. Every value round-trips through [AppSettings.fromMap].
  Map<String, String> toMap() => <String, String>{
    'study.zone_id': studyDay.zoneId,
    'study.rollover_minutes': '${studyDay.rolloverMinutes}',
    'queue.max_cards': '${queue.maxCards}',
    'queue.max_new_cards': '${queue.maxNewCards}',
    'queue.max_topics': '${queue.maxTopics}',
    'queue.cards_per_topic': '${queue.cardsPerTopic}',
    'queue.min_topic_every': '${queue.minTopicEvery}',
    'queue.randomization': '${queue.randomization}',
    'queue.priority_weight': '${queue.priorityWeight}',
    'queue.overdue_weight': '${queue.overdueWeight}',
    'queue.protected_percentile': '${queue.protectedPercentile}',
    'queue.overload_tolerance': '${queue.overloadTolerance}',
    'queue.max_share_per_root': '${queue.maxSharePerRoot}',
    'queue.auto_postpone': '${queue.autoPostpone}',
    'queue.auto_sort': '${queue.autoSort}',
    'queue.study_more_step': '${queue.studyMoreStep}',
    'topic.pacing_mode': topics.pacing.storageName,
    'topic.base_a_factor': '${topics.baseAFactor}',
    'topic.priority_floor': '${topics.priorityFloor}',
    'topic.priority_span': '${topics.prioritySpan}',
    'topic.completion_floor': '${topics.completionFloor}',
    'topic.completion_span': '${topics.completionSpan}',
    'topic.unconverted_extract_factor': '${topics.unconvertedExtractFactor}',
    'topic.converted_extract_factor': '${topics.convertedExtractFactor}',
    'topic.yield_enabled': '${topics.yieldEnabled}',
    'topic.yield_weight': '${topics.yieldWeight}',
    'topic.yield_smoothing': '${topics.yieldSmoothing}',
    'topic.yield_reference_density': '${topics.yieldReferenceDensity}',
    'topic.min_a_factor': '${topics.minAFactor}',
    'topic.max_a_factor': '${topics.maxAFactor}',
    'topic.source_first_span': '${topics.sourceFirstIntervalSpan}',
    'topic.source_first_max': '${topics.sourceFirstIntervalMax}',
    'topic.extract_first_span': '${topics.extractFirstIntervalSpan}',
    'topic.extract_first_max': '${topics.extractFirstIntervalMax}',
    'topic.auto_finish_sources': '${topics.autoFinishSources}',
    'topic.extract_finish_prompt_after': '${topics.extractFinishPromptAfter}',
    'card.desired_retention': '${cards.desiredRetention}',
    'card.learning_steps': cards.learningStepMinutes.join(','),
    'card.relearning_steps': cards.relearningStepMinutes.join(','),
    'card.maximum_interval_days': '${cards.maximumIntervalDays}',
    'card.enable_fuzzing': '${cards.enableFuzzing}',
    'card.leech_lapses': '${cards.leechLapses}',
    'card.bury_siblings': '${cards.burySiblings}',
    'postpone.later_min_fraction': '${postpone.laterMinFraction}',
    'postpone.later_max_fraction': '${postpone.laterMaxFraction}',
    'postpone.later_max_days': '${postpone.laterMaxDays}',
    'postpone.auto_base_fraction': '${postpone.autoBaseFraction}',
    'postpone.auto_priority_multiplier': '${postpone.autoPriorityMultiplier}',
    'postpone.auto_dispersal': '${postpone.autoDispersal}',
    'postpone.auto_max_days': '${postpone.autoMaxDays}',
    'postpone.mercy_horizon_days': '${postpone.mercyHorizonDays}',
    'postpone.mercy_daily_cap': '${postpone.mercyDailyCap}',
    'reader.reminder_words': '${reader.reminderWords}',
    'reader.default_later_days': '${reader.defaultLaterDays}',
    'diagnostics.log_enabled': '${diagnostics.logEnabled}',
    'diagnostics.log_max_bytes': '${diagnostics.logMaxBytes}',
    'diagnostics.log_retained_files': '${diagnostics.logRetainedFiles}',
    'diagnostics.show_content': '${diagnostics.showContentInPanel}',
    for (final MapEntry<String, List<int>> entry in intervalProfiles.entries)
      '$_profilePrefix${entry.key}': entry.value.join(','),
  };

  AppSettings copyWith({
    StudyDaySettings? studyDay,
    QueueSettings? queue,
    TopicSchedulerSettings? topics,
    CardSettings? cards,
    PostponeSettings? postpone,
    ReaderSettings? reader,
    DiagnosticsSettings? diagnostics,
    Map<String, List<int>>? intervalProfiles,
  }) => AppSettings(
    studyDay: studyDay ?? this.studyDay,
    queue: queue ?? this.queue,
    topics: topics ?? this.topics,
    cards: cards ?? this.cards,
    postpone: postpone ?? this.postpone,
    reader: reader ?? this.reader,
    diagnostics: diagnostics ?? this.diagnostics,
    intervalProfiles: intervalProfiles ?? this.intervalProfiles,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.studyDay == studyDay &&
      other.queue == queue &&
      other.topics == topics &&
      other.cards == cards &&
      other.postpone == postpone &&
      other.reader == reader &&
      other.diagnostics == diagnostics &&
      _sameProfiles(other.intervalProfiles, intervalProfiles);

  @override
  int get hashCode => Object.hash(
    studyDay,
    queue,
    topics,
    cards,
    postpone,
    reader,
    diagnostics,
    intervalProfiles.length,
  );
}

const String _profilePrefix = 'profile.days.';

bool _sameInts(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _sameProfiles(Map<String, List<int>> a, Map<String, List<int>> b) {
  if (a.length != b.length) return false;
  for (final MapEntry<String, List<int>> entry in a.entries) {
    final List<int>? other = b[entry.key];
    if (other == null || !_sameInts(entry.value, other)) return false;
  }
  return true;
}

int _int(String? raw, int fallback, {required int min, required int max}) {
  final int? parsed = raw == null ? null : int.tryParse(raw.trim());
  if (parsed == null) return fallback;
  return parsed < min ? min : (parsed > max ? max : parsed);
}

double _double(
  String? raw,
  double fallback, {
  required double min,
  required double max,
}) {
  final double? parsed = raw == null ? null : double.tryParse(raw.trim());
  if (parsed == null || parsed.isNaN) return fallback;
  return parsed < min ? min : (parsed > max ? max : parsed);
}

bool _bool(String? raw, bool fallback) => switch (raw?.trim().toLowerCase()) {
  'true' || '1' || 'yes' => true,
  'false' || '0' || 'no' => false,
  _ => fallback,
};

List<int> _readIntList(String raw) => <int>[
  for (final String part in raw.split(','))
    if (int.tryParse(part.trim()) case final int value when value > 0) value,
];

List<int> _readIntListOr(String? raw, List<int> fallback) {
  if (raw == null) return fallback;
  final List<int> parsed = _readIntList(raw);
  return parsed.isEmpty ? fallback : parsed;
}
