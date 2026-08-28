/// Typed success/failure values used across application boundaries.
///
/// Domain and application code never throws for expected failures; it returns
/// a [Result]. Unexpected exceptions are caught at the handler boundary,
/// wrapped in an [UnexpectedFailure], and reported to a diagnostic sink with
/// their original stack trace preserved.
library;

import 'package:meta/meta.dart';

/// Base class for every expected failure crossing an application boundary.
@immutable
sealed class AppFailure {
  const AppFailure(this.message, {this.cause, this.stackTrace});

  /// Human-readable description. Never contains user content.
  final String message;

  /// The originating exception, when this failure wraps one.
  final Object? cause;

  /// Stack trace of [cause], preserved for diagnostics.
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType($message)';
}

/// A command was rejected because its inputs violate a domain rule.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {this.field});

  /// Optional name of the offending field, for form-level reporting.
  final String? field;
}

/// The referenced entity does not exist.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(
    super.message, {
    required this.entity,
    required this.id,
  });

  final String entity;
  final String id;
}

/// The command is well-formed but illegal in the entity's current state.
final class ConflictFailure extends AppFailure {
  const ConflictFailure(super.message);
}

/// Persistence, filesystem, or platform-level failure.
final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {super.cause, super.stackTrace});
}

/// Anything not anticipated. Always logged with its stack trace.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(super.message, {super.cause, super.stackTrace});
}

/// The outcome of an operation: either a value or an [AppFailure].
@immutable
sealed class Result<T> {
  const Result();

  /// Wraps a successful value.
  const factory Result.ok(T value) = Ok<T>;

  /// Wraps a failure.
  const factory Result.err(AppFailure failure) = Err<T>;

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  /// The value, or `null` when this is an [Err].
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure, or `null` when this is an [Ok].
  AppFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Transforms a success value, passing failures through untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Chains another fallible operation onto a success value.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => transform(value),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Collapses both branches into a single value.
  R fold<R>(R Function(T value) onOk, R Function(AppFailure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };

  /// The value, or a thrown [StateError] when this is an [Err].
  ///
  /// Only for tests and call sites that already checked [isOk].
  T unwrap() => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>(:final failure) => throw StateError('unwrap() on Err: $failure'),
  };
}

/// Successful [Result].
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

/// Failed [Result].
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}

/// Marker for commands that produce no value.
@immutable
final class Unit {
  const Unit._();

  /// The single [Unit] instance.
  static const Unit value = Unit._();

  @override
  String toString() => 'Unit';
}

/// Convenience success for void-returning commands.
const Result<Unit> okUnit = Ok<Unit>(Unit.value);
