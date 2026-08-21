/// Identifier generation. Deterministic in tests, random in production.
library;

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// Supplies new, unique entity identifiers.
abstract interface class IdGenerator {
  /// A new identifier.
  String newId();
}

/// Production generator using UUID v4.
final class UuidGenerator implements IdGenerator {
  /// Creates a generator over an existing [Uuid] instance.
  const UuidGenerator(this._uuid);

  /// Creates a generator with its own [Uuid] instance.
  factory UuidGenerator.create() => const UuidGenerator(Uuid());

  final Uuid _uuid;

  @override
  String newId() => _uuid.v4();
}

/// Sequential generator for tests: `id-1`, `id-2`, ...
@visibleForTesting
final class FakeIdGenerator implements IdGenerator {
  FakeIdGenerator({this.prefix = 'id'});

  final String prefix;
  int _counter = 0;

  @override
  String newId() => '$prefix-${++_counter}';
}
