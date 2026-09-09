/// The one storage form for an instant: milliseconds since the Unix epoch, UTC.
///
/// Rows, snapshot JSON, and the SM-20 runtime state all keep instants as a
/// plain integer. Reading one back has to say `isUtc: true` or Dart hands out a
/// local-time [DateTime] that compares wrong against every stored neighbour, so
/// the rule lives here rather than being spelled out again in each layer that
/// decodes a row.
library;

/// Milliseconds since the Unix epoch, the storage form for every instant.
int toEpochMs(DateTime instant) => instant.toUtc().millisecondsSinceEpoch;

/// A UTC instant from stored milliseconds.
DateTime fromEpochMs(int value) =>
    DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
