/// Identity and lineage of one collection's data.
///
/// v1 has a single device and never exercises handoff, but the fields cost
/// almost nothing now and a schema migration over real review history later
/// costs a great deal. Recording them from the first write means v1.1 can add
/// the exclusive-handoff protocol without migrating anything.
library;

import 'package:meta/meta.dart';

/// Who owns a dataset and how far it has advanced.
@immutable
final class DatasetIdentity {
  const DatasetIdentity({
    required this.datasetId,
    required this.generation,
    required this.writerEpoch,
    required this.ownerDeviceId,
  });

  /// Stable identity of the collection, preserved across export and import.
  final String datasetId;

  /// Incremented by every domain transaction. Lets a copy be recognized as
  /// behind, ahead, or diverged.
  final int generation;

  /// Incremented when write ownership moves to another device. Only the
  /// current epoch's writer may mutate.
  final int writerEpoch;

  /// Device currently holding write ownership.
  final String ownerDeviceId;

  /// The same dataset one transaction later.
  DatasetIdentity advanced() => DatasetIdentity(
    datasetId: datasetId,
    generation: generation + 1,
    writerEpoch: writerEpoch,
    ownerDeviceId: ownerDeviceId,
  );

  /// Whether [other] is the same dataset as this one.
  bool isSameDataset(DatasetIdentity other) => other.datasetId == datasetId;

  /// Whether this copy may be written to by [deviceId].
  bool isWritableBy(String deviceId) => ownerDeviceId == deviceId;

  @override
  bool operator ==(Object other) =>
      other is DatasetIdentity &&
      other.datasetId == datasetId &&
      other.generation == generation &&
      other.writerEpoch == writerEpoch &&
      other.ownerDeviceId == ownerDeviceId;

  @override
  int get hashCode =>
      Object.hash(datasetId, generation, writerEpoch, ownerDeviceId);

  @override
  String toString() =>
      'DatasetIdentity($datasetId gen=$generation epoch=$writerEpoch '
      'owner=$ownerDeviceId)';
}
