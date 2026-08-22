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

import 'package:meta/meta.dart';

import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/queue_policy.dart';
import '../../domain/scheduling/revlog.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../../domain/settings/app_settings.dart';
import '../ports/repositories.dart';
import '../scheduling/effective_due_query.dart';
import '../scheduling/scheduling_context.dart';

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
    this.effectiveDueDay,
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
  final AFactorComputation? nextIntervalPreview;

  /// The day it may next be presented, after every active adjustment. The
  /// panel shows this beside the canonical due precisely so the difference
  /// between "the scheduler said" and "the calendar allows" stays visible.
  final StudyDay? effectiveDueDay;
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

  /// Today's admission numbers, including how deep into the collection the
  /// day's work actually reached.
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

  /// Share of today's due volume the valve had to shed.
  ///
  /// Sustained above roughly 30% for three weeks means the collection is
  /// oversubscribed, and the fix is bulk demotion rather than a bigger cap.
  double get overflowRatio => counters.overflowRatio;
}

/// Loads the diagnostics projections.
final class DiagnosticsQuery {
  const DiagnosticsQuery({
    required LearningRepository learning,
    required ContentRepository content,
    required SearchRepository search,
    required SchedulingContext context,
    required EffectiveDueQuery effectiveDue,
  }) : _learning = learning,
       _content = content,
       _search = search,
       _context = context,
       _effectiveDue = effectiveDue;

  final LearningRepository _learning;
  final ContentRepository _content;
  final SearchRepository _search;
  final SchedulingContext _context;
  final EffectiveDueQuery _effectiveDue;

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

    AFactorComputation? preview;
    if (topic != null) {
      final TopicScheduler scheduler = await _context.topicScheduler();
      preview = scheduler.computeAFactor(
        topic,
        TopicEncounter(
          readFraction: topic.isExtract ? null : 0.5,
          hasChildItems: topic.isExtract
              ? (await _content.listCardsOfExtract(ref.id)).isNotEmpty
              : false,
        ),
        pressure: scale.pressureOf(schedule.priority),
      );
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
      effectiveDueDay: await _effectiveDue.forElement(ref),
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

  /// The most recent log entries, newest first.
  Future<List<RevlogEntry>> recentEvents({int limit = 100}) =>
      _learning.recentRevlog(limit: limit);

  Future<String?> _titleOf(ElementRef ref) async => switch (ref.type) {
    ElementType.source => (await _content.findSource(ref.id))?.title,
    ElementType.extract => (await _content.findExtract(ref.id))?.markdown,
    ElementType.card => (await _content.findCard(ref.id))?.front,
  };
}
