/// Verifies complete, validated restoration of database backup packages.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/files/backup_restore_service.dart';
import 'package:incremental_reader/storage/files/backup_service.dart';
import 'package:incremental_reader/storage/files/source_asset_file_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir_backup_restore_test_');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  test('restores rows and assets and removes stale WAL siblings', () async {
    final File sourceFile = File('${workspace.path}/source.sqlite');
    final sourceDatabase = openDatabaseAt(sourceFile);
    await sourceDatabase.customStatement(
      "INSERT INTO settings (key, value) VALUES ('answer', 'before')",
    );
    final SourceAssetFileStore sourceAssets = SourceAssetFileStore(
      assetDirectory: Directory('${workspace.path}/source-assets'),
    );
    final stored = await sourceAssets.saveBytes(
      Uint8List.fromList(<int>[2, 4, 6, 8]),
    );
    final BackupService backups = BackupService(
      database: sourceDatabase,
      backupDirectory: Directory('${workspace.path}/backups'),
      assetDirectory: sourceAssets.directory,
      listReferencedAssets: () async => <BackupAssetReference>[
        BackupAssetReference(sha256: stored.sha256),
      ],
      clock: FakeClock(DateTime.utc(2026, 6, 7, 8, 9, 10)),
    );
    final File package = (await backups.createBackup()).unwrap();
    await sourceDatabase.close();

    final File target = File('${workspace.path}/db/$kDatabaseFileName')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(<int>[1, 2, 3]);
    File('${target.path}-wal').writeAsBytesSync(<int>[9]);
    File('${target.path}-shm').writeAsBytesSync(<int>[9]);
    final Directory targetAssets = Directory('${workspace.path}/assets');

    final result = await BackupRestoreService(
      databaseFile: target,
      assetDirectory: targetAssets,
    ).restore(package);

    expect(result.isOk, isTrue);
    expect(File('${target.path}-wal').existsSync(), isFalse);
    expect(File('${target.path}-shm').existsSync(), isFalse);
    expect(File('${target.path}.superseded').existsSync(), isTrue);
    expect(
      File('${targetAssets.path}/${stored.sha256}').readAsBytesSync(),
      <int>[2, 4, 6, 8],
    );
    final restored = openDatabaseAt(target);
    addTearDown(restored.close);
    final row = await restored
        .customSelect("SELECT value FROM settings WHERE key = 'answer'")
        .getSingle();
    expect(row.read<String>('value'), 'before');
  });

  test('rejects a manifest whose database length was changed', () async {
    final File sourceFile = File('${workspace.path}/source.sqlite');
    final sourceDatabase = openDatabaseAt(sourceFile);
    await sourceDatabase.customSelect('SELECT 1').get();
    final File package = (await BackupService(
      database: sourceDatabase,
      backupDirectory: Directory('${workspace.path}/backups'),
      clock: FakeClock(DateTime.utc(2026, 6, 7, 8, 9, 10)),
    ).createBackup()).unwrap();
    await sourceDatabase.close();
    final Archive archive = ZipDecoder().decodeBytes(package.readAsBytesSync());
    final ArchiveFile manifestEntry = archive.files.singleWhere(
      (ArchiveFile entry) => entry.name == 'manifest.json',
    );
    final Map<String, Object?> manifest =
        jsonDecode(utf8.decode(manifestEntry.readBytes()!))
            as Map<String, Object?>;
    (manifest['database']! as Map<String, Object?>)['bytes'] = 1;
    archive.removeFile(manifestEntry);
    archive.addFile(
      ArchiveFile.bytes('manifest.json', utf8.encode(jsonEncode(manifest))),
    );
    final File tampered = File('${workspace.path}/tampered.irbackup');
    tampered.writeAsBytesSync(ZipEncoder().encode(archive));
    final File target = File('${workspace.path}/db/$kDatabaseFileName');

    final result = await BackupRestoreService(
      databaseFile: target,
      assetDirectory: Directory('${workspace.path}/assets'),
    ).restore(tampered);

    expect(result.isErr, isTrue);
    expect(target.existsSync(), isFalse);
  });
}
