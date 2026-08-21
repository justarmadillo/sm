/// The daily queue: eligibility, ordering, admission, and overflow.
///
/// The queue is the heart of the application — a session is "work through
/// today's queue", not "open a deck". Everything the design documents argue
/// about converges here, so the rules are worth stating plainly:
///
/// * **Priority sorts the queue; it does not shrink it.** Ordering and
///   admission are separate decisions, and neither may pull not-yet-due
///   material forward or change an interval.
/// * **Strict priority order is wrong.** New material always feels important,
///   so a precise priority sort lets today's imports displace last year's
///   investment — the priority bias. A capped overdue term and a configurable
///   jitter push back against it.
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

/// A scheduling aggregate ready for queue admission.
@immutable
final class QueueCandidate {
  const QueueCandidate._({this.card, this.topic, this.rootId});

  /// Candidate from the recall stream.
  ///
  /// [rootId] names the source the card ultimately came from, so one article's
  /// subtree cannot take over a session.
  factory QueueCandidate.card(CardState state, {String? rootId}) {
    if (state.ref.type != ElementType.card) {
      throw ArgumentError('the recall stream accepts cards only');
    }
    return QueueCandidate._(card: state, rootId: rootId);
  }

  /// Candidate from the processing stream.
  factory QueueCandidate.topic(TopicState state, {String? rootId}) {
    if (!state.ref.type.isTopic) {
      throw ArgumentError('the topic stream accepts sources and extracts only');
    }
    return QueueCandidate._(topic: state, rootId: rootId);
  }

  final CardState? card;
  final TopicState? topic;

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
    final CardState? cardState = card;
    if (cardState != null) {
      return schedule.lifecycle.isSchedulable &&
          schedule.effectiveDueDay <= today &&
          cardState.memory.isDueAt(nowUtc);
    }
    return schedule.isEligibleOn(today);
  }

  int get _originalDueOrder => card == null
      ? schedule.originalDueDay.epochDay * Duration.millisecondsPerDay
      : card!.memory.originalDueAtUtc.millisecondsSinceEpoch;
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
  });

  final QueueCandidate candidate;

  /// Blended sort score. Higher goes first.
  final double score;

  /// `1` at the top of the collection, `0` at the bottom.
  final double normalizedPriority;

  /// Days late divided by the scheduled interval, capped at one.
  final double overdueRatio;

  /// The day's deterministic shuffle term.
  final double jitter;

  /// Whether the element sits inside the protected top percentile.
  final bool isProtected;

  ElementRef get ref => candidate.ref;
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

  /// Elements the protected floor kept in the queue past the cap.
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
  );

  /// Admitted elements in presentation order.
  final List<QueueCandidate> entries;

  /// Elements the caller should defer, worst priority last.
  final List<ScoredCandidate> overflow;

  final QueueCounters counters;

  /// Every admitted element with the terms that placed it.
  final List<ScoredCandidate> scored;

  bool get isEmpty => entries.isEmpty;
}

/// Builds the day's queue.
@immutable
final class QueuePolicy {
  const QueuePolicy({
    this.settings = const QueueSettings(),
    this.scale = PriorityScale.empty,
  });

  /// Caps, mixing, and sorting weights.
  final QueueSettings settings;

  /// The collection's current priority order, for percentiles and the
  /// protected floor.
  final PriorityScale scale;

  /// Builds a plan for [today].
  ///
  /// [extraAdmissions] raises every cap by that many elements for this build
  /// only — that is what Study More does, without persisting a bigger limit
  /// the user did not ask for.
  QueuePlan build({
    required Iterable<QueueCandidate> candidates,
    required DateTime nowUtc,
    required StudyDay today,
    int extraAdmissions = 0,
  }) {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'must be UTC');
    }
    final DeterministicRandom random = DeterministicRandom(
      'queue:${today.zoneId}:$today',
    );

    final List<ScoredCandidate> cards = <ScoredCandidate>[];
    final List<ScoredCandidate> topics = <ScoredCandidate>[];
    for (final QueueCandidate candidate in candidates) {
      if (!candidate.isEligible(nowUtc: nowUtc, today: today)) continue;
      final ScoredCandidate scored = _score(candidate, today, random);
      (candidate.isCard ? cards : topics).add(scored);
    }
    if (cards.isEmpty && topics.isEmpty) return QueuePlan.empty;

    cards.sort(_compare);
    topics.sort(_compare);

    final _Admission cardAdmission = _admit(
      cards,
      cap: settings.maxCards + extraAdmissions,
      newCap: settings.maxNewCards + extraAdmissions,
    );
    final _Admission topicAdmission = _admit(
      topics,
      cap: settings.maxTopics + extraAdmissions,
      newCap: null,
    );

    final List<QueueCandidate> ordered = _interleave(
      cards: cardAdmission.admitted,
      topics: topicAdmission.admitted,
    );
    final List<ScoredCandidate> overflow = <ScoredCandidate>[
      ...cardAdmission.overflow,
      ...topicAdmission.overflow,
    ]..sort(_compare);

    final List<ScoredCandidate> admittedScored = <ScoredCandidate>[
      ...cardAdmission.admitted,
      ...topicAdmission.admitted,
    ];
    return QueuePlan(
      entries: List<QueueCandidate>.unmodifiable(ordered),
      overflow: List<ScoredCandidate>.unmodifiable(overflow),
      scored: List<ScoredCandidate>.unmodifiable(admittedScored),
      counters: QueueCounters(
        dueCards: cards.length,
        dueTopics: topics.length,
        admittedCards: cardAdmission.admitted.length,
        admittedTopics: topicAdmission.admitted.length,
        admittedNewCards: cardAdmission.admitted
            .where((ScoredCandidate s) => s.candidate.isNewCard)
            .length,
        overflowCards: cardAdmission.overflow.length,
        overflowTopics: topicAdmission.overflow.length,
        protectedElements: admittedScored
            .where((ScoredCandidate s) => s.isProtected)
            .length,
        protectionPercent: _protectionPercent(overflow),
      ),
    );
  }

  ScoredCandidate _score(
    QueueCandidate candidate,
    StudyDay today,
    DeterministicRandom random,
  ) {
    final PriorityPosition? position = scale.positionOf(
      candidate.schedule.priority,
    );
    final double normalized = position?.normalized ?? 0.5;
    final double overdue = math.min(
      1,
      candidate.schedule.overdueDaysOn(today) / candidate.scheduledDays,
    );
    final double jitter = settings.randomization == 0
        ? 0
        : random.symmetric(candidate.ref.toString(), settings.randomization);
    return ScoredCandidate(
      candidate: candidate,
      score:
          settings.priorityWeight * normalized +
          settings.overdueWeight * overdue +
          jitter,
      normalizedPriority: normalized,
      overdueRatio: overdue,
      jitter: jitter,
      isProtected: scale.isProtected(
        candidate.schedule.priority,
        settings.protectedPercentile,
      ),
    );
  }

  /// Applies the caps to one already-sorted stream.
  _Admission _admit(
    List<ScoredCandidate> stream, {
    required int cap,
    required int? newCap,
  }) {
    if (stream.isEmpty) return const _Admission.empty();
    final bool withinTolerance =
        !settings.autoPostpone ||
        stream.length <= (cap * settings.overloadTolerance).floor();

    final admitted = <ScoredCandidate>[];
    final overflow = <ScoredCandidate>[];
    final rootCounts = <String, int>{};
    final int rootCap = math.max(
      1,
      (stream.length * settings.maxSharePerRoot).ceil(),
    );
    // Displacing an element to protect the share only makes sense when
    // something from another article could take the slot. On a day that is
    // entirely one article, enforcing it would shrink the session rather than
    // diversify it.
    final bool enforceRootShare =
        settings.maxSharePerRoot < 1 &&
        stream
                .map((ScoredCandidate s) => s.candidate.rootId)
                .whereType<String>()
                .toSet()
                .length >
            1;
    // However many elements claim protection, only this many can have it.
    // Order keys can tie — a collection imported before priorities were ever
    // set has many — and a tie must not exempt the whole stream and silently
    // disable the valve.
    final int protectedCap = settings.protectedPercentile <= 0
        ? 0
        : (stream.length * settings.protectedPercentile).ceil();
    var protectedAdmitted = 0;
    var newAdmitted = 0;

    for (final ScoredCandidate scored in stream) {
      final QueueCandidate candidate = scored.candidate;
      final bool protectedHere =
          scored.isProtected && protectedAdmitted < protectedCap;

      // A started learning step and a protected element are not negotiable:
      // the first was already admitted today, and the second is what stops
      // the valve from eventually deferring the entire collection.
      if (candidate.isIntradayStep || protectedHere) {
        admitted.add(scored);
        if (protectedHere) protectedAdmitted++;
        if (candidate.isNewCard) newAdmitted++;
        final String? root = candidate.rootId;
        if (root != null) rootCounts[root] = (rootCounts[root] ?? 0) + 1;
        continue;
      }

      if (!withinTolerance && admitted.length >= cap) {
        overflow.add(scored);
        continue;
      }
      if (newCap != null && candidate.isNewCard && newAdmitted >= newCap) {
        overflow.add(scored);
        continue;
      }
      final String? root = candidate.rootId;
      if (root != null &&
          enforceRootShare &&
          (rootCounts[root] ?? 0) >= rootCap) {
        // One article that produced two hundred descendants must not take
        // over a session; exact priority inheritance makes that easy to do
        // by accident, so the share is capped at admission rather than by
        // quietly demoting the children.
        overflow.add(scored);
        continue;
      }

      admitted.add(scored);
      if (candidate.isNewCard) newAdmitted++;
      if (root != null) rootCounts[root] = (rootCounts[root] ?? 0) + 1;
    }
    return _Admission(admitted: admitted, overflow: overflow);
  }

  /// Mixes the two streams, honouring both the ratio and the hard floor.
  List<QueueCandidate> _interleave({
    required List<ScoredCandidate> cards,
    required List<ScoredCandidate> topics,
  }) {
    final result = <QueueCandidate>[];
    var cardIndex = 0;
    var topicIndex = 0;
    var sinceTopic = 0;

    while (cardIndex < cards.length || topicIndex < topics.length) {
      final bool topicsRemain = topicIndex < topics.length;
      final bool cardsRemain = cardIndex < cards.length;
      final bool ratioDue = sinceTopic >= settings.cardsPerTopic;
      final bool floorDue = sinceTopic >= settings.minTopicEvery;

      if (topicsRemain && (!cardsRemain || ratioDue || floorDue)) {
        result.add(topics[topicIndex++].candidate);
        sinceTopic = 0;
        continue;
      }
      if (cardsRemain) {
        result.add(cards[cardIndex++].candidate);
        sinceTopic++;
        continue;
      }
      // Neither stream can supply anything: only reachable when both are
      // exhausted, which the loop condition already excludes.
      break;
    }
    return result;
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

/// One stream's admitted and overflowed halves.
@immutable
final class _Admission {
  const _Admission({required this.admitted, required this.overflow});

  const _Admission.empty()
    : admitted = const <ScoredCandidate>[],
      overflow = const <ScoredCandidate>[];

  final List<ScoredCandidate> admitted;
  final List<ScoredCandidate> overflow;
}

/// Highest score first, with deterministic tie-breaks so a rebuild within one
/// day never reshuffles the user's place in the session.
int _compare(ScoredCandidate a, ScoredCandidate b) {
  final int byScore = b.score.compareTo(a.score);
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
