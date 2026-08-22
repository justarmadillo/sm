/// The daily queue: eligibility, ordering, admission, and overflow.
///
/// The queue is the heart of the application — a session is "work through
/// today's queue", not "open a deck". Everything the design documents argue
/// about converges here, so the rules are worth stating plainly:
///
/// * **Priority sorts the queue; it does not shrink it.** Ordering and
///   admission are separate decisions, and neither may pull not-yet-due
///   material forward or change an interval.
/// * **Ranking is bounded.** Canonical priority remains dominant; lateness can
///   move work only inside a small priority neighbourhood, and stable jitter
///   is presentation-only.
/// * **Topics must not starve.** Items outnumber topics within months, and a
///   pure sort front-loads items until reading stops. Reading is what
///   generates future items, so an interleave floor is a hard rule rather
///   than a preference.
/// * **Overflow is normal.** What does not fit is handed back as overflow for
///   the caller to defer, except for the protected top of the collection and
///   for cards already inside an intraday learning step.
///
/// Every decision is deterministic given the same day and settings, so
/// rebuilding the queue mid-session does not reshuffle the user's place.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../settings/app_settings.dart';
import 'card_scheduler.dart';
import 'deterministic_random.dart';
import 'element.dart';
import 'priority_rank.dart';
import 'study_day.dart';
import 'topic_scheduler.dart';

/// Stable identity used by queue jitter and persisted plan diagnostics.
const String kQueuePolicyVersion = 'queue_policy_v2';

/// A scheduling aggregate ready for queue admission.
@immutable
final class QueueCandidate {
  const QueueCandidate._({
    this.card,
    this.topic,
    this.rootId,
    this.effectiveCardDueAtUtc,
    this.effectiveTopicDueDay,
  });

  /// Candidate from the recall stream.
  ///
  /// [rootId] names the source the card ultimately came from. It remains useful
  /// provenance, but queue policy v2 does not invent a root-share admission
  /// rule that is absent from the authoritative specification.
  factory QueueCandidate.card(
    CardState state, {
    String? rootId,
    DateTime? effectiveDueAtUtc,
  }) {
    if (state.ref.type != ElementType.card) {
      throw ArgumentError('the recall stream accepts cards only');
    }
    if (effectiveDueAtUtc != null && !effectiveDueAtUtc.isUtc) {
      throw ArgumentError.value(
        effectiveDueAtUtc,
        'effectiveDueAtUtc',
        'must be UTC',
      );
    }
    return QueueCandidate._(
      card: state,
      rootId: rootId,
      effectiveCardDueAtUtc: effectiveDueAtUtc,
    );
  }

  /// Candidate from the processing stream.
  factory QueueCandidate.topic(
    TopicState state, {
    String? rootId,
    StudyDay? effectiveDueDay,
  }) {
    if (!state.ref.type.isTopic) {
      throw ArgumentError('the topic stream accepts sources and extracts only');
    }
    return QueueCandidate._(
      topic: state,
      rootId: rootId,
      effectiveTopicDueDay: effectiveDueDay,
    );
  }

  final CardState? card;
  final TopicState? topic;

  /// Presentation due after typed adjustments. Canonical scheduler state is
  /// deliberately left untouched on [card] and [topic].
  final DateTime? effectiveCardDueAtUtc;
  final StudyDay? effectiveTopicDueDay;

  /// The source at the root of this element's provenance, when known.
  final String? rootId;

  bool get isCard => card != null;

  ElementSchedule get schedule => card?.schedule ?? topic!.schedule;

  ElementRef get ref => schedule.ref;

  /// Whether this is a card that has never been reviewed.
  bool get isNewCard => card?.memory.isNew ?? false;

  /// Whether this card is mid-way through learning or relearning steps.
  ///
  /// Such a card bypasses admission limits entirely: it is due again in
  /// minutes, it was already admitted today, and deferring it to tomorrow
  /// would abandon a repetition the user has started.
  bool get isIntradayStep => card?.memory.isIntradayStep ?? false;

  /// The interval this element was last scheduled by, in days.
  ///
  /// Used to normalize overdue-ness: forty days late on a two-day interval is
  /// a different situation from forty days late on a two-year one.
  double get scheduledDays {
    final TopicState? state = topic;
    if (state != null) {
      return state.intervalDays > 0 ? state.intervalDays : 1;
    }
    final CardMemory memory = card!.memory;
    final double? storedInterval = memory.scheduledDays;
    if (storedInterval != null &&
        storedInterval.isFinite &&
        storedInterval > 0) {
      return storedInterval;
    }
    final DateTime? last = memory.lastReviewAtUtc;
    if (last == null) return 1;
    final double days =
        memory.originalDueAtUtc.difference(last).inMinutes / 1440;
    return days < 1 ? 1 : days;
  }

  /// Whether the element may appear at all on this day.
  bool isEligible({required DateTime nowUtc, required StudyDay today}) {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'must be UTC');
    }
    if (!schedule.lifecycle.isSchedulable) return false;
    // Defence in depth for the pre-v7 deferral columns. Typed adjustments are
    // canonical and the v7 migration converts every legacy value into one, so
    // this can only fire for a row written by an older build. Honouring it
    // costs nothing and stops a stale lower bound from silently releasing
    // work the user had already pushed away.
    final StudyDay? legacyDeferral = schedule.deferredUntil;
    if (legacyDeferral != null && legacyDeferral > today) return false;
    final CardState? cardState = card;
    if (cardState != null) {
      return !(effectiveCardDueAtUtc ?? cardState.memory.dueAtUtc)
          .isAfter(nowUtc);
    }
    return (effectiveTopicDueDay ?? schedule.algorithmicDueDay) <= today;
  }

  int get _originalDueOrder => card == null
      ? schedule.originalDueDay.epochDay * Duration.millisecondsPerDay
      : card!.memory.originalDueAtUtc.millisecondsSinceEpoch;
}

/// The minimum independent lanes required by the queue specification.
///
/// A lane is selected only after eligibility and protection have been
/// evaluated. Keeping it on [ScoredCandidate] makes queue diagnostics able to
/// explain both admission and deterministic jitter seeds.
enum QueueLane {
  mandatoryIntradayStep,
  protectedDueReview,
  regularDueReview,
  availableNewCard,
  protectedDueTopic,
  regularDueTopic,
}

/// One scored candidate, kept so the diagnostics panel can explain an order.
@immutable
final class ScoredCandidate {
  const ScoredCandidate({
    required this.candidate,
    required this.score,
    required this.normalizedPriority,
    required this.overdueRatio,
    required this.jitter,
    required this.isProtected,
    this.latenessShift = 0,
    this.lane = QueueLane.regularDueTopic,
  });

  final QueueCandidate candidate;

  /// Presentation rank. Lower goes first.
  ///
  /// This is `priorityFraction - latenessShift + jitter`; it is never written
  /// back to canonical priority.
  final double score;

  /// `1` at the top of the collection, `0` at the bottom.
  final double normalizedPriority;

  /// `0` at the top of the collection and `1` at the bottom.
  double get priorityFraction => 1 - normalizedPriority;

  /// Days late divided by the scheduled interval, capped at one.
  final double overdueRatio;

  /// Bounded lateness correction in `[0, 0.05]`.
  final double latenessShift;

  /// The day's deterministic shuffle term.
  final double jitter;

  /// Whether the element sits inside the protected top percentile.
  final bool isProtected;

  /// The independently ranked/admitted lane this element belongs to.
  final QueueLane lane;

  ElementRef get ref => candidate.ref;
}

/// Persistent position in the ordinary `C C C C T` opportunity pattern.
///
/// Mandatory intraday steps do not advance this cursor: they are injected at
/// the next card opportunity without stealing an ordinary card or topic
/// opportunity. Persist this alongside an active session and pass it back to
/// [QueuePolicy.build] when rebuilding the remaining plan.
@immutable
final class QueueMergeCursor {
  const QueueMergeCursor({this.ordinaryCardsSinceTopic = 0})
    : assert(ordinaryCardsSinceTopic >= 0);

  static const QueueMergeCursor zero = QueueMergeCursor();

  final int ordinaryCardsSinceTopic;

  QueueMergeCursor after(QueueCandidate candidate) {
    if (candidate.isIntradayStep) return this;
    if (candidate.isCard) {
      return QueueMergeCursor(
        ordinaryCardsSinceTopic: ordinaryCardsSinceTopic + 1,
      );
    }
    return zero;
  }

  @override
  bool operator ==(Object other) =>
      other is QueueMergeCursor &&
      other.ordinaryCardsSinceTopic == ordinaryCardsSinceTopic;

  @override
  int get hashCode => ordinaryCardsSinceTopic.hashCode;
}

/// What the day's build actually did, for diagnostics and the weekly stats.
@immutable
final class QueueCounters {
  const QueueCounters({
    required this.dueCards,
    required this.dueTopics,
    required this.admittedCards,
    required this.admittedTopics,
    required this.admittedNewCards,
    required this.overflowCards,
    required this.overflowTopics,
    required this.protectedElements,
    required this.protectionPercent,
  });

  /// Cards eligible before any cap applied.
  final int dueCards;

  /// Topics eligible before any cap applied.
  final int dueTopics;

  final int admittedCards;
  final int admittedTopics;

  /// How many of [admittedCards] had never been reviewed.
  final int admittedNewCards;

  final int overflowCards;
  final int overflowTopics;

  /// Admitted due elements classified as protected from canonical priority.
  final int protectedElements;

  /// How deep into the collection today's admission actually reached: the
  /// percentile of the highest-priority element that did *not* fit.
  ///
  /// This is the single most honest indicator of whether priorities are being
  /// set honestly. If it sits at 3%, nothing in the 3–100% band is safe.
  final double protectionPercent;

  /// Everything eligible today, before admission.
  int get dueTotal => dueCards + dueTopics;

  /// Everything admitted today.
  int get admittedTotal => admittedCards + admittedTopics;

  /// Everything deferred by the valve today.
  int get overflowTotal => overflowCards + overflowTopics;

  /// Share of the day's due volume the valve had to shed.
  ///
  /// Sustained above roughly 30% for weeks means the collection is
  /// oversubscribed and wants bulk demotion, not a bigger cap.
  double get overflowRatio => dueTotal == 0 ? 0 : overflowTotal / dueTotal;

  Map<String, Object?> toMetadata() => <String, Object?>{
    'due_cards': dueCards,
    'due_topics': dueTopics,
    'admitted_cards': admittedCards,
    'admitted_topics': admittedTopics,
    'admitted_new_cards': admittedNewCards,
    'overflow_cards': overflowCards,
    'overflow_topics': overflowTopics,
    'protected': protectedElements,
    'protection_percent': protectionPercent,
  };
}

/// The day's queue: what to show, what to defer, and why.
@immutable
final class QueuePlan {
  const QueuePlan({
    required this.entries,
    required this.overflow,
    required this.counters,
    required this.scored,
    this.nextMergeCursor = QueueMergeCursor.zero,
  });

  /// An empty day.
  static const QueuePlan empty = QueuePlan(
    entries: <QueueCandidate>[],
    overflow: <ScoredCandidate>[],
    counters: QueueCounters(
      dueCards: 0,
      dueTopics: 0,
      admittedCards: 0,
      admittedTopics: 0,
      admittedNewCards: 0,
      overflowCards: 0,
      overflowTopics: 0,
      protectedElements: 0,
      protectionPercent: 100,
    ),
    scored: <ScoredCandidate>[],
    nextMergeCursor: QueueMergeCursor.zero,
  );

  /// Admitted elements in presentation order.
  final List<QueueCandidate> entries;

  /// Elements the caller should defer, worst priority last.
  final List<ScoredCandidate> overflow;

  final QueueCounters counters;

  /// Every admitted element with the terms that placed it.
  final List<ScoredCandidate> scored;

  /// Cursor after every entry in this plan has been consumed.
  final QueueMergeCursor nextMergeCursor;

  bool get isEmpty => entries.isEmpty;
}

/// Builds the day's queue.
@immutable
final class QueuePolicy {
  const QueuePolicy({
    this.settings = const QueueSettings(),
    this.scale = PriorityScale.empty,
    this.datasetId = 'default',
    this.policyVersion = kQueuePolicyVersion,
  });

  /// Caps, merge shape, protected cutoff, and jitter amplitude.
  ///
  /// Legacy settings remain on [QueueSettings] for storage compatibility, but
  /// undocumented root-share, tolerance, and weighted-score behavior does not
  /// participate in this policy.
  final QueueSettings settings;

  /// The collection's current priority order, for percentiles and the
  /// protected floor.
  final PriorityScale scale;

  /// Stable dataset identity included in every deterministic jitter seed.
  final String datasetId;

  /// Versioned identity included in every deterministic jitter seed.
  final String policyVersion;

  /// Builds a plan for [today].
  ///
  /// [extraAdmissions] raises every cap by that many elements for this build
  /// only — that is what Study More does, without persisting a bigger limit
  /// the user did not ask for. [completedInActivePlan] and [inScope] are
  /// eligibility gates and therefore run before any rank work. [mergeCursor]
  /// resumes the ordinary opportunity pattern without reshuffling a session.
  QueuePlan build({
    required Iterable<QueueCandidate> candidates,
    required DateTime nowUtc,
    required StudyDay today,
    int extraAdmissions = 0,
    Set<ElementRef> completedInActivePlan = const <ElementRef>{},
    bool Function(QueueCandidate candidate)? inScope,
    QueueMergeCursor mergeCursor = QueueMergeCursor.zero,
  }) {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'must be UTC');
    }
    final DeterministicRandom random = DeterministicRandom(
      'queue:$datasetId:${today.zoneId}:$today:$policyVersion',
    );

    final lanes = _CandidateLanes();
    for (final QueueCandidate candidate in candidates) {
      if (completedInActivePlan.contains(candidate.ref)) continue;
      if (inScope != null && !inScope(candidate)) continue;
      if (!candidate.isEligible(nowUtc: nowUtc, today: today)) continue;
      // Eligibility deliberately precedes the priority lookup, protection
      // decision, lateness calculation, and jitter draw.
      lanes.add(_score(candidate, nowUtc, today, random));
    }
    if (lanes.isEmpty) return _emptyPlan(mergeCursor);
    lanes.sort();

    final int raisedBy = math.max(0, extraAdmissions);
    final _CardAdmission cardAdmission = _admitCards(
      lanes,
      cap: math.max(0, settings.maxCards + raisedBy),
      newCap: math.max(0, settings.maxNewCards + raisedBy),
    );
    final _TopicAdmission topicAdmission = _admitTopics(
      lanes,
      cap: math.max(0, settings.maxTopics + raisedBy),
    );

    final _MergeResult merged = _interleave(
      mandatory: cardAdmission.mandatory,
      cards: cardAdmission.ordinary,
      topics: topicAdmission.admitted,
      cursor: mergeCursor,
    );
    final List<ScoredCandidate> overflow = <ScoredCandidate>[
      ...cardAdmission.overflow,
      ...topicAdmission.overflow,
    ]..sort(_compare);

    final List<ScoredCandidate> admittedScored = <ScoredCandidate>[
      ...cardAdmission.allAdmitted,
      ...topicAdmission.admitted,
    ];
    return QueuePlan(
      entries: List<QueueCandidate>.unmodifiable(merged.entries),
      overflow: List<ScoredCandidate>.unmodifiable(overflow),
      scored: List<ScoredCandidate>.unmodifiable(admittedScored),
      nextMergeCursor: merged.cursor,
      counters: QueueCounters(
        dueCards: lanes.cardCount,
        dueTopics: lanes.topicCount,
        admittedCards: cardAdmission.allAdmitted.length,
        admittedTopics: topicAdmission.admitted.length,
        admittedNewCards: cardAdmission.admittedNew.length,
        overflowCards: cardAdmission.overflow.length,
        overflowTopics: topicAdmission.overflow.length,
        protectedElements:
            lanes.protectedReviews.length + lanes.protectedTopics.length,
        protectionPercent: _protectionPercent(overflow),
      ),
    );
  }

  ScoredCandidate _score(
    QueueCandidate candidate,
    DateTime nowUtc,
    StudyDay today,
    DeterministicRandom random,
  ) {
    final PriorityPosition? position = scale.positionOf(
      candidate.schedule.priority,
    );
    final double priorityFraction = position?.fraction ?? 0.5;

    // Protection is based only on canonical priority and is fixed before any
    // lateness correction or presentation jitter is calculated.
    final bool isProtected =
        position != null &&
        settings.protectedPercentile > 0 &&
        position.index < (scale.total * settings.protectedPercentile).ceil();
    final QueueLane lane = _laneFor(candidate, isProtected);
    final double overdue = _overdueRatio(candidate, nowUtc, today);
    final double latenessShift = (overdue * 0.05).clamp(0.0, 0.05).toDouble();
    final double jitterAmplitude = math.max(0, settings.randomization);
    final double jitter = jitterAmplitude == 0
        ? 0
        : random.symmetric(
            '$policyVersion|${lane.name}|${candidate.ref}',
            jitterAmplitude / 2,
          );
    return ScoredCandidate(
      candidate: candidate,
      score: priorityFraction - latenessShift + jitter,
      normalizedPriority: 1 - priorityFraction,
      overdueRatio: overdue,
      latenessShift: latenessShift,
      jitter: jitter,
      isProtected: isProtected,
      lane: lane,
    );
  }

  QueueLane _laneFor(QueueCandidate candidate, bool isProtected) {
    if (candidate.isIntradayStep) {
      return QueueLane.mandatoryIntradayStep;
    }
    if (candidate.isNewCard) return QueueLane.availableNewCard;
    if (candidate.isCard) {
      return isProtected
          ? QueueLane.protectedDueReview
          : QueueLane.regularDueReview;
    }
    return isProtected
        ? QueueLane.protectedDueTopic
        : QueueLane.regularDueTopic;
  }

  double _overdueRatio(
    QueueCandidate candidate,
    DateTime nowUtc,
    StudyDay today,
  ) {
    final CardState? card = candidate.card;
    if (card == null) {
      return math.min(
        1,
        candidate.schedule.overdueDaysOn(today) / candidate.scheduledDays,
      );
    }
    final int lateMicros = nowUtc
        .difference(card.memory.originalDueAtUtc)
        .inMicroseconds;
    if (lateMicros <= 0) return 0;
    final double lateDays = lateMicros / Duration.microsecondsPerDay.toDouble();
    return math.min(1, lateDays / candidate.scheduledDays);
  }

  /// Admits mandatory steps, then due reviews, and only then New cards.
  _CardAdmission _admitCards(
    _CandidateLanes lanes, {
    required int cap,
    required int newCap,
  }) {
    final List<ScoredCandidate> protected = lanes.protectedReviews;
    final int regularSlots = math.max(0, cap - protected.length);
    final List<ScoredCandidate> admittedRegular = lanes.regularReviews
        .take(regularSlots)
        .toList(growable: false);
    final List<ScoredCandidate> excludedRegular = lanes.regularReviews
        .skip(regularSlots)
        .toList(growable: false);

    // New is considered only after every regular due review fits the unique
    // card cap. If even one regular review is excluded, admit zero New.
    final int remainingUnique = math.max(
      0,
      cap - protected.length - admittedRegular.length,
    );
    final int admittedNewCount = excludedRegular.isEmpty
        ? math.min(newCap, remainingUnique)
        : 0;
    final List<ScoredCandidate> admittedNew = lanes.newCards
        .take(admittedNewCount)
        .toList(growable: false);
    final List<ScoredCandidate> excludedNew = lanes.newCards
        .skip(admittedNewCount)
        .toList(growable: false);

    final List<ScoredCandidate> reviews = <ScoredCandidate>[
      ...protected,
      ...admittedRegular,
    ]..sort(_compare);
    return _CardAdmission(
      mandatory: lanes.mandatorySteps,
      reviews: reviews,
      admittedNew: admittedNew,
      overflow: <ScoredCandidate>[...excludedRegular, ...excludedNew],
    );
  }

  /// Protected topics may exceed the soft cap; regular topics use what is
  /// left. Card and topic capacities never borrow from one another.
  _TopicAdmission _admitTopics(_CandidateLanes lanes, {required int cap}) {
    final int regularSlots = math.max(0, cap - lanes.protectedTopics.length);
    final List<ScoredCandidate> admittedRegular = lanes.regularTopics
        .take(regularSlots)
        .toList(growable: false);
    final List<ScoredCandidate> admitted = <ScoredCandidate>[
      ...lanes.protectedTopics,
      ...admittedRegular,
    ]..sort(_compare);
    return _TopicAdmission(
      admitted: admitted,
      overflow: lanes.regularTopics.skip(regularSlots).toList(growable: false),
    );
  }

  /// Mixes ordinary streams by opportunity and injects mandatory due steps at
  /// the next card opportunity without advancing the ordinary cursor.
  _MergeResult _interleave({
    required List<ScoredCandidate> mandatory,
    required List<ScoredCandidate> cards,
    required List<ScoredCandidate> topics,
    required QueueMergeCursor cursor,
  }) {
    final result = <QueueCandidate>[];
    var mandatoryIndex = 0;
    var cardIndex = 0;
    var topicIndex = 0;
    var sinceTopic = cursor.ordinaryCardsSinceTopic;
    final int target = math.max(1, settings.cardsPerTopic);
    final int maximumGap = math.max(1, settings.minTopicEvery);

    while (mandatoryIndex < mandatory.length ||
        cardIndex < cards.length ||
        topicIndex < topics.length) {
      final bool topicsRemain = topicIndex < topics.length;
      final bool cardsRemain =
          mandatoryIndex < mandatory.length || cardIndex < cards.length;
      final bool ratioDue = sinceTopic >= target;
      final bool guardDue = sinceTopic >= maximumGap;

      if (topicsRemain && (!cardsRemain || ratioDue || guardDue)) {
        result.add(topics[topicIndex++].candidate);
        sinceTopic = 0;
        continue;
      }

      if (mandatoryIndex < mandatory.length) {
        result.add(mandatory[mandatoryIndex++].candidate);
        continue;
      }
      if (cardIndex < cards.length) {
        result.add(cards[cardIndex++].candidate);
        sinceTopic++;
        continue;
      }

      // Only topics remain: weighted slots are targets, never reservations.
      result.add(topics[topicIndex++].candidate);
      sinceTopic = 0;
    }
    return _MergeResult(
      entries: result,
      cursor: QueueMergeCursor(ordinaryCardsSinceTopic: sinceTopic),
    );
  }

  QueuePlan _emptyPlan(QueueMergeCursor cursor) {
    if (cursor == QueueMergeCursor.zero) return QueuePlan.empty;
    return QueuePlan(
      entries: const <QueueCandidate>[],
      overflow: const <ScoredCandidate>[],
      counters: QueuePlan.empty.counters,
      scored: const <ScoredCandidate>[],
      nextMergeCursor: cursor,
    );
  }

  /// The percentile of the best-priority element that did not fit.
  double _protectionPercent(List<ScoredCandidate> overflow) {
    if (overflow.isEmpty) return 100;
    double best = 100;
    for (final ScoredCandidate scored in overflow) {
      final PriorityPosition? position = scale.positionOf(
        scored.candidate.schedule.priority,
      );
      final double percent = position?.percent ?? 100;
      if (percent < best) best = percent;
    }
    return best;
  }
}

final class _CandidateLanes {
  final List<ScoredCandidate> mandatorySteps = <ScoredCandidate>[];
  final List<ScoredCandidate> protectedReviews = <ScoredCandidate>[];
  final List<ScoredCandidate> regularReviews = <ScoredCandidate>[];
  final List<ScoredCandidate> newCards = <ScoredCandidate>[];
  final List<ScoredCandidate> protectedTopics = <ScoredCandidate>[];
  final List<ScoredCandidate> regularTopics = <ScoredCandidate>[];

  bool get isEmpty => cardCount == 0 && topicCount == 0;

  int get cardCount =>
      mandatorySteps.length +
      protectedReviews.length +
      regularReviews.length +
      newCards.length;

  int get topicCount => protectedTopics.length + regularTopics.length;

  void add(ScoredCandidate scored) {
    switch (scored.lane) {
      case QueueLane.mandatoryIntradayStep:
        mandatorySteps.add(scored);
        return;
      case QueueLane.protectedDueReview:
        protectedReviews.add(scored);
        return;
      case QueueLane.regularDueReview:
        regularReviews.add(scored);
        return;
      case QueueLane.availableNewCard:
        newCards.add(scored);
        return;
      case QueueLane.protectedDueTopic:
        protectedTopics.add(scored);
        return;
      case QueueLane.regularDueTopic:
        regularTopics.add(scored);
        return;
    }
  }

  void sort() {
    mandatorySteps.sort(_compareMandatory);
    protectedReviews.sort(_compare);
    regularReviews.sort(_compare);
    newCards.sort(_compare);
    protectedTopics.sort(_compare);
    regularTopics.sort(_compare);
  }
}

@immutable
final class _CardAdmission {
  const _CardAdmission({
    required this.mandatory,
    required this.reviews,
    required this.admittedNew,
    required this.overflow,
  });

  final List<ScoredCandidate> mandatory;
  final List<ScoredCandidate> reviews;
  final List<ScoredCandidate> admittedNew;
  final List<ScoredCandidate> overflow;

  List<ScoredCandidate> get ordinary => <ScoredCandidate>[
    ...reviews,
    ...admittedNew,
  ];

  List<ScoredCandidate> get allAdmitted => <ScoredCandidate>[
    ...mandatory,
    ...ordinary,
  ];
}

@immutable
final class _TopicAdmission {
  const _TopicAdmission({required this.admitted, required this.overflow});

  final List<ScoredCandidate> admitted;
  final List<ScoredCandidate> overflow;
}

@immutable
final class _MergeResult {
  const _MergeResult({required this.entries, required this.cursor});

  final List<QueueCandidate> entries;
  final QueueMergeCursor cursor;
}

/// Lowest rank score first, with deterministic tie-breaks so a rebuild within
/// one day never reshuffles the user's place in the session.
int _compare(ScoredCandidate a, ScoredCandidate b) {
  final int byScore = a.score.compareTo(b.score);
  if (byScore != 0) return byScore;
  final int byPriority = a.candidate.schedule.priority.compareTo(
    b.candidate.schedule.priority,
  );
  if (byPriority != 0) return byPriority;
  final int byDue = a.candidate._originalDueOrder.compareTo(
    b.candidate._originalDueOrder,
  );
  if (byDue != 0) return byDue;
  final int byId = a.ref.id.compareTo(b.ref.id);
  if (byId != 0) return byId;
  return a.ref.type.index.compareTo(b.ref.type.index);
}

/// Exact intraday steps are chronological before presentation ranking.
int _compareMandatory(ScoredCandidate a, ScoredCandidate b) {
  final DateTime aDue =
      a.candidate.effectiveCardDueAtUtc ?? a.candidate.card!.memory.dueAtUtc;
  final DateTime bDue =
      b.candidate.effectiveCardDueAtUtc ?? b.candidate.card!.memory.dueAtUtc;
  final int byDue = aDue.compareTo(bDue);
  return byDue != 0 ? byDue : _compare(a, b);
}
