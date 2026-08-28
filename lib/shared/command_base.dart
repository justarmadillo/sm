/// The base of every application command.
library;

import 'package:incremental_reader/shared/operation_id.dart';
import 'package:meta/meta.dart';

/// A named, immutable request to change something.
///
/// Not sealed: commands are added per feature and are never switched over
/// exhaustively. Every command carries both an operation id and the instant at
/// which the intent was issued. The id makes terminal actions safe to retry;
/// the timestamp keeps delayed/replayed work auditable without substituting
/// the handler's later execution time.
@immutable
abstract base class AppCommand {
  AppCommand(this.operationId, {DateTime? timestampUtc})
    : timestampUtc = (timestampUtc ?? DateTime.now()).toUtc();

  /// Correlates every row and log line this command produces.
  final OperationId operationId;

  /// When the caller issued this intent, normalized to UTC.
  final DateTime timestampUtc;
}
