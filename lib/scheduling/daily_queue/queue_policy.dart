/// Executable-derived SM20 Outstanding queue ordering and stage selection.
library;

import 'dart:math' as math;

import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/settings/queue_settings.dart';
import 'package:meta/meta.dart';

enum QueueLane { outstandingItem, outstandingTopic, finalDrill, pending }

@immutable
final class QueueCandidate {
  const QueueCandidate._({
    this.card,
    this.topic,
    this.rootId,
    this.effectiveCardDueAtUtc,
    this.effectiveTopicDueDay,
  });

  factory QueueCandidate.card(
    CardState state, {
    String? rootId,
    DateTime? effectiveDueAtUtc,
  }) => QueueCandidate._(
    card: state,
    rootId: rootId,
    effectiveCardDueAtUtc: effectiveDueAtUtc,
  );

  factory QueueCandidate.topic(
    TopicState state, {
    String? rootId,
    StudyDay? effectiveDueDay,
  }) => QueueCandidate._(
    topic: state,
    rootId: rootId,
    effectiveTopicDueDay: effectiveDueDay,
  );

  final CardState? card;
  final TopicState? topic;
  final DateTime? effectiveCardDueAtUtc;
  final StudyDay? effectiveTopicDueDay;
  final String? rootId;

  bool get isCard => card != null;
  ElementSchedule get schedule => card?.schedule ?? topic!.schedule;
  ElementRef get ref => schedule.ref;

  /// Pending is a separate fallback stage, never injected into Outstanding.
  bool get isPending => isCard
      ? card!.memory.repetitionCount == 0
      : topic!.status == Sm20ElementStatus.pending;

  bool isDue({required DateTime nowUtc, required StudyDay today}) {
    if (!schedule.lifecycle.isSchedulable) return false;
    if (isCard) {
      return !(effectiveCardDueAtUtc ?? card!.memory.dueAtUtc).isAfter(nowUtc);
    }
    return (effectiveTopicDueDay ?? topic!.schedule.algorithmicDueDay) <= today;
  }

  double get scheduledDays => isCard
      ? (card!.memory.scheduledDays ?? 1).clamp(1, double.infinity)
      : math.max(topic!.storedInterval, 1).toDouble();
}

/// One queue entry with the exact priority key used by the heap sorter.
@immutable
final class ScoredCandidate {
  const ScoredCandidate({
    required this.candidate,
    required this.priorityPercent,
    required this.sortKey,
    required this.lane,
  });

  final QueueCandidate candidate;
  final double priorityPercent;
  final int sortKey;
  final QueueLane lane;
  ElementRef get ref => candidate.ref;
}

@immutable
final class QueueCounters {
  const QueueCounters({
    required this.dueCards,
    required this.dueTopics,
    required this.admittedCards,
    required this.admittedTopics,
    required this.admittedNewCards,
  });

  final int dueCards;
  final int dueTopics;
  final int admittedCards;
  final int admittedTopics;
  final int admittedNewCards;
  int get dueTotal => dueCards + dueTopics;
  int get admittedTotal => admittedCards + admittedTopics;

  Map<String, Object?> toMetadata() => <String, Object?>{
    'due_cards': dueCards,
    'due_topics': dueTopics,
    'admitted_cards': admittedCards,
    'admitted_topics': admittedTopics,
    'admitted_new_cards': admittedNewCards,
  };
}

@immutable
final class QueuePlan {
  const QueuePlan({
    required this.entries,
    required this.prioritySortedItems,
    required this.prioritySortedTopics,
    required this.counters,
    required this.scored,
    required this.randomNumberState,
  });

  factory QueuePlan.empty(Sm20RandomNumberGeneratorState state) => QueuePlan(
    entries: const <QueueCandidate>[],
    prioritySortedItems: const <QueueCandidate>[],
    prioritySortedTopics: const <QueueCandidate>[],
    counters: const QueueCounters(
      dueCards: 0,
      dueTopics: 0,
      admittedCards: 0,
      admittedTopics: 0,
      admittedNewCards: 0,
    ),
    scored: const <ScoredCandidate>[],
    randomNumberState: state,
  );

  /// A separate fallback learning stage.  Final Drill and Pending are never
  /// injected into the Outstanding item/topic merge.
  factory QueuePlan.stage({
    required Iterable<QueueCandidate> candidates,
    required QueueLane lane,
    required Sm20RandomNumberGeneratorState randomNumberState,
  }) {
    final List<QueueCandidate> entries = List<QueueCandidate>.unmodifiable(
      candidates,
    );
    final List<ScoredCandidate> scored = List<ScoredCandidate>.unmodifiable(
      entries.map(
        (QueueCandidate candidate) => ScoredCandidate(
          candidate: candidate,
          priorityPercent: 100,
          sortKey: 0,
          lane: lane,
        ),
      ),
    );
    final int cards = entries
        .where((QueueCandidate value) => value.isCard)
        .length;
    final int topics = entries.length - cards;
    return QueuePlan(
      entries: entries,
      prioritySortedItems: const <QueueCandidate>[],
      prioritySortedTopics: const <QueueCandidate>[],
      counters: QueuePolicy._counters(cards, topics),
      scored: scored,
      randomNumberState: randomNumberState,
    );
  }

  final List<QueueCandidate> entries;
  final List<QueueCandidate> prioritySortedItems;
  final List<QueueCandidate> prioritySortedTopics;
  final QueueCounters counters;
  final List<ScoredCandidate> scored;
  final Sm20RandomNumberGeneratorState randomNumberState;
  bool get isEmpty => entries.isEmpty;
}

final class QueuePolicy {
  const QueuePolicy({
    this.settings = const QueueSettings(),
    this.scale = PriorityScale.empty,
  });

  final QueueSettings settings;
  final PriorityScale scale;

  /// Builds and sorts the combined Outstanding queue. All eligible memorized
  /// repetitions are admitted; Pending and Final Drill remain separate stages.
  QueuePlan build({
    required Iterable<QueueCandidate> candidates,
    required DateTime nowUtc,
    required StudyDay today,
    required Sm20RandomNumberGenerator randomNumbers,
    Iterable<ElementRef>? combinedOrder,
    Set<ElementRef>? outstandingItemMembership,
    bool shouldSort = true,
  }) {
    final Map<ElementRef, QueueCandidate> byRef = <ElementRef, QueueCandidate>{
      for (final QueueCandidate candidate in candidates)
        candidate.ref: candidate,
    };
    final List<QueueCandidate> outstanding = <QueueCandidate>[];
    if (combinedOrder == null) {
      for (final QueueCandidate candidate in candidates) {
        if (!candidate.isPending &&
            candidate.isDue(nowUtc: nowUtc, today: today)) {
          outstanding.add(candidate);
        }
      }
    } else {
      for (final ElementRef ref in combinedOrder) {
        final QueueCandidate? candidate = byRef[ref];
        if (candidate != null && !candidate.isPending) {
          outstanding.add(candidate);
        }
      }
      // Newly due repetitions not already stored are appended before sorting.
      final Set<ElementRef> present = outstanding
          .map((QueueCandidate c) => c.ref)
          .toSet();
      for (final QueueCandidate candidate in candidates) {
        if (!present.contains(candidate.ref) &&
            !candidate.isPending &&
            candidate.isDue(nowUtc: nowUtc, today: today)) {
          outstanding.add(candidate);
        }
      }
    }
    if (outstanding.isEmpty) return QueuePlan.empty(randomNumbers.state);

    final Set<ElementRef>? membership = outstandingItemMembership;
    final List<ScoredCandidate> items = <ScoredCandidate>[];
    final List<ScoredCandidate> topics = <ScoredCandidate>[];
    for (final QueueCandidate candidate in outstanding) {
      final double priority = scale.percentageOf(candidate.schedule.priority);
      final ScoredCandidate scored = ScoredCandidate(
        candidate: candidate,
        priorityPercent: priority,
        sortKey: sm20RoundEven((100 - priority) * 10000),
        lane: membership == null
            ? (candidate.isCard
                  ? QueueLane.outstandingItem
                  : QueueLane.outstandingTopic)
            : (membership.contains(candidate.ref)
                  ? QueueLane.outstandingItem
                  : QueueLane.outstandingTopic),
      );
      final bool isItem = membership == null
          ? candidate.isCard
          : membership.contains(candidate.ref);
      (isItem ? items : topics).add(scored);
    }

    if (outstanding.length < 2 || !shouldSort) {
      return QueuePlan(
        entries: List<QueueCandidate>.unmodifiable(outstanding),
        prioritySortedItems: List<QueueCandidate>.unmodifiable(
          items.map((ScoredCandidate value) => value.candidate),
        ),
        prioritySortedTopics: List<QueueCandidate>.unmodifiable(
          topics.map((ScoredCandidate value) => value.candidate),
        ),
        counters: _counters(items.length, topics.length),
        scored: List<ScoredCandidate>.unmodifiable(<ScoredCandidate>[
          ...items,
          ...topics,
        ]),
        randomNumberState: randomNumbers.state,
      );
    }

    sm20HeapSortDescendingInPlace<ScoredCandidate>(
      items,
      keyOf: (ScoredCandidate value) => value.sortKey,
    );
    sm20HeapSortDescendingInPlace<ScoredCandidate>(
      topics,
      keyOf: (ScoredCandidate value) => value.sortKey,
    );
    final List<ScoredCandidate> randomizedItems = _randomizedExtraction(
      items,
      settings.itemRandomization,
      randomNumbers,
    );
    final List<ScoredCandidate> randomizedTopics = _randomizedExtraction(
      topics,
      settings.topicRandomization,
      randomNumbers,
    );
    final List<ScoredCandidate> merged = _merge(
      randomizedItems,
      randomizedTopics,
      settings.topicPercent,
    );
    return QueuePlan(
      entries: List<QueueCandidate>.unmodifiable(
        merged.map((ScoredCandidate value) => value.candidate),
      ),
      prioritySortedItems: List<QueueCandidate>.unmodifiable(
        items.map((ScoredCandidate value) => value.candidate),
      ),
      prioritySortedTopics: List<QueueCandidate>.unmodifiable(
        topics.map((ScoredCandidate value) => value.candidate),
      ),
      counters: _counters(items.length, topics.length),
      scored: List<ScoredCandidate>.unmodifiable(merged),
      randomNumberState: randomNumbers.state,
    );
  }

  static double randomizationCurve(int slider) {
    final int value = slider.clamp(0, 100);
    if (value == 0) return 0.001;
    if (value == 100) return 1000;
    final double x = math.sqrt(value / 100);
    return x > 0.5 ? (x - 0.5) * 38 + 1 : x + 0.5;
  }

  static List<ScoredCandidate> _randomizedExtraction(
    List<ScoredCandidate> sorted,
    int slider,
    Sm20RandomNumberGenerator randomNumbers,
  ) {
    final List<ScoredCandidate> remaining = <ScoredCandidate>[...sorted];
    final List<ScoredCandidate> output = <ScoredCandidate>[];
    final int count = remaining.length;
    final double curve = randomizationCurve(slider);
    for (var i = 1; i <= count; i++) {
      final double x = (i - 1) / count;
      final double gate = math.pow(x, 1 / curve).toDouble();
      final double update = randomNumbers.nextDouble();
      var index = 0;
      if (gate > update) {
        final double depth = math
            .pow(randomNumbers.nextDouble(), 1 / curve)
            .toDouble();
        index = (randomNumbers.nextDouble() * depth * remaining.length)
            .truncate();
      }
      output.add(remaining.removeAt(index.clamp(0, remaining.length - 1)));
    }
    return output;
  }

  static List<ScoredCandidate> _merge(
    List<ScoredCandidate> items,
    List<ScoredCandidate> topics,
    int topicPercent,
  ) {
    final List<ScoredCandidate> output = <ScoredCandidate>[];
    final double topicFraction = topicPercent.clamp(0, 100) / 100;
    var itemIndex = 0;
    var topicIndex = 0;
    var itemsPlaced = 0;
    var topicsPlaced = 0;
    final int total = items.length + topics.length;
    for (var slot = 0; slot < total; slot++) {
      bool shouldChooseItem =
          (1 - topicFraction) > itemsPlaced / (itemsPlaced + topicsPlaced + 1);
      if (shouldChooseItem) {
        itemsPlaced++;
        if (itemIndex >= items.length) {
          shouldChooseItem = false;
          topicsPlaced++;
        }
      } else {
        topicsPlaced++;
        if (topicIndex >= topics.length) {
          shouldChooseItem = true;
          itemsPlaced++;
        }
      }
      output.add(shouldChooseItem ? items[itemIndex++] : topics[topicIndex++]);
    }
    return output;
  }

  static QueueCounters _counters(int items, int topics) => QueueCounters(
    dueCards: items,
    dueTopics: topics,
    admittedCards: items,
    admittedTopics: topics,
    admittedNewCards: 0,
  );

  /// Fixed-full-range swap used by Final Drill and Mercy mode 3.
  static void randomizeFixedSize<T>(
    List<T> queue,
    Sm20RandomNumberGenerator randomNumbers,
  ) {
    final int count = queue.length;
    for (var position = 0; position < count; position++) {
      final int swapWith = randomNumbers.nextInt(count);
      final T value = queue[position];
      queue[position] = queue[swapWith];
      queue[swapWith] = value;
    }
  }
}
