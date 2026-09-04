/// Source-image schema, migration, and repository contract tests.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:incremental_reader/documents/source_asset.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/drift/drift_source_asset_repository.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir-source-assets-');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  Future<AppDatabase> openFileDatabase() async {
    final AppDatabase database = openDatabaseAt(
      File('${workspace.path}/db/$kDatabaseFileName'),
    );
    await database.customSelect('SELECT 1').getSingle();
    return database;
  }

  Future<void> insertSource(AppDatabase database, String id) =>
      database.customStatement(
        'INSERT INTO sources (id, title, markdown, content_hash, word_count, '
        'imported_at_utc) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[id, 'Fixture', '# Fixture', 'a' * 64, 1, 0],
      );

  SourceAsset asset({
    String id = 'asset-1',
    String sourceId = 'source-1',
    String? srcRef,
    String sha256 = '',
  }) => SourceAsset(
    id: id,
    sourceId: sourceId,
    srcRef: srcRef ?? 'ir-asset:${'b' * 64}',
    sha256: sha256.isEmpty ? 'b' * 64 : sha256,
    mime: 'image/png',
    widthPx: 640,
    heightPx: 480,
    byteSize: 2048,
    state: SourceAssetState.ok,
    importedAtUtc: DateTime.utc(2026, 9),
  );

  test('v14 collection gains the empty source-assets table', () async {
    final AppDatabase seeded = await openFileDatabase();
    await insertSource(seeded, 'source-before-upgrade');
    await seeded.customStatement('DROP TABLE source_assets');
    await seeded.customStatement('PRAGMA user_version = 14');
    await seeded.close();

    final AppDatabase upgraded = await openFileDatabase();
    addTearDown(upgraded.close);

    final QueryRow source = await upgraded
        .customSelect(
          "SELECT title FROM sources WHERE id = 'source-before-upgrade'",
        )
        .getSingle();
    expect(source.read<String>('title'), 'Fixture');
    final QueryRow version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 16);
    expect(
      await upgraded.customSelect('SELECT * FROM source_assets').get(),
      isEmpty,
    );
  });

  test('repository round-trips and deletes source asset metadata', () async {
    final AppDatabase database = await openFileDatabase();
    addTearDown(database.close);
    await insertSource(database, 'source-1');
    final DriftSourceAssetRepository repository = DriftSourceAssetRepository(
      database,
    );
    final SourceAsset expected = asset();

    await repository.insertSourceAsset(expected);

    expect(await repository.findSourceAsset(expected.id), expected);
    expect(
      await repository.findSourceAssetByReference(
        expected.sourceId,
        expected.srcRef,
      ),
      expected,
    );
    expect(await repository.listSourceAssets(expected.sourceId), <SourceAsset>[
      expected,
    ]);
    expect(
      await repository.listSourceAssetsBySha256(expected.sha256),
      <SourceAsset>[expected],
    );
    expect(await repository.countSourceAssets(expected.sourceId), 1);
    expect(await repository.countSourceAssetsBySha256(expected.sha256), 1);
    expect(await repository.listAvailableSourceAssetSha256Values(), <String>[
      expected.sha256,
    ]);

    await repository.deleteSourceAsset(expected.id);
    expect(await repository.findSourceAsset(expected.id), isNull);
  });

  test('identical blobs can be referenced by several sources', () async {
    final AppDatabase database = await openFileDatabase();
    addTearDown(database.close);
    await insertSource(database, 'source-1');
    await insertSource(database, 'source-2');
    final DriftSourceAssetRepository repository = DriftSourceAssetRepository(
      database,
    );

    await repository.insertSourceAsset(asset());
    await repository.insertSourceAsset(
      asset(id: 'asset-2', sourceId: 'source-2'),
    );

    expect(await repository.countSourceAssetsBySha256('b' * 64), 2);
  });

  test('source deletion cascades to its image references', () async {
    final AppDatabase database = await openFileDatabase();
    addTearDown(database.close);
    await insertSource(database, 'source-1');
    final DriftSourceAssetRepository repository = DriftSourceAssetRepository(
      database,
    );
    await repository.insertSourceAsset(asset());

    await database.customStatement("DELETE FROM sources WHERE id = 'source-1'");

    expect(await repository.countSourceAssets('source-1'), 0);
  });

  test('constraints reject duplicate references and unsafe hashes', () async {
    final AppDatabase database = await openFileDatabase();
    addTearDown(database.close);
    await insertSource(database, 'source-1');
    final DriftSourceAssetRepository repository = DriftSourceAssetRepository(
      database,
    );
    await repository.insertSourceAsset(asset());

    await expectLater(
      repository.insertSourceAsset(asset(id: 'asset-2')),
      throwsA(isA<Object>()),
    );
    await expectLater(
      database.customStatement(
        'INSERT INTO source_assets (id, source_id, src_ref, sha256, mime, '
        'width_px, height_px, byte_size, state, imported_at_utc) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          'asset-unsafe',
          'source-1',
          'ir-asset:unsafe',
          'B' * 64,
          'image/png',
          1,
          1,
          1,
          0,
          0,
        ],
      ),
      throwsA(isA<Object>()),
    );
  });

  test('domain rejects impossible dimensions and non-image MIME types', () {
    SourceAsset build({String mime = 'image/png', int widthPx = 1}) =>
        SourceAsset(
          id: 'asset',
          sourceId: 'source',
          srcRef: 'ir-asset:${'c' * 64}',
          sha256: 'c' * 64,
          mime: mime,
          widthPx: widthPx,
          heightPx: 1,
          byteSize: 1,
          state: SourceAssetState.ok,
          importedAtUtc: DateTime.utc(2026),
        );

    expect(() => build(widthPx: 0), throwsArgumentError);
    expect(() => build(mime: 'text/plain'), throwsArgumentError);
  });
}
