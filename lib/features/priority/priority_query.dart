/// Read model for the priority slider and the priority browser.
///
/// Everything here is derived at query time. Position and percentile are never
/// stored, because a stored score inflates: every new import feels like an 80,
/// and twelve months in the field no longer discriminates between anything.
/// Deriving them keeps scarcity structural — there is exactly one 0%.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/storage/contracts/content_repository.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:meta/meta.dart';

/// One row of the priority browser.
@immutable
final class PriorityEntry {
  const PriorityEntry({
    required this.schedule,
    required this.position,
    required this.title,
    required this.preview,
    this.intervalDays = 0,
    this.repetitions = 0,
    this.lapses = 0,
    this.lastRepetition,
  });

  final ElementSchedule schedule;

  /// Where it sits now. Recomputed on every load.
  final PriorityPosition position;

  final String title;

  /// Short excerpt, so the user can recognize the element without opening it.
  final String preview;

  /// Stored interval in days. Cards report their rounded scheduled days.
  final int intervalDays;

  final int repetitions;
  final int lapses;

  /// Day of the last repetition, or null when there has never been one.
  final StudyDay? lastRepetition;

  ElementRef get ref => schedule.ref;

  /// SuperMemo-style percent: `0` is the most important.
  double get percent => position.percent;

  /// Canonical next repetition.
  StudyDay get nextRepetition => schedule.algorithmicDueDay;
}

/// What the Alt+P dialog shows about one element.
///
/// The neighbours are the useful part: an abstract 42% means little, while
/// "more important than this, less important than that" is a judgement the
/// user can actually make.
@immutable
final class PriorityContext {
  const PriorityContext({
    required this.ref,
    required this.rank,
    required this.position,
    this.above,
    this.below,
  });

  final ElementRef ref;
  final PriorityRank rank;
  final PriorityPosition position;

  /// The element immediately more important, if any.
  final PriorityEntry? above;

  /// The element immediately less important, if any.
  final PriorityEntry? below;

  double get percent => position.percent;
}

/// Loads priority projections.
final class PriorityQuery {
  const PriorityQuery({
    required ContentRepository content,
    required LearningRepository learning,
    required SchedulingContext context,
  }) : _content = content,
       _learning = learning,
       _context = context;

  final ContentRepository _content;
  final LearningRepository _learning;
  final SchedulingContext _context;

  /// The browser's rows, most important first.
  Future<List<PriorityEntry>> browse({
    Set<ElementType>? types,
    Set<ElementLifecycle>? lifecycles,
    int? limit,
    int? offset,
  }) async {
    final List<ElementSchedule> schedules = await _learning.listSchedules(
      types: types ?? ElementType.values.toSet(),
      lifecycles: lifecycles ?? <ElementLifecycle>{ElementLifecycle.active},
      limit: limit,
      offset: offset,
    );
    if (schedules.isEmpty) return const <PriorityEntry>[];

    final PriorityScale scale = await _context.priorityScale();
    final entries = <PriorityEntry>[];
    for (var index = 0; index < schedules.length; index++) {
      final ElementSchedule schedule = schedules[index];
      final (String title, String preview) = await _describe(schedule.ref);
      final _Repetitions counters = await _countersFor(schedule.ref);
      entries.add(
        PriorityEntry(
          schedule: schedule,
          position:
              scale.positionOf(schedule.priority) ??
              PriorityPosition(
                index: (offset ?? 0) + index,
                total: schedules.length,
              ),
          title: title,
          preview: preview,
          intervalDays: counters.intervalDays,
          repetitions: counters.repetitions,
          lapses: counters.lapses,
          lastRepetition: counters.lastRepetition,
        ),
      );
    }
    return List<PriorityEntry>.unmodifiable(entries);
  }

  /// Repetition counters, read from whichever engine owns this element.
  ///
  /// Topics keep their own SM20 counters; cards keep FSRS ones. The browser
  /// shows a single table, so the two are read into one shape here rather than
  /// leaving the view to branch on element type.
  Future<_Repetitions> _countersFor(ElementRef ref) async {
    if (ref.type == ElementType.card) {
      final CardState? card = await _learning.findCardState(ref.id);
      if (card == null) return const _Repetitions();
      final StudyDayCalendar calendar = await _context.calendar();
      return _Repetitions(
        intervalDays: (card.memory.scheduledDays ?? 0).round(),
        repetitions: card.memory.repetitionCount,
        lapses: card.memory.lapses,
        lastRepetition: card.memory.lastReviewAtUtc == null
            ? null
            : calendar.dayOf(card.memory.lastReviewAtUtc!),
      );
    }
    final TopicState? topic = await _learning.findTopic(ref);
    if (topic == null) return const _Repetitions();
    return _Repetitions(
      intervalDays: topic.storedInterval,
      repetitions: topic.repetitionCount,
      lapses: topic.lapseCount,
      lastRepetition: topic.lastReviewDay,
    );
  }

  /// What the slider should show for [ref], or null when it has no schedule.
  Future<PriorityContext?> contextFor(ElementRef ref) async {
    final ElementSchedule? schedule = await _learning.findSchedule(ref);
    if (schedule == null) return null;

    final PriorityScale scale = await _context.priorityScale();
    final PriorityPosition position =
        scale.positionOf(schedule.priority) ??
        const PriorityPosition(index: 0, total: 1);

    return PriorityContext(
      ref: ref,
      rank: schedule.priority,
      position: position,
      above: await _neighbour(scale.neighbourAbove(schedule.priority), scale),
      below: await _neighbour(scale.neighbourBelow(schedule.priority), scale),
    );
  }

  /// Every element under [sourceId], in current priority order.
  ///
  /// The input to Spread: after an article is read, most of what it produced
  /// deserves a lower priority than the article itself was given.
  Future<List<PriorityEntry>> branchOf(String sourceId) async {
    final List<ElementSchedule> schedules = await _learning.listSchedules(
      types: ElementType.values.toSet(),
      lifecycles: <ElementLifecycle>{ElementLifecycle.active},
    );
    final PriorityScale scale = await _context.priorityScale();
    final entries = <PriorityEntry>[];
    for (final ElementSchedule schedule in schedules) {
      if (schedule.rootId != sourceId) continue;
      final (String title, String preview) = await _describe(schedule.ref);
      entries.add(
        PriorityEntry(
          schedule: schedule,
          position:
              scale.positionOf(schedule.priority) ??
              const PriorityPosition(index: 0, total: 1),
          title: title,
          preview: preview,
        ),
      );
    }
    return List<PriorityEntry>.unmodifiable(entries);
  }

  /// The neighbours a Set Priority to [percent] would place [ref] between.
  ///
  /// The dialog calls this as the slider moves, so what it names is where the
  /// element would actually land rather than where it currently sits.
  Future<({PriorityEntry? above, PriorityEntry? below})> neighboursAt({
    required ElementRef ref,
    required double percent,
  }) async {
    final ElementSchedule? schedule = await _learning.findSchedule(ref);
    if (schedule == null) {
      return (above: null, below: null);
    }
    final PriorityScale scale = await _context.priorityScale();
    final (PriorityRank? above, PriorityRank? below) = scale
        .neighboursForSetPriority(schedule.priority, percent);
    return (
      above: await _neighbour(above, scale),
      below: await _neighbour(below, scale),
    );
  }

  Future<PriorityEntry?> _neighbour(
    PriorityRank? rank,
    PriorityScale scale,
  ) async {
    if (rank == null) return null;
    final List<ElementSchedule> all = await _learning.listSchedules(
      types: ElementType.values.toSet(),
      lifecycles: <ElementLifecycle>{ElementLifecycle.active},
    );
    for (final ElementSchedule schedule in all) {
      if (schedule.priority != rank) continue;
      final (String title, String preview) = await _describe(schedule.ref);
      return PriorityEntry(
        schedule: schedule,
        position:
            scale.positionOf(rank) ??
            const PriorityPosition(index: 0, total: 1),
        title: title,
        preview: preview,
      );
    }
    return null;
  }

  Future<(String, String)> _describe(ElementRef ref) async {
    switch (ref.type) {
      case ElementType.source:
        final Source? source = await _content.findSource(ref.id);
        return (source?.title ?? 'Source', excerptOf(source?.markdown ?? ''));
      case ElementType.extract:
        final Extract? extract = await _content.findExtract(ref.id);
        if (extract == null) return ('Extract', '');
        final Source? source = await _content.findSource(
          extract.provenance.sourceId,
        );
        return (source?.title ?? 'Extract', excerptOf(extract.markdown));
      case ElementType.card:
        final Card? card = await _content.findCard(ref.id);
        if (card == null) return ('Card', '');
        final String question = switch (card.kind) {
          CardKind.qa => card.front,
          CardKind.cloze => renderClozeQuestion(card.front, card.clozeOrdinal!),
        };
        return ('Card', excerptOf(question));
    }
  }
}

/// Collapses whitespace and trims [markdown] to a one-line preview.
String excerptOf(String markdown, {int maximum = 140}) {
  final String collapsed = markdown.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.length <= maximum) return collapsed;
  return '${collapsed.substring(0, maximum - 1).trimRight()}…';
}

/// The counters a browser row shows, whichever engine produced them.
@immutable
final class _Repetitions {
  const _Repetitions({
    this.intervalDays = 0,
    this.repetitions = 0,
    this.lapses = 0,
    this.lastRepetition,
  });

  final int intervalDays;
  final int repetitions;
  final int lapses;
  final StudyDay? lastRepetition;
}
