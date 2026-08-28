/// Commands for creating and processing extracts.
///
/// Extraction has to be frictionless — select, extract, keep reading — so the
/// command carries only what the Reader already knows. No metadata prompt, no
/// modal: provenance and priority are inherited, and the one affordance the
/// user gets afterwards is Undo.
library;

import 'package:incremental_reader/src/application/app_command.dart';
import 'package:incremental_reader/src/domain/content/reader_anchor.dart';

/// Promote a selected passage into an independent learning object.
final class CreateExtract extends AppCommand {
  CreateExtract(
    super.operationId, {
    required this.parentId,
    required this.parentIsSource,
    required this.range,
    super.timestampUtc,
  });

  /// The source or extract the selection was made in.
  final String parentId;

  /// Whether [parentId] names a source rather than another extract.
  final bool parentIsSource;

  /// The selection, including the hash of exactly what was selected.
  final SelectionRange range;
}

/// Remove an extract created moments ago, leaving nothing behind.
///
/// Distinct from Dismiss: dismissing keeps the content and the provenance and
/// only stops scheduling. Undo is for the mis-drag, so it removes the object.
final class UndoExtract extends AppCommand {
  UndoExtract(super.operationId, {required this.extractId, super.timestampUtc});

  final String extractId;
}

/// Refine an extract's text. Never reschedules it.
final class EditExtract extends AppCommand {
  EditExtract(
    super.operationId, {
    required this.extractId,
    required this.markdown,
    super.timestampUtc,
  });

  final String extractId;
  final String markdown;
}
