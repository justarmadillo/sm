/// Runs every command the Reader and the Library can issue.
///
/// One runner owns validation, transaction scope, the scheduling call,
/// persistence, and the emitted events — in that order, for every command.
/// Nothing above this layer knows about intervals or lifecycles, and nothing
/// below it decides policy.
///
/// Three rules the whole reading loop rests on:
///
/// * Only completing an encounter or postponing touches a schedule. Moving the
///   marker, saving a soft position, renaming, or reading to the end do not,
///   because interruption must never be recorded as progress.
/// * Terminal commands are exactly-once. The activity log is consulted for the
///   command's operation id before the domain is invoked, so a retry after a
///   crash, a double click, or a queue that advances twice commits once.
/// * Every schedule change is journalled. The repetition log is the only
///   record that cannot be rebuilt from current state, so a write that skips
///   it loses information permanently.
library;

import 'dart:convert';

import 'package:incremental_reader/documents/apply_source_edit.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/block_edit.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/documents/source_edit.dart';
import 'package:incremental_reader/documents/text_splice.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/revlog.dart';
import 'package:incremental_reader/scheduling/history/scheduler_event.dart';
import 'package:incremental_reader/scheduling/history/scheduling_journal.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/command_base.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/content_repository.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/search_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';
import 'package:meta/meta.dart';

/// Activity kind recorded when a source is imported.
const String kSourceImportedKind = 'source.imported';

/// Activity kind recorded when the resume marker moves.
const String kMarkerMovedKind = 'reader.marker_moved';

/// Activity kind recorded when a source's text is edited.
const String kSourceEditedKind = 'source.edited';

/// Activity kind recorded when an edit is reversed.
const String kSourceEditUndoneKind = 'source.edit_undone';

/// Activity kind recorded when a topic's interval is set by hand.
const String kTopicRescheduledKind = 'topic.rescheduled';

/// Activity kind for a completed topic encounter.
///
/// The idempotency guard in `_run` looks the operation up by this exact kind,
/// so the row written on success has to carry it. Logging the domain event's
/// own name here instead would leave the guard permanently unsatisfied and
/// let a retried Done commit a second repetition.
const String kTopicEncounterCompletedKind = 'topic.encounter_completed';

/// What one text edit produced, for the caller that has to redraw.
///
/// [outcome] is null when nothing was written — a no-op edit, or a command
/// replayed after it had already been applied.
@immutable
final class SourceEdited {
  const SourceEdited({
    required this.source,
    required this.document,
    required this.outcome,
  });

  final Source source;

  /// The re-derived document. Block ids differ from the previous parse and
  /// carry no meaning across it.
  final Document document;

  final SourceEditOutcome? outcome;

  /// Whether the text actually changed.
  bool get didChange => outcome != null;
}

/// Runs the commands for reading, marking, and pacing sources.
final class ReaderCommandRunner {
  ReaderCommandRunner({
    required ContentRepository content,
    required LearningRepository learning,
    required SearchRepository search,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required SchedulingContext context,
    required Clock clock,
    required IdGenerator ids,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _content = content,
       _learning = learning,
       _search = search,
       _transfer = transfer,
       _transactions = transactions,
       _context = context,
       _clock = clock,
       _ids = ids,
       _journal = SchedulingJournal(learning: learning, ids: ids),
       _diagnostics = diagnostics;

  final ContentRepository _content;
  final LearningRepository _learning;
  final SearchRepository _search;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final SchedulingContext _context;
  final Clock _clock;
  final IdGenerator _ids;
  final SchedulingJournal _journal;
  final DiagnosticSink _diagnostics;

  /// The study day the clock currently falls in.
  Future<StudyDay> today() => _context.today();

  /// Imports markdown as a new source, due today.
  Future<Result<Source>> importSource(
    ImportSource command,
  ) => _run<Source>(command, kSourceImportedKind, () async {
    final String markdown = command.markdown.trim();
    if (markdown.isEmpty) {
      return const Err<Source>(
        ValidationFailure('a source needs some markdown', field: 'markdown'),
      );
    }
    final String title = command.title.trim();
    if (title.isEmpty) {
      return const Err<Source>(
        ValidationFailure('a source needs a title', field: 'title'),
      );
    }

    final Source source = Source.import(
      id: _ids.newId(),
      title: title,
      markdown: markdown,
      importedAtUtc: _clock.nowUtc(),
    );
    final Document document = Document.parse(
      sourceId: source.id,
      markdown: source.markdown,
    );
    if (document.isEmpty) {
      return const Err<Source>(
        ValidationFailure('that markdown produced no readable blocks'),
      );
    }

    // New root elements start in the middle unless the user says
    // otherwise: nothing has been claimed about importance yet, and
    // pretending otherwise would bury or promote the article for no
    // reason. The first interval then follows from where that lands.
    //
    // "The middle" is resolved against the collection rather than being a
    // shared constant, because identical keys collapse the order: every
    // tied element reports the same percentile, and a queue that cannot
    // tell its elements apart cannot prioritize between them.
    final PriorityScale scale = await _context.priorityScale();
    final PriorityRank rank = scale.rankAtPercent(
      command.priorityPercent ?? 50,
    );
    // Against the order the article is about to join, not the one it is
    // not yet part of — otherwise every import would read as an edge case.
    final double pressure = scale.including(rank).pressureOf(rank);

    final StudyDay day = await today();
    final ElementRef ref = ElementRef(id: source.id, type: ElementType.source);
    final TopicScheduler scheduler = await _context.topicScheduler();
    final TopicState topic = scheduler.createFor(
      ref: ref,
      today: day,
      buildSchedule: (StudyDay due) => ElementSchedule(
        ref: ref,
        priority: rank,
        lifecycle: ElementLifecycle.active,
        dueDay: due,
        originalDueDay: due,
        rootId: source.id,
        createdAtUtc: source.importedAtUtc,
        updatedAtUtc: source.importedAtUtc,
      ),
    );

    await _content.insertSource(source, document);
    await _learning.insertTopic(topic);
    final runtime = await _context.runtimeState();
    await _context.saveRuntimeState(
      runtime.copyWith(
        pending: <ElementRef>[
          ...runtime.pending.where((ElementRef value) => value != ref),
          ref,
        ],
      ),
    );
    await _search.saveDocument(
      SearchDocument(
        ref: ref,
        title: source.title,
        // The whole article is indexed, so a passage can be found before
        // it has ever been extracted.
        body: source.markdown,
        sourceId: source.id,
        updatedAtUtc: source.importedAtUtc,
      ),
    );
    await _journalCreation(command, topic, pressure);
    await _log(
      command,
      kSourceImportedKind,
      ref: ref,
      metadata: <String, Object?>{
        'words': source.wordCount,
        'blocks': document.blocks.length,
        'first_interval_days': topic.intervalDays,
      },
    );
    return Ok<Source>(source);
  });

  /// Places the authoritative resume marker. Never advances the schedule.
  Future<Result<Source>> moveResumeMarker(MoveResumeMarker command) =>
      _run<Source>(command, kMarkerMovedKind, () async {
        final Source? source = await _content.findSource(command.sourceId);
        if (source == null) return _missingSource<Source>(command.sourceId);

        final Document? document = await _content.findDocument(
          command.sourceId,
        );
        if (document == null || !document.containsAnchor(command.anchor)) {
          return const Err<Source>(
            ValidationFailure('that anchor does not belong to this source'),
          );
        }

        final Source? updated = await _content.saveResumeMarker(
          source.id,
          command.anchor,
        );
        if (updated == null) return _missingSource<Source>(command.sourceId);
        await _log(
          command,
          kMarkerMovedKind,
          ref: ElementRef(id: source.id, type: ElementType.source),
          metadata: <String, Object?>{'offset': command.anchor.utf8Offset},
        );
        return Ok<Source>(updated);
      });

  /// Records the last stable scroll position.
  ///
  /// Written often and cheaply, outside every log: it is not an event, it is a
  /// scratch value that the next scroll overwrites.
  Future<Result<Source>> saveSoftPosition(SaveSoftPosition command) async {
    final Source? source = await _content.findSource(command.sourceId);
    if (source == null) return _missingSource<Source>(command.sourceId);
    final Document? document = await _content.findDocument(command.sourceId);
    if (document == null || !document.containsAnchor(command.anchor)) {
      return const Err<Source>(
        ValidationFailure('that anchor does not belong to this source'),
      );
    }
    if (source.resume.softPosition == command.anchor) {
      return Ok<Source>(source);
    }
    final Source? updated = await _content.saveSoftPosition(
      source.id,
      command.anchor,
    );
    if (updated == null) return _missingSource<Source>(command.sourceId);
    return Ok<Source>(updated);
  }

  /// Promotes the soft position to the authoritative marker.
  Future<Result<Source>> confirmSoftPosition(ConfirmSoftPosition command) =>
      _run<Source>(command, kMarkerMovedKind, () async {
        final Source? source = await _content.findSource(command.sourceId);
        if (source == null) return _missingSource<Source>(command.sourceId);
        if (source.resume.softPosition == null) {
          return const Err<Source>(
            ConflictFailure('there is no soft position to confirm'),
          );
        }
        final Source? updated = await _content.confirmSoftPosition(source.id);
        if (updated == null) return _missingSource<Source>(command.sourceId);
        await _log(
          command,
          kMarkerMovedKind,
          ref: ElementRef(id: source.id, type: ElementType.source),
          metadata: <String, Object?>{'from': 'soft_position'},
        );
        return Ok<Source>(updated);
      });

  /// Done: grows the topic's interval exactly once.
  Future<Result<TopicState>> completeEncounter(
    CompleteTopicEncounter command,
  ) => _run<TopicState>(command, kTopicEncounterCompletedKind, () async {
    final TopicState? topic = await _learning.findTopic(command.ref);
    if (topic == null) return _missingSchedule<TopicState>(command.ref.id);

    final StudyDay day = await today();
    final TopicScheduler scheduler = await _context.topicScheduler();
    final PriorityScale scale = await _context.priorityScale();
    final double pressure = scale.pressureOf(topic.schedule.priority);
    final TopicEncounter encounter = await _describeEncounter(command, topic);

    final TopicTransition transition = scheduler.complete(
      topic,
      day,
      encounter: encounter,
      priorityScale: scale,
    );
    if (!transition.isChange) {
      // The domain refused: the element is already finished, dismissed, or
      // suspended. Not an error, and nothing to write.
      return Ok<TopicState>(transition.state);
    }

    final StudyDayCalendar calendar = await _context.calendar();
    if (!await _learning.compareAndSwapTopic(
      expected: topic,
      replacement: transition.state,
    )) {
      return const Err<TopicState>(
        ConflictFailure('the topic changed before Done committed'),
      );
    }
    final runtime = await _context.runtimeState();
    await _context.saveRuntimeState(
      runtime.copyWith(
        prngSeed: transition.prngState.seed,
        outstanding: runtime.outstanding
            .where((ElementRef value) => value != command.ref)
            .toList(),
        outstandingItems: runtime.outstandingItems
            .where((ElementRef value) => value != command.ref)
            .toList(),
        outstandingTopics: runtime.outstandingTopics
            .where((ElementRef value) => value != command.ref)
            .toList(),
        finalDrill: runtime.finalDrill
            .where((ElementRef value) => value != command.ref)
            .toList(),
        pending: runtime.pending
            .where((ElementRef value) => value != command.ref)
            .toList(),
      ),
    );
    for (final TopicEvent event in transition.events) {
      await _journal.append(
        operationId: command.operationId.value,
        ref: command.ref,
        eventType: event is TopicLifecycleChanged
            ? RevlogEventType.finish
            : RevlogEventType.topicRead,
        atUtc: command.timestampUtc,
        before: _journal.topicSnapshot(
          topic,
          calendar: calendar,
          pressure: pressure,
          readFraction: encounter.readFraction,
        ),
        after: _journal.topicSnapshot(
          transition.state,
          calendar: calendar,
          pressure: pressure,
          readFraction: encounter.readFraction,
        ),
        elapsedDays: topic.lastEncounterDay?.daysUntil(day).toDouble(),
        scheduledDays: topic.intervalDays,
        durationMs: command.foregroundMs,
        postponeCount: topic.postponeCount,
        metadata: <String, Object?>{
          if (event is TopicRepetitionCommitted) ...<String, Object?>{
            'interval_days': event.storedInterval,
            'selected_interval': event.selectedInterval,
            'next_due': event.nextDueDay.toString(),
            'a_before': event.oldAFactor,
            'a_after': event.newAFactor,
            'priority_before': event.priorityBefore,
            'priority_after': event.priorityAfter,
            'random_draws': event.randomDraws,
          },
          if (event is TopicLifecycleChanged) ...<String, Object?>{
            'from': event.from.name,
            'to': event.to.name,
          },
          'words_read': encounter.wordsRead,
          'extracts_created': encounter.extractsCreated,
          'has_child_items': encounter.hasChildItems,
        },
      );
      await _log(
        command,
        kTopicEncounterCompletedKind,
        ref: command.ref,
        durationMs: command.foregroundMs,
        // The specific domain event stays in the row, it just no longer
        // decides the kind the retry guard searches for.
        metadata: <String, Object?>{
          ...?_metadataFor(event),
          'event': event.kind,
        },
      );
    }
    await _journal.appendScheduler(
      operationId: command.operationId.value,
      ref: command.ref,
      eventType: SchedulerEventType.topicEncountered,
      atUtc: command.timestampUtc,
      studyDay: day,
      policyVersion: transition.state.schedulerVersion,
      schedulerName: transition.state.schedulerName,
      schedulerVersion: transition.state.schedulerVersion,
      stateBefore: _topicStateJson(topic),
      stateAfter: _topicStateJson(transition.state),
      algorithmicDueBefore: SchedulerEvent.encodeStudyDayDue(
        topic.schedule.algorithmicDueDay,
      ),
      algorithmicDueAfter: SchedulerEvent.encodeStudyDayDue(
        transition.state.schedule.algorithmicDueDay,
      ),
      metadata: <String, Object?>{
        'words_read': encounter.wordsRead,
        'extracts_created': encounter.extractsCreated,
        'foreground_ms': command.foregroundMs,
      },
    );
    return Ok<TopicState>(transition.state);
  });

  /// SM20 Later Today: queue-only when already Outstanding; otherwise it
  /// performs Jump Interval 0 without priority adaptation.
  Future<Result<TopicState>> postpone(PostponeElement command) =>
      _run<TopicState>(command, 'topic.postponed', () async {
        final TopicState? topic = await _learning.findTopic(command.ref);
        if (topic == null) return _missingSchedule<TopicState>(command.ref.id);

        final StudyDay day = await today();
        final StudyDayCalendar calendar = await _context.calendar();
        final TopicScheduler scheduler = await _context.topicScheduler();
        final PriorityScale scale = await _context.priorityScale();
        final runtime = await _context.runtimeState();
        final bool isAlreadyOutstanding = runtime.outstanding.contains(topic.ref);
        final TopicTransition transition = command.until == null
            ? scheduler.laterToday(
                topic,
                today: day,
                isAlreadyOutstanding: isAlreadyOutstanding,
                priorityScale: scale,
              )
            : scheduler.rescheduleElement(
                topic,
                targetDay: command.until!,
                today: day,
              );
        if (transition.isChange &&
            !await _learning.compareAndSwapTopic(
              expected: topic,
              replacement: transition.state,
            )) {
          return const Err<TopicState>(
            ConflictFailure('the topic changed before Later committed'),
          );
        }
        final outstanding = <ElementRef>[
          for (final ElementRef ref in runtime.outstanding)
            if (ref != topic.ref) ref,
          if (command.until == null || command.until! <= day) topic.ref,
        ];
        final outstandingTopics = <ElementRef>[
          for (final ElementRef ref in runtime.outstandingTopics)
            if (ref != topic.ref) ref,
          if (command.until == null || command.until! <= day) topic.ref,
        ];
        // An element belongs to exactly one stage store. Later Today on a
        // pending topic memorizes it through the section 8.1 nonmemorized
        // branch, so it has to leave Pending as it joins Outstanding —
        // otherwise it sits in both, and the stale entry resurfaces the next
        // time the Pending stage is built.
        final bool isStillPending =
            transition.state.status == Sm20ElementStatus.pending;
        final pending = <ElementRef>[
          for (final ElementRef ref in runtime.pending)
            if (ref != topic.ref) ref,
          if (isStillPending) topic.ref,
        ];
        await _context.saveRuntimeState(
          runtime.copyWith(
            outstanding: outstanding,
            outstandingTopics: outstandingTopics,
            pending: pending,
            prngSeed: transition.prngState.seed,
          ),
        );
        final TopicState after = transition.state;
        await _journal.append(
          operationId: command.operationId.value,
          ref: command.ref,
          eventType: command.isAutomatic
              ? RevlogEventType.autoPostpone
              : RevlogEventType.postpone,
          atUtc: command.timestampUtc,
          before: _journal.topicSnapshot(topic, calendar: calendar),
          after: _journal.topicSnapshot(after, calendar: calendar),
          scheduledDays: topic.intervalDays,
          postponeCount: topic.postponeCount,
          metadata: <String, Object?>{
            'target': (command.until ?? day).toString(),
            'queue_only': isAlreadyOutstanding,
          },
        );
        await _log(
          command,
          'topic.postponed',
          ref: command.ref,
          metadata: <String, Object?>{
            'target': (command.until ?? day).toString(),
            'queue_only': isAlreadyOutstanding,
          },
        );
        return Ok<TopicState>(after);
      });

  /// Sets a topic's interval by hand.
  ///
  /// The standard SM20 UI adapts A and priority against the entered remaining
  /// interval after the low-level due rewrite.
  Future<Result<TopicState>> reschedule(RescheduleTopic command) =>
      _run<TopicState>(command, kTopicRescheduledKind, () async {
        if (command.intervalDays < 0) {
          return const Err<TopicState>(
            ValidationFailure('an interval cannot be negative'),
          );
        }
        final TopicState? topic = await _learning.findTopic(command.ref);
        if (topic == null) return _missingSchedule<TopicState>(command.ref.id);

        final StudyDay day = await today();
        final StudyDayCalendar calendar = await _context.calendar();
        final StudyDay destination = day.addDays(command.intervalDays);
        final TopicScheduler scheduler = await _context.topicScheduler();
        final TopicTransition transition = scheduler.jumpInterval(
          topic,
          today: day,
          remainingInterval: command.intervalDays,
          shouldModifyPriority: true,
          priorityScale: await _context.priorityScale(),
        );
        if (!await _learning.compareAndSwapTopic(
          expected: topic,
          replacement: transition.state,
        )) {
          return const Err<TopicState>(
            ConflictFailure('the topic changed before reschedule committed'),
          );
        }
        await _context.savePrngState(transition.prngState);
        await _journal.append(
          operationId: command.operationId.value,
          ref: command.ref,
          eventType: RevlogEventType.manualReschedule,
          atUtc: command.timestampUtc,
          before: _journal.topicSnapshot(topic, calendar: calendar),
          after: _journal.topicSnapshot(transition.state, calendar: calendar),
          scheduledDays: topic.intervalDays,
          metadata: <String, Object?>{'scheduled_for': destination.toString()},
        );
        await _log(
          command,
          kTopicRescheduledKind,
          ref: command.ref,
          metadata: <String, Object?>{'scheduled_for': destination.toString()},
        );
        return Ok<TopicState>(transition.state);
      });

  /// Keeps content, stops scheduling.
  ///
  /// SM20 has no Suspend and no Finish: an element is pending, memorized,
  /// dismissed, or deleted. Both of those commands only ever meant "stop
  /// scheduling this but keep it", which is exactly Dismiss.
  Future<Result<TopicState>> dismiss(DismissElement command) => _lifecycle(
    command,
    command.ref,
    'topic.dismissed',
    RevlogEventType.dismiss,
    Sm20ElementStatus.dismissed,
  );

  /// Undismiss: the status byte only, exactly as the executable does it.
  Future<Result<TopicState>> undismiss(UndismissSource command) => _lifecycle(
    command,
    command.ref,
    'topic.undismissed',
    RevlogEventType.resume,
    Sm20ElementStatus.pending,
  );

  /// Soft-deletes a source without touching content or descendant schedules.
  Future<Result<TopicState>> deleteSource(DeleteSource command) => _lifecycle(
    command,
    ElementRef(id: command.sourceId, type: ElementType.source),
    'source.deleted',
    RevlogEventType.dismiss,
    Sm20ElementStatus.deleted,
  );

  /// Changes a source's pacing profile without touching position or interval.
  /// Renames a source.
  Future<Result<Source>> renameSource(RenameSource command) =>
      _run<Source>(command, 'source.renamed', () async {
        final String title = command.title.trim();
        if (title.isEmpty) {
          return const Err<Source>(
            ValidationFailure('a source needs a title', field: 'title'),
          );
        }
        final Source? source = await _content.findSource(command.sourceId);
        if (source == null) return _missingSource<Source>(command.sourceId);
        final Source updated = source.copyWith(title: title);
        await _content.updateSource(updated);
        await _search.saveDocument(
          SearchDocument(
            ref: ElementRef(id: source.id, type: ElementType.source),
            title: title,
            body: source.markdown,
            sourceId: source.id,
            updatedAtUtc: command.timestampUtc,
          ),
        );
        await _log(
          command,
          'source.renamed',
          ref: ElementRef(id: source.id, type: ElementType.source),
        );
        return Ok<Source>(updated);
      });

  /// Gathers the A-factor's inputs for this encounter.
  ///
  /// The completion term needs how far the marker has reached, and the extract
  /// conversion term needs whether the element has produced any cards. Both
  /// are read here rather than trusted from the UI, because a schedule must
  /// not depend on what a widget believed.
  Future<TopicEncounter> _describeEncounter(
    CompleteTopicEncounter command,
    TopicState topic,
  ) async {
    if (topic.isExtract) {
      final int cards = (await _content.listCardsOfExtract(
        topic.ref.id,
      )).length;
      return TopicEncounter(
        hasChildItems: cards > 0,
        wordsRead: command.wordsRead,
        extractsCreated: command.extractsCreated,
      );
    }

    final Source? source = await _content.findSource(topic.ref.id);
    final Document? document = await _content.findDocument(topic.ref.id);
    if (source == null || document == null) {
      return TopicEncounter(
        wordsRead: command.wordsRead,
        extractsCreated: command.extractsCreated,
      );
    }

    final ReaderAnchor? marker = source.resume.marker;
    final ReaderAnchor start = document.startAnchor;
    final ReaderAnchor end = document.endAnchor;
    double? readFraction;
    var hasReachedEnd = false;
    if (marker != null) {
      final int total = document.wordsBetween(start, end);
      final int read = document.wordsBetween(start, marker);
      readFraction = total <= 0 ? 1 : (read / total).clamp(0, 1);
      hasReachedEnd = !document.isBefore(marker, end);
    }

    // "Nothing left to mine" is the strict reading: every word of the article
    // now sits inside an extract. It is deliberately hard to satisfy, because
    // closing a source the user still wanted is worse than leaving a dead one
    // in the queue.
    final List<Extract> extracts = await _content.listExtractsOfSource(
      source.id,
    );
    final int uncovered = document.wordsOutside(<(ReaderAnchor, ReaderAnchor)>[
      for (final Extract extract in extracts)
        if (extract.provenance.hasSourceAsParent &&
            extract.provenance.parentId == source.id)
          (extract.provenance.startAnchor, extract.provenance.endAnchor),
    ]);

    return TopicEncounter(
      readFraction: readFraction,
      wordsRead: command.wordsRead,
      extractsCreated: command.extractsCreated,
      hasReachedEnd: hasReachedEnd,
      hasUnprocessedText: uncovered > 0,
    );
  }

  Future<Result<TopicState>> _lifecycle(
    AppCommand command,
    ElementRef ref,
    String kind,
    RevlogEventType eventType,
    Sm20ElementStatus target,
  ) => _run<TopicState>(command, kind, () async {
    final TopicState? topic = await _learning.findTopic(ref);
    if (topic == null) return _missingSchedule<TopicState>(ref.id);

    final StudyDay day = await today();
    final TopicScheduler scheduler = await _context.topicScheduler();
    final TopicTransition result = switch (target) {
      Sm20ElementStatus.dismissed => scheduler.dismiss(
        topic,
        day,
        priorityScale: await _context.priorityScale(),
      ),
      Sm20ElementStatus.pending => scheduler.undismiss(topic),
      Sm20ElementStatus.deleted => scheduler.delete(topic, day),
      Sm20ElementStatus.memorized => TopicTransition.unchanged(
        topic,
        scheduler.prngState,
      ),
    };
    if (!result.isChange) return Ok<TopicState>(result.state);

    final StudyDayCalendar calendar = await _context.calendar();
    if (!await _learning.compareAndSwapTopic(
      expected: topic,
      replacement: result.state,
    )) {
      return const Err<TopicState>(
        ConflictFailure('the topic changed before lifecycle commit'),
      );
    }
    final runtime = await _context.runtimeState();
    final List<ElementRef> pending = runtime.pending
        .where((ElementRef value) => value != ref)
        .toList();
    if (result.state.status == Sm20ElementStatus.pending) pending.add(ref);
    await _context.saveRuntimeState(
      runtime.copyWith(
        prngSeed: result.prngState.seed,
        outstanding: runtime.outstanding
            .where((ElementRef value) => value != ref)
            .toList(),
        outstandingItems: runtime.outstandingItems
            .where((ElementRef value) => value != ref)
            .toList(),
        outstandingTopics: runtime.outstandingTopics
            .where((ElementRef value) => value != ref)
            .toList(),
        finalDrill: runtime.finalDrill
            .where((ElementRef value) => value != ref)
            .toList(),
        pending: pending,
      ),
    );
    await _journal.append(
      operationId: command.operationId.value,
      ref: ref,
      eventType: eventType,
      atUtc: command.timestampUtc,
      before: _journal.topicSnapshot(topic, calendar: calendar),
      after: _journal.topicSnapshot(result.state, calendar: calendar),
      scheduledDays: topic.intervalDays,
      metadata: <String, Object?>{
        'from': topic.schedule.lifecycle.name,
        'to': result.state.schedule.lifecycle.name,
      },
    );
    final SchedulerEventType schedulerEventType =
        switch (result.state.schedule.lifecycle) {
          ElementLifecycle.active => SchedulerEventType.resumed,
          ElementLifecycle.dismissed => SchedulerEventType.dismissed,
          ElementLifecycle.deleted => SchedulerEventType.dismissed,
        };
    await _journal.appendScheduler(
      operationId: command.operationId.value,
      ref: ref,
      eventType: schedulerEventType,
      atUtc: command.timestampUtc,
      studyDay: day,
      policyVersion: result.state.schedulerVersion,
      schedulerName: result.state.schedulerName,
      schedulerVersion: result.state.schedulerVersion,
      stateBefore: _topicStateJson(topic),
      stateAfter: _topicStateJson(result.state),
      algorithmicDueBefore: SchedulerEvent.encodeStudyDayDue(
        topic.schedule.algorithmicDueDay,
      ),
      algorithmicDueAfter: SchedulerEvent.encodeStudyDayDue(
        result.state.schedule.algorithmicDueDay,
      ),
      metadata: <String, Object?>{
        'from': topic.schedule.lifecycle.name,
        'to': result.state.schedule.lifecycle.name,
      },
    );
    for (final TopicEvent event in result.events) {
      await _log(command, event.kind, ref: ref, metadata: _metadataFor(event));
    }
    return Ok<TopicState>(result.state);
  });

  Future<void> _journalCreation(
    AppCommand command,
    TopicState topic,
    double pressure,
  ) async {
    final StudyDayCalendar calendar = await _context.calendar();
    await _journal.append(
      operationId: command.operationId.value,
      ref: topic.ref,
      eventType: RevlogEventType.created,
      atUtc: command.timestampUtc,
      after: _journal.topicSnapshot(
        topic,
        calendar: calendar,
        pressure: pressure,
      ),
      scheduledDays: topic.intervalDays,
      metadata: <String, Object?>{
        'first_interval_days': topic.intervalDays,
        'pressure': pressure,
      },
    );
  }

  /// Wraps a command body in a transaction, idempotency check, and tracing.
  /// Replaces one block's markdown.
  ///
  /// Editing text is not a repetition. Nothing here reads or writes a
  /// schedule, a priority, a revlog entry, or a scheduler event, and the
  /// source's due date is exactly where it was before.
  Future<Result<SourceEdited>> editSourceBlock(EditSourceBlock command) =>
      _runEdit(command, kSourceEditedKind, (Document document) {
        final Block? block = document.blockById(command.blockId);
        if (block == null) return null;
        return spliceForBlockEdit(document, block, command.markdown);
      }, sourceId: command.sourceId, base: command.baseContentRevision);

  /// Removes one block, separator included.
  Future<Result<SourceEdited>> deleteSourceBlock(DeleteSourceBlock command) =>
      _runEdit(command, kSourceEditedKind, (Document document) {
        final Block? block = document.blockById(command.blockId);
        if (block == null) return null;
        return spliceForBlockRemoval(document, block);
      }, sourceId: command.sourceId, base: command.baseContentRevision);

  /// Adds a new block after an existing one.
  Future<Result<SourceEdited>> insertSourceBlock(InsertSourceBlock command) =>
      _runEdit(command, kSourceEditedKind, (Document document) {
        final Block? block = document.blockById(command.afterBlockId);
        if (block == null) return null;
        return spliceForBlockInsertion(document, block, command.markdown);
      }, sourceId: command.sourceId, base: command.baseContentRevision);

  /// Reverses the most recent edit, as a new forward edit.
  Future<Result<SourceEdited>> undoSourceEdit(UndoSourceEdit command) async {
    final SourceEdit? last = await _content.findLatestSourceEdit(command.sourceId);
    if (last == null) {
      return const Err<SourceEdited>(
        ConflictFailure('there is nothing to undo on this source'),
      );
    }
    return _runEdit(
      command,
      kSourceEditUndoneKind,
      (Document _) => last.inverseSplice,
      sourceId: command.sourceId,
      base: last.contentRevision,
      isUndo: true,
      restore: last.restore,
    );
  }

  /// Shared body for every text edit.
  ///
  /// [buildSplice] receives the document as currently stored and returns the
  /// splice to apply, or null when the block it names is gone. Everything
  /// after that — validation, migration of positions and provenance, the
  /// journal row, the block rebuild — happens inside the repository's single
  /// transaction, so a crash leaves the previous revision wholly intact.
  Future<Result<SourceEdited>> _runEdit(
    AppCommand command,
    String kind,
    TextSplice? Function(Document document) buildSplice, {
    required String sourceId,
    required int base,
    bool isUndo = false,
    SourceEditRestore? restore,
  }) async {
    try {
      return await _transactions.run<Result<SourceEdited>>(() async {
        final Document? document = await _content.findDocument(sourceId);
        if (document == null) return _missingSource<SourceEdited>(sourceId);

        final TextSplice? splice = buildSplice(document);
        if (splice == null) {
          return const Err<SourceEdited>(
            ValidationFailure('that block is not part of this source'),
          );
        }
        if (splice.isNoop || splice.changesNothingIn(document.markdown)) {
          // Nothing changed. Reporting success without writing keeps the
          // revision counter meaningful: it counts real edits, and replaying
          // the journal has to land exactly where eager migration did.
          final Source? unchanged = await _content.findSource(sourceId);
          if (unchanged == null) return _missingSource<SourceEdited>(sourceId);
          return Ok<SourceEdited>(
            SourceEdited(
              source: unchanged,
              document: document,
              outcome: null,
            ),
          );
        }

        final SourceEditResult applied = await _content.applySourceEdit(
          sourceId: sourceId,
          splice: splice,
          baseContentRevision: base,
          operationId: command.operationId.value,
          nowUtc: _clock.nowUtc(),
          isUndo: isUndo,
          restore: restore,
        );

        switch (applied) {
          case SourceEditTargetMissing():
            return _missingSource<SourceEdited>(sourceId);

          case SourceEditConflict(:final actualRevision):
            return Err<SourceEdited>(
              ConflictFailure(
                'this source changed while you were editing '
                '(now at revision $actualRevision)',
              ),
            );

          case SourceEditRejected(:final reason):
            return Err<SourceEdited>(
              ValidationFailure(_rejectionMessage(reason)),
            );

          case SourceEditReplayed(:final source):
            final Document? current = await _content.findDocument(sourceId);
            return Ok<SourceEdited>(
              SourceEdited(
                source: source,
                document: current ?? document,
                outcome: null,
              ),
            );

          case SourceEditApplied(:final source, :final outcome):
            final Document? next = await _content.findDocument(sourceId);
            await _search.saveDocument(
              SearchDocument(
                ref: ElementRef(id: sourceId, type: ElementType.source),
                title: source.title,
                body: source.markdown,
                sourceId: sourceId,
                updatedAtUtc: _clock.nowUtc(),
              ),
            );
            await _transfer.advanceGeneration();
            await _log(
              command,
              kind,
              ref: ElementRef(id: sourceId, type: ElementType.source),
              metadata: <String, Object?>{
                'revision': outcome.contentRevision,
                'removed': splice.removedLength,
                'inserted': splice.insertedLength,
                'marker_displaced': outcome.markerWasInsideEdit,
                'provenance_changed': outcome.changedProvenance.length,
                'stale': outcome.provenanceUpdates
                    .where(
                      (ProvenanceUpdate update) =>
                          update.provenance.state == ProvenanceState.stale,
                    )
                    .length,
                'orphaned': outcome.provenanceUpdates
                    .where(
                      (ProvenanceUpdate update) =>
                          update.provenance.state == ProvenanceState.orphaned,
                    )
                    .length,
              },
            );
            return Ok<SourceEdited>(
              SourceEdited(
                source: source,
                document:
                    next ??
                    Document.parse(
                      sourceId: sourceId,
                      markdown: source.markdown,
                      contentRevision: source.contentRevision,
                    ),
                outcome: outcome,
              ),
            );
        }
      });
    } on Object catch (error, stackTrace) {
      final UnexpectedFailure failure = UnexpectedFailure(
        'command $kind failed',
        cause: error,
        stackTrace: stackTrace,
      );
      _diagnostics.record(
        DiagnosticEvent(
          level: DiagnosticLevel.error,
          name: kind,
          timestampUtc: _clock.nowUtc(),
          operationId: command.operationId,
          failure: failure,
        ),
      );
      return Err<SourceEdited>(failure);
    }
  }

  static String _rejectionMessage(SpliceRejection reason) => switch (reason) {
    SpliceRejection.outOfRange => 'that edit is outside the source text',
    SpliceRejection.notOnCharacterBoundary =>
      'that edit would split a character',
    SpliceRejection.tooLarge => 'that edit is too large to apply at once',
    SpliceRejection.empty => 'that edit changes nothing',
  };

  Future<Result<T>> _run<T>(
    AppCommand command,
    String kind,
    Future<Result<T>> Function() body,
  ) async {
    try {
      return await _transactions.run<Result<T>>(() async {
        if (await _learning.hasActivity(command.operationId.value, kind)) {
          final ElementRef? topicRef = switch (command) {
            CompleteTopicEncounter(:final ref) ||
            PostponeElement(:final ref) ||
            RescheduleTopic(:final ref) ||
            DismissElement(:final ref) ||
            UndismissSource(:final ref) => ref,
            DeleteSource(:final sourceId) => ElementRef(
              id: sourceId,
              type: ElementType.source,
            ),
            _ => null,
          };
          if (topicRef != null) {
            final TopicState? replayed = await _learning.findTopic(topicRef);
            if (replayed is T) return Ok<T>(replayed as T);
          }
          return Err<T>(
            ConflictFailure('operation ${command.operationId} already applied'),
          );
        }
        final Result<T> result = await body();
        if (result.isOk) {
          // One generation bump per successful domain transaction, so a copy
          // of the dataset can always be placed relative to another.
          await _transfer.advanceGeneration();
        }
        _record(command, kind, result);
        return result;
      });
    } on Object catch (error, stackTrace) {
      final UnexpectedFailure failure = UnexpectedFailure(
        'command $kind failed',
        cause: error,
        stackTrace: stackTrace,
      );
      _diagnostics.record(
        DiagnosticEvent(
          level: DiagnosticLevel.error,
          name: kind,
          timestampUtc: _clock.nowUtc(),
          operationId: command.operationId,
          failure: failure,
        ),
      );
      return Err<T>(failure);
    }
  }

  String _topicStateJson(TopicState state) => jsonEncode(<String, Object?>{
    'element_id': state.ref.id,
    'element_type': state.ref.type.index,
    'priority_key': state.schedule.priority.orderKey,
    'lifecycle': state.schedule.lifecycle.index,
    'due_day': state.schedule.algorithmicDueDay.epochDay,
    'original_due_day': state.schedule.originalDueDay.epochDay,
    'zone_id': state.schedule.algorithmicDueDay.zoneId,
    'root_id': state.schedule.rootId,
    'parent_element_id': state.schedule.parentElementId,
    'ordinal': state.schedule.ordinal,
    'created_at_utc': state.schedule.createdAtUtc?.millisecondsSinceEpoch,
    'updated_at_utc': state.schedule.updatedAtUtc?.millisecondsSinceEpoch,
    'schedule_revision': state.schedule.revision,
    'legacy_due_provenance': state.schedule.legacyDueProvenance.index,
    'status': state.status.index,
    'repetition_count': state.repetitionCount,
    'lapse_count': state.lapseCount,
    'stored_interval': state.storedInterval,
    'a_factor_raw': state.aFactorRaw.toString(),
    'last_interval_ratio_raw': state.lastIntervalRatioRaw.toString(),
    'history_block_id': state.historyBlockId,
    'recent_postponement_count': state.recentPostponementCount,
    'total_postponement_count': state.totalPostponementCount,
    'learning_control': state.learningControl,
    'encounters_since_last_card': state.encountersSinceLastCard,
    'last_review_day': state.lastReviewDay?.epochDay,
    'topic_revision': state.revision,
  });

  Future<void> _log(
    AppCommand command,
    String kind, {
    ElementRef? ref,
    int? durationMs,
    Map<String, Object?>? metadata,
  }) => _learning.appendActivity(
    ActivityRecord(
      id: _ids.newId(),
      operationId: command.operationId.value,
      kind: kind,
      atUtc: command.timestampUtc,
      ref: ref,
      durationMs: durationMs,
      metadata: metadata,
    ),
  );

  void _record<T>(AppCommand command, String kind, Result<T> result) {
    _diagnostics.record(
      DiagnosticEvent(
        level: result.isOk ? DiagnosticLevel.info : DiagnosticLevel.warning,
        name: kind,
        timestampUtc: _clock.nowUtc(),
        operationId: command.operationId,
        fields: <String, Object?>{'ok': result.isOk},
        failure: result.failureOrNull,
      ),
    );
  }

  Map<String, Object?>? _metadataFor(TopicEvent event) => switch (event) {
    TopicRepetitionCommitted(
      :final oldInterval,
      :final selectedInterval,
      :final storedInterval,
      :final nextDueDay,
      :final oldAFactor,
      :final newAFactor,
      :final priorityBefore,
      :final priorityAfter,
      :final isBulkOperation,
      :final randomDraws,
    ) =>
      <String, Object?>{
        'old_interval': oldInterval,
        'selected_interval': selectedInterval,
        'stored_interval': storedInterval,
        'next_due': nextDueDay.toString(),
        'a_before': oldAFactor,
        'a_after': newAFactor,
        'priority_before': priorityBefore,
        'priority_after': priorityAfter,
        'bulk': isBulkOperation,
        'random_draws': randomDraws,
      },
    TopicRescheduled(
      :final oldInterval,
      :final newInterval,
      :final targetDay,
    ) =>
      <String, Object?>{
        'old_interval': oldInterval,
        'new_interval': newInterval,
        'target_day': targetDay.toString(),
      },
    TopicLifecycleChanged(:final from, :final to) => <String, Object?>{
      'from': from.name,
      'to': to.name,
    },
  };

  Err<T> _missingSource<T>(String id) =>
      Err<T>(NotFoundFailure('no such source', entity: 'source', id: id));

  Err<T> _missingSchedule<T>(String id) => Err<T>(
    NotFoundFailure('no schedule for that element', entity: 'schedule', id: id),
  );
}
