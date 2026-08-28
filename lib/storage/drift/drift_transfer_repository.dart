/// Saves and loads this collection's identity and lineage, using Drift.
///
/// SQL and row mapping, nothing else. No repository decides an interval, a
/// lifecycle transition, or whether an operation is allowed -- those are the
/// command runners' and the schedulers' jobs. A repository that starts making
/// policy is how scheduling rules end up spread across three folders.
library;

import 'package:drift/drift.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/dataset_lineage.dart';

/// Dataset identity and lineage.
final class DriftTransferRepository implements TransferRepository {
  const DriftTransferRepository(this._database, this._ids, this._deviceId);

  final AppDatabase _database;
  final IdGenerator _ids;
  final String _deviceId;

  @override
  Future<DatasetIdentity> currentIdentity() async {
    final row = await (_database.select(
      _database.datasetMeta,
    )..where(($DatasetMetaTable t) => t.id.equals(1))).getSingleOrNull();
    if (row != null) {
      return DatasetIdentity(
        datasetId: row.datasetId,
        generation: row.generation,
        writerEpoch: row.writerEpoch,
        ownerDeviceId: row.ownerDeviceId,
      );
    }
    // First write on a fresh database establishes the lineage.
    final created = DatasetIdentity(
      datasetId: _ids.newId(),
      generation: 0,
      writerEpoch: 1,
      ownerDeviceId: _deviceId,
    );
    await saveIdentity(created);
    return created;
  }

  @override
  Future<void> saveIdentity(DatasetIdentity identity) => _database
      .into(_database.datasetMeta)
      .insertOnConflictUpdate(
        DatasetMetaCompanion.insert(
          id: const Value<int>(1),
          datasetId: identity.datasetId,
          generation: identity.generation,
          writerEpoch: identity.writerEpoch,
          ownerDeviceId: identity.ownerDeviceId,
        ),
      );

  @override
  Future<DatasetIdentity> advanceGeneration() async {
    final next = (await currentIdentity()).advanced();
    await saveIdentity(next);
    return next;
  }
}
