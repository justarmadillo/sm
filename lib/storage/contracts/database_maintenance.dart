/// What the app promises about keeping the database file in good shape.
///
/// Everything here is repair and housekeeping: it rewrites how rows are
/// stored, never which rows exist. A collection that has been imported into,
/// extracted from and postponed for a year holds free pages SQLite will reuse
/// but never hand back, query plans built from stale statistics, and a
/// full-text index spread over more segments than it needs. None of that is
/// wrong, so nothing reports it — it just gets slower.
library;

import 'package:meta/meta.dart';

/// What one maintenance pass found and how much it recovered.
@immutable
final class DatabaseMaintenanceReport {
  const DatabaseMaintenanceReport({
    required this.bytesBefore,
    required this.bytesAfter,
    required this.problems,
    required this.wasSearchIndexRebuilt,
  });

  /// Size of the database file before the pass, in bytes.
  final int bytesBefore;

  /// Size after it, in bytes.
  final int bytesAfter;

  /// What `PRAGMA integrity_check` and the search index reported, when either
  /// reported anything other than health. Empty means the collection is sound.
  ///
  /// Held rather than thrown: a corrupt page is something the user has to be
  /// told about, and a pass that refuses to say what it found is worse than
  /// one that finds nothing.
  final List<String> problems;

  /// Whether the full-text index had to be rebuilt from its content table.
  ///
  /// Worth reporting on its own: the index is derived, so a rebuild is a
  /// silent repair the user would otherwise never know had been needed.
  final bool wasSearchIndexRebuilt;

  /// Bytes the file gave back. Never negative: rewriting a heavily fragmented
  /// database can leave it fractionally larger, and reporting "−4 KB
  /// reclaimed" would read as a fault rather than a rounding.
  int get bytesReclaimed =>
      bytesBefore > bytesAfter ? bytesBefore - bytesAfter : 0;

  /// Whether the collection reported itself sound.
  bool get isHealthy => problems.isEmpty;
}

/// Housekeeping over the whole database file.
abstract interface class DatabaseMaintenance {
  /// Checks the collection, repairs what is derived, and compacts the file.
  ///
  /// Safe to run at any time and safe to interrupt: every step either
  /// completes or leaves the previous state, because none of them is the only
  /// copy of anything.
  Future<DatabaseMaintenanceReport> optimize();
}
