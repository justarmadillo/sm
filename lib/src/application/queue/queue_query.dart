/// Read model for the daily study queue.
///
/// Loading the queue is not a pure read: the day's admission valve runs first,
/// because what the user is shown and what the collection records as deferred
/// have to be the same decision. Running it here — rather than on a timer or
/// at startup — means the caps apply from the first moment the user looks,
/// and the operation is keyed on the study day so looking twice changes
/// nothing.
library;

import 'package:meta/meta.dart';

import '../../core/clock.dart';
import '../../core/result.dart';
import '../../core/tracing.dart';
import '../../domain/content/card.dart';
import '../../domain/content/extract.dart';
import '../../domain/content/source.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/queue_policy.dart';
import '../../domain/scheduling/study_day.dart';
import '../ports/repositories.dart';
import '../scheduling/scheduling_context.dart';
import 'queue_commands.dart';
import 'queue_handlers.dart';

/// Presentation-neutral queue row. Answers are deliberately never projected.
@immutable
final class QueueEntry {
  const QueueEntry({
    required this.candidate,
    required this.actionLabel,
    required this.title,
    required this.preview,
    this.priorityPercent,
    this.isLeech = false,
  });

  final QueueCandidate candidate;
  final String actionLabel;
  final String title;
  final String preview;

  /// Where the element sits in the collection, `0` being most important.
  final double? priorityPercent;

  /// Whether this card has failed often enough to be worth reformulating.
  final bool isLeech;

  ElementRef get ref => candidate.ref;
}

/// The day's queue plus the numbers behind it.
@immutable
final class QueueProjection {
  const QueueProjection({
    required this.entries,
    required this.counters,
    required this.today,
    this.deferredThisRun = 0,
  });

  /// An empty day.
  static QueueProjection emptyOn(StudyDay today) => QueueProjection(
    entries: const <QueueEntry>[],
    counters: QueuePlan.empty.counters,
    today: today,
  );

  final List<QueueEntry> entries;

  /// What admission did: due volume, admitted volume, and how deep into the
  /// collection the day actually reached.
  final QueueCounters counters;

  final StudyDay today;

  /// How many elements this load deferred. Non-zero only on the first build
  /// of a study day.
  final int deferredThisRun;

  bool get isEmpty => entries.isEmpty;
}

/// Builds the day's queue projection.
final class QueueQuery {
  const QueueQuery({
    required ContentRepository content,
    required LearningRepository learning,
    required QueueHandlers handlers,
    required SchedulingContext context,
    required Clock clock,
  }) : _content = content,
       _learning = learning,
       _handlers = handlers,
       _context = context,
       _clock = clock;

  final ContentRepository _content;
  final LearningRepository _learning;
  final QueueHandlers _handlers;
  final SchedulingContext _context;
  final Clock _clock;

  /// Runs admission and projects the resulting queue.
  ///
  /// [extraAdmissions] raises every cap for this build only, which is what a
  /// Study More press asks for: more work now, without quietly persisting a
  /// bigger daily limit the user never chose.
  Future<QueueProjection> load({int extraAdmissions = 0}) async {
    final StudyDay today = await _context.today();
    final Result<AdmissionOutcome> outcome = await _handlers.runDailyAdmission(
      RunDailyAdmission(
        // Derived, not random: this is what makes the day's valve idempotent
        // across refreshes, restarts, and crashes.
        OperationId(dailyAdmissionOperationId(today)),
        day: today,
        extraAdmissions: extraAdmissions,
        timestampUtc: _clock.nowUtc(),
      ),
    );
    if (outcome.isErr) return QueueProjection.emptyOn(today);

    final AdmissionOutcome value = outcome.unwrap();
    // The handler owns the durable remaining plan. Rebuilding here would
    // discard its completion set and merge cursor and reshuffle a live day.
    final QueuePlan plan = value.plan;
    final QueueCounters counters = plan.counters;

    final PriorityScale scale = await _context.priorityScale();
    final int leechLapses = (await _context.settings()).cards.leechLapses;
    final entries = <QueueEntry>[];
    for (final QueueCandidate candidate in plan.entries) {
      final QueueEntry? entry = await _project(candidate, scale, leechLapses);
      if (entry != null) entries.add(entry);
    }
    return QueueProjection(
      entries: List<QueueEntry>.unmodifiable(entries),
      counters: counters,
      today: today,
      deferredThisRun: value.deferred,
    );
  }

  /// The day's numbers without projecting any content. For diagnostics.
  Future<QueueCounters> counters() async {
    final StudyDay today = await _context.today();
    final QueuePolicy policy = await _context.queuePolicy();
    return policy
        .build(
          candidates: await _handlers.loadCandidates(today),
          nowUtc: _clock.nowUtc(),
          today: today,
        )
        .counters;
  }

  Future<QueueEntry?> _project(
    QueueCandidate candidate,
    PriorityScale scale,
    int leechLapses,
  ) => switch (candidate.ref.type) {
    ElementType.source => _sourceEntry(candidate, scale),
    ElementType.extract => _extractEntry(candidate, scale),
    ElementType.card => _cardEntry(candidate, scale, leechLapses),
  };

  double? _percentOf(QueueCandidate candidate, PriorityScale scale) =>
      scale.positionOf(candidate.schedule.priority)?.percent;

  Future<QueueEntry?> _sourceEntry(
    QueueCandidate candidate,
    PriorityScale scale,
  ) async {
    final Source? source = await _content.findSource(candidate.ref.id);
    if (source == null) return null;
    return QueueEntry(
      candidate: candidate,
      actionLabel: 'Read',
      title: source.title,
      preview: _excerpt(source.markdown),
      priorityPercent: _percentOf(candidate, scale),
    );
  }

  Future<QueueEntry?> _extractEntry(
    QueueCandidate candidate,
    PriorityScale scale,
  ) async {
    final Extract? extract = await _content.findExtract(candidate.ref.id);
    if (extract == null) return null;
    final Source? source = await _content.findSource(
      extract.provenance.sourceId,
    );
    return QueueEntry(
      candidate: candidate,
      actionLabel: 'Process',
      title: source?.title ?? 'Extract',
      preview: _excerpt(extract.markdown),
      priorityPercent: _percentOf(candidate, scale),
    );
  }

  /// The article a card ultimately came from, through whichever parent it
  /// has. A standalone card has none, and the entry falls back to its type.
  Future<Source?> _sourceOfCard(Card card) async {
    final CardParent? parent = card.parent;
    if (parent == null) return null;
    if (parent.isSource) return _content.findSource(parent.id);
    final Extract? extract = await _content.findExtract(parent.id);
    if (extract == null) return null;
    return _content.findSource(extract.provenance.sourceId);
  }

  Future<QueueEntry?> _cardEntry(
    QueueCandidate candidate,
    PriorityScale scale,
    int leechLapses,
  ) async {
    final Card? card = await _content.findCard(candidate.ref.id);
    if (card == null) return null;
    final Source? source = await _sourceOfCard(card);
    final String question = switch (card.kind) {
      CardKind.qa => card.front,
      CardKind.cloze => renderClozeQuestion(card.front, card.clozeOrdinal!),
    };
    final int lapses = candidate.card?.memory.lapses ?? 0;
    return QueueEntry(
      candidate: candidate,
      actionLabel: 'Review',
      title: source?.title ?? 'Card',
      preview: _excerpt(question),
      priorityPercent: _percentOf(candidate, scale),
      isLeech: leechLapses > 0 && lapses >= leechLapses,
    );
  }

  /// The learning repository, held so callers that already have this query do
  /// not need a second handle for schedule lookups.
  LearningRepository get learning => _learning;
}

String _excerpt(String markdown, {int maximum = 180}) {
  final String collapsed = markdown.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.length <= maximum) return collapsed;
  return '${collapsed.substring(0, maximum - 1).trimRight()}…';
}
