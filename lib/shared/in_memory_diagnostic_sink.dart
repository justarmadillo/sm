/// Keeps the most recent events in memory for the diagnostics panel.
///
/// Bounded on purpose: the panel shows what just happened, and the durable
/// record is the rotating file and the repetition log.
library;

import 'package:incremental_reader/shared/diagnostics_sink.dart';

/// Keeps the most recent events in memory for the diagnostics panel.
///
/// Bounded on purpose: the panel shows what just happened, and the durable
/// record is the rotating file and the repetition log.
final class InMemoryDiagnosticSink implements DiagnosticSink {
  InMemoryDiagnosticSink({this.capacity = 200});

  final int capacity;
  final List<DiagnosticEvent> _events = <DiagnosticEvent>[];

  /// Newest first.
  List<DiagnosticEvent> get events =>
      List<DiagnosticEvent>.unmodifiable(_events.reversed);

  @override
  void record(DiagnosticEvent event) {
    _events.add(event);
    if (_events.length > capacity) _events.removeAt(0);
  }

  /// Drops everything recorded so far.
  void clear() => _events.clear();
}
