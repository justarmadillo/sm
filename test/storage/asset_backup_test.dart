/// Verifies portable daily backup packages containing image assets.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/files/backup_service.dart';
import 'package:incremental_reader/storage/files/source_asset_file_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir_asset_backup_test_');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  test(
    'packages the database, manifest, and verified assets',
    () async {
      final database = openDatabaseAt(
        File('${workspace.path}/db/$kDatabaseFileName'),
      );
      addTearDown(database.close);
      await database.customSelect('SELECT 1').get();

      final assetStore = SourceAssetFileStore(
        assetDirectory: Directory('${workspace.path}/assets'),
      );
      final stored = await assetStore.saveBytes(
        Uint8List.fromList(<int>[1, 3, 3, 7]),
      );
      final missingSha256 = 'f' * 64;
      final service = BackupService(
        database: database,
        backupDirectory: Directory('${workspace.path}/backups'),
        assetDirectory: assetStore.directory,
        listReferencedAssets: () async => <BackupAssetReference>[
          BackupAssetReference(sha256: stored.sha256),
          BackupAssetReference(sha256: stored.sha256),
          BackupAssetReference(sha256: missingSha256),
        ],
        clock: FakeClock(DateTime.utc(2026, 3, 5, 9)),
      );

      final package = (await service.createBackup()).unwrap();

      expect(package.path, endsWith('backup-20260305090000.irbackup'));
      final archive = ZipDecoder().decodeBytes(package.readAsBytesSync());
      final names = archive.files.map((entry) => entry.name).toList();
      expect(names, <String>[
        'collection.sqlite',
        'manifest.json',
        'assets/${stored.sha256}',
      ]);
      final manifestEntry = archive.files.singleWhere(
        (entry) => entry.name == 'manifest.json',
      );
      final manifest =
          jsonDecode(utf8.decode(manifestEntry.readBytes()!))
              as Map<String, Object?>;
      expect(manifest['assets'], hasLength(1));
      expect(
        (manifest['database']! as Map<String, Object?>)['sha256'],
        sha256
            .convert(
              archive.files
                  .singleWhere((entry) => entry.name == 'collection.sqlite')
                  .readBytes()!,
            )
            .toString(),
      );
      expect(manifest['missingAssets'], <Map<String, Object?>>[
        <String, Object?>{
          'sha256': missingSha256,
          'problem': 'file is missing',
        },
      ]);
      expect(
        service.directory.listSync().where(
          (entity) => entity.path.endsWith('.partial'),
        ),
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'manual export does not enter rolling backup retention',
    () async {
      final database = openDatabaseAt(
        File('${workspace.path}/db/$kDatabaseFileName'),
      );
      addTearDown(database.close);
      await database.customSelect('SELECT 1').get();
      final BackupService service = BackupService(
        database: database,
        backupDirectory: Directory('${workspace.path}/backups'),
        clock: FakeClock(DateTime.utc(2026, 3, 5, 9)),
      );
      final File destination = File(
        '${workspace.path}/exports/reader.irbackup',
      );

      final CollectionExportReport report = (await service.exportCollection(
        target: destination,
      )).unwrap();

      expect(report.file.path, destination.path);
      expect(destination.existsSync(), isTrue);
      expect(service.listBackups(), isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'pre-import packages have independent retention',
    () async {
      final database = openDatabaseAt(
        File('${workspace.path}/db/$kDatabaseFileName'),
      );
      addTearDown(database.close);
      await database.customSelect('SELECT 1').get();
      final FakeClock clock = FakeClock(DateTime.utc(2026, 3, 5, 9));
      final BackupService service = BackupService(
        database: database,
        backupDirectory: Directory('${workspace.path}/backups'),
        clock: clock,
        retention: const BackupRetention(preImport: 2),
      );

      for (var backupNumber = 0; backupNumber < 3; backupNumber++) {
        expect(
          (await service.createBackup(type: BackupType.preImport)).isOk,
          isTrue,
        );
        clock.advance(const Duration(seconds: 1));
      }

      expect(service.listBackups(type: BackupType.preImport), hasLength(2));
      expect(service.listBackups(type: BackupType.daily), isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('lists legacy database-only daily backups beside packages', () async {
    final backupDirectory = Directory('${workspace.path}/backups')
      ..createSync(recursive: true);
    final database = openDatabaseAt(
      File('${workspace.path}/db/$kDatabaseFileName'),
    );
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();
    File(
      '${backupDirectory.path}/backup-20260201090000.sqlite',
    ).writeAsBytesSync(<int>[1]);
    File(
      '${backupDirectory.path}/backup-20260301090000.irbackup',
    ).writeAsBytesSync(<int>[1]);

    final service = BackupService(
      database: database,
      backupDirectory: backupDirectory,
      clock: FakeClock(DateTime.utc(2026, 3, 5, 9)),
    );

    expect(
      service
          .listBackups(type: BackupType.daily)
          .map((file) => file.path.split(RegExp(r'[/\\]')).last),
      <String>[
        'backup-20260301090000.irbackup',
        'backup-20260201090000.sqlite',
      ],
    );
  });
}
