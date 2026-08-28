/// Sends one event to several places at once.
///
/// Lets the in-memory diagnostics panel and the on-disk log both be fed
/// from a single call site.
library;

import 'package:incremental_reader/shared/diagnostics_sink.dart';

/// Sends events to several sinks. Used to keep the in-memory diagnostics
/// panel and the on-disk log fed from one call site.
final class FanOutDiagnosticSink implements DiagnosticSink {
  const FanOutDiagnosticSink(this._sinks);

  final List<DiagnosticSink> _sinks;

  @override
  void record(DiagnosticEvent event) {
    for (final DiagnosticSink sink in _sinks) {
      sink.record(event);
    }
  }
}
