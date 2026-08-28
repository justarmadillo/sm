/// One identifier that follows a single user action all the way down.
///
/// The screen creates it, the command carries it, and every row and log
/// line the action writes records it, so a failure the user reports can be
/// traced from the button they pressed to the query that failed.
library;

import 'package:meta/meta.dart';

/// Correlates one user-initiated operation across every layer.
@immutable
final class OperationId {
  const OperationId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is OperationId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
