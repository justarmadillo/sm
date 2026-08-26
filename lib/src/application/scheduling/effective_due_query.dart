/// Canonical due-date projection for the sole SM20 scheduler.
///
/// SM20 has no per-element adjustment overlay: Later, Smart Postpone, Mercy,
/// and manual rescheduling all replace the stored due state directly.
library;

import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../ports/repositories.dart';
import 'scheduling_context.dart';

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

  Future<Map<ElementRef, StudyDay>> forSchedules(
    Iterable<ElementSchedule> schedules,
  ) async {
    final List<ElementSchedule> all = schedules.toList(growable: false);
    final StudyDayCalendar calendar = await _context.calendar();
    final Map<ElementRef, StudyDay> result = <ElementRef, StudyDay>{};
    for (final ElementSchedule schedule in all) {
      if (schedule.ref.type == ElementType.card) {
        final CardState? card = await _learning.findCardState(schedule.ref.id);
        if (card != null) {
          result[schedule.ref] = calendar.dayOf(card.memory.dueAtUtc);
        }
      } else {
        result[schedule.ref] = schedule.algorithmicDueDay;
      }
    }
    return result;
  }
}
