/// Cold restoration of a validated database backup and its image assets.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/files/backup_service.dart';
import 'package:incremental_reader/storage/files/source_asset_file_store.dart';
import 'package:path/path.dart' as p;

/// Restores backups while no Drift database or provider graph exists.
final class BackupRestoreService {
  BackupRestoreService({
    required File databaseFile,
    required Directory assetDirectory,
  }) : _databaseFile = databaseFile,
       _assetFiles = SourceAssetFileStore(assetDirectory: assetDirectory);

  /// Derives the standard database and asset paths without exposing storage
  /// layout details to the recovery screen.
  factory BackupRestoreService.fromBackupDirectory(Directory backupDirectory) {
    final Directory root = backupDirectory.parent;
    return BackupRestoreService(
      databaseFile: File(p.join(root.path, 'db', kDatabaseFileName)),
      assetDirectory: Directory(p.join(root.path, 'assets')),
    );
  }

  final File _databaseFile;
  final SourceAssetFileStore _assetFiles;

  /// Validates all package content before exposing any of it to the app.
  ///
  /// Assets are promoted before the database because an unused asset is safe
  /// to sweep later, while a database row that names a missing asset is not.
  Future<Result<Unit>> restore(File backupFile) async {
    final String stamp = _stampFromBackup(backupFile);
    final File staging = File(
      p.join(_databaseFile.parent.path, 'restore-$stamp.sqlite.partial'),
    );
    try {
      _databaseFile.parent.createSync(recursive: true);
      _deleteIfPresent(staging);
      final List<_VerifiedAsset> assets = backupFile.path.endsWith('.irbackup')
          ? await _extractPackage(backupFile, staging)
          : await _stageDatabaseOnlyBackup(backupFile, staging);

      final String? databaseProblem = validateDatabaseFile(staging);
      if (databaseProblem != null) throw StateError(databaseProblem);
      for (final _VerifiedAsset asset in assets) {
        await _assetFiles.saveBytes(asset.bytes);
      }
      _promoteDatabase(staging);
      return okUnit;
    } on Object catch (error, stackTrace) {
      _deleteIfPresent(staging);
      return Err<Unit>(
        StorageFailure(
          'could not restore backup',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<List<_VerifiedAsset>> _extractPackage(
    File packageFile,
    File staging,
  ) async {
    final Archive archive = ZipDecoder().decodeBytes(
      await packageFile.readAsBytes(),
      verify: true,
    );
    final Map<String, ArchiveFile> entries = <String, ArchiveFile>{
      for (final ArchiveFile entry in archive.files)
        if (entry.isFile) entry.name: entry,
    };
    final ArchiveFile databaseEntry = _requiredEntry(
      entries,
      'collection.sqlite',
    );
    final ArchiveFile manifestEntry = _requiredEntry(entries, 'manifest.json');
    final Map<String, Object?> manifest =
        jsonDecode(utf8.decode(manifestEntry.readBytes()!))
            as Map<String, Object?>;
    if (manifest['formatVersion'] != 1) {
      throw const FormatException('unsupported backup format');
    }
    final Map<String, Object?> database =
        manifest['database']! as Map<String, Object?>;
    final Uint8List databaseBytes = databaseEntry.readBytes()!;
    if (database['path'] != 'collection.sqlite' ||
        database['bytes'] != databaseBytes.length) {
      throw const FormatException('database manifest does not match package');
    }

    final List<_VerifiedAsset> assets = <_VerifiedAsset>[];
    for (final Object? rawAsset in manifest['assets']! as List<Object?>) {
      final Map<String, Object?> asset = rawAsset! as Map<String, Object?>;
      final String expectedSha256 = asset['sha256']! as String;
      final String path = asset['path']! as String;
      if (path != 'assets/$expectedSha256') {
        throw const FormatException('asset path does not match its hash');
      }
      final Uint8List bytes = _requiredEntry(entries, path).readBytes()!;
      if (asset['bytes'] != bytes.length ||
          sha256.convert(bytes).toString() != expectedSha256) {
        throw const FormatException('asset manifest does not match package');
      }
      assets.add(_VerifiedAsset(bytes));
    }
    await staging.writeAsBytes(databaseBytes, flush: true);
    return assets;
  }

  Future<List<_VerifiedAsset>> _stageDatabaseOnlyBackup(
    File backupFile,
    File staging,
  ) async {
    await backupFile.copy(staging.path);
    return const <_VerifiedAsset>[];
  }

  void _promoteDatabase(File staging) {
    if (_databaseFile.existsSync()) {
      _databaseFile.renameSync(_availableSupersededPath());
    }
    _deleteIfPresent(File('${_databaseFile.path}-wal'));
    _deleteIfPresent(File('${_databaseFile.path}-shm'));
    staging.renameSync(_databaseFile.path);
  }

  String _availableSupersededPath() {
    final String base = '${_databaseFile.path}.superseded';
    if (!File(base).existsSync()) return base;
    var suffix = 1;
    while (File('$base.$suffix').existsSync()) {
      suffix++;
    }
    return '$base.$suffix';
  }
}

ArchiveFile _requiredEntry(Map<String, ArchiveFile> entries, String name) {
  final ArchiveFile? entry = entries[name];
  if (entry == null) throw FormatException('backup is missing $name');
  return entry;
}

String _stampFromBackup(File file) {
  final RegExpMatch? match = RegExp(
    r'-(\d{14})\.(?:irbackup|sqlite)$',
  ).firstMatch(p.basename(file.path));
  return match?.group(1) ?? 'unknown';
}

void _deleteIfPresent(File file) {
  if (file.existsSync()) file.deleteSync();
}

final class _VerifiedAsset {
  const _VerifiedAsset(this.bytes);

  final Uint8List bytes;
}
