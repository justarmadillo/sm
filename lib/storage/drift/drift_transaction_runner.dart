/// Runs a block of work inside one database transaction.
///
/// SQL and row mapping, nothing else. No repository decides an interval, a
/// lifecycle transition, or whether an operation is allowed -- those are the
/// command runners' and the schedulers' jobs. A repository that starts making
/// policy is how scheduling rules end up spread across three folders.
library;

import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/database/app_database.dart';

/// Runs handler bodies inside one Drift transaction.
final class DriftTransactionRunner implements TransactionRunner {
  const DriftTransactionRunner(this._database);

  final AppDatabase _database;

  @override
  Future<T> run<T>(Future<T> Function() body) => _database.transaction(body);
}
