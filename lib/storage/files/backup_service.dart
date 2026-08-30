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

import 'dart:io';

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
  });

  final int daily;
  final int monthly;

  /// Snapshots taken immediately before a schema migration, retained
  /// separately so an ordinary daily rotation cannot discard the one copy
  /// that predates a bad upgrade.
  final int preMigration;
}

/// Why a backup was taken. Determines its file prefix and retention class.
enum BackupType {
  daily('backup'),
  preMigration('premigration');

  const BackupType(this.prefix);

  /// File-name prefix identifying the retention class.
  final String prefix;
}

void _safeDeleteFile(File? file) {
  try {
    if (file?.existsSync() ?? false) file!.deleteSync();
  } on FileSystemException {
    // A leftover staging file is harmless and retried on the next startup.
  }
}

String _basename(File file) => file.path.split(RegExp(r'[/\\]')).last;

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
  if (!databaseFile.existsSync() || databaseFile.lengthSync() == 0) {
    return const Ok<File?>(null);
  }

  sqlite.Database? live;
  sqlite.Database? copy;
  File? staging;
  try {
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
      _safeDeleteFile(backups[i]);
    }
    return Ok<File?>(target);
  } on Object catch (error, stackTrace) {
    _safeDeleteFile(staging);
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
    this.retention = const BackupRetention(),
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _database = database,
       _backupDirectory = backupDirectory,
       _clock = clock,
       _diagnostics = diagnostics;

  final AppDatabase _database;
  final Directory _backupDirectory;
  final Clock _clock;
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
    _backupDirectory.createSync(recursive: true);

    final stamp = _timestamp(startedAt);
    final target = File(
      '${_backupDirectory.path}/${type.prefix}-$stamp.sqlite',
    );
    final staging = File('${target.path}.partial');

    try {
      if (staging.existsSync()) staging.deleteSync();

      // VACUUM INTO asks SQLite for a consistent snapshot rather than reading
      // the files behind its back.
      await _database.customStatement('VACUUM INTO ?', <Object?>[staging.path]);

      final validation = await _validate(staging);
      if (validation != null) {
        _safeDelete(staging);
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

      // Atomic within a volume: readers see either the old file or the new.
      staging.renameSync(target.path);
      await pruneOldBackups();

      _record(
        DiagnosticLevel.info,
        'backup.created',
        operationId,
        <String, Object?>{
          'kind': type.name,
          'bytes': target.lengthSync(),
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
    }
  }

  /// Backups on disk, newest first.
  List<File> listBackups({BackupType? type}) {
    if (!_backupDirectory.existsSync()) return <File>[];
    final prefixes = type == null
        ? BackupType.values.map((BackupType k) => k.prefix).toList()
        : <String>[type.prefix];
    final files = _backupDirectory.listSync().whereType<File>().where((File f) {
      final name = _basename(f);
      return name.endsWith('.sqlite') &&
          prefixes.any((String p) => name.startsWith('$p-'));
    }).toList()..sort((File a, File b) => _basename(b).compareTo(_basename(a)));
    return files;
  }

  /// Applies the retention policy, deleting whatever falls outside it.
  Future<void> pruneOldBackups() async {
    _prunePreMigration();
    _pruneDaily();
  }

  /// Whether [file] is a readable, uncorrupted database at a known schema.
  Future<String?> _validate(File file) async {
    if (!file.existsSync() || file.lengthSync() == 0) {
      return 'backup file is empty';
    }
    sqlite.Database? copy;
    try {
      copy = sqlite.sqlite3.open(file.path);
      final integrity = copy.select('PRAGMA integrity_check');
      if (integrity.length != 1 || integrity.first.values.first != 'ok') {
        return 'integrity_check reported corruption';
      }
      if (copy.select('PRAGMA foreign_key_check').isNotEmpty) {
        return 'foreign keys do not resolve';
      }
      final userVersion = copy.userVersion;
      if (userVersion > kSchemaVersion) {
        return 'backup schema $userVersion is newer than $kSchemaVersion';
      }
      return null;
    } on Object catch (error) {
      return 'could not open backup: $error';
    } finally {
      copy?.close();
    }
  }

  void _pruneDaily() {
    final backups = listBackups(type: BackupType.daily);
    // Newest first, so the first file seen for a day or month is the keeper.
    final keptDays = <String>{};
    final keptMonths = <String>{};
    final keep = <String>{};
    for (final file in backups) {
      final stamp = _stampOf(file);
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

  static void _safeDelete(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // A backup that cannot be deleted is not worth failing an operation for;
      // the next prune will try again.
    }
  }

  static String _basename(File file) => file.path.split(RegExp(r'[/\\]')).last;

  /// The `YYYYMMDDHHMMSS` stamp in a backup file name.
  static String? _stampOf(File file) {
    final name = _basename(file);
    final dash = name.indexOf('-');
    final dot = name.lastIndexOf('.sqlite');
    if (dash < 0 || dot <= dash) return null;
    final stamp = name.substring(dash + 1, dot);
    return stamp.length == 14 ? stamp : null;
  }

  static String _timestamp(DateTime instant) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${instant.year.toString().padLeft(4, '0')}'
        '${two(instant.month)}${two(instant.day)}'
        '${two(instant.hour)}${two(instant.minute)}${two(instant.second)}';
  }
}
