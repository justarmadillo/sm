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
      _tryDelete(staging);
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
    final String supersededPath = _availableSupersededPath();
    final List<_DisplacedFile> displacedSidecars = <_DisplacedFile>[];
    File? supersededDatabase;
    try {
      for (final String suffix in <String>['-wal', '-shm']) {
        final File sidecar = File('${_databaseFile.path}$suffix');
        if (!sidecar.existsSync()) continue;
        displacedSidecars.add(
          _DisplacedFile(
            originalPath: sidecar.path,
            displaced: sidecar.renameSync('$supersededPath$suffix'),
          ),
        );
      }
      if (_databaseFile.existsSync()) {
        supersededDatabase = _databaseFile.renameSync(supersededPath);
      }
      staging.renameSync(_databaseFile.path);
    } on Object catch (error, stackTrace) {
      final Object? rollbackError = _rollbackPromotion(
        staging: staging,
        supersededDatabase: supersededDatabase,
        displacedSidecars: displacedSidecars,
      );
      if (rollbackError != null) {
        throw StateError(
          'database promotion failed ($error) and rollback failed '
          '($rollbackError)',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    for (final _DisplacedFile sidecar in displacedSidecars) {
      _tryDelete(sidecar.displaced);
    }
  }

  /// Restores displaced database files without abandoning later cleanup when
  /// one rollback step itself fails.
  Object? _rollbackPromotion({
    required File staging,
    required File? supersededDatabase,
    required List<_DisplacedFile> displacedSidecars,
  }) {
    Object? firstError;

    void attempt(void Function() action) {
      try {
        action();
      } on Object catch (error) {
        firstError ??= error;
      }
    }

    bool exists(File file) {
      try {
        return file.existsSync();
      } on Object catch (error) {
        firstError ??= error;
        return false;
      }
    }

    if (supersededDatabase != null && exists(_databaseFile)) {
      attempt(() {
        _deleteIfPresent(staging);
        _databaseFile.renameSync(staging.path);
      });
    }
    if (supersededDatabase != null && !exists(_databaseFile)) {
      attempt(() => supersededDatabase.renameSync(_databaseFile.path));
    }
    for (final _DisplacedFile sidecar in displacedSidecars.reversed) {
      if (!exists(sidecar.displaced) || exists(File(sidecar.originalPath))) {
        continue;
      }
      attempt(() => sidecar.displaced.renameSync(sidecar.originalPath));
    }
    return firstError;
  }

  String _availableSupersededPath() {
    final String base = '${_databaseFile.path}.superseded';
    if (_isSupersededPathAvailable(base)) return base;
    var suffix = 1;
    while (!_isSupersededPathAvailable('$base.$suffix')) {
      suffix++;
    }
    return '$base.$suffix';
  }

  bool _isSupersededPathAvailable(String path) =>
      !File(path).existsSync() &&
      !File('$path-wal').existsSync() &&
      !File('$path-shm').existsSync();
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

void _tryDelete(File file) {
  try {
    _deleteIfPresent(file);
  } on FileSystemException {
    // Best-effort cleanup must not mask the restoration result.
  }
}

final class _DisplacedFile {
  const _DisplacedFile({required this.originalPath, required this.displaced});

  final String originalPath;
  final File displaced;
}

final class _VerifiedAsset {
  const _VerifiedAsset(this.bytes);

  final Uint8List bytes;
}
