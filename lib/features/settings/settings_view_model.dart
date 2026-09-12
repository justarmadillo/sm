/// ViewModel for Settings.
///
/// Edits are held as a draft and written on Save, so a half-typed number never
/// reaches a scheduler. Saving invalidates the providers that captured the old
/// configuration, because an Outstanding order built under the previous merge
/// and randomization settings remains authoritative until it is rebuilt.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/daily_queue/queue_view_model.dart';
import 'package:incremental_reader/features/priority/priority_view_model.dart';
import 'package:incremental_reader/features/settings/collection_file_dialogs.dart';
import 'package:incremental_reader/features/settings/fsrs_settings_rescheduler.dart';
import 'package:incremental_reader/features/settings/settings_providers.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/backup_settings.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/database_check.dart';
import 'package:incremental_reader/storage/contracts/database_maintenance.dart';
import 'package:incremental_reader/storage/files/backup_service.dart';
import 'package:incremental_reader/storage/platform/automatic_backup_folder_access.dart';
import 'package:path/path.dart' as p;

enum SettingsOperation {
  saving,
  checkingDatabase,
  optimizingDatabase,
  exportingCollection,
  importingCollection,
}

@immutable
final class SettingsUiState {
  const SettingsUiState({
    required this.saved,
    required this.draft,
    this.activeOperation,
    this.message,
  });

  /// What is on disk.
  final AppSettings saved;

  /// What the user is editing.
  final AppSettings draft;

  final SettingsOperation? activeOperation;

  bool get isBusy => activeOperation != null;
  final UiMessage? message;

  /// Whether there is anything to save.
  bool get isDirty => draft != saved;

  SettingsUiState copyWith({
    AppSettings? saved,
    AppSettings? draft,
    SettingsOperation? activeOperation,
    bool shouldClearOperation = false,
    UiMessage? message,
    bool shouldClearMessage = false,
  }) => SettingsUiState(
    saved: saved ?? this.saved,
    draft: draft ?? this.draft,
    activeOperation: shouldClearOperation
        ? null
        : (activeOperation ?? this.activeOperation),
    message: shouldClearMessage ? null : (message ?? this.message),
  );
}

final class SettingsViewModel extends AsyncNotifier<SettingsUiState> {
  @override
  Future<SettingsUiState> build() async {
    final AppSettings settings = await ref.read(settingsStoreProvider).reload();
    return SettingsUiState(saved: settings, draft: settings);
  }

  /// Applies an edit to the draft without writing anything.
  void edit(AppSettings Function(AppSettings draft) change) {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<SettingsUiState>.data(
      current.copyWith(draft: change(current.draft)),
    );
  }

  /// Throws the draft away.
  void revert() {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<SettingsUiState>.data(
      current.copyWith(draft: current.saved),
    );
  }

  /// Restores every shipped default into the draft.
  ///
  /// Not written until Save, so "what would the defaults do?" is a question
  /// the user can ask and then back out of.
  void restoreDefaults() {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<SettingsUiState>.data(
      current.copyWith(draft: const AppSettings()),
    );
  }

  /// Selects an external automatic-backup folder without saving the draft.
  Future<void> chooseAutomaticBackupFolder() async {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    final AutomaticBackupFolderAccess folderAccess = ref.read(
      automaticBackupFolderAccessProvider,
    );
    if (!folderAccess.isSupported) {
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          message: const UiMessage(
            'Automatic backup folders are available on Windows and Android.',
            isError: true,
          ),
        ),
      );
      return;
    }
    try {
      final SelectedAutomaticBackupFolder? selected = await folderAccess
          .chooseFolder();
      if (selected == null) return;
      final BackupSettings changed = current.draft.backup.copyWith(
        directoryLocation: selected.location,
        directoryLabel: selected.label,
      );
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(draft: current.draft.copyWith(backup: changed)),
      );
    } on Object catch (error) {
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          message: UiMessage(
            'Could not choose the automatic backup folder: $error',
            isError: true,
          ),
        ),
      );
    }
  }

  /// Keeps automatic backups only in the app-owned recovery folder.
  void useApplicationBackupFolder() {
    edit(
      (AppSettings settings) => settings.copyWith(
        backup: BackupSettings(interval: settings.backup.interval),
      ),
    );
  }

  /// Writes the draft.
  Future<void> save() async {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy || !current.isDirty) return;
    state = AsyncValue<SettingsUiState>.data(
      current.copyWith(activeOperation: SettingsOperation.saving),
    );

    final FsrsSettingsSaveResult saveResult = await FsrsSettingsRescheduler(
      settings: ref.read(settingsStoreProvider),
      context: ref.read(schedulingContextProvider),
      learning: ref.read(learningRepositoryProvider),
      transactions: ref.read(transactionRunnerProvider),
    ).save(previous: current.saved, replacement: current.draft);
    final Result<AppSettings> result = saveResult.settings;
    if (result.isErr) {
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          shouldClearOperation: true,
          message: UiMessage(result.failureOrNull!.message, isError: true),
        ),
      );
      return;
    }

    // Everything that captured the old configuration has to be rebuilt: the
    // calendar, the diagnostic sink's limits, today's queue, and the priority
    // projections all read settings at construction time.
    ref.invalidate(studyCalendarProvider);
    ref.invalidate(diagnosticsProvider);
    ref.invalidate(queueViewModelProvider);
    ref.invalidate(priorityBrowserViewModelProvider);

    state = AsyncValue<SettingsUiState>.data(
      SettingsUiState(
        saved: result.unwrap(),
        draft: result.unwrap(),
        message: UiMessage(
          saveResult.cardsUpdated == 0
              ? 'Settings saved'
              : 'Settings saved. ${saveResult.cardsUpdated} card '
                    '${saveResult.cardsUpdated == 1 ? 'schedule was' : 'schedules were'} '
                    'updated.',
        ),
      ),
    );
  }

  /// Compacts and checks the database, then says what it found.
  ///
  /// Not part of the draft, so it does not wait for Save: this changes how the
  /// collection is stored, never what it contains, and there is nothing here
  /// to back out of.
  ///
  /// No backup is taken first. Every step is either transactional (SQLite
  /// rolls a half-finished VACUUM back) or derived (the search index is
  /// rebuilt from rows that are still there), so an interrupted pass leaves
  /// the collection exactly as it was.
  Future<void> optimizeDatabase() async {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<SettingsUiState>.data(
      current.copyWith(activeOperation: SettingsOperation.optimizingDatabase),
    );

    try {
      final DatabaseMaintenanceReport report = await ref
          .read(databaseMaintenanceProvider)
          .optimize();
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          shouldClearOperation: true,
          message: UiMessage(
            _reportMessage(report),
            isError: !report.isHealthy,
          ),
        ),
      );
    } on Object catch (error) {
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          shouldClearOperation: true,
          message: UiMessage('Could not optimize: $error', isError: true),
        ),
      );
    }
  }

  /// Repairs logical collection damage, then performs ordinary housekeeping.
  Future<void> checkDatabase() async {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<SettingsUiState>.data(
      current.copyWith(activeOperation: SettingsOperation.checkingDatabase),
    );
    try {
      final DatabaseCheckReport report = await ref
          .read(databaseCheckProvider)
          .repairIntegrity();
      if (report.outcome != DatabaseCheckOutcome.corrupt) {
        await ref.read(databaseMaintenanceProvider).optimize();
      }
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          shouldClearOperation: true,
          message: UiMessage(
            _databaseCheckMessage(report),
            isError:
                report.outcome == DatabaseCheckOutcome.corrupt ||
                report.findings.any(
                  (DatabaseCheckFinding finding) => !finding.wasRepaired,
                ),
          ),
        ),
      );
    } on Object catch (error) {
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          shouldClearOperation: true,
          message: UiMessage('Could not check database: $error', isError: true),
        ),
      );
    }
  }

  /// Opens the platform picker without treating cancellation as an error.
  Future<SelectedCollectionPackage?> chooseCollectionPackage() async {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy || current.isDirty) return null;
    try {
      return await ref.read(collectionFileDialogsProvider).pickPackage();
    } on Object catch (error) {
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          message: UiMessage(
            'Could not open the collection picker: $error',
            isError: true,
          ),
        ),
      );
      return null;
    }
  }

  /// Deletes an Android picker cache copy after it is no longer needed.
  Future<void> discardSelectedCollectionPackage(
    SelectedCollectionPackage selected,
  ) async {
    if (!selected.shouldDeleteAfterUse) return;
    try {
      if (selected.file.existsSync()) await selected.file.delete();
    } on FileSystemException {
      // Android may still hold the picker copy; its cache policy removes it.
    }
  }

  /// Replaces the collection after the screen has obtained confirmation.
  Future<void> importCollection(SelectedCollectionPackage selected) async {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy || current.isDirty) {
      await discardSelectedCollectionPackage(selected);
      return;
    }
    final OperationId operationId = OperationId(
      ref.read(idGeneratorProvider).newId(),
    );
    state = AsyncValue<SettingsUiState>.data(
      current.copyWith(activeOperation: SettingsOperation.importingCollection),
    );
    final Result<Unit> result = await ref
        .read(collectionReplacementProvider)
        .replaceWithPackage(selected.file, operationId: operationId);
    await discardSelectedCollectionPackage(selected);
    if (result.isOk) return;
    state = AsyncValue<SettingsUiState>.data(
      current.copyWith(
        shouldClearOperation: true,
        message: UiMessage(result.failureOrNull!.message, isError: true),
      ),
    );
  }

  /// Creates a full package and hands it to the platform save dialog.
  Future<void> exportCollection() async {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy || current.isDirty) return;
    final CollectionFileDialogs dialogs = ref.read(
      collectionFileDialogsProvider,
    );
    if (!dialogs.isSupported) {
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          message: const UiMessage(
            'Collection export is available on Windows and Android.',
            isError: true,
          ),
        ),
      );
      return;
    }

    final OperationId operationId = OperationId(
      ref.read(idGeneratorProvider).newId(),
    );
    final String suggestedName = _collectionPackageName(
      ref.read(clockProvider).nowUtc(),
    );
    state = AsyncValue<SettingsUiState>.data(
      current.copyWith(activeOperation: SettingsOperation.exportingCollection),
    );

    _CollectionExportDestination? destination;
    try {
      destination = await _chooseExportDestination(
        dialogs: dialogs,
        suggestedName: suggestedName,
        operationId: operationId,
        previous: current,
      );
      if (destination == null) {
        if (state.valueOrNull?.activeOperation ==
            SettingsOperation.exportingCollection) {
          _clearOperation(current);
        }
        return;
      }
      await _createAndSaveExport(
        destination: destination,
        dialogs: dialogs,
        suggestedName: suggestedName,
        operationId: operationId,
        previous: current,
      );
    } on Object catch (error) {
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          shouldClearOperation: true,
          message: UiMessage(
            'Could not export collection: $error',
            isError: true,
          ),
        ),
      );
    } finally {
      if (destination?.shouldDeleteAfterUse ?? false) {
        await _deleteScratchPackage(destination!.file);
      }
    }
  }

  Future<_CollectionExportDestination?> _chooseExportDestination({
    required CollectionFileDialogs dialogs,
    required String suggestedName,
    required OperationId operationId,
    required SettingsUiState previous,
  }) async {
    if (dialogs.usesAndroidDocumentPicker) {
      return _CollectionExportDestination(
        file: File(
          p.join(
            ref.read(appPathsProvider).collectionTransferDirectory.path,
            'collection-${operationId.value}.irbackup',
          ),
        ),
        shouldDeleteAfterUse: true,
      );
    }
    final File? file = await dialogs.chooseWindowsExportFile(suggestedName);
    if (file == null) return null;
    if (_isInsideApplicationStorage(file, ref.read(appPathsProvider).root)) {
      state = AsyncValue<SettingsUiState>.data(
        previous.copyWith(
          shouldClearOperation: true,
          message: const UiMessage(
            'Choose a folder outside the app’s private storage.',
            isError: true,
          ),
        ),
      );
      return null;
    }
    return _CollectionExportDestination(
      file: file,
      shouldDeleteAfterUse: false,
    );
  }

  Future<void> _createAndSaveExport({
    required _CollectionExportDestination destination,
    required CollectionFileDialogs dialogs,
    required String suggestedName,
    required OperationId operationId,
    required SettingsUiState previous,
  }) async {
    final Result<CollectionExportReport> export = await ref
        .read(backupServiceProvider)
        .exportCollection(target: destination.file, operationId: operationId);
    if (export.isErr) {
      state = AsyncValue<SettingsUiState>.data(
        previous.copyWith(
          shouldClearOperation: true,
          message: UiMessage(export.failureOrNull!.message, isError: true),
        ),
      );
      return;
    }
    if (dialogs.usesAndroidDocumentPicker &&
        !await dialogs.saveAndroidPackage(destination.file, suggestedName)) {
      _clearOperation(previous);
      return;
    }
    final int missingAssetCount = export.unwrap().missingAssetCount;
    final String missing = missingAssetCount == 0
        ? ''
        : ' $missingAssetCount missing image '
              '${missingAssetCount == 1 ? 'was' : 'were'} not included.';
    state = AsyncValue<SettingsUiState>.data(
      previous.copyWith(
        shouldClearOperation: true,
        message: UiMessage('Collection exported.$missing'),
      ),
    );
  }

  Future<void> _deleteScratchPackage(File packageFile) async {
    try {
      if (packageFile.existsSync()) await packageFile.delete();
    } on FileSystemException {
      // Startup retries app-owned scratch packages left behind here.
    }
  }

  void _clearOperation(SettingsUiState previous) {
    state = AsyncValue<SettingsUiState>.data(
      previous.copyWith(shouldClearOperation: true),
    );
  }

  String _databaseCheckMessage(DatabaseCheckReport report) {
    if (report.outcome == DatabaseCheckOutcome.corrupt) {
      return 'The database file is corrupt. Restart the app to restore a backup.';
    }
    if (report.findings.isEmpty) return 'Database check found no problems.';
    final int repaired = report.findings
        .where((DatabaseCheckFinding finding) => finding.wasRepaired)
        .fold<int>(
          0,
          (int count, DatabaseCheckFinding finding) => count + finding.count,
        );
    final int unrepaired = report.findings
        .where((DatabaseCheckFinding finding) => !finding.wasRepaired)
        .fold<int>(
          0,
          (int count, DatabaseCheckFinding finding) => count + finding.count,
        );
    if (unrepaired == 0) return 'Database check repaired $repaired rows.';
    return 'Database check repaired $repaired rows and found $unrepaired that need attention.';
  }

  /// The pass in one sentence.
  ///
  /// A problem is reported instead of the saving, not alongside it: how much
  /// space was recovered is irrelevant news next to a collection that has just
  /// reported itself damaged.
  String _reportMessage(DatabaseMaintenanceReport report) {
    if (!report.isHealthy) {
      final String first = report.problems.first;
      final int rest = report.problems.length - 1;
      return rest == 0
          ? 'The collection reported a problem: $first'
          : 'The collection reported ${report.problems.length} problems, '
                'starting with: $first';
    }
    final String repaired = report.wasSearchIndexRebuilt
        ? ', search index rebuilt'
        : '';
    return report.bytesReclaimed == 0
        ? 'Database optimized. There was no space left to reclaim$repaired.'
        : 'Database optimized. ${_formatBytes(report.bytesReclaimed)} '
              'reclaimed$repaired.';
  }

  /// Bytes as something a person reads, since the number is only ever shown to
  /// answer "was that worth doing".
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes bytes';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Clears the one-shot message after the view has shown it.
  void shouldClearMessage() {
    final SettingsUiState? current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<SettingsUiState>.data(
      current!.copyWith(shouldClearMessage: true),
    );
  }
}

String _collectionPackageName(DateTime instant) {
  String two(int number) => number.toString().padLeft(2, '0');
  final DateTime utc = instant.toUtc();
  return 'collection-${utc.year.toString().padLeft(4, '0')}'
      '${two(utc.month)}${two(utc.day)}${two(utc.hour)}'
      '${two(utc.minute)}${two(utc.second)}.irbackup';
}

bool _isInsideApplicationStorage(File file, Directory applicationRoot) {
  final String filePath = p.normalize(p.absolute(file.path)).toLowerCase();
  final String rootPath = p
      .normalize(p.absolute(applicationRoot.path))
      .toLowerCase();
  return p.equals(filePath, rootPath) || p.isWithin(rootPath, filePath);
}

final class _CollectionExportDestination {
  const _CollectionExportDestination({
    required this.file,
    required this.shouldDeleteAfterUse,
  });

  final File file;
  final bool shouldDeleteAfterUse;
}

final AsyncNotifierProvider<SettingsViewModel, SettingsUiState>
settingsViewModelProvider =
    AsyncNotifierProvider<SettingsViewModel, SettingsUiState>(
      SettingsViewModel.new,
    );
