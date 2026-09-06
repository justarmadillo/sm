/// Findings and outcomes from collection-level integrity repair.
library;

import 'package:meta/meta.dart';

enum DatabaseCheckOutcome { sound, repaired, corrupt }

/// One stable, countable condition found during a database check.
@immutable
final class DatabaseCheckFinding {
  const DatabaseCheckFinding({
    required this.name,
    required this.description,
    required this.count,
    required this.wasRepaired,
  });

  final String name;
  final String description;
  final int count;
  final bool wasRepaired;
}

/// Complete result of one atomic check and repair pass.
@immutable
final class DatabaseCheckReport {
  const DatabaseCheckReport({
    required this.outcome,
    required this.findings,
    this.corruption = const <String>[],
  });

  final DatabaseCheckOutcome outcome;
  final List<DatabaseCheckFinding> findings;
  final List<String> corruption;

  bool get isEmpty => findings.isEmpty;
}

abstract interface class DatabaseCheck {
  /// Checks physical health first, then repairs logical damage atomically.
  Future<DatabaseCheckReport> repairIntegrity();
}
