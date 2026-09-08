/// Opens one collection and rebuilds its provider scope after replacement.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/collection_replacement.dart';
import 'package:incremental_reader/app/incremental_reader_app.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/app/startup_gate.dart';
import 'package:incremental_reader/app/startup_tasks.dart';
import 'package:incremental_reader/features/recovery/recovery_screen.dart';
import 'package:incremental_reader/features/settings/settings_providers.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/files/backup_restore_service.dart';
import 'package:incremental_reader/storage/files/backup_service.dart';
import 'package:incremental_reader/storage/platform/app_paths.dart';

/// Owns only the lifetime of the current database and Riverpod container.
final class CollectionSessionRoot extends StatefulWidget {
  const CollectionSessionRoot({required this.paths, super.key});

  final AppPaths paths;

  @override
  State<CollectionSessionRoot> createState() => _CollectionSessionRootState();
}

final class _CollectionSessionRootState extends State<CollectionSessionRoot> {
  late final CollectionReplacement _replacement =
      _CollectionReplacementCallback(_replaceWithPackage);

  ProviderContainer? _container;
  AppDatabase? _database;
  StartupFailure? _failure;
  String? _progressMessage = 'Opening collection…';
  String? _startupMessage;
  bool _startupMessageIsError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_openInitialCollection());
  }

  @override
  void dispose() {
    _container?.dispose();
    unawaited(_database?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StartupFailure? failure = _failure;
    if (failure != null) {
      return RecoveryApp(
        failure: failure,
        backupDirectory: widget.paths.backupDirectory,
      );
    }

    final ProviderContainer? container = _container;
    if (container == null) {
      return _CollectionProgressApp(
        message: _progressMessage ?? 'Opening collection…',
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          UncontrolledProviderScope(
            key: ObjectKey(container),
            container: container,
            child: IncrementalReaderApp(
              startupMessage: _startupMessage,
              startupMessageIsError: _startupMessageIsError,
            ),
          ),
          if (_progressMessage case final String message)
            _CollectionProgressOverlay(message: message),
        ],
      ),
    );
  }

  Future<void> _openInitialCollection() async {
    await _deleteAbandonedCollectionTransfers();
    final Result<_OpenedCollection> opened = await _openCollection(
      shouldRunDailyBackup: true,
    );
    if (!mounted) {
      await _disposeOpenedCollection(opened.valueOrNull);
      return;
    }
    _showOpenedCollection(opened);
  }

  Future<Result<Unit>> _replaceWithPackage(
    File packageFile, {
    required OperationId operationId,
  }) async {
    final ProviderContainer? currentContainer = _container;
    final AppDatabase? currentDatabase = _database;
    if (currentContainer == null || currentDatabase == null) {
      return Err<Unit>(
        const ConflictFailure('No collection is currently open.'),
      );
    }

    final Result<_PreparedReplacement> prepared = await _prepareReplacement(
      packageFile: packageFile,
      operationId: operationId,
      currentContainer: currentContainer,
      currentDatabase: currentDatabase,
    );
    if (prepared.isErr) {
      _hideProgress();
      return Err<Unit>(prepared.failureOrNull!);
    }
    return _promoteReplacement(prepared.unwrap());
  }

  Future<Result<_PreparedReplacement>> _prepareReplacement({
    required File packageFile,
    required OperationId operationId,
    required ProviderContainer currentContainer,
    required AppDatabase currentDatabase,
  }) async {
    _showProgress('Checking collection package…');
    final BackupRestoreService restoreService = BackupRestoreService(
      databaseFile: widget.paths.databaseFile,
      assetDirectory: widget.paths.assetDirectory,
      clock: currentContainer.read(clockProvider),
    );
    final Result<StagedCollectionPackage> stagedResult = await restoreService
        .stagePackage(packageFile);
    if (stagedResult.isErr) {
      return Err<_PreparedReplacement>(stagedResult.failureOrNull!);
    }
    final StagedCollectionPackage staged = stagedResult.unwrap();

    _showProgress('Creating a safety backup…');
    final Result<File> safetyBackup = await currentContainer
        .read(backupServiceProvider)
        .createBackup(type: BackupType.preImport, operationId: operationId);
    if (safetyBackup.isErr) {
      await staged.delete();
      return Err<_PreparedReplacement>(safetyBackup.failureOrNull!);
    }
    return Ok<_PreparedReplacement>(
      _PreparedReplacement(
        currentContainer: currentContainer,
        currentDatabase: currentDatabase,
        restoreService: restoreService,
        staged: staged,
        safetyBackup: safetyBackup.unwrap(),
      ),
    );
  }

  Future<Result<Unit>> _promoteReplacement(
    _PreparedReplacement prepared,
  ) async {
    _showProgress('Replacing collection…');
    if (mounted) {
      setState(() {
        _container = null;
        _database = null;
      });
      await WidgetsBinding.instance.endOfFrame;
    }
    prepared.currentContainer.dispose();
    await prepared.currentDatabase.close();

    final Result<Unit> promotion = await prepared.restoreService.promote(
      prepared.staged,
    );
    if (promotion.isErr) {
      await _reopenAfterReplacement(
        message: promotion.failureOrNull!.message,
        isError: true,
      );
      return okUnit;
    }

    final Result<_OpenedCollection> imported = await _openCollection(
      shouldRunDailyBackup: false,
    );
    if (imported.isOk) {
      _showOpenedCollection(
        imported,
        message: 'Collection imported',
        isError: false,
      );
      return okUnit;
    }

    final Result<Unit> rollback = await BackupRestoreService(
      databaseFile: widget.paths.databaseFile,
      assetDirectory: widget.paths.assetDirectory,
    ).restore(prepared.safetyBackup);
    await _reopenAfterReplacement(
      message: rollback.isOk
          ? 'The imported collection could not be opened. The previous collection was restored.'
          : 'The imported collection and its safety backup could not be opened.',
      isError: true,
    );
    return okUnit;
  }

  Future<void> _reopenAfterReplacement({
    required String message,
    required bool isError,
  }) async {
    final Result<_OpenedCollection> reopened = await _openCollection(
      shouldRunDailyBackup: false,
    );
    _showOpenedCollection(reopened, message: message, isError: isError);
  }

  Future<Result<_OpenedCollection>> _openCollection({
    required bool shouldRunDailyBackup,
  }) async {
    final Result<AppDatabase> openResult = await openCollectionOrFail(
      databaseFile: widget.paths.databaseFile,
      backupDirectory: widget.paths.backupDirectory,
    );
    if (openResult.isErr) {
      return Err<_OpenedCollection>(openResult.failureOrNull!);
    }

    final AppDatabase database = openResult.unwrap();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appPathsProvider.overrideWithValue(widget.paths),
        databaseProvider.overrideWithValue(database),
        logDirectoryProvider.overrideWithValue(widget.paths.logDirectory),
        collectionReplacementProvider.overrideWithValue(_replacement),
      ],
    );
    try {
      await _prepareCollectionFiles(container);
      await warmSettings(container);
      if (shouldRunDailyBackup) await runDailyBackupIfDue(container);
      return Ok<_OpenedCollection>(
        _OpenedCollection(database: database, container: container),
      );
    } on Object catch (error, stackTrace) {
      container.dispose();
      await database.close();
      return Err<_OpenedCollection>(
        UnexpectedFailure(
          'The collection could not finish opening.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> _prepareCollectionFiles(ProviderContainer container) async {
    final sourceAssetFiles = container.read(sourceAssetFileStoreProvider);
    await sourceAssetFiles.deletePartialFiles();
    await sourceAssetFiles.deleteUnreferencedBlobs(<String>{
      ...await container
          .read(sourceAssetRepositoryProvider)
          .listAvailableSourceAssetSha256Values(),
      ...await container
          .read(occlusionRepositoryProvider)
          .listReferencedOcclusionSha256Values(),
    });
  }

  void _showOpenedCollection(
    Result<_OpenedCollection> result, {
    String? message,
    bool isError = false,
  }) {
    if (!mounted) {
      unawaited(_disposeOpenedCollection(result.valueOrNull));
      return;
    }
    setState(() {
      _progressMessage = null;
      _startupMessage = message;
      _startupMessageIsError = isError;
      if (result case Ok<_OpenedCollection>(value: final opened)) {
        _container = opened.container;
        _database = opened.database;
        _failure = null;
      } else {
        _container = null;
        _database = null;
        final AppFailure failure = result.failureOrNull!;
        _failure = failure is StartupFailure
            ? failure
            : StartupFailure(
                StartupFailureKind.unreadable,
                failure.message,
                cause: failure.cause,
                stackTrace: failure.stackTrace,
              );
      }
    });
  }

  void _showProgress(String message) {
    if (!mounted) return;
    setState(() => _progressMessage = message);
  }

  void _hideProgress() {
    if (!mounted) return;
    setState(() => _progressMessage = null);
  }

  Future<void> _deleteAbandonedCollectionTransfers() async {
    final Directory directory = widget.paths.collectionTransferDirectory;
    if (!directory.existsSync()) return;
    await for (final FileSystemEntity entry in directory.list()) {
      try {
        await entry.delete(recursive: true);
      } on FileSystemException {
        // A later startup retries scratch files still locked by the platform.
      }
    }
  }

  Future<void> _disposeOpenedCollection(_OpenedCollection? opened) async {
    if (opened == null) return;
    opened.container.dispose();
    await opened.database.close();
  }
}

final class _CollectionReplacementCallback implements CollectionReplacement {
  const _CollectionReplacementCallback(this._replace);

  final Future<Result<Unit>> Function(
    File packageFile, {
    required OperationId operationId,
  })
  _replace;

  @override
  Future<Result<Unit>> replaceWithPackage(
    File packageFile, {
    required OperationId operationId,
  }) => _replace(packageFile, operationId: operationId);
}

final class _OpenedCollection {
  const _OpenedCollection({required this.database, required this.container});

  final AppDatabase database;
  final ProviderContainer container;
}

final class _PreparedReplacement {
  const _PreparedReplacement({
    required this.currentContainer,
    required this.currentDatabase,
    required this.restoreService,
    required this.staged,
    required this.safetyBackup,
  });

  final ProviderContainer currentContainer;
  final AppDatabase currentDatabase;
  final BackupRestoreService restoreService;
  final StagedCollectionPackage staged;
  final File safetyBackup;
}

final class _CollectionProgressApp extends StatelessWidget {
  const _CollectionProgressApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: Scaffold(body: _CollectionProgress(message: message)),
  );
}

final class _CollectionProgressOverlay extends StatelessWidget {
  const _CollectionProgressOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xB3FFFFFF),
    child: Material(
      color: Colors.transparent,
      child: _CollectionProgress(message: message),
    ),
  );
}

final class _CollectionProgress extends StatelessWidget {
  const _CollectionProgress({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message),
      ],
    ),
  );
}
