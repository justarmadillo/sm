/// What the app promises about this collection's identity and lineage.
///
/// Used to tell one exported dataset from another.
library;

import 'package:incremental_reader/storage/dataset_lineage.dart';

/// Dataset lineage, backups, and export snapshots.
abstract interface class TransferRepository {
  /// Current dataset identity, creating it on first use.
  Future<DatasetIdentity> currentIdentity();

  /// Records an advanced generation after a domain transaction.
  Future<void> saveIdentity(DatasetIdentity identity);

  /// Increments the generation counter and returns the new identity.
  Future<DatasetIdentity> advanceGeneration();
}
