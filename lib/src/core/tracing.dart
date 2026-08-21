/// Operation tracing and structured diagnostics.
///
/// Every mutation carries an [OperationId] so a user-visible failure can be
/// traced through ViewModel, handler, domain transition, and DAO without
/// recording user content.
library;

import 'package:meta/meta.dart';

import 'result.dart';

/// Correlates one user-initiated operation across every layer.
@immutable
final class OperationId {
  const OperationId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is OperationId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

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
