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

import 'dart:convert';

import 'package:incremental_reader/features/priority/priority_commands.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/revlog.dart';
import 'package:incremental_reader/scheduling/history/scheduler_event.dart';
import 'package:incremental_reader/scheduling/history/scheduling_journal.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/command_base.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';

/// Activity kind recorded when relative priority changes.
const String kPrioritySetKind = 'element.priority_set';

/// Activity kind recorded when a range is spread across many elements.
const String kPrioritySpreadKind = 'element.priority_spread';

/// Handlers for the priority slider, the browser, and bulk spread.
final class PriorityCommandRunner {
  PriorityCommandRunner({
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
  Future<Result<ElementSchedule>> setPercent(
    SetPriorityPercent command,
  ) => _run<ElementSchedule>(command, kPrioritySetKind, () async {
    if (command.percent.isNaN || command.percent < 0 || command.percent > 100) {
      return const Err<ElementSchedule>(
        ValidationFailure('priority is a percent from 0 to 100'),
      );
    }
    final ElementSchedule? schedule = await _learning.findSchedule(command.ref);
    if (schedule == null) return _missing<ElementSchedule>(command.ref);

    final PriorityScale scale = await _context.priorityScale();
    final PriorityRank rank = scale.rankForSetPriority(
      schedule.priority,
      command.percent,
    );
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
        final double current = scale.percentageOf(schedule.priority);
        final double target =
            current +
            (command.shouldIncrease ? -0.1 : 0.1) *
                (command.places < 1 ? 1 : command.places);
        final PriorityRank rank = scale.rankForSetPriority(
          schedule.priority,
          target,
        );
        return _apply(command, schedule, rank, scale, kPrioritySetKind);
      });

  /// Applies Increase, Decrease, Spread, or Adjust exactly in subset order.
  Future<Result<int>> batch(
    BatchPriority command,
  ) => _run<int>(command, kPrioritySpreadKind, () async {
    if (command.refs.isEmpty) {
      return const Err<int>(ValidationFailure('choose an element subset'));
    }
    if (!command.lowPercent.isFinite ||
        !command.highPercent.isFinite ||
        !command.changePercent.isFinite) {
      return const Err<int>(
        ValidationFailure('priority values must be finite'),
      );
    }

    var low = command.lowPercent;
    var high = command.highPercent;
    var change = command.changePercent;
    final bool doesRemapRange =
        command.mode == Sm20BatchPriorityMode.spread ||
        command.mode == Sm20BatchPriorityMode.adjust;
    if (!doesRemapRange && !command.shouldLimitChanges) {
      low = 0;
      high = 100;
    }
    if (doesRemapRange) {
      change = 0;
      if (low == high) {
        low -= 0.1;
        high += 0.1;
      }
    }
    low = low.clamp(0, 99);
    high = high.clamp(0.0001, 100);
    change = change.clamp(0, 1000);
    if (low > high) {
      final double swap = low;
      low = high;
      high = swap;
    }

    var scale = await _context.priorityScale();
    final int available =
        scale.positionForPercentage(high) -
        scale.positionForPercentage(low) +
        1;
    if (command.refs.length > available) {
      return Err<int>(
        ValidationFailure(
          'the selected range has only $available priority slots',
        ),
      );
    }

    final records =
        <({ElementRef ref, ElementSchedule? schedule, int status})>[];
    final Set<ElementRef> seen = <ElementRef>{};
    for (final ElementRef ref in command.refs) {
      if (!seen.add(ref)) {
        return const Err<int>(
          ValidationFailure('the priority subset contains duplicates'),
        );
      }
      final ElementSchedule? schedule = await _learning.findSchedule(ref);
      records.add((
        ref: ref,
        schedule: schedule,
        status: await _sm20Status(ref, schedule),
      ));
    }

    var oldMinimum = 100.0;
    var oldMaximum = 0.0;
    if (command.mode == Sm20BatchPriorityMode.adjust) {
      for (final record in records) {
        if (record.status != Sm20ElementStatus.memorized.index ||
            record.schedule == null) {
          continue;
        }
        final double percent = scale.percentageOf(record.schedule!.priority);
        if (percent < oldMinimum) oldMinimum = percent;
        if (percent > oldMaximum) oldMaximum = percent;
      }
    }

    final double requestedStep = command.refs.length == 1
        ? 0
        : (high - low) / (command.refs.length - 1);
    final double populationStep = scale.total == 0 ? 0 : 100 / scale.total;
    final double spreadStep = requestedStep < populationStep
        ? populationStep
        : requestedStep;

    final schedules = <ElementSchedule>[];
    final changes = <({ElementSchedule before, ElementSchedule after})>[];
    final entries = <RevlogEntry>[];
    final DateTime now = command.timestampUtc;
    var sourcePosition = 1;
    for (final record in records) {
      if (record.status == Sm20ElementStatus.deleted.index) continue;
      final double? spreadTarget = command.mode == Sm20BatchPriorityMode.spread
          ? (low + (sourcePosition - 1) * spreadStep).clamp(0, high)
          : null;
      final int currentSourcePosition = sourcePosition;
      if (command.mode == Sm20BatchPriorityMode.spread) sourcePosition++;

      final ElementSchedule? schedule = record.schedule;
      if (schedule == null ||
          (record.status != Sm20ElementStatus.pending.index &&
              record.status != Sm20ElementStatus.memorized.index)) {
        continue;
      }
      final double current = scale.percentageOf(schedule.priority);
      final double calculated = switch (command.mode) {
        Sm20BatchPriorityMode.shouldIncrease => _increaseTarget(
          current,
          change,
          low,
          high,
        ),
        Sm20BatchPriorityMode.decrease => _decreaseTarget(
          current,
          change,
          low,
          high,
        ),
        Sm20BatchPriorityMode.spread => spreadTarget!,
        Sm20BatchPriorityMode.adjust =>
          oldMaximum == oldMinimum
              ? low
              : low +
                    (high - low) *
                        (current - oldMinimum) /
                        (oldMaximum - oldMinimum),
      };
      final double target = calculated > high ? high : calculated;
      final PriorityRank rank = scale.rankForSetPriority(
        schedule.priority,
        target,
      );
      final ElementSchedule updated = schedule.copyWith(
        priority: rank,
        revision: schedule.revision + 1,
        updatedAtUtc: now,
      );
      schedules.add(updated);
      changes.add((before: schedule, after: updated));
      entries.add(
        _journal.build(
          operationId: command.operationId.value,
          ref: schedule.ref,
          eventType: RevlogEventType.priorityChange,
          atUtc: now,
          before: RevlogSnapshot(
            priorityKey: schedule.priority.orderKey,
            pressure: current / 100,
            lifecycle: schedule.lifecycle.index,
          ),
          after: RevlogSnapshot(
            priorityKey: rank.orderKey,
            lifecycle: schedule.lifecycle.index,
          ),
          metadata: <String, Object?>{
            'mode': command.mode.name,
            'low': low,
            'high': high,
            'change': change,
            'source_position': currentSourcePosition,
            'of': command.refs.length,
          },
        ),
      );
      scale = scale.replacing(schedule.priority, rank);
    }
    if (schedules.isEmpty) {
      return const Err<int>(
        ValidationFailure('none of those elements is pending or memorized'),
      );
    }

    await _learning.saveSchedules(schedules);
    await _journal.appendAll(entries);
    for (final changeRecord in changes) {
      await _appendSchedulerPriority(
        command,
        changeRecord.before,
        changeRecord.after,
        metadata: <String, Object?>{
          'mode': command.mode.name,
          'low': low,
          'high': high,
          'change': change,
        },
      );
    }
    await _learning.appendActivity(
      ActivityRecord(
        id: _ids.newId(),
        operationId: command.operationId.value,
        kind: kPrioritySpreadKind,
        atUtc: now,
        metadata: <String, Object?>{
          'count': schedules.length,
          'mode': command.mode.name,
          'low': low,
          'high': high,
          'change': change,
        },
      ),
    );
    return Ok<int>(schedules.length);
  });

  Future<int> _sm20Status(ElementRef ref, ElementSchedule? schedule) async {
    if (schedule == null || schedule.lifecycle == ElementLifecycle.deleted) {
      return Sm20ElementStatus.deleted.index;
    }
    if (ref.type.isTopic) {
      return (await _learning.findTopic(ref))?.status.index ??
          Sm20ElementStatus.deleted.index;
    }
    if (schedule.lifecycle != ElementLifecycle.active) {
      return Sm20ElementStatus.dismissed.index;
    }
    final CardState? card = await _learning.findCardState(ref.id);
    if (card == null) return Sm20ElementStatus.deleted.index;
    return card.memory.reps == 0
        ? Sm20ElementStatus.pending.index
        : Sm20ElementStatus.memorized.index;
  }

  double _increaseTarget(
    double current,
    double change,
    double low,
    double high,
  ) {
    var value = (current * change / 100).clamp(low, high).toDouble();
    if (value > current) value = current;
    return value > high ? high : value;
  }

  double _decreaseTarget(
    double current,
    double change,
    double low,
    double high,
  ) {
    var value = (current * change / 100).clamp(low, high).toDouble();
    if (value < current) value = current;
    return value > high ? high : value;
  }

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
    final ElementSchedule updated = schedule.copyWith(
      priority: rank,
      revision: schedule.revision + 1,
      updatedAtUtc: command.timestampUtc,
    );
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
    await _appendSchedulerPriority(command, schedule, updated);
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
          final ElementRef? ref = switch (command) {
            SetPriority(:final ref) ||
            SetPriorityPercent(:final ref) ||
            ReorderPriority(:final ref) ||
            StepPriority(:final ref) => ref,
            _ => null,
          };
          if (ref != null) {
            final ElementSchedule? replayed = await _learning.findSchedule(ref);
            if (replayed is T) return Ok<T>(replayed as T);
          }
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

  Future<void> _appendSchedulerPriority(
    AppCommand command,
    ElementSchedule before,
    ElementSchedule after, {
    Map<String, Object?>? metadata,
  }) async {
    final calendar = await _context.calendar();
    final CardState? card = before.ref.type == ElementType.card
        ? await _learning.findCardState(before.ref.id)
        : null;
    final String algorithmicDue = card == null
        ? SchedulerEvent.encodeStudyDayDue(before.algorithmicDueDay)
        : SchedulerEvent.encodeUtcDue(card.memory.dueAtUtc);
    await _journal.appendScheduler(
      operationId: command.operationId.value,
      ref: before.ref,
      eventType: SchedulerEventType.priorityChanged,
      atUtc: command.timestampUtc,
      studyDay: calendar.dayOf(command.timestampUtc),
      policyVersion: 'priority_order_v1',
      stateBefore: _scheduleJson(before),
      stateAfter: _scheduleJson(after),
      algorithmicDueBefore: algorithmicDue,
      algorithmicDueAfter: algorithmicDue,
      metadata: metadata,
    );
  }

  String _scheduleJson(ElementSchedule schedule) =>
      jsonEncode(<String, Object?>{
        'id': schedule.ref.id,
        'type': schedule.ref.type.index,
        'priority_key': schedule.priority.orderKey,
        'lifecycle': schedule.lifecycle.index,
        'revision': schedule.revision,
      });

  Err<T> _missing<T>(ElementRef ref) => Err<T>(
    NotFoundFailure(
      'no schedule for that element',
      entity: 'schedule',
      id: ref.id,
    ),
  );
}
