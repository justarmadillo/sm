/// Handlers for every Reader and Library mutation.
///
/// One handler owns validation, transaction scope, domain invocation,
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

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../core/result.dart';
import '../../core/tracing.dart';
import '../../domain/content/document.dart';
import '../../domain/content/extract.dart';
import '../../domain/content/reader_anchor.dart';
import '../../domain/content/source.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/overload.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/revlog.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../app_command.dart';
import '../ports/repositories.dart';
import '../ports/transaction_runner.dart';
import '../scheduling/scheduling_context.dart';
import '../scheduling/scheduling_journal.dart';
import 'reader_commands.dart';

/// Activity kind recorded when a source is imported.
const String kSourceImportedKind = 'source.imported';

/// Activity kind recorded when the resume marker moves.
const String kMarkerMovedKind = 'reader.marker_moved';

/// Activity kind recorded when a topic's interval is set by hand.
const String kTopicRescheduledKind = 'topic.rescheduled';

/// Handlers for reading, marking, and pacing sources.
final class ReaderHandlers {
  ReaderHandlers({
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
  Future<Result<Source>> importSource(ImportSource command) =>
      _run<Source>(command, kSourceImportedKind, () async {
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
          pace: command.pace,
          folderId: command.folderId,
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
        final ElementRef ref = ElementRef(
          id: source.id,
          type: ElementType.source,
        );
        final TopicScheduler scheduler = await _context.topicScheduler();
        final TopicState topic = scheduler.createFor(
          ref: ref,
          profileId: command.pace.name,
          today: day,
          pressure: pressure,
          buildSchedule: (StudyDay due) => ElementSchedule(
            ref: ref,
            priority: rank,
            lifecycle: ElementLifecycle.active,
            dueDay: due,
            originalDueDay: due,
            rootId: source.id,
          ),
        );

        await _content.insertSource(source, document);
        await _learning.insertTopic(topic);
        await _search.upsertDocument(
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
            'pace': command.pace.name,
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

        final Source? updated = await _content.setResumeMarker(
          source.id,
          command.anchor,
        );
        if (updated == null) return _missingSource<Source>(command.sourceId);
        await _log(
          command,
          kMarkerMovedKind,
          ref: ElementRef(id: source.id, type: ElementType.source),
          metadata: <String, Object?>{'block': command.anchor.blockId},
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
    final Source? updated = await _content.setSoftPosition(
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
  ) => _run<TopicState>(command, 'topic.encounter_completed', () async {
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
      pressure: pressure,
    );
    if (!transition.isChange) {
      // The domain refused: the element is already finished, dismissed, or
      // suspended. Not an error, and nothing to write.
      return Ok<TopicState>(transition.state);
    }

    final StudyDayCalendar calendar = await _context.calendar();
    await _learning.saveTopic(transition.state);
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
          if (event is TopicEncounterCompleted) ...<String, Object?>{
            'interval_days': event.intervalDays,
            'exact_interval_days': event.exactIntervalDays,
            'next_due': event.nextDueDay.toString(),
            ...?event.aFactor?.toMetadata(),
          },
          if (event is TopicLifecycleChanged) ...<String, Object?>{
            'from': event.from.name,
            'to': event.to.name,
            'automatic': event.automatic,
          },
          'words_read': encounter.wordsRead,
          'extracts_created': encounter.extractsCreated,
          'has_child_items': encounter.hasChildItems,
        },
      );
      await _log(
        command,
        event.kind,
        ref: command.ref,
        durationMs: command.foregroundMs,
        metadata: _metadataFor(event),
      );
    }
    return Ok<TopicState>(transition.state);
  });

  /// Later: moves eligibility without growing anything.
  ///
  /// When no target day is given the delay scales with the element's own
  /// interval. A fixed one day would simply return the element tomorrow into
  /// an equally full queue, which is why it is not the default.
  Future<Result<TopicState>> postpone(PostponeElement command) =>
      _run<TopicState>(command, 'topic.postponed', () async {
        final TopicState? topic = await _learning.findTopic(command.ref);
        if (topic == null) return _missingSchedule<TopicState>(command.ref.id);

        final StudyDay day = await today();
        final TopicScheduler scheduler = await _context.topicScheduler();
        final StudyDayCalendar calendar = await _context.calendar();

        StudyDay until;
        PostponeDecision? decision;
        if (command.until != null) {
          until = command.until!;
        } else {
          final OverloadValve valve = await _context.overloadValve();
          decision = valve.later(
            intervalDays: topic.intervalDays,
            seed: '${command.operationId.value}:${command.ref}',
          );
          until = day.addDays(decision.delayDays);
        }

        final TopicTransition transition = scheduler.postpone(
          topic,
          until: until,
          kind: command.kind,
        );
        if (!transition.isChange) return Ok<TopicState>(transition.state);

        await _learning.saveTopic(transition.state);
        await _journal.append(
          operationId: command.operationId.value,
          ref: command.ref,
          eventType: command.kind == DeferralKind.automatic
              ? RevlogEventType.autoPostpone
              : RevlogEventType.postpone,
          atUtc: command.timestampUtc,
          before: _journal.topicSnapshot(topic, calendar: calendar),
          after: _journal.topicSnapshot(transition.state, calendar: calendar),
          scheduledDays: topic.intervalDays,
          postponeCount: transition.state.postponeCount,
          metadata: <String, Object?>{
            'until': until.toString(),
            'kind': command.kind.name,
            if (decision != null) ...decision.toMetadata(),
          },
        );
        for (final TopicEvent event in transition.events) {
          await _log(
            command,
            event.kind,
            ref: command.ref,
            metadata: _metadataFor(event),
          );
        }
        return Ok<TopicState>(transition.state);
      });

  /// Sets a topic's interval by hand.
  ///
  /// SuperMemo treats this as a priority signal — asking to see something in
  /// eleven days rather than thirty says it matters more — but the priority
  /// change stays a separate, visible command rather than a hidden side
  /// effect, so the user is never surprised by their collection reordering.
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
        final TopicScheduler scheduler = await _context.topicScheduler();
        final StudyDayCalendar calendar = await _context.calendar();
        final TopicTransition transition = scheduler.reschedule(
          topic,
          today: day,
          intervalDays: command.intervalDays,
        );
        if (!transition.isChange) return Ok<TopicState>(transition.state);

        await _learning.saveTopic(transition.state);
        await _journal.append(
          operationId: command.operationId.value,
          ref: command.ref,
          eventType: RevlogEventType.manualReschedule,
          atUtc: command.timestampUtc,
          before: _journal.topicSnapshot(topic, calendar: calendar),
          after: _journal.topicSnapshot(transition.state, calendar: calendar),
          scheduledDays: topic.intervalDays,
          metadata: <String, Object?>{'interval_days': command.intervalDays},
        );
        await _log(
          command,
          kTopicRescheduledKind,
          ref: command.ref,
          metadata: <String, Object?>{'interval_days': command.intervalDays},
        );
        return Ok<TopicState>(transition.state);
      });

  /// Declares a source finished.
  Future<Result<TopicState>> finishSource(FinishSource command) => _lifecycle(
    command,
    ElementRef(id: command.sourceId, type: ElementType.source),
    'topic.finished',
    RevlogEventType.finish,
    (TopicScheduler s, TopicState t, StudyDay _) => s.finish(t),
  );

  /// Keeps content, stops scheduling.
  Future<Result<TopicState>> dismiss(DismissElement command) => _lifecycle(
    command,
    command.ref,
    'topic.dismissed',
    RevlogEventType.dismiss,
    (TopicScheduler s, TopicState t, StudyDay _) => s.dismiss(t),
  );

  /// Temporary removal from the queue.
  Future<Result<TopicState>> suspend(SuspendElement command) => _lifecycle(
    command,
    command.ref,
    'topic.suspended',
    RevlogEventType.suspend,
    (TopicScheduler s, TopicState t, StudyDay _) => s.suspend(t),
  );

  /// Returns an element to the queue, due today, at its existing interval.
  Future<Result<TopicState>> reactivate(ReactivateElement command) =>
      _lifecycle(
        command,
        command.ref,
        'topic.reactivated',
        RevlogEventType.resume,
        (TopicScheduler s, TopicState t, StudyDay day) =>
            t.schedule.lifecycle == ElementLifecycle.suspended
            ? s.resume(t, day)
            : s.reactivate(t, day),
      );

  /// Soft-deletes a source without touching content or descendant schedules.
  Future<Result<TopicState>> deleteSource(DeleteSource command) => _lifecycle(
    command,
    ElementRef(id: command.sourceId, type: ElementType.source),
    'source.deleted',
    RevlogEventType.dismiss,
    (TopicScheduler s, TopicState t, StudyDay _) => s.delete(t),
  );

  /// Changes a source's pacing profile without touching position or interval.
  Future<Result<Source>> setReadingPace(SetReadingPace command) =>
      _run<Source>(command, 'source.pace_set', () async {
        final Source? source = await _content.findSource(command.sourceId);
        if (source == null) return _missingSource<Source>(command.sourceId);
        final ElementRef ref = ElementRef(
          id: source.id,
          type: ElementType.source,
        );
        final TopicState? topic = await _learning.findTopic(ref);
        if (topic == null) return _missingSchedule<Source>(command.sourceId);

        final Source updated = source.copyWith(pace: command.pace);
        await _content.updateSource(updated);
        // The interval and the position survive: changing pace changes future
        // intervals, it does not restart a half-processed source.
        await _learning.saveTopic(topic.copyWith(profileId: command.pace.name));
        await _log(
          command,
          'source.pace_set',
          ref: ref,
          metadata: <String, Object?>{'pace': command.pace.name},
        );
        return Ok<Source>(updated);
      });

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
        await _search.upsertDocument(
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
    final ReaderAnchor? start = document.startAnchor;
    final ReaderAnchor? end = document.endAnchor;
    double? readFraction;
    var reachedEnd = false;
    if (marker != null && start != null && end != null) {
      final int total = document.wordsBetween(start, end);
      final int read = document.wordsBetween(start, marker);
      readFraction = total <= 0 ? 1 : (read / total).clamp(0, 1);
      reachedEnd = !document.isBefore(marker, end);
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
        if (extract.provenance.parentIsSource &&
            extract.provenance.parentId == source.id)
          (extract.provenance.startAnchor, extract.provenance.endAnchor),
    ]);

    return TopicEncounter(
      readFraction: readFraction,
      wordsRead: command.wordsRead,
      extractsCreated: command.extractsCreated,
      reachedEnd: reachedEnd,
      unprocessedTextRemains: uncovered > 0,
    );
  }

  Future<Result<TopicState>> _lifecycle(
    AppCommand command,
    ElementRef ref,
    String kind,
    RevlogEventType eventType,
    TopicTransition Function(TopicScheduler, TopicState, StudyDay) transition,
  ) => _run<TopicState>(command, kind, () async {
    final TopicState? topic = await _learning.findTopic(ref);
    if (topic == null) return _missingSchedule<TopicState>(ref.id);

    final StudyDay day = await today();
    final TopicScheduler scheduler = await _context.topicScheduler();
    final TopicTransition result = transition(scheduler, topic, day);
    if (!result.isChange) return Ok<TopicState>(result.state);

    final StudyDayCalendar calendar = await _context.calendar();
    await _learning.saveTopic(result.state);
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
  Future<Result<T>> _run<T>(
    AppCommand command,
    String kind,
    Future<Result<T>> Function() body,
  ) async {
    try {
      return await _transactions.run<Result<T>>(() async {
        if (await _learning.hasActivity(command.operationId.value, kind)) {
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
    TopicEncounterCompleted(
      :final fromStep,
      :final toStep,
      :final intervalDays,
      :final nextDueDay,
      :final aFactor,
    ) =>
      <String, Object?>{
        'from_step': fromStep,
        'to_step': toStep,
        'interval_days': intervalDays,
        'next_due': nextDueDay.toString(),
        if (aFactor != null) 'a_factor': aFactor.value,
      },
    TopicPostponed(:final until, :final deferralKind) => <String, Object?>{
      'until': until.toString(),
      'kind': deferralKind.name,
    },
    TopicLifecycleChanged(:final from, :final to, :final automatic) =>
      <String, Object?>{
        'from': from.name,
        'to': to.name,
        if (automatic) 'automatic': true,
      },
  };

  Err<T> _missingSource<T>(String id) =>
      Err<T>(NotFoundFailure('no such source', entity: 'source', id: id));

  Err<T> _missingSchedule<T>(String id) => Err<T>(
    NotFoundFailure('no schedule for that element', entity: 'schedule', id: id),
  );
}
