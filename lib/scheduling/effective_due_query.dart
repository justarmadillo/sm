/// Canonical due-date projection for the sole SM20 scheduler.
///
/// SM20 has no per-element adjustment overlay: Later, Smart Postpone, Mercy,
/// and manual rescheduling all replace the stored due state directly.
library;

import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';

final class EffectiveDueQuery {
  const EffectiveDueQuery({
    required LearningRepository learning,
    required SchedulingContext context,
  }) : _learning = learning,
       _context = context;

  final LearningRepository _learning;
  final SchedulingContext _context;

  Future<StudyDay> forTopic(TopicState topic) async =>
      topic.schedule.algorithmicDueDay;

  Future<Map<ElementRef, StudyDay>> forTopics(
    Iterable<TopicState> topics,
  ) async => <ElementRef, StudyDay>{
    for (final TopicState topic in topics)
      topic.ref: topic.schedule.algorithmicDueDay,
  };

  Future<StudyDay?> forElement(ElementRef ref) async {
    if (ref.type == ElementType.card) {
      final CardState? card = await _learning.findCardState(ref.id);
      if (card == null) return null;
      return (await _context.calendar()).dayOf(card.memory.dueAtUtc);
    }
    return (await _learning.findTopic(ref))?.schedule.algorithmicDueDay;
  }
}
