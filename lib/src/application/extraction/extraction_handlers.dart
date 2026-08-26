/// Handlers for extraction.
///
/// The invariants this file enforces, in order of how easy they are to break:
///
/// * **The parent content and reading position are never modified.** SM20 does
///   intentionally adapt the source A and priority when an extract is made.
/// * **The selection is verified before it is stored.** The command carries a
///   hash of exactly what the user selected, and it is checked against the
///   parent's own markdown. A mismatch is refused rather than silently
///   recording provenance that points at different text.
/// * **The new extract is independent from creation.** Its own schedule, its
///   own lifecycle. Finishing, dismissing, or deleting the parent later
///   changes nothing about it.
library;

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../core/result.dart';
import '../../core/tracing.dart';
import '../../domain/content/document.dart';
import '../../domain/content/extract.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/revlog.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../app_command.dart';
import '../ports/repositories.dart';
import '../ports/transaction_runner.dart';
import '../scheduling/scheduling_context.dart';
import '../scheduling/scheduling_journal.dart';
import 'extraction_commands.dart';

/// Activity kind recorded when an extract is created.
const String kExtractCreatedKind = 'extract.created';

/// Activity kind recorded when an extract is undone.
const String kExtractUndoneKind = 'extract.undone';

/// Handlers for creating, undoing, and editing extracts.
final class ExtractionHandlers {
  ExtractionHandlers({
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

  /// Creates an extract from a verified selection, in one transaction.
  Future<Result<Extract>> createExtract(CreateExtract command) => _run<Extract>(
    command,
    kExtractCreatedKind,
    () async {
      final parent = await _resolveParent(
        command.parentId,
        command.parentIsSource,
      );
      if (parent == null) {
        return Err<Extract>(
          NotFoundFailure(
            'no such parent',
            entity: command.parentIsSource ? 'source' : 'extract',
            id: command.parentId,
          ),
        );
      }

      if (!command.range.isSameBlock) {
        return const Err<Extract>(
          ValidationFailure(
            'Multi-block extraction arrives in M5; select within one block',
          ),
        );
      }
      if (!parent.document.containsAnchor(command.range.startAnchor) ||
          !parent.document.containsAnchor(command.range.endAnchor) ||
          !parent.document.isBefore(
            command.range.startAnchor,
            command.range.endAnchor,
          )) {
        return const Err<Extract>(
          ValidationFailure('that selection has invalid source coordinates'),
        );
      }

      final selectedSource = parent.document.markdownForRange(command.range);
      if (selectedSource.trim().isEmpty) {
        return const Err<Extract>(ValidationFailure('that selection is empty'));
      }
      if (!command.range.matches(selectedSource)) {
        // The parent's text no longer produces what was selected. Recording
        // provenance anyway would create a reference to text that does not
        // exist, which is worse than refusing.
        return const Err<Extract>(
          ConflictFailure('the selection no longer matches the source text'),
        );
      }
      final markdown = parent.document.markdownFragmentForRange(command.range);
      if (markdown.trim().isEmpty) {
        return const Err<Extract>(
          ValidationFailure('that selection cannot be rendered independently'),
        );
      }

      final parentSchedule = await _learning.findSchedule(parent.ref);
      if (parentSchedule == null) {
        return _missingSchedule<Extract>(command.parentId);
      }

      final extract = Extract(
        id: _ids.newId(),
        markdown: markdown,
        provenance: Provenance(
          sourceId: parent.rootSourceId,
          parentId: command.parentId,
          parentIsSource: command.parentIsSource,
          startAnchor: command.range.startAnchor,
          endAnchor: command.range.endAnchor,
          selectedTextHash: command.range.selectedTextHash,
        ),
        createdAtUtc: _clock.nowUtc(),
      );

      final ref = ElementRef(id: extract.id, type: ElementType.extract);
      final StudyDay day = await today();
      final TopicScheduler scheduler = await _context.topicScheduler();
      final PriorityScale scale = await _context.priorityScale();
      final TopicState? sourceTopic = await _learning.findTopic(parent.ref);
      if (sourceTopic == null) {
        return _missingSchedule<Extract>(command.parentId);
      }
      final double sourcePercent = scale.percentageOf(parentSchedule.priority);
      final Sm20TextExtraction extraction = scheduler.extractText(
        sourceTopic,
        utf16CodeUnits: markdown.length,
        sourcePriorityPercent: sourcePercent,
      );
      final PriorityRank sourceRank = scale.rankForSetPriority(
        parentSchedule.priority,
        extraction.sourcePriorityTarget,
      );
      final TopicState updatedSource = extraction.source.copyWith(
        schedule: sourceTopic.schedule.copyWith(
          priority: sourceRank,
          revision: sourceTopic.schedule.revision + 1,
          updatedAtUtc: extract.createdAtUtc,
        ),
      );
      final PriorityScale afterSource = scale.replacing(
        parentSchedule.priority,
        sourceRank,
      );
      final PriorityRank firstChildRank = afterSource.rankAtPercent(
        extraction.childPriorityTarget,
      );
      TopicState topic = scheduler.createFor(
        ref: ref,
        today: day,
        initialAFactor: extraction.childAFactor,
        memorized: true,
        buildSchedule: (StudyDay due) => ElementSchedule(
          ref: ref,
          priority: firstChildRank,
          lifecycle: ElementLifecycle.active,
          dueDay: due,
          originalDueDay: due,
          rootId: parentSchedule.rootId ?? parent.rootSourceId,
          parentElementId: parent.ref.id,
          createdAtUtc: extract.createdAtUtc,
          updatedAtUtc: extract.createdAtUtc,
        ),
      );
      final PriorityScale withChild = afterSource.including(firstChildRank);
      topic = topic.copyWith(
        schedule: topic.schedule.copyWith(
          priority: withChild.rankForSetPriority(
            firstChildRank,
            extraction.childPriorityTarget,
          ),
        ),
      );

      await _content.insertExtract(extract);
      if (!await _learning.compareAndSwapTopic(
        expected: sourceTopic,
        replacement: updatedSource,
      )) {
        return const Err<Extract>(
          ConflictFailure('the extraction source changed before commit'),
        );
      }
      await _learning.insertTopic(topic);
      await _context.savePrngState(extraction.prngState);
      await _search.upsertDocument(
        SearchDocument(
          ref: ref,
          title:
              (await _content.findSource(parent.rootSourceId))?.title ??
              'Extract',
          body: markdown,
          sourceId: parent.rootSourceId,
          updatedAtUtc: extract.createdAtUtc,
        ),
      );
      await _journal.append(
        operationId: command.operationId.value,
        ref: ref,
        eventType: RevlogEventType.created,
        atUtc: command.timestampUtc,
        after: _journal.topicSnapshot(
          topic,
          calendar: await _context.calendar(),
          pressure: withChild.pressureOf(topic.schedule.priority),
        ),
        scheduledDays: topic.intervalDays,
        metadata: <String, Object?>{
          'parent': command.parentId,
          'first_interval_days': topic.intervalDays,
          'child_a_raw': topic.aFactorRaw.toString(),
          'source_a_raw': updatedSource.aFactorRaw.toString(),
          'source_priority_target': extraction.sourcePriorityTarget,
          'child_priority_target': extraction.childPriorityTarget,
        },
      );
      await _log(
        command,
        kExtractCreatedKind,
        ref: ref,
        metadata: <String, Object?>{
          'parent': command.parentId,
          'same_block': command.range.isSameBlock,
          'length': markdown.length,
        },
      );
      return Ok<Extract>(extract);
    },
  );

  /// Removes an extract entirely, as though it had never been made.
  Future<Result<Unit>> undoExtract(
    UndoExtract command,
  ) => _run<Unit>(command, kExtractUndoneKind, () async {
    final extract = await _content.findExtract(command.extractId);
    if (extract == null) {
      return Err<Unit>(
        NotFoundFailure(
          'no such extract',
          entity: 'extract',
          id: command.extractId,
        ),
      );
    }

    final ref = ElementRef(id: extract.id, type: ElementType.extract);
    final recent = await _learning.recentActivity(limit: 1);
    if (recent.isEmpty ||
        recent.single.kind != kExtractCreatedKind ||
        recent.single.ref != ref) {
      return const Err<Unit>(
        ConflictFailure('only the most recently created extract can be undone'),
      );
    }

    final children = await _content.listExtractsOfParent(extract.id);
    if (children.isNotEmpty) {
      return const Err<Unit>(
        ConflictFailure('this extract already has extracts of its own'),
      );
    }
    final cards = await _content.listCardsOfExtract(extract.id);
    if (cards.isNotEmpty) {
      return const Err<Unit>(
        ConflictFailure('this extract already has cards formulated from it'),
      );
    }

    await _learning.deleteSchedule(ref);
    await _search.deleteDocument(ref);
    await _content.deleteExtract(extract.id);
    // Scheduling history is append-only. Retain the creation record even when
    // the just-created content is removed so transfer and audit consumers can
    // still explain why the former element briefly had a schedule.
    await _log(command, kExtractUndoneKind, ref: ref);
    return okUnit;
  });

  /// Refines an extract's text without touching its schedule.
  Future<Result<Extract>> editExtract(
    EditExtract command,
  ) => _run<Extract>(command, 'extract.edited', () async {
    final markdown = command.markdown.trim();
    if (markdown.isEmpty) {
      return const Err<Extract>(
        ValidationFailure('an extract needs some text'),
      );
    }
    final extract = await _content.findExtract(command.extractId);
    if (extract == null) {
      return Err<Extract>(
        NotFoundFailure(
          'no such extract',
          entity: 'extract',
          id: command.extractId,
        ),
      );
    }

    final children = await _content.listExtractsOfParent(extract.id);
    if (children.isNotEmpty) {
      return const Err<Extract>(
        ConflictFailure(
          'this extract cannot be edited because nested extracts depend on its coordinates',
        ),
      );
    }

    final updated = extract.withMarkdown(markdown, _clock.nowUtc());
    await _content.updateExtract(updated);
    final ElementRef extractRef = ElementRef(
      id: extract.id,
      type: ElementType.extract,
    );
    final ElementSchedule? schedule = await _learning.findSchedule(extractRef);
    final String rootTitle =
        (await _content.findSource(extract.provenance.sourceId))?.title ??
        'Extract';
    await _search.upsertDocument(
      SearchDocument(
        ref: extractRef,
        title: rootTitle,
        body: markdown,
        sourceId: schedule?.rootId ?? extract.provenance.sourceId,
        updatedAtUtc: command.timestampUtc,
      ),
    );
    await _log(
      command,
      'extract.edited',
      ref: ElementRef(id: extract.id, type: ElementType.extract),
    );
    return Ok<Extract>(updated);
  });

  /// Extracts taken from [parentId], for the Reader's gutter marks.
  Future<List<Extract>> listExtractsOf(String parentId) =>
      _content.listExtractsOfParent(parentId);

  /// The document an extract's anchors address, source or extract.
  ///
  /// An extract's own text is parsed on demand rather than stored as blocks:
  /// extracts are short, and deriving them keeps one coordinate system for
  /// every level of the chain.
  Future<_Parent?> _resolveParent(String parentId, bool parentIsSource) async {
    if (parentIsSource) {
      final document = await _content.findDocument(parentId);
      if (document == null) return null;
      return _Parent(
        ref: ElementRef(id: parentId, type: ElementType.source),
        document: document,
        rootSourceId: parentId,
      );
    }
    final extract = await _content.findExtract(parentId);
    if (extract == null) return null;
    return _Parent(
      ref: ElementRef(id: parentId, type: ElementType.extract),
      document: Document.parse(sourceId: parentId, markdown: extract.markdown),
      rootSourceId: extract.provenance.sourceId,
    );
  }

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
        if (result.isOk) await _transfer.advanceGeneration();
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
    Map<String, Object?>? metadata,
  }) => _learning.appendActivity(
    ActivityRecord(
      id: _ids.newId(),
      operationId: command.operationId.value,
      kind: kind,
      atUtc: command.timestampUtc,
      ref: ref,
      metadata: metadata,
    ),
  );

  Err<T> _missingSchedule<T>(String id) => Err<T>(
    NotFoundFailure('no schedule for that element', entity: 'schedule', id: id),
  );
}

/// The parent of an extract, resolved to a document plus identity.
final class _Parent {
  const _Parent({
    required this.ref,
    required this.document,
    required this.rootSourceId,
  });

  final ElementRef ref;
  final Document document;

  /// Root source of the whole chain, denormalized onto every extract.
  final String rootSourceId;
}
