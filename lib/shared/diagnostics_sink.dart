/// Where the app writes what it just did, for later diagnosis.
///
/// Events carry ids, counts, and versions -- never what the user is
/// studying, so a log pasted into a bug report stays safe to share.
library;

import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:meta/meta.dart';

/// Severity of a diagnostic record.
enum DiagnosticLevel { debug, info, warning, error }

/// One structured diagnostic record. Fields hold metadata only, never content.
@immutable
final class DiagnosticEvent {
  const DiagnosticEvent({
    required this.level,
    required this.name,
    required this.timestampUtc,
    this.operationId,
    this.fields = const <String, Object?>{},
    this.failure,
  });

  final DiagnosticLevel level;

  /// Stable dotted event name, for example `reader.move_resume_marker`.
  final String name;
  final DateTime timestampUtc;
  final OperationId? operationId;
  final Map<String, Object?> fields;
  final AppFailure? failure;

  @override
  String toString() {
    final op = operationId == null ? '' : ' op=$operationId';
    final err = failure == null ? '' : ' failure=$failure';
    return '[${level.name}] $name$op $fields$err';
  }
}

/// Destination for [DiagnosticEvent]s. Implementations must never throw.
abstract interface class DiagnosticSink {
  /// Records one diagnostic event.
  void record(DiagnosticEvent event);
}

/// Discards everything. Default in tests that do not assert on diagnostics.
final class NullDiagnosticSink implements DiagnosticSink {
  const NullDiagnosticSink();

  @override
  void record(DiagnosticEvent event) {}
}

/// Keeps events in memory so tests can assert on them.
@visibleForTesting
final class RecordingDiagnosticSink implements DiagnosticSink {
  /// Everything recorded so far, in order.
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void record(DiagnosticEvent event) => events.add(event);

  /// Every recorded event whose name equals [name].
  Iterable<DiagnosticEvent> named(String name) =>
      events.where((DiagnosticEvent e) => e.name == name);

  /// Drops all recorded events.
  void clear() => events.clear();
}
