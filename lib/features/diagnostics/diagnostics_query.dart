/// The development diagnostics panel's read model.
///
/// Built for one question: *why did the scheduler do that?* Answering it needs
/// the element's current state, the commands that touched it, and the before
/// and after of each transition — which is exactly what the repetition log
/// records.
///
/// Element **content** is not part of that answer, so it is not projected
/// unless the user turns it on in Settings. A panel meant for scheduling bugs
/// should not spill a collection into a screenshot or a support paste.
library;

import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/daily_queue/queue_policy.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/revlog.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/storage/contracts/repositories.dart';
import 'package:meta/meta.dart';

/// Everything known about one element's scheduling.
@immutable
final class ElementDiagnostics {
  const ElementDiagnostics({
    required this.ref,
    required this.schedule,
    required this.position,
    required this.history,
    this.topic,
    this.card,
    this.title,
    this.nextIntervalPreview,
  });

  final ElementRef ref;
  final ElementSchedule schedule;

  /// Where it sits in the collection right now.
  final PriorityPosition? position;

  /// Its repetition log, newest first.
  final List<RevlogEntry> history;

  /// Pacing state, for a source or extract.
  final TopicState? topic;

  /// Memory state, for a card.
  final CardState? card;

  /// Shown only when Settings allows content in the panel.
  final String? title;

  /// What the next encounter would schedule, without committing to it.
  final int? nextIntervalPreview;
}

/// A snapshot of how the collection as a whole is doing.
@immutable
final class CollectionDiagnostics {
  const CollectionDiagnostics({
    required this.today,
    required this.counters,
    required this.byLifecycle,
    required this.eventsToday,
    required this.indexedDocuments,
    required this.searchIndexValid,
    required this.settings,
  });

  final StudyDay today;

  /// Current SM20 Outstanding item/topic counts.
  final QueueCounters counters;

  final Map<ElementType, Map<ElementLifecycle, int>> byLifecycle;

  /// What the repetition log recorded today, by event type.
  final Map<RevlogEventType, int> eventsToday;

  final int indexedDocuments;
  final bool searchIndexValid;

  /// The configuration the schedulers are actually running on.
  final AppSettings settings;

  /// Elements in the collection, whatever their lifecycle.
  int get totalElements => byLifecycle.values.fold(
    0,
    (int sum, Map<ElementLifecycle, int> counts) =>
        sum + counts.values.fold(0, (int a, int b) => a + b),
  );
}

/// Loads the diagnostics projections.
final class DiagnosticsQuery {
  const DiagnosticsQuery({
    required LearningRepository learning,
    required ContentRepository content,
    required SearchRepository search,
    required SchedulingContext context,
  }) : _learning = learning,
       _content = content,
       _search = search,
       _context = context;

  final LearningRepository _learning;
  final ContentRepository _content;
  final SearchRepository _search;
  final SchedulingContext _context;

  /// Everything about [ref].
  Future<ElementDiagnostics?> forElement(ElementRef ref) async {
    final ElementSchedule? schedule = await _learning.findSchedule(ref);
    if (schedule == null) return null;

    final AppSettings settings = await _context.settings();
    final PriorityScale scale = await _context.priorityScale();
    final TopicState? topic = ref.type.isTopic
        ? await _learning.findTopic(ref)
        : null;
    final CardState? card = ref.type == ElementType.card
        ? await _learning.findCardState(ref.id)
        : null;

    int? preview;
    if (topic != null) {
      final TopicScheduler scheduler = await _context.topicScheduler();
      preview = topic.status == Sm20ElementStatus.pending
          ? 1
          : scheduler.nextAutomaticInterval(topic);
    }

    return ElementDiagnostics(
      ref: ref,
      schedule: schedule,
      position: scale.positionOf(schedule.priority),
      history: (await _learning.listRevlogFor(
        ref,
        limit: 200,
      )).reversed.toList(growable: false),
      topic: topic,
      card: card,
      title: settings.diagnostics.showContentInPanel
          ? await _titleOf(ref)
          : null,
      nextIntervalPreview: preview,
    );
  }

  /// How the collection as a whole is doing.
  Future<CollectionDiagnostics> forCollection(QueueCounters counters) async {
    final StudyDay today = await _context.today();
    return CollectionDiagnostics(
      today: today,
      counters: counters,
      byLifecycle: await _learning.countByLifecycle(),
      eventsToday: await _learning.countRevlogOn(today),
      indexedDocuments: await _search.documentCount(),
      searchIndexValid: await _search.indexIsValid(),
      settings: await _context.settings(),
    );
  }

  /// The most recent commands, newest first.
  Future<List<ActivityRecord>> recentCommands({int limit = 50}) =>
      _learning.recentActivity(limit: limit);

  Future<String?> _titleOf(ElementRef ref) async => switch (ref.type) {
    ElementType.source => (await _content.findSource(ref.id))?.title,
    ElementType.extract => (await _content.findExtract(ref.id))?.markdown,
    ElementType.card => (await _content.findCard(ref.id))?.front,
  };
}
