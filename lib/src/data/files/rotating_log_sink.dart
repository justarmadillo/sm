/// A local rotating structured log.
///
/// Writes one JSON object per line: operation metadata, failures, and the
/// schema and app versions the event happened under. When something scheduled
/// wrongly three weeks ago, the repetition log says *what* the collection
/// decided and this says *which build decided it and what else was happening
/// at the time*.
///
/// Two properties it must have and one it must not:
///
/// * **Never throws.** A [DiagnosticSink] is called from inside command
///   handlers; a full disk or a locked file must not roll back a review.
/// * **Bounded.** It rotates at a size limit and keeps a fixed number of
///   files, so a long-running collection cannot fill the disk with logs.
/// * **No element content.** Fields carry ids, counts, and versions. A log the
///   user might paste into a bug report must not contain what they are
///   studying.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/tracing.dart';
import '../database/app_database.dart';

/// Basename of the active log file.
const String kDiagnosticLogName = 'diagnostics.log';

/// Appends [DiagnosticEvent]s to a size-capped rotating file.
final class RotatingLogSink implements DiagnosticSink {
  RotatingLogSink({
    required Directory directory,
    required String appVersion,
    int maxBytes = 2097152,
    int retainedFiles = 5,
    DiagnosticLevel minimumLevel = DiagnosticLevel.info,
  }) : _directory = directory,
       _appVersion = appVersion,
       _maxBytes = maxBytes,
       _retainedFiles = retainedFiles,
       _minimumLevel = minimumLevel;

  final Directory _directory;
  final String _appVersion;
  final int _maxBytes;
  final int _retainedFiles;
  final DiagnosticLevel _minimumLevel;

  /// Serializes writes so interleaved commands cannot split a line.
  Future<void> _pending = Future<void>.value();
  bool _disabled = false;

  /// The active log file.
  File get file => File(
    '${_directory.path}${Platform.pathSeparator}'
    '$kDiagnosticLogName',
  );

  @override
  void record(DiagnosticEvent event) {
    if (_disabled || event.level.index < _minimumLevel.index) return;
    final String line = jsonEncode(<String, Object?>{
      'at': event.timestampUtc.toIso8601String(),
      'level': event.level.name,
      'name': event.name,
      if (event.operationId != null) 'op': event.operationId!.value,
      'app': _appVersion,
      'schema': kSchemaVersion,
      if (event.fields.isNotEmpty) 'fields': _sanitize(event.fields),
      if (event.failure != null)
        'failure': <String, Object?>{
          'type': event.failure.runtimeType.toString(),
          'message': event.failure!.message,
          if (event.failure!.cause != null)
            'cause': event.failure!.cause.runtimeType.toString(),
          if (event.failure!.stackTrace != null)
            'stack': _trim(event.failure!.stackTrace!.toString()),
        },
    });
    // Fire-and-forget by design: a diagnostic write must never make a caller
    // wait, and must never be the thing that fails a transaction.
    unawaited(_append(line));
  }

  /// Waits for every queued line to reach the file. For tests and shutdown.
  Future<void> flush() => _pending;

  Future<void> _append(String line) {
    _pending = _pending
        .then((_) async {
          if (_disabled) return;
          if (!_directory.existsSync()) {
            _directory.createSync(recursive: true);
          }
          final File target = file;
          if (target.existsSync() && target.lengthSync() >= _maxBytes) {
            _rotate();
          }
          await target.writeAsString(
            '$line\n',
            mode: FileMode.append,
            flush: false,
          );
        })
        .catchError((Object _) {
          // One failure is enough: if the log directory is unwritable it will
          // stay unwritable, and retrying on every event would turn a
          // diagnostic into a performance problem.
          _disabled = true;
        });
    return _pending;
  }

  /// Rotation is synchronous so a concurrent append cannot land between the
  /// renames and write into a file that is about to move.
  void _rotate() {
    final String separator = Platform.pathSeparator;
    final File oldest = File(
      '${_directory.path}$separator$kDiagnosticLogName.$_retainedFiles',
    );
    if (oldest.existsSync()) oldest.deleteSync();
    for (var index = _retainedFiles - 1; index >= 1; index--) {
      final File from = File(
        '${_directory.path}$separator$kDiagnosticLogName.$index',
      );
      if (from.existsSync()) {
        from.renameSync(
          '${_directory.path}$separator$kDiagnosticLogName.${index + 1}',
        );
      }
    }
    final File current = file;
    if (current.existsSync()) {
      current.renameSync('${_directory.path}$separator$kDiagnosticLogName.1');
    }
  }

  /// Keeps only scalars, so a caller cannot accidentally log a whole element.
  Map<String, Object?> _sanitize(Map<String, Object?> fields) =>
      <String, Object?>{
        for (final MapEntry<String, Object?> entry in fields.entries)
          entry.key: switch (entry.value) {
            null => null,
            final num value => value,
            final bool value => value,
            final String value =>
              value.length <= 120 ? value : '${value.substring(0, 117)}...',
            final Object value => value.runtimeType.toString(),
          },
      };

  String _trim(String stack) {
    final List<String> lines = stack.split('\n');
    return lines.length <= 12 ? stack : lines.take(12).join('\n');
  }
}

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
