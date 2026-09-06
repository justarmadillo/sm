/// The transaction, retry, generation, and diagnostic boundary for commands.
library;

import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/command_base.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';

/// Runs one command with the guarantees shared by every command runner.
///
/// Storage operations arrive as callbacks so this innermost layer stays
/// independent of database contracts. A feature may supply [replay] when a
/// repeated operation can return its already-committed result; otherwise a
/// repeated operation is reported as a conflict.
Future<Result<T>> executeCommand<T>({
  required AppCommand command,
  required String activityType,
  required Clock clock,
  required DiagnosticSink diagnostics,
  required Future<Result<T>> Function(Future<Result<T>> Function() changes)
  withinTransaction,
  required Future<bool> Function() wasAlreadyApplied,
  required Future<Result<T>> Function() changes,
  required Future<void> Function() advanceDatasetGeneration,
  Future<Result<T>?> Function()? replay,
}) async {
  try {
    return await withinTransaction(() async {
      if (await wasAlreadyApplied()) {
        final Future<Result<T>?> Function()? replayCommitted = replay;
        if (replayCommitted != null) {
          final Result<T>? replayed = await replayCommitted();
          if (replayed != null) return replayed;
        }
        return Err<T>(
          ConflictFailure('operation ${command.operationId} already applied'),
        );
      }

      final Result<T> result = await changes();
      if (result.isOk) await advanceDatasetGeneration();
      diagnostics.record(
        DiagnosticEvent(
          level: result.isOk ? DiagnosticLevel.info : DiagnosticLevel.warning,
          name: activityType,
          timestampUtc: clock.nowUtc(),
          operationId: command.operationId,
          fields: <String, Object?>{'ok': result.isOk},
          failure: result.failureOrNull,
        ),
      );
      return result;
    });
  } on Object catch (error, stackTrace) {
    return Err<T>(
      recordCommandException(
        operationId: command.operationId,
        activityType: activityType,
        clock: clock,
        diagnostics: diagnostics,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

/// Preserves and reports an exception caught by a custom command boundary.
UnexpectedFailure recordCommandException({
  required OperationId operationId,
  required String activityType,
  required Clock clock,
  required DiagnosticSink diagnostics,
  required Object error,
  required StackTrace stackTrace,
}) {
  final UnexpectedFailure failure = UnexpectedFailure(
    'command $activityType failed',
    cause: error,
    stackTrace: stackTrace,
  );
  diagnostics.record(
    DiagnosticEvent(
      level: DiagnosticLevel.error,
      name: activityType,
      timestampUtc: clock.nowUtc(),
      operationId: operationId,
      failure: failure,
    ),
  );
  return failure;
}
