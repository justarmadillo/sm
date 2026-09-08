/// Rolling backups of the live database.
///
/// Backups exist before real study data does, deliberately: a backup system
/// added after a collection is valuable is a backup system that has never been
/// tested. Copies are made with `VACUUM INTO`, which produces a consistent
/// snapshot through SQLite itself — copying the `.sqlite`, `-wal`, and `-shm`
/// files by hand races the writer and yields a file that looks fine until it
/// is needed. Every copy is validated and only then atomically renamed into
/// place, so a crash mid-backup can never replace a good file with a truncated
/// one.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// How many copies of each cadence to keep.
final class BackupRetention {
  const BackupRetention({
    this.daily = 30,
    this.monthly = 12,
    this.preMigration = 5,
    this.preImport = 5,
  });

  final int daily;
  final int monthly;

  /// Snapshots taken immediately before a schema migration, retained
  /// separately so an ordinary daily rotation cannot discard the one copy
  /// that predates a bad upgrade.
  final int preMigration;

  /// Full packages taken before a collection replacement.
  final int preImport;
}

/// Why a backup was taken. Determines its file prefix and retention class.
enum BackupType {
  daily('backup'),
  preMigration('premigration'),
  preImport('preimport');

  const BackupType(this.prefix);

  /// File-name prefix identifying the retention class.
  final String prefix;
}

/// One database-referenced asset that belongs in a daily backup package.
final class BackupAssetReference {
  const BackupAssetReference({required this.sha256});

  /// Lowercase content hash and on-disk file name.
  final String sha256;
}

/// What a completed full-collection package contains.
final class CollectionExportReport {
  const CollectionExportReport({
    required this.file,
    required this.includedAssetCount,
    required this.missingAssetCount,
  });

  final File file;
  final int includedAssetCount;
  final int missingAssetCount;
}

/// Reads the valid asset references from the same collection being backed up.
typedef BackupAssetLister = Future<List<BackupAssetReference>> Function();

void _safeDelete(File? file) {
  try {
    if (file?.existsSync() ?? false) file!.deleteSync();
  } on FileSystemException {
    // Cleanup must not hide the result of the backup or recovery operation.
    // Retention and the next startup will retry files left behind here.
  }
}

String _basename(File file) => file.path.split(RegExp(r'[/\\]')).last;

/// Backups in [backupDirectory], newest first.
///
/// This is top-level because recovery runs before there is a live database
/// from which a [BackupService] could be constructed.
List<File> listBackupFiles(Directory backupDirectory, {BackupType? type}) {
  try {
    if (!backupDirectory.existsSync()) return <File>[];
    final List<String> prefixes = type == null
        ? BackupType.values.map((BackupType kind) => kind.prefix).toList()
        : <String>[type.prefix];
    final List<File> files = backupDirectory.listSync().whereType<File>().where(
      (File file) {
        final String name = _basename(file);
        final bool hasBackupExtension =
            name.endsWith('.sqlite') || name.endsWith('.irbackup');
        return hasBackupExtension &&
            prefixes.any((String prefix) => name.startsWith('$prefix-'));
      },
    ).toList();
    files.sort(
      (File first, File second) =>
          _basename(second).compareTo(_basename(first)),
    );
    return files;
  } on FileSystemException {
    return <File>[];
  }
}

/// Whether [file] is a readable, uncorrupted database at a known schema.
///
/// Restore uses the same validator as the writer so a package cannot be
/// accepted under weaker rules than the rules that created it.
String? validateDatabaseFile(File file) {
  sqlite.Database? copy;
  try {
    if (!file.existsSync() || file.lengthSync() == 0) {
      return 'backup file is empty';
    }
    copy = sqlite.sqlite3.open(file.path);
    final sqlite.ResultSet integrity = copy.select('PRAGMA integrity_check');
    if (integrity.length != 1 || integrity.first.values.first != 'ok') {
      return 'integrity_check reported corruption';
    }
    if (copy.select('PRAGMA foreign_key_check').isNotEmpty) {
      return 'foreign keys do not resolve';
    }
    final int userVersion = copy.userVersion;
    if (userVersion <= 0) {
      return 'backup has no Incremental Reader schema version';
    }
    if (userVersion > kSchemaVersion) {
      return 'backup schema $userVersion is newer than $kSchemaVersion';
    }
    final Set<String> tableNames = copy
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((sqlite.Row row) => row['name'] as String)
        .toSet();
    const Set<String> requiredTables = <String>{'sources', 'cards', 'settings'};
    if (!tableNames.containsAll(requiredTables)) {
      return 'backup is not an Incremental Reader collection';
    }
    return null;
  } on Object catch (error) {
    return 'could not open backup: $error';
  } finally {
    copy?.close();
  }
}

String _timestamp(DateTime instant) {
  String two(int value) => value.toString().padLeft(2, '0');
  final utc = instant.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}'
      '${two(utc.month)}${two(utc.day)}${two(utc.hour)}'
      '${two(utc.minute)}${two(utc.second)}';
}

/// Creates a consistent snapshot before Drift is allowed to migrate [databaseFile].
///
/// This uses SQLite directly because constructing [AppDatabase] would run the
/// migration before the backup existed. A failed backup blocks startup so the
/// only copy of a user's collection is never upgraded without a recovery point.
Result<File?> createPreMigrationBackupIfNeeded({
  required File databaseFile,
  required Directory backupDirectory,
  required int targetSchemaVersion,
  Clock clock = const SystemClock(),
  int retain = 5,
}) {
  sqlite.Database? live;
  sqlite.Database? copy;
  File? staging;
  try {
    if (!databaseFile.existsSync() || databaseFile.lengthSync() == 0) {
      return const Ok<File?>(null);
    }
    live = sqlite.sqlite3.open(databaseFile.path);
    final version = live.userVersion;
    if (version == 0 || version >= targetSchemaVersion) {
      return const Ok<File?>(null);
    }

    backupDirectory.createSync(recursive: true);
    final stamp = _timestamp(clock.nowUtc());
    final target = File(
      '${backupDirectory.path}/${BackupType.preMigration.prefix}-$stamp.sqlite',
    );
    staging = File('${target.path}.partial');
    if (staging.existsSync()) staging.deleteSync();
    live.execute('VACUUM INTO ?', <Object?>[staging.path]);

    copy = sqlite.sqlite3.open(staging.path);
    final integrity = copy.select('PRAGMA integrity_check');
    if (integrity.length != 1 || integrity.first.values.first != 'ok') {
      throw StateError('integrity_check rejected the pre-migration backup');
    }
    if (copy.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw StateError('foreign_key_check rejected the pre-migration backup');
    }
    copy.close();
    copy = null;
    staging.renameSync(target.path);
    staging = null;

    final backups =
        backupDirectory
            .listSync()
            .whereType<File>()
            .where(
              (file) => _basename(
                file,
              ).startsWith('${BackupType.preMigration.prefix}-'),
            )
            .toList()
          ..sort((a, b) => _basename(b).compareTo(_basename(a)));
    for (var i = retain; i < backups.length; i++) {
      _safeDelete(backups[i]);
    }
    return Ok<File?>(target);
  } on Object catch (error, stackTrace) {
    _safeDelete(staging);
    return Err<File?>(
      StorageFailure(
        'could not create the required pre-migration backup',
        cause: error,
        stackTrace: stackTrace,
      ),
    );
  } finally {
    copy?.close();
    live?.close();
  }
}

/// Creates, validates, and prunes database backups.
final class BackupService {
  BackupService({
    required AppDatabase database,
    required Directory backupDirectory,
    required Clock clock,
    Directory? assetDirectory,
    BackupAssetLister? listReferencedAssets,
    this.retention = const BackupRetention(),
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _database = database,
       _backupDirectory = backupDirectory,
       _clock = clock,
       _assetDirectory = assetDirectory,
       _listReferencedAssets = listReferencedAssets,
       _diagnostics = diagnostics;

  final AppDatabase _database;
  final Directory _backupDirectory;
  final Clock _clock;
  final Directory? _assetDirectory;
  final BackupAssetLister? _listReferencedAssets;
  final DiagnosticSink _diagnostics;

  /// How many copies of each cadence to keep.
  final BackupRetention retention;

  /// Directory backups are written to.
  Directory get directory => _backupDirectory;

  /// Writes a validated backup and prunes older ones.
  ///
  /// Returns the finished file. The previous newest backup is left untouched
  /// if anything fails.
  Future<Result<File>> createBackup({
    BackupType type = BackupType.daily,
    OperationId? operationId,
  }) async {
    final startedAt = _clock.nowUtc();
    final stamp = _timestamp(startedAt);
    final bool isPackage = type != BackupType.preMigration;
    final extension = isPackage ? 'irbackup' : 'sqlite';
    final target = File(
      '${_backupDirectory.path}/${type.prefix}-$stamp.$extension',
    );
    final staging = File('${target.path}.partial');
    File? databaseSnapshot;
    File? manifestFile;

    try {
      _backupDirectory.createSync(recursive: true);
      if (staging.existsSync()) staging.deleteSync();
      databaseSnapshot = isPackage
          ? File('${target.path}.database.partial')
          : staging;
      _safeDelete(databaseSnapshot);
      await _createDatabaseSnapshot(databaseSnapshot);

      final validation = validateDatabaseFile(databaseSnapshot);
      if (validation != null) {
        _safeDelete(databaseSnapshot);
        _record(
          DiagnosticLevel.error,
          'backup.invalid',
          operationId,
          <String, Object?>{'kind': type.name, 'problem': validation},
        );
        return Err<File>(
          StorageFailure('backup failed validation: $validation'),
        );
      }

      var missingAssetCount = 0;
      if (isPackage) {
        manifestFile = File('${target.path}.manifest.partial');
        _safeDelete(manifestFile);
        final CollectionExportReport report = await _createCollectionPackage(
          packageFile: staging,
          databaseSnapshot: databaseSnapshot,
          manifestFile: manifestFile,
          createdAtUtc: startedAt,
        );
        missingAssetCount = report.missingAssetCount;
        final packageProblem = _validatePackage(staging);
        if (packageProblem != null) {
          throw StateError(packageProblem);
        }
      }

      // Atomic within a volume: readers see either no file or the complete one.
      staging.renameSync(target.path);
      if (type == BackupType.preMigration) databaseSnapshot = null;
      await pruneOldBackups();

      _record(
        DiagnosticLevel.info,
        'backup.created',
        operationId,
        <String, Object?>{
          'kind': type.name,
          'bytes': target.lengthSync(),
          'missingAssets': missingAssetCount,
          'ms': _clock.nowUtc().difference(startedAt).inMilliseconds,
        },
      );
      return Ok<File>(target);
    } on Object catch (error, stackTrace) {
      _safeDelete(staging);
      _record(
        DiagnosticLevel.error,
        'backup.failed',
        operationId,
        <String, Object?>{'kind': type.name},
        StorageFailure(
          'could not write backup',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
      return Err<File>(
        StorageFailure(
          'could not write backup',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      _safeDelete(databaseSnapshot);
      _safeDelete(manifestFile);
    }
  }

  /// Writes a full collection package to a user-selected destination.
  ///
  /// Manual exports do not participate in rolling-backup retention.
  Future<Result<CollectionExportReport>> exportCollection({
    required File target,
    OperationId? operationId,
  }) async {
    final DateTime startedAt = _clock.nowUtc();
    final File staging = File('${target.path}.partial');
    final File databaseSnapshot = File('${target.path}.database.partial');
    final File manifestFile = File('${target.path}.manifest.partial');
    try {
      target.parent.createSync(recursive: true);
      for (final File file in <File>[staging, databaseSnapshot, manifestFile]) {
        _safeDelete(file);
      }
      await _createDatabaseSnapshot(databaseSnapshot);
      final String? databaseProblem = validateDatabaseFile(databaseSnapshot);
      if (databaseProblem != null) throw StateError(databaseProblem);
      final CollectionExportReport packageReport =
          await _createCollectionPackage(
            packageFile: staging,
            databaseSnapshot: databaseSnapshot,
            manifestFile: manifestFile,
            createdAtUtc: startedAt,
          );
      final String? packageProblem = _validatePackage(staging);
      if (packageProblem != null) throw StateError(packageProblem);

      _replaceExportTarget(staging: staging, target: target);
      _record(
        DiagnosticLevel.info,
        'collection_export.created',
        operationId,
        <String, Object?>{
          'bytes': target.lengthSync(),
          'missingAssets': packageReport.missingAssetCount,
        },
      );
      return Ok<CollectionExportReport>(
        CollectionExportReport(
          file: target,
          includedAssetCount: packageReport.includedAssetCount,
          missingAssetCount: packageReport.missingAssetCount,
        ),
      );
    } on Object catch (error, stackTrace) {
      _safeDelete(staging);
      return Err<CollectionExportReport>(
        StorageFailure(
          'could not export collection',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      _safeDelete(databaseSnapshot);
      _safeDelete(manifestFile);
    }
  }

  /// Replaces an existing export without exposing a half-written package.
  void _replaceExportTarget({required File staging, required File target}) {
    File? displacedTarget;
    try {
      if (target.existsSync()) {
        displacedTarget = File('${target.path}.superseded');
        _safeDelete(displacedTarget);
        target.renameSync(displacedTarget.path);
      }
      staging.renameSync(target.path);
      _safeDelete(displacedTarget);
    } on Object catch (error, stackTrace) {
      if (!target.existsSync() && (displacedTarget?.existsSync() ?? false)) {
        try {
          displacedTarget!.renameSync(target.path);
        } on FileSystemException {
          // The displaced file remains recoverable beside the destination.
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Backups on disk, newest first.
  List<File> listBackups({BackupType? type}) {
    return listBackupFiles(_backupDirectory, type: type);
  }

  /// Applies the retention policy, deleting whatever falls outside it.
  Future<void> pruneOldBackups() async {
    _prunePreMigration();
    _prunePreImport();
    _pruneDaily();
  }

  Future<void> _createDatabaseSnapshot(File snapshot) async {
    // VACUUM INTO asks SQLite for a consistent snapshot rather than reading
    // the files behind its back.
    await _database.customStatement('VACUUM INTO ?', <Object?>[snapshot.path]);
  }

  /// Streams a database, manifest, and every verified asset into one package.
  Future<CollectionExportReport> _createCollectionPackage({
    required File packageFile,
    required File databaseSnapshot,
    required File manifestFile,
    required DateTime createdAtUtc,
  }) async {
    final references = await _listUniqueAssetReferences();
    final included = <Map<String, Object?>>[];
    final missing = <Map<String, Object?>>[];
    final includedFiles = <File>[];
    for (final reference in references) {
      final asset = _findAssetFile(reference.sha256);
      final problem = await _assetProblem(asset, reference.sha256);
      if (problem != null) {
        missing.add(<String, Object?>{
          'sha256': reference.sha256,
          'problem': problem,
        });
        continue;
      }
      includedFiles.add(asset!);
      included.add(<String, Object?>{
        'sha256': reference.sha256,
        'path': 'assets/${reference.sha256}',
        'bytes': await asset.length(),
      });
    }

    final String databaseSha256 =
        (await sha256.bind(databaseSnapshot.openRead()).first).toString();
    final manifest = <String, Object?>{
      'formatVersion': 1,
      'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
      'database': <String, Object?>{
        'path': 'collection.sqlite',
        'bytes': await databaseSnapshot.length(),
        'schemaVersion': kSchemaVersion,
        'sha256': databaseSha256,
      },
      'assets': included,
      'missingAssets': missing,
    };
    await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

    final encoder = ZipFileEncoder();
    encoder.create(packageFile.path);
    try {
      await encoder.addFile(databaseSnapshot, 'collection.sqlite');
      await encoder.addFile(manifestFile, 'manifest.json');
      for (final asset in includedFiles) {
        await encoder.addFile(asset, 'assets/${_basename(asset)}');
      }
    } finally {
      await encoder.close();
    }
    return CollectionExportReport(
      file: packageFile,
      includedAssetCount: included.length,
      missingAssetCount: missing.length,
    );
  }

  Future<List<BackupAssetReference>> _listUniqueAssetReferences() async {
    final references =
        await _listReferencedAssets?.call() ?? const <BackupAssetReference>[];
    final unique = <String, BackupAssetReference>{};
    for (final reference in references) {
      unique.putIfAbsent(reference.sha256, () => reference);
    }
    return unique.values.toList()
      ..sort((first, second) => first.sha256.compareTo(second.sha256));
  }

  File? _findAssetFile(String sha256Value) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256Value)) return null;
    final directory = _assetDirectory;
    return directory == null ? null : File('${directory.path}/$sha256Value');
  }

  Future<String?> _assetProblem(File? asset, String expectedSha256) async {
    if (asset == null || !asset.existsSync()) return 'file is missing';
    final actualSha256 = (await sha256.bind(asset.openRead()).first).toString();
    return actualSha256 == expectedSha256 ? null : 'SHA-256 does not match';
  }

  String? _validatePackage(File packageFile) {
    try {
      if (!packageFile.existsSync() || packageFile.lengthSync() == 0) {
        return 'backup package is empty';
      }
      final input = InputFileStream(packageFile.path);
      try {
        final archive = ZipDecoder().decodeStream(input, verify: true);
        final names = archive.files
            .where((entry) => entry.isFile)
            .map((entry) => entry.name)
            .toSet();
        if (!names.contains('collection.sqlite') ||
            !names.contains('manifest.json')) {
          return 'backup package is missing a required entry';
        }
      } finally {
        input.closeSync();
      }
      return null;
    } on Object catch (error) {
      return 'could not open backup package: $error';
    }
  }

  void _pruneDaily() {
    final backups = listBackups(type: BackupType.daily);
    // Newest first, so the first file seen for a day or month is the keeper.
    final keptDays = <String>{};
    final keptMonths = <String>{};
    final keep = <String>{};
    for (final file in backups) {
      final stamp = _backupStampOf(file);
      if (stamp == null) continue;
      final day = stamp.substring(0, 8);
      final month = stamp.substring(0, 6);
      if (keptDays.length < retention.daily && keptDays.add(day)) {
        keep.add(file.path);
      }
      if (keptMonths.length < retention.monthly && keptMonths.add(month)) {
        keep.add(file.path);
      }
    }
    for (final file in backups) {
      if (!keep.contains(file.path)) _safeDelete(file);
    }
  }

  void _prunePreMigration() {
    final backups = listBackups(type: BackupType.preMigration);
    for (var i = retention.preMigration; i < backups.length; i++) {
      _safeDelete(backups[i]);
    }
  }

  void _prunePreImport() {
    final backups = listBackups(type: BackupType.preImport);
    for (var index = retention.preImport; index < backups.length; index++) {
      _safeDelete(backups[index]);
    }
  }

  void _record(
    DiagnosticLevel level,
    String name,
    OperationId? operationId,
    Map<String, Object?> fields, [
    AppFailure? failure,
  ]) {
    _diagnostics.record(
      DiagnosticEvent(
        level: level,
        name: name,
        timestampUtc: _clock.nowUtc(),
        operationId: operationId,
        fields: fields,
        failure: failure,
      ),
    );
  }

  static String? _backupStampOf(File file) {
    final name = _basename(file);
    final dash = name.indexOf('-');
    final dot = name.lastIndexOf('.');
    if (dash < 0 || dot <= dash) return null;
    final stamp = name.substring(dash + 1, dot);
    return stamp.length == 14 ? stamp : null;
  }
}
