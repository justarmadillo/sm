/// Handlers for every Reader and Library mutation.
///
/// One handler owns validation, transaction scope, domain invocation,
/// persistence, and the activity event — in that order, for every command.
/// Nothing above this layer knows about intervals or lifecycles, and nothing
/// below it decides policy.
///
/// Two rules the whole M1 gate rests on:
///
/// * Only completing an encounter or postponing touches a schedule. Moving the
///   marker, saving a soft position, renaming, or reading to the end do not,
///   because interruption must never be recorded as progress.
/// * Terminal commands are exactly-once. The activity log is consulted for the
///   command's operation id before the domain is invoked, so a retry after a
///   crash, a double click, or a queue that advances twice commits once.
library;

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../core/result.dart';
import '../../core/tracing.dart';
import '../../domain/content/document.dart';
import '../../domain/content/source.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/interval_profile.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../app_command.dart';
import '../ports/repositories.dart';
import '../ports/transaction_runner.dart';
import 'reader_commands.dart';

/// Activity kind recorded when a source is imported.
const String kSourceImportedKind = 'source.imported';

/// Activity kind recorded when the resume marker moves.
const String kMarkerMovedKind = 'reader.marker_moved';

/// Handlers for reading, marking, and pacing sources.
final class ReaderHandlers {
  ReaderHandlers({
    required ContentRepository content,
    required LearningRepository learning,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required Clock clock,
    required IdGenerator ids,
    required StudyDayCalendar calendar,
    required IntervalProfiles profiles,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _content = content,
       _learning = learning,
       _transfer = transfer,
       _transactions = transactions,
       _clock = clock,
       _ids = ids,
       _calendar = calendar,
       _scheduler = TopicScheduler(profiles),
       _diagnostics = diagnostics;

  final ContentRepository _content;
  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final Clock _clock;
  final IdGenerator _ids;
  final StudyDayCalendar _calendar;
  final TopicScheduler _scheduler;
  final DiagnosticSink _diagnostics;

  /// The study day the clock currently falls in.
  StudyDay get today => _calendar.dayOf(_clock.nowUtc());

  /// Imports markdown as a new source, due today.
  Future<Result<Source>> importSource(ImportSource command) => _run<Source>(
    command,
    kSourceImportedKind,
    () async {
      final markdown = command.markdown.trim();
      if (markdown.isEmpty) {
        return const Err<Source>(
          ValidationFailure('a source needs some markdown', field: 'markdown'),
        );
      }
      final title = command.title.trim();
      if (title.isEmpty) {
        return const Err<Source>(
          ValidationFailure('a source needs a title', field: 'title'),
        );
      }

      final source = Source.import(
        id: _ids.newId(),
        title: title,
        markdown: markdown,
        importedAtUtc: _clock.nowUtc(),
        pace: command.pace,
        folderId: command.folderId,
      );
      final document = Document.parse(
        sourceId: source.id,
        markdown: source.markdown,
      );
      if (document.isEmpty) {
        return const Err<Source>(
          ValidationFailure('that markdown produced no readable blocks'),
        );
      }

      final ref = ElementRef(id: source.id, type: ElementType.source);
      final topic = _scheduler.createFor(
        ref: ref,
        profileId: command.pace.name,
        today: today,
        buildSchedule: (StudyDay due) => ElementSchedule(
          ref: ref,
          // New root elements start in the middle: the user has not said
          // anything about importance yet, and pretending otherwise would
          // bury or promote it for no reason.
          priority: PriorityRank.middle,
          lifecycle: ElementLifecycle.active,
          dueDay: due,
          originalDueDay: due,
        ),
      );

      await _content.insertSource(source, document);
      await _learning.insertTopic(topic);
      await _log(
        command,
        kSourceImportedKind,
        ref: ref,
        metadata: <String, Object?>{
          'words': source.wordCount,
          'blocks': document.blocks.length,
          'pace': command.pace.name,
        },
      );
      return Ok<Source>(source);
    },
  );

  /// Places the authoritative resume marker. Never advances the schedule.
  Future<Result<Source>> moveResumeMarker(MoveResumeMarker command) =>
      _run<Source>(command, kMarkerMovedKind, () async {
        final source = await _content.findSource(command.sourceId);
        if (source == null) return _missingSource<Source>(command.sourceId);

        final document = await _content.findDocument(command.sourceId);
        if (document == null || !document.containsAnchor(command.anchor)) {
          return const Err<Source>(
            ValidationFailure('that anchor does not belong to this source'),
          );
        }

        final updated = await _content.setResumeMarker(
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
  /// Written often and cheaply, outside the activity log: it is not an event,
  /// it is a scratch value that the next scroll overwrites.
  Future<Result<Source>> saveSoftPosition(SaveSoftPosition command) async {
    final source = await _content.findSource(command.sourceId);
    if (source == null) return _missingSource<Source>(command.sourceId);
    final document = await _content.findDocument(command.sourceId);
    if (document == null || !document.containsAnchor(command.anchor)) {
      return const Err<Source>(
        ValidationFailure('that anchor does not belong to this source'),
      );
    }
    if (source.resume.softPosition == command.anchor) {
      return Ok<Source>(source);
    }
    final updated = await _content.setSoftPosition(source.id, command.anchor);
    if (updated == null) return _missingSource<Source>(command.sourceId);
    return Ok<Source>(updated);
  }

  /// Promotes the soft position to the authoritative marker.
  Future<Result<Source>> confirmSoftPosition(ConfirmSoftPosition command) =>
      _run<Source>(command, kMarkerMovedKind, () async {
        final source = await _content.findSource(command.sourceId);
        if (source == null) return _missingSource<Source>(command.sourceId);
        if (source.resume.softPosition == null) {
          return const Err<Source>(
            ConflictFailure('there is no soft position to confirm'),
          );
        }
        final updated = await _content.confirmSoftPosition(source.id);
        if (updated == null) return _missingSource<Source>(command.sourceId);
        await _log(
          command,
          kMarkerMovedKind,
          ref: ElementRef(id: source.id, type: ElementType.source),
          metadata: <String, Object?>{'from': 'soft_position'},
        );
        return Ok<Source>(updated);
      });

  /// Done: advances the topic's schedule exactly once.
  Future<Result<TopicState>> completeEncounter(
    CompleteTopicEncounter command,
  ) => _runTopic(
    command,
    command.ref,
    'topic.encounter_completed',
    (TopicState topic) => _scheduler.complete(topic, today),
    durationMs: command.foregroundMs,
  );

  /// Later: moves eligibility without advancing anything.
  Future<Result<TopicState>> postpone(PostponeElement command) => _runTopic(
    command,
    command.ref,
    'topic.postponed',
    (TopicState topic) =>
        _scheduler.postpone(topic, until: command.until, kind: command.kind),
  );

  /// Declares a source finished.
  Future<Result<TopicState>> finishSource(FinishSource command) => _runTopic(
    command,
    ElementRef(id: command.sourceId, type: ElementType.source),
    'topic.finished',
    _scheduler.finish,
  );

  /// Keeps content, stops scheduling.
  Future<Result<TopicState>> dismiss(DismissElement command) =>
      _runTopic(command, command.ref, 'topic.dismissed', _scheduler.dismiss);

  /// Temporary removal from the queue.
  Future<Result<TopicState>> suspend(SuspendElement command) =>
      _runTopic(command, command.ref, 'topic.suspended', _scheduler.suspend);

  /// Returns an element to the queue, due today, at its existing step.
  Future<Result<TopicState>> reactivate(ReactivateElement command) => _runTopic(
    command,
    command.ref,
    'topic.reactivated',
    (TopicState topic) => topic.schedule.lifecycle == ElementLifecycle.suspended
        ? _scheduler.resume(topic, today)
        : _scheduler.reactivate(topic, today),
  );

  /// Changes relative priority. Ordering only; never pulls work forward.
  Future<Result<ElementSchedule>> setPriority(SetPriority command) =>
      _run<ElementSchedule>(command, 'element.priority_set', () async {
        final schedule = await _learning.findSchedule(command.ref);
        if (schedule == null) {
          return Err<ElementSchedule>(
            NotFoundFailure(
              'no schedule for that element',
              entity: 'schedule',
              id: command.ref.id,
            ),
          );
        }
        final updated = schedule.copyWith(priority: command.rank);
        await _learning.saveSchedule(updated);
        await _log(
          command,
          'element.priority_set',
          ref: command.ref,
          metadata: <String, Object?>{'key': command.rank.orderKey},
        );
        return Ok<ElementSchedule>(updated);
      });

  /// Changes a source's pacing profile without touching position or step.
  Future<Result<Source>> setReadingPace(SetReadingPace command) =>
      _run<Source>(command, 'source.pace_set', () async {
        final source = await _content.findSource(command.sourceId);
        if (source == null) return _missingSource<Source>(command.sourceId);
        final ref = ElementRef(id: source.id, type: ElementType.source);
        final topic = await _learning.findTopic(ref);
        if (topic == null) {
          return _missingSchedule<Source>(command.sourceId);
        }

        final updated = source.copyWith(pace: command.pace);
        await _content.updateSource(updated);
        // The step index survives: changing pace changes future intervals, it
        // does not restart the reading of a half-processed source.
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
        final title = command.title.trim();
        if (title.isEmpty) {
          return const Err<Source>(
            ValidationFailure('a source needs a title', field: 'title'),
          );
        }
        final source = await _content.findSource(command.sourceId);
        if (source == null) return _missingSource<Source>(command.sourceId);
        final updated = source.copyWith(title: title);
        await _content.updateSource(updated);
        await _log(
          command,
          'source.renamed',
          ref: ElementRef(id: source.id, type: ElementType.source),
        );
        return Ok<Source>(updated);
      });

  /// Soft-deletes a source without touching content or descendant schedules.
  Future<Result<TopicState>> deleteSource(DeleteSource command) {
    final ref = ElementRef(id: command.sourceId, type: ElementType.source);
    return _runTopic(command, ref, 'source.deleted', _scheduler.delete);
  }

  /// Runs a topic transition through the scheduler, exactly once.
  Future<Result<TopicState>> _runTopic(
    AppCommand command,
    ElementRef ref,
    String kind,
    TopicTransition Function(TopicState topic) transition, {
    int? durationMs,
  }) => _run<TopicState>(command, kind, () async {
    final topic = await _learning.findTopic(ref);
    if (topic == null) return _missingSchedule<TopicState>(ref.id);

    final result = transition(topic);
    if (!result.isChange) {
      // The domain refused: the element is already in that state, or is
      // not schedulable. Not an error, and nothing to write.
      return Ok<TopicState>(result.state);
    }

    await _learning.saveTopic(result.state);
    for (final event in result.events) {
      await _log(
        command,
        event.kind,
        ref: ref,
        durationMs: durationMs,
        metadata: _metadataFor(event),
      );
    }
    return Ok<TopicState>(result.state);
  });

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
        final result = await body();
        if (result.isOk) {
          // One generation bump per successful domain transaction, so a copy
          // of the dataset can always be placed relative to another.
          await _transfer.advanceGeneration();
        }
        _record(command, kind, result);
        return result;
      });
    } on Object catch (error, stackTrace) {
      final failure = UnexpectedFailure(
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
    ) =>
      <String, Object?>{
        'from_step': fromStep,
        'to_step': toStep,
        'interval_days': intervalDays,
        'next_due': nextDueDay.toString(),
      },
    TopicPostponed(:final until, :final deferralKind) => <String, Object?>{
      'until': until.toString(),
      'kind': deferralKind.name,
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
