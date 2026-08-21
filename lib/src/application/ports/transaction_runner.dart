/// Transaction scope shared by every repository.
///
/// Compound operations — creating an extract, formulating cards, running
/// auto-postpone — touch several repositories and must commit as one unit.
/// Handlers own the transaction boundary. Repositories and DAOs never open
/// one themselves.
library;

/// Runs a unit of work inside a single database transaction.
abstract interface class TransactionRunner {
  /// Executes [body] atomically.
  ///
  /// Any thrown error rolls the transaction back and propagates. Nested calls
  /// join the enclosing transaction rather than opening a new one.
  Future<T> run<T>(Future<T> Function() body);
}

/// Runs bodies directly, without any transaction.
///
/// For unit tests with in-memory fakes, where atomicity is not being tested.
final class DirectTransactionRunner implements TransactionRunner {
  const DirectTransactionRunner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}
