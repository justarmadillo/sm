/// Handlers for every priority change.
///
/// One rule runs through all of them: a priority change rewrites order keys
/// and nothing else. No due date moves, no interval changes, no lifecycle
/// shifts. Priority decides what gets attention among elements that are
/// already eligible; letting it touch scheduling would collapse the two axes
/// the whole design keeps apart.
///
/// The second rule is that a change is logged. Priority is the input to
/// admission, so a queue that behaved oddly last Tuesday is only explainable
/// if the order it saw is recoverable — which means recording both the key
/// and the derived percentile at the time of the change.
library;

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../core/result.dart';
import '../../core/tracing.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/revlog.dart';
import '../app_command.dart';
import '../ports/repositories.dart';
import '../ports/transaction_runner.dart';
import '../scheduling/scheduling_context.dart';
import '../scheduling/scheduling_journal.dart';
import 'priority_commands.dart';

/// Activity kind recorded when relative priority changes.
const String kPrioritySetKind = 'element.priority_set';

/// Activity kind recorded when a range is spread across many elements.
const String kPrioritySpreadKind = 'element.priority_spread';

/// Handlers for the priority slider, the browser, and bulk spread.
final class PriorityHandlers {
  PriorityHandlers({
    required LearningRepository learning,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required SchedulingContext context,
    required Clock clock,
    required IdGenerator ids,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _learning = learning,
       _transfer = transfer,
       _transactions = transactions,
       _context = context,
       _clock = clock,
       _ids = ids,
       _journal = SchedulingJournal(learning: learning, ids: ids),
       _diagnostics = diagnostics;

  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final SchedulingContext _context;
  final Clock _clock;
  final IdGenerator _ids;
  final SchedulingJournal _journal;
  final DiagnosticSink _diagnostics;

  /// Places an element at an exact order key.
  Future<Result<ElementSchedule>> setRank(SetPriority command) =>
      _run<ElementSchedule>(command, kPrioritySetKind, () async {
        final ElementSchedule? schedule = await _learning.findSchedule(
          command.ref,
        );
        if (schedule == null) return _missing<ElementSchedule>(command.ref);
        return _apply(
          command,
          schedule,
          command.rank,
          await _context.priorityScale(),
          kPrioritySetKind,
        );
      });

  /// Places an element at [SetPriorityPercent.percent] of the collection.
  Future<Result<ElementSchedule>> setPercent(SetPriorityPercent command) =>
      _run<ElementSchedule>(command, kPrioritySetKind, () async {
        if (command.percent.isNaN ||
            command.percent < 0 ||
            command.percent > 100) {
          return const Err<ElementSchedule>(
            ValidationFailure('priority is a percent from 0 to 100'),
          );
        }
        final ElementSchedule? schedule = await _learning.findSchedule(
          command.ref,
        );
        if (schedule == null) return _missing<ElementSchedule>(command.ref);

        final PriorityScale scale = await _context.priorityScale();
        final PriorityRank rank = scale.rankAtPercent(command.percent);
        return _apply(command, schedule, rank, scale, kPrioritySetKind);
      });

  /// Moves an element between two neighbours, as a drag does.
  Future<Result<ElementSchedule>> reorder(ReorderPriority command) =>
      _run<ElementSchedule>(command, kPrioritySetKind, () async {
        final ElementSchedule? schedule = await _learning.findSchedule(
          command.ref,
        );
        if (schedule == null) return _missing<ElementSchedule>(command.ref);
        if (command.after != null &&
            command.before != null &&
            command.after! >= command.before!) {
          return const Err<ElementSchedule>(
            ValidationFailure('those two neighbours are not in order'),
          );
        }
        final PriorityScale scale = await _context.priorityScale();
        final PriorityRank rank = PriorityRank.between(
          command.after,
          command.before,
        );
        return _apply(command, schedule, rank, scale, kPrioritySetKind);
      });

  /// Nudges an element past its neighbours.
  Future<Result<ElementSchedule>> step(StepPriority command) =>
      _run<ElementSchedule>(command, kPrioritySetKind, () async {
        final ElementSchedule? schedule = await _learning.findSchedule(
          command.ref,
        );
        if (schedule == null) return _missing<ElementSchedule>(command.ref);

        final PriorityScale scale = await _context.priorityScale();
        final PriorityRank rank = scale.stepped(
          schedule.priority,
          increase: command.increase,
          places: command.places,
        );
        return _apply(command, schedule, rank, scale, kPrioritySetKind);
      });

  /// Spreads a percent range across many elements in one transaction.
  Future<Result<int>> spread(SpreadPriority command) =>
      _run<int>(command, kPrioritySpreadKind, () async {
        if (command.refs.isEmpty) {
          return const Err<int>(
            ValidationFailure('choose at least one element to spread'),
          );
        }
        final double from = command.fromPercent.clamp(0, 100);
        final double to = command.toPercent.clamp(0, 100);
        if (from > to) {
          return const Err<int>(
            ValidationFailure('the range must run from most to least urgent'),
          );
        }

        final PriorityScale scale = await _context.priorityScale();
        // Anchor the spread on the ranks that currently bound the range, then
        // generate evenly spaced keys strictly inside them. Rewriting only the
        // named elements keeps the rest of the collection where it was.
        final PriorityRank low = scale.rankAtPercent(from);
        final PriorityRank high = scale.rankAtPercent(to);
        final List<PriorityRank> ranks = low < high
            ? PriorityRank.spread(
                count: command.refs.length,
                before: low,
                after: high,
              )
            : PriorityRank.spread(count: command.refs.length, before: low);

        final schedules = <ElementSchedule>[];
        final entries = <RevlogEntry>[];
        final DateTime now = command.timestampUtc;
        for (var index = 0; index < command.refs.length; index++) {
          final ElementRef ref = command.refs[index];
          final ElementSchedule? schedule = await _learning.findSchedule(ref);
          if (schedule == null) continue;
          final PriorityRank rank = ranks[index];
          schedules.add(schedule.copyWith(priority: rank));
          entries.add(
            _journal.build(
              operationId: command.operationId.value,
              ref: ref,
              eventType: RevlogEventType.priorityChange,
              atUtc: now,
              before: RevlogSnapshot(
                priorityKey: schedule.priority.orderKey,
                pressure: scale.pressureOf(schedule.priority),
                lifecycle: schedule.lifecycle.index,
              ),
              after: RevlogSnapshot(
                priorityKey: rank.orderKey,
                lifecycle: schedule.lifecycle.index,
              ),
              metadata: <String, Object?>{
                'spread_from': from,
                'spread_to': to,
                'position': index,
                'of': command.refs.length,
              },
            ),
          );
        }
        if (schedules.isEmpty) {
          return const Err<int>(
            ValidationFailure('none of those elements has a schedule'),
          );
        }

        await _learning.saveSchedules(schedules);
        await _journal.appendAll(entries);
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kPrioritySpreadKind,
            atUtc: now,
            metadata: <String, Object?>{
              'count': schedules.length,
              'from': from,
              'to': to,
            },
          ),
        );
        return Ok<int>(schedules.length);
      });

  Future<Result<ElementSchedule>> _apply(
    AppCommand command,
    ElementSchedule schedule,
    PriorityRank rank,
    PriorityScale scale,
    String kind,
  ) async {
    if (rank == schedule.priority) {
      return Ok<ElementSchedule>(schedule);
    }
    final ElementSchedule updated = schedule.copyWith(priority: rank);
    await _learning.saveSchedule(updated);
    await _journal.append(
      operationId: command.operationId.value,
      ref: schedule.ref,
      eventType: RevlogEventType.priorityChange,
      atUtc: command.timestampUtc,
      before: RevlogSnapshot(
        priorityKey: schedule.priority.orderKey,
        pressure: scale.pressureOf(schedule.priority),
        lifecycle: schedule.lifecycle.index,
      ),
      after: RevlogSnapshot(
        priorityKey: rank.orderKey,
        pressure: scale.pressureOf(rank),
        lifecycle: schedule.lifecycle.index,
      ),
    );
    await _learning.appendActivity(
      ActivityRecord(
        id: _ids.newId(),
        operationId: command.operationId.value,
        kind: kind,
        atUtc: command.timestampUtc,
        ref: schedule.ref,
        metadata: <String, Object?>{
          'key': rank.orderKey,
          'percent': scale.positionOf(rank)?.percent,
        },
      ),
    );
    return Ok<ElementSchedule>(updated);
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
        final Result<T> result = await body();
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

  Err<T> _missing<T>(ElementRef ref) => Err<T>(
    NotFoundFailure(
      'no schedule for that element',
      entity: 'schedule',
      id: ref.id,
    ),
  );
}
