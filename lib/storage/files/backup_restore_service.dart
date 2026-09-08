/// Stages and restores validated collection packages and their image assets.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/files/backup_service.dart';
import 'package:incremental_reader/storage/files/source_asset_file_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Human-readable facts established while a package is verified.
final class CollectionPackageSummary {
  const CollectionPackageSummary({
    required this.createdAtUtc,
    required this.schemaVersion,
    required this.databaseByteLength,
    required this.packageByteLength,
    required this.includedAssetCount,
    required this.missingAssetCount,
  });

  final DateTime createdAtUtc;
  final int schemaVersion;
  final int databaseByteLength;
  final int packageByteLength;
  final int includedAssetCount;
  final int missingAssetCount;
}

/// One verified image waiting to be moved into content-addressed storage.
final class StagedSourceAsset {
  const StagedSourceAsset({
    required this.file,
    required this.sha256,
    required this.byteLength,
  });

  final File file;
  final String sha256;
  final int byteLength;
}

/// A package that is safe to promote after the live Drift connection closes.
final class StagedCollectionPackage {
  const StagedCollectionPackage._({
    required this.directory,
    required this.databaseFile,
    required this.assets,
    required this.summary,
  });

  final Directory directory;
  final File databaseFile;
  final List<StagedSourceAsset> assets;
  final CollectionPackageSummary summary;

  /// Removes package files that were not promoted.
  Future<void> delete() async {
    try {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    } on FileSystemException {
      // A later startup cleanup can retry an abandoned staging directory.
    }
  }
}

/// Restores packages while keeping archive work separate from the live file.
final class BackupRestoreService {
  BackupRestoreService({
    required File databaseFile,
    required Directory assetDirectory,
    Clock clock = const SystemClock(),
  }) : _databaseFile = databaseFile,
       _assetFiles = SourceAssetFileStore(assetDirectory: assetDirectory),
       _clock = clock;

  /// Derives standard collection paths for recovery before providers exist.
  factory BackupRestoreService.fromBackupDirectory(Directory backupDirectory) {
    final Directory root = backupDirectory.parent;
    return BackupRestoreService(
      databaseFile: File(p.join(root.path, 'db', kDatabaseFileName)),
      assetDirectory: Directory(p.join(root.path, 'assets')),
    );
  }

  final File _databaseFile;
  final SourceAssetFileStore _assetFiles;
  final Clock _clock;

  /// Validates and migrates a package without changing the live collection.
  Future<Result<StagedCollectionPackage>> stagePackage(File packageFile) async {
    Directory? stagingDirectory;
    try {
      if (p.extension(packageFile.path).toLowerCase() != '.irbackup') {
        throw const FormatException('select an Incremental Reader package');
      }
      stagingDirectory = _createStagingDirectory(_stampFromBackup(packageFile));
      final StagedCollectionPackage staged = await _extractPackage(
        packageFile,
        stagingDirectory,
      );
      await _migrateStagedDatabase(staged.databaseFile);
      return Ok<StagedCollectionPackage>(staged);
    } on Object catch (error, stackTrace) {
      if (stagingDirectory != null) {
        await _deleteDirectoryIfPresent(stagingDirectory);
      }
      return Err<StagedCollectionPackage>(
        StorageFailure(
          'could not read collection package',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Promotes previously verified files while no Drift connection is open.
  Future<Result<Unit>> promote(StagedCollectionPackage staged) async {
    try {
      for (final StagedSourceAsset asset in staged.assets) {
        await _assetFiles.saveStagedFile(
          stagedFile: asset.file,
          expectedSha256: asset.sha256,
          expectedByteLength: asset.byteLength,
        );
      }
      _promoteDatabase(staged.databaseFile);
      await staged.delete();
      return okUnit;
    } on Object catch (error, stackTrace) {
      await staged.delete();
      return Err<Unit>(
        StorageFailure(
          'could not replace collection',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Restores either a package or a legacy database-only recovery backup.
  Future<Result<Unit>> restore(File backupFile) async {
    if (p.extension(backupFile.path).toLowerCase() == '.irbackup') {
      final Result<StagedCollectionPackage> staged = await stagePackage(
        backupFile,
      );
      if (staged.isErr) return Err<Unit>(staged.failureOrNull!);
      return promote(staged.unwrap());
    }

    Directory? stagingDirectory;
    try {
      stagingDirectory = _createStagingDirectory(_stampFromBackup(backupFile));
      final File databaseFile = File(
        p.join(stagingDirectory.path, 'collection.sqlite'),
      );
      await backupFile.copy(databaseFile.path);
      await _migrateStagedDatabase(databaseFile);
      return promote(
        StagedCollectionPackage._(
          directory: stagingDirectory,
          databaseFile: databaseFile,
          assets: const <StagedSourceAsset>[],
          summary: CollectionPackageSummary(
            createdAtUtc: _clock.nowUtc(),
            schemaVersion: kSchemaVersion,
            databaseByteLength: await databaseFile.length(),
            packageByteLength: await backupFile.length(),
            includedAssetCount: 0,
            missingAssetCount: 0,
          ),
        ),
      );
    } on Object catch (error, stackTrace) {
      if (stagingDirectory != null) {
        await _deleteDirectoryIfPresent(stagingDirectory);
      }
      return Err<Unit>(
        StorageFailure(
          'could not restore backup',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<StagedCollectionPackage> _extractPackage(
    File packageFile,
    Directory stagingDirectory,
  ) async {
    final InputFileStream input = InputFileStream(packageFile.path);
    late final Archive archive;
    final Set<String> decodedNames = <String>{};
    String? duplicateName;
    try {
      archive = ZipDecoder().decodeStream(
        input,
        verify: true,
        callback: (ArchiveFile entry) {
          if (entry.isFile && !decodedNames.add(entry.name)) {
            duplicateName ??= entry.name;
          }
        },
      );
    } finally {
      input.closeSync();
    }

    try {
      if (duplicateName != null) {
        throw FormatException('package contains duplicate $duplicateName');
      }
      final Map<String, ArchiveFile> entries = _fileEntries(archive);
      final _PackageDescription description = _readPackageDescription(entries);
      final File stagedDatabase = await _stageDatabase(
        entries: entries,
        description: description,
        stagingDirectory: stagingDirectory,
      );
      final List<StagedSourceAsset> stagedAssets = await _stageAssets(
        entries: entries,
        descriptions: description.assets,
        stagingDirectory: stagingDirectory,
      );
      _requireOnlyDeclaredEntries(entries, description.assets);
      return StagedCollectionPackage._(
        directory: stagingDirectory,
        databaseFile: stagedDatabase,
        assets: stagedAssets,
        summary: CollectionPackageSummary(
          createdAtUtc: description.createdAtUtc,
          schemaVersion: description.schemaVersion,
          databaseByteLength: description.databaseByteLength,
          packageByteLength: await packageFile.length(),
          includedAssetCount: stagedAssets.length,
          missingAssetCount: description.missingAssetCount,
        ),
      );
    } finally {
      archive.clearSync();
    }
  }

  _PackageDescription _readPackageDescription(
    Map<String, ArchiveFile> entries,
  ) {
    final ArchiveFile manifestEntry = _requiredEntry(entries, 'manifest.json');
    if (manifestEntry.size > 1024 * 1024) {
      throw const FormatException('package manifest is too large');
    }
    final Map<String, Object?> manifest = _jsonObject(
      jsonDecode(utf8.decode(manifestEntry.readBytes()!)),
      'manifest',
    );
    if (manifest['formatVersion'] != 1) {
      throw const FormatException('unsupported package format');
    }
    final Map<String, Object?> database = _jsonObject(
      manifest['database'],
      'database',
    );
    if (database['path'] != 'collection.sqlite') {
      throw const FormatException('database path does not match package');
    }
    return _PackageDescription(
      createdAtUtc: DateTime.parse(
        _jsonString(manifest['createdAtUtc'], 'createdAtUtc'),
      ).toUtc(),
      schemaVersion: _jsonInteger(database['schemaVersion'], 'schemaVersion'),
      databaseByteLength: _jsonInteger(database['bytes'], 'bytes'),
      databaseSha256: database['sha256'] as String?,
      assets: _readAssetDescriptions(manifest['assets']),
      missingAssetCount: _jsonList(
        manifest['missingAssets'],
        'missingAssets',
      ).length,
    );
  }

  Future<File> _stageDatabase({
    required Map<String, ArchiveFile> entries,
    required _PackageDescription description,
    required Directory stagingDirectory,
  }) async {
    final ArchiveFile entry = _requiredEntry(entries, 'collection.sqlite');
    if (entry.size != description.databaseByteLength) {
      throw const FormatException('database length does not match manifest');
    }
    final File stagedDatabase = File(
      p.join(stagingDirectory.path, 'collection.sqlite'),
    );
    _writeArchiveEntry(entry, stagedDatabase);
    if (description.databaseSha256 case final String expectedHash) {
      if (await _hashFile(stagedDatabase) != expectedHash) {
        throw const FormatException('database hash does not match manifest');
      }
    }
    if (_databaseSchemaVersion(stagedDatabase) != description.schemaVersion) {
      throw const FormatException('database schema does not match manifest');
    }
    return stagedDatabase;
  }

  Future<List<StagedSourceAsset>> _stageAssets({
    required Map<String, ArchiveFile> entries,
    required List<_AssetDescription> descriptions,
    required Directory stagingDirectory,
  }) async {
    final Directory assetDirectory = Directory(
      p.join(stagingDirectory.path, 'assets'),
    )..createSync(recursive: true);
    final List<StagedSourceAsset> stagedAssets = <StagedSourceAsset>[];
    for (final _AssetDescription description in descriptions) {
      final ArchiveFile entry = _requiredEntry(entries, description.entryPath);
      if (entry.size != description.byteLength) {
        throw FormatException(
          '${description.entryPath} length does not match manifest',
        );
      }
      final File file = File(p.join(assetDirectory.path, description.sha256));
      _writeArchiveEntry(entry, file);
      if (await _hashFile(file) != description.sha256) {
        throw FormatException(
          '${description.entryPath} hash does not match manifest',
        );
      }
      stagedAssets.add(
        StagedSourceAsset(
          file: file,
          sha256: description.sha256,
          byteLength: description.byteLength,
        ),
      );
    }
    return stagedAssets;
  }

  /// Runs existing migrations against the expendable staged copy first.
  Future<void> _migrateStagedDatabase(File stagedDatabase) async {
    final String? problem = validateDatabaseFile(stagedDatabase);
    if (problem != null) throw StateError(problem);
    if (_databaseSchemaVersion(stagedDatabase) < kSchemaVersion) {
      final AppDatabase database = openDatabaseAt(stagedDatabase);
      try {
        await database.customSelect('SELECT 1').get();
      } finally {
        await database.close();
      }
    }
    final String? migratedProblem = validateDatabaseFile(stagedDatabase);
    if (migratedProblem != null) throw StateError(migratedProblem);
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
      attempt(() => _databaseFile.renameSync(staging.path));
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

  Directory _createStagingDirectory(String stamp) {
    _databaseFile.parent.createSync(recursive: true);
    final String base = p.join(
      _databaseFile.parent.path,
      'collection-import-$stamp.partial',
    );
    var suffix = 0;
    while (true) {
      final Directory candidate = Directory(
        suffix == 0 ? base : '$base.$suffix',
      );
      if (!candidate.existsSync()) {
        candidate.createSync(recursive: true);
        return candidate;
      }
      suffix++;
    }
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

Map<String, ArchiveFile> _fileEntries(Archive archive) => <String, ArchiveFile>{
  for (final ArchiveFile entry in archive.files)
    if (entry.isFile) entry.name: entry,
};

List<_AssetDescription> _readAssetDescriptions(Object? rawAssets) {
  final List<_AssetDescription> descriptions = <_AssetDescription>[];
  final Set<String> entryPaths = <String>{};
  for (final Object? rawAsset in _jsonList(rawAssets, 'assets')) {
    final Map<String, Object?> asset = _jsonObject(rawAsset, 'asset');
    final String sha256Value = _jsonString(asset['sha256'], 'sha256');
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256Value)) {
      throw const FormatException('asset identifier is not a SHA-256');
    }
    final String entryPath = _jsonString(asset['path'], 'path');
    if (entryPath != 'assets/$sha256Value') {
      throw const FormatException('asset path does not match its hash');
    }
    if (!entryPaths.add(entryPath)) {
      throw FormatException('manifest contains duplicate $entryPath');
    }
    descriptions.add(
      _AssetDescription(
        entryPath: entryPath,
        sha256: sha256Value,
        byteLength: _jsonInteger(asset['bytes'], 'bytes'),
      ),
    );
  }
  return descriptions;
}

void _requireOnlyDeclaredEntries(
  Map<String, ArchiveFile> entries,
  List<_AssetDescription> assets,
) {
  final Set<String> allowedNames = <String>{
    'collection.sqlite',
    'manifest.json',
    for (final _AssetDescription asset in assets) asset.entryPath,
  };
  final Set<String> unexpectedNames = entries.keys.toSet()
    ..removeAll(allowedNames);
  if (unexpectedNames.isNotEmpty) {
    throw FormatException(
      'package contains undeclared ${unexpectedNames.first}',
    );
  }
}

ArchiveFile _requiredEntry(Map<String, ArchiveFile> entries, String name) {
  final ArchiveFile? entry = entries[name];
  if (entry == null) throw FormatException('package is missing $name');
  return entry;
}

void _writeArchiveEntry(ArchiveFile entry, File target) {
  final OutputFileStream output = OutputFileStream(target.path);
  try {
    entry.writeContent(output);
  } finally {
    output.closeSync();
  }
}

Map<String, Object?> _jsonObject(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$name is not an object');
  }
  return value;
}

List<Object?> _jsonList(Object? value, String name) {
  if (value is! List<Object?>) throw FormatException('$name is not a list');
  return value;
}

String _jsonString(Object? value, String name) {
  if (value is! String) throw FormatException('$name is not text');
  return value;
}

int _jsonInteger(Object? value, String name) {
  if (value is! int || value < 0) {
    throw FormatException('$name is not a non-negative integer');
  }
  return value;
}

int _databaseSchemaVersion(File file) {
  final sqlite.Database database = sqlite.sqlite3.open(file.path);
  try {
    return database.userVersion;
  } finally {
    database.close();
  }
}

Future<String> _hashFile(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

String _stampFromBackup(File file) {
  final RegExpMatch? match = RegExp(
    r'-(\d{14})\.(?:irbackup|sqlite)$',
  ).firstMatch(p.basename(file.path));
  return match?.group(1) ?? 'selected';
}

Future<void> _deleteDirectoryIfPresent(Directory directory) async {
  try {
    if (directory.existsSync()) await directory.delete(recursive: true);
  } on FileSystemException {
    // Best-effort cleanup must not hide the validation failure.
  }
}

void _tryDelete(File file) {
  try {
    if (file.existsSync()) file.deleteSync();
  } on FileSystemException {
    // Best-effort cleanup must not mask the restoration result.
  }
}

final class _DisplacedFile {
  const _DisplacedFile({required this.originalPath, required this.displaced});

  final String originalPath;
  final File displaced;
}

final class _PackageDescription {
  const _PackageDescription({
    required this.createdAtUtc,
    required this.schemaVersion,
    required this.databaseByteLength,
    required this.databaseSha256,
    required this.assets,
    required this.missingAssetCount,
  });

  final DateTime createdAtUtc;
  final int schemaVersion;
  final int databaseByteLength;
  final String? databaseSha256;
  final List<_AssetDescription> assets;
  final int missingAssetCount;
}

final class _AssetDescription {
  const _AssetDescription({
    required this.entryPath,
    required this.sha256,
    required this.byteLength,
  });

  final String entryPath;
  final String sha256;
  final int byteLength;
}
