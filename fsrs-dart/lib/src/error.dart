/// The error hierarchy ts-fsrs throws, preserved so that call sites can
/// distinguish "you passed me nonsense" from an internal failure.
library;

/// Base class for every error raised by this package.
class FSRSError implements Exception {
  FSRSError([this.message = 'FSRS Error']);

  final String message;

  String get name => 'FSRSError';

  @override
  String toString() => '$name: $message';
}

/// Raised when an input (date, rating, state, parameter vector) is invalid.
class FSRSValidationError extends FSRSError {
  FSRSValidationError([super.message = 'FSRS Error']);

  @override
  String get name => 'FSRSValidationError';
}

/// Raised when an operation is not permitted for the given card or log.
class FSRSOperationError extends FSRSError {
  FSRSOperationError([super.message = 'FSRS Error']);

  @override
  String get name => 'FSRSOperationError';
}
