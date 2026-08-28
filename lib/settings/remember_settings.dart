/// What happens to an element the user chooses to remember again.///
/// Mirrors the controls described by `SM20_AIO_SCHEDULER.md`.
library;

import 'package:meta/meta.dart';

/// The first-interval range used by the browser Remember command.
@immutable
final class RememberSettings {
  const RememberSettings({
    this.firstIntervalLowDays = 1,
    this.firstIntervalHighDays = 1,
  });

  /// Inclusive lower endpoint of the initial interval range.
  final int firstIntervalLowDays;

  /// Inclusive upper endpoint. Zero requests the generated-interval path.
  final int firstIntervalHighDays;

  RememberSettings copyWith({
    int? firstIntervalLowDays,
    int? firstIntervalHighDays,
  }) => RememberSettings(
    firstIntervalLowDays: firstIntervalLowDays ?? this.firstIntervalLowDays,
    firstIntervalHighDays: firstIntervalHighDays ?? this.firstIntervalHighDays,
  );

  @override
  bool operator ==(Object other) =>
      other is RememberSettings &&
      other.firstIntervalLowDays == firstIntervalLowDays &&
      other.firstIntervalHighDays == firstIntervalHighDays;

  @override
  int get hashCode => Object.hash(firstIntervalLowDays, firstIntervalHighDays);
}
