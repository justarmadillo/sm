/// The one place presentation asks "when does this actually come back?".
///
/// The canonical due is what the scheduler decided; the effective due is what
/// the calendar currently allows, after Later, automatic overflow, sibling
/// burying, Mercy, and manual reschedules. Screens must show the second and
/// must never derive it themselves, because an element that silently displays
/// its canonical date looks like the postponement the user just made never
/// happened.
library;

import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/schedule_adjustment.dart';
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

  static const EffectiveDueService _service = EffectiveDueService();

  final LearningRepository _learning;
  final SchedulingContext _context;

  /// The day [topic] may next be presented on.
  Future<StudyDay> forTopic(TopicState topic) async {
    final ScheduleAdjustmentSet adjustments = ScheduleAdjustmentSet(
      await _learning.listActiveAdjustments(
        elements: <ElementRef>{topic.ref},
      ),
    );
    return _service.topicDueStudyDay(
      topic: topic.ref,
      algorithmicDueStudyDay: topic.schedule.algorithmicDueDay,
      adjustments: adjustments,
    );
  }

  /// The same, for many topics in one query rather than one per row.
  Future<Map<ElementRef, StudyDay>> forTopics(
    Iterable<TopicState> topics,
  ) async {
    final List<TopicState> all = topics.toList(growable: false);
    if (all.isEmpty) return const <ElementRef, StudyDay>{};
    final ScheduleAdjustmentSet adjustments = ScheduleAdjustmentSet(
      await _learning.listActiveAdjustments(
        elements: <ElementRef>{for (final TopicState topic in all) topic.ref},
      ),
    );
    return <ElementRef, StudyDay>{
      for (final TopicState topic in all)
        topic.ref: _service.topicDueStudyDay(
          topic: topic.ref,
          algorithmicDueStudyDay: topic.schedule.algorithmicDueDay,
          adjustments: adjustments,
        ),
    };
  }

  /// The day an element of either kind may next be presented on.
  Future<StudyDay?> forElement(ElementRef ref) async {
    final ScheduleAdjustmentSet adjustments = ScheduleAdjustmentSet(
      await _learning.listActiveAdjustments(elements: <ElementRef>{ref}),
    );
    if (ref.type == ElementType.card) {
      final CardState? card = await _learning.findCardState(ref.id);
      if (card == null) return null;
      final StudyDayCalendar calendar = await _context.calendar();
      return calendar.dayOf(
        _service.cardDueAtUtc(
          card: ref,
          algorithmicDueAtUtc: card.memory.dueAtUtc,
          adjustments: adjustments,
        ),
      );
    }
    final TopicState? topic = await _learning.findTopic(ref);
    if (topic == null) return null;
    return _service.topicDueStudyDay(
      topic: ref,
      algorithmicDueStudyDay: topic.schedule.algorithmicDueDay,
      adjustments: adjustments,
    );
  }

  /// Effective due for many schedules of mixed kinds, for list screens.
  Future<Map<ElementRef, StudyDay>> forSchedules(
    Iterable<ElementSchedule> schedules,
  ) async {
    final List<ElementSchedule> all = schedules.toList(growable: false);
    if (all.isEmpty) return const <ElementRef, StudyDay>{};
    final Set<ElementRef> refs = <ElementRef>{
      for (final ElementSchedule schedule in all) schedule.ref,
    };
    final ScheduleAdjustmentSet adjustments = ScheduleAdjustmentSet(
      await _learning.listActiveAdjustments(elements: refs),
    );
    final StudyDayCalendar calendar = await _context.calendar();
    final Map<ElementRef, StudyDay> result = <ElementRef, StudyDay>{};
    for (final ElementSchedule schedule in all) {
      if (schedule.ref.type == ElementType.card) {
        final CardState? card = await _learning.findCardState(schedule.ref.id);
        if (card == null) continue;
        result[schedule.ref] = calendar.dayOf(
          _service.cardDueAtUtc(
            card: schedule.ref,
            algorithmicDueAtUtc: card.memory.dueAtUtc,
            adjustments: adjustments,
          ),
        );
      } else {
        result[schedule.ref] = _service.topicDueStudyDay(
          topic: schedule.ref,
          algorithmicDueStudyDay: schedule.algorithmicDueDay,
          adjustments: adjustments,
        );
      }
    }
    return result;
  }
}
