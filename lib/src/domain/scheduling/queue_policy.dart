/// Minimal deterministic heterogeneous queue used by the M3 study loop.
///
/// Production admission limits, overdue correction, randomization, and
/// auto-postpone arrive in M4. This policy intentionally does only the stable
/// core: eligibility, within-stream order, and four cards followed by a topic.
library;

import 'package:meta/meta.dart';

import 'card_scheduler.dart';
import 'element.dart';
import 'study_day.dart';
import 'topic_scheduler.dart';

/// A scheduling aggregate ready for queue admission.
@immutable
final class QueueCandidate {
  const QueueCandidate._({this.card, this.topic});

  /// Candidate from the recall stream.
  factory QueueCandidate.card(CardState state) {
    if (state.ref.type != ElementType.card) {
      throw ArgumentError('the recall stream accepts cards only');
    }
    return QueueCandidate._(card: state);
  }

  /// Candidate from the processing stream.
  factory QueueCandidate.topic(TopicState state) {
    if (!state.ref.type.isTopic) {
      throw ArgumentError('the topic stream accepts sources and extracts only');
    }
    return QueueCandidate._(topic: state);
  }

  final CardState? card;
  final TopicState? topic;

  bool get isCard => card != null;

  ElementSchedule get schedule => card?.schedule ?? topic!.schedule;

  ElementRef get ref => schedule.ref;

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

/// Four cards followed by one topic, draining whichever stream remains.
@immutable
final class MinimalQueuePolicy {
  const MinimalQueuePolicy({this.cardRunLength = 4})
    : assert(cardRunLength > 0);

  final int cardRunLength;

  /// Builds a fresh deterministic queue from [candidates].
  List<QueueCandidate> build({
    required Iterable<QueueCandidate> candidates,
    required DateTime nowUtc,
    required StudyDay today,
  }) {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'must be UTC');
    }
    final List<QueueCandidate> cards = <QueueCandidate>[];
    final List<QueueCandidate> topics = <QueueCandidate>[];
    for (final QueueCandidate candidate in candidates) {
      if (!candidate.isEligible(nowUtc: nowUtc, today: today)) continue;
      (candidate.isCard ? cards : topics).add(candidate);
    }
    cards.sort(_compareWithinStream);
    topics.sort(_compareWithinStream);

    final List<QueueCandidate> result = <QueueCandidate>[];
    var cardIndex = 0;
    var topicIndex = 0;
    while (cardIndex < cards.length || topicIndex < topics.length) {
      final int cardEnd = (cardIndex + cardRunLength).clamp(
        cardIndex,
        cards.length,
      );
      while (cardIndex < cardEnd) {
        result.add(cards[cardIndex++]);
      }
      if (topicIndex < topics.length) {
        result.add(topics[topicIndex++]);
      } else if (cardIndex < cards.length) {
        // No topic slot to reserve: the next iteration drains another run.
        continue;
      }
    }
    return List<QueueCandidate>.unmodifiable(result);
  }
}

int _compareWithinStream(QueueCandidate a, QueueCandidate b) {
  final int byPriority = a.schedule.priority.compareTo(b.schedule.priority);
  if (byPriority != 0) return byPriority;
  final int byOriginalDue = a._originalDueOrder.compareTo(b._originalDueOrder);
  if (byOriginalDue != 0) return byOriginalDue;
  final int byId = a.ref.id.compareTo(b.ref.id);
  if (byId != 0) return byId;
  return a.ref.type.index.compareTo(b.ref.type.index);
}
