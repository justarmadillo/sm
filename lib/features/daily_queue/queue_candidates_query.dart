/// Reads the population the day's queue is built from.
///
/// Its own file because three callers need it and only one of them writes: the
/// queue's command runner, the queue's projection, and the diagnostics metrics
/// panel. Reaching into the command runner for this read is what made a
/// read-only screen depend on the object that admits a day.
library;

import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/daily_queue/queue_policy.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';

/// Every element eligible to appear in a queue, before any due filtering.
final class QueueCandidatesQuery {
  const QueueCandidatesQuery({required LearningRepository learning})
    : _learning = learning;

  final LearningRepository _learning;

  /// All active topic records and card memories.
  ///
  /// Due filtering belongs to the queue transaction because existing queue
  /// membership can intentionally contain a future repetition added by a
  /// browser command.
  Future<List<QueueCandidate>> listCandidates() async {
    final List<ElementSchedule> topicSchedules = await _learning.listSchedules(
      types: const <ElementType>{
        ElementType.source,
        ElementType.extract,
        ElementType.video,
      },
      lifecycles: const <ElementLifecycle>{ElementLifecycle.active},
    );
    final Map<ElementRef, TopicState> topics = await _learning.findTopics(
      <ElementRef>[
        for (final ElementSchedule schedule in topicSchedules) schedule.ref,
      ],
    );
    final List<CardState> cards = await _learning.listCardStates(
      lifecycles: const <ElementLifecycle>{ElementLifecycle.active},
    );
    return <QueueCandidate>[
      for (final ElementSchedule schedule in topicSchedules)
        if (topics[schedule.ref] case final TopicState topic)
          if (topic.status != Sm20ElementStatus.dismissed &&
              topic.status != Sm20ElementStatus.deleted)
            QueueCandidate.topic(topic, rootId: schedule.rootId),
      for (final CardState card in cards)
        QueueCandidate.card(card, rootId: card.schedule.rootId),
    ];
  }
}
