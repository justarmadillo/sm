/// Drift-backed storage for source image metadata.
library;

import 'package:drift/drift.dart';
import 'package:incremental_reader/documents/source_asset.dart';
import 'package:incremental_reader/storage/contracts/source_asset_repository.dart';
import 'package:incremental_reader/storage/database/app_database.dart';

/// Keeps [SourceAssetRepository]'s promise in the application database.
final class DriftSourceAssetRepository implements SourceAssetRepository {
  const DriftSourceAssetRepository(this._database);

  final AppDatabase _database;

  @override
  Future<SourceAsset?> findSourceAsset(String id) async {
    final QueryRow? row = await _database
        .customSelect(
          'SELECT * FROM source_assets WHERE id = ?',
          variables: <Variable<Object>>[Variable<String>(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _sourceAssetFromRow(row);
  }

  @override
  Future<SourceAsset?> findSourceAssetByReference(
    String sourceId,
    String srcRef,
  ) async {
    final QueryRow? row = await _database
        .customSelect(
          'SELECT * FROM source_assets WHERE source_id = ? AND src_ref = ?',
          variables: <Variable<Object>>[
            Variable<String>(sourceId),
            Variable<String>(srcRef),
          ],
        )
        .getSingleOrNull();
    return row == null ? null : _sourceAssetFromRow(row);
  }

  @override
  Future<List<SourceAsset>> listSourceAssets(String sourceId) =>
      _listSourceAssets(
        'SELECT * FROM source_assets WHERE source_id = ? '
        'ORDER BY imported_at_utc, id',
        <Variable<Object>>[Variable<String>(sourceId)],
      );

  @override
  Future<List<SourceAsset>> listSourceAssetsBySha256(String sha256) =>
      _listSourceAssets(
        'SELECT * FROM source_assets WHERE sha256 = ? '
        'ORDER BY imported_at_utc, id',
        <Variable<Object>>[Variable<String>(sha256)],
      );

  @override
  Future<List<String>> listAvailableSourceAssetSha256Values() async {
    final List<QueryRow> rows = await _database
        .customSelect(
          'SELECT DISTINCT sha256 FROM source_assets WHERE state = 0 '
          'ORDER BY sha256',
        )
        .get();
    return <String>[
      for (final QueryRow row in rows) row.read<String>('sha256'),
    ];
  }

  @override
  Future<int> countSourceAssets(String sourceId) => _countSourceAssets(
    'SELECT COUNT(*) AS asset_count FROM source_assets WHERE source_id = ?',
    Variable<String>(sourceId),
  );

  @override
  Future<int> countSourceAssetsBySha256(String sha256) => _countSourceAssets(
    'SELECT COUNT(*) AS asset_count FROM source_assets WHERE sha256 = ?',
    Variable<String>(sha256),
  );

  @override
  Future<void> insertSourceAsset(SourceAsset asset) =>
      _database.customStatement(
        'INSERT INTO source_assets (id, source_id, src_ref, sha256, mime, '
        'width_px, height_px, byte_size, state, imported_at_utc) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          asset.id,
          asset.sourceId,
          asset.srcRef,
          asset.sha256,
          asset.mime,
          asset.widthPx,
          asset.heightPx,
          asset.byteSize,
          asset.state.index,
          asset.importedAtUtc.millisecondsSinceEpoch,
        ],
      );

  @override
  Future<void> deleteSourceAsset(String id) => _database.customStatement(
    'DELETE FROM source_assets WHERE id = ?',
    <Object?>[id],
  );

  Future<List<SourceAsset>> _listSourceAssets(
    String statement,
    List<Variable<Object>> variables,
  ) async {
    final List<QueryRow> rows = await _database
        .customSelect(statement, variables: variables)
        .get();
    return <SourceAsset>[
      for (final QueryRow row in rows) _sourceAssetFromRow(row),
    ];
  }

  Future<int> _countSourceAssets(
    String statement,
    Variable<Object> variable,
  ) async {
    final QueryRow row = await _database
        .customSelect(statement, variables: <Variable<Object>>[variable])
        .getSingle();
    return row.read<int>('asset_count');
  }
}

SourceAsset _sourceAssetFromRow(QueryRow row) => SourceAsset(
  id: row.read<String>('id'),
  sourceId: row.read<String>('source_id'),
  srcRef: row.read<String>('src_ref'),
  sha256: row.read<String>('sha256'),
  mime: row.read<String>('mime'),
  widthPx: row.read<int>('width_px'),
  heightPx: row.read<int>('height_px'),
  byteSize: row.read<int>('byte_size'),
  state: SourceAssetState.values[row.read<int>('state')],
  importedAtUtc: DateTime.fromMillisecondsSinceEpoch(
    row.read<int>('imported_at_utc'),
    isUtc: true,
  ),
);
