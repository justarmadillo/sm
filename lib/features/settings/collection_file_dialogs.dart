/// Native file dialogs used only by collection transfer in Settings.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

/// A selected package and whether the picker created a disposable cache copy.
final class SelectedCollectionPackage {
  const SelectedCollectionPackage({
    required this.file,
    required this.shouldDeleteAfterUse,
  });

  final File file;
  final bool shouldDeleteAfterUse;
}

/// Keeps Windows and Android dialog differences out of the view model.
class CollectionFileDialogs {
  const CollectionFileDialogs();

  static const XTypeGroup _packageType = XTypeGroup(
    label: 'Incremental Reader collection',
    extensions: <String>['irbackup'],
  );

  bool get isSupported => Platform.isWindows || Platform.isAndroid;

  bool get usesAndroidDocumentPicker => Platform.isAndroid;

  /// Selects one package without transferring its bytes through Dart memory.
  Future<SelectedCollectionPackage?> pickPackage() async {
    if (Platform.isAndroid) {
      final String? path = await FlutterFileDialog.pickFile(
        params: const OpenFileDialogParams(
          fileExtensionsFilter: <String>['irbackup'],
          mimeTypesFilter: <String>[
            'application/zip',
            'application/octet-stream',
          ],
          copyFileToCacheDir: true,
        ),
      );
      return path == null
          ? null
          : SelectedCollectionPackage(
              file: File(path),
              shouldDeleteAfterUse: true,
            );
    }
    if (Platform.isWindows) {
      final XFile? selected = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[_packageType],
      );
      return selected == null
          ? null
          : SelectedCollectionPackage(
              file: File(selected.path),
              shouldDeleteAfterUse: false,
            );
    }
    return null;
  }

  /// Chooses the Windows destination before package creation begins.
  Future<File?> chooseWindowsExportFile(String suggestedName) async {
    if (!Platform.isWindows) return null;
    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const <XTypeGroup>[_packageType],
    );
    if (location == null) return null;
    final String path = location.path.toLowerCase().endsWith('.irbackup')
        ? location.path
        : '${location.path}.irbackup';
    return File(path);
  }

  /// Copies an app-owned package to an Android document chosen by the user.
  Future<bool> saveAndroidPackage(
    File packageFile,
    String suggestedName,
  ) async {
    if (!Platform.isAndroid) return false;
    final String? savedLocation = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        sourceFilePath: packageFile.path,
        fileName: suggestedName,
        mimeTypesFilter: const <String>['application/zip'],
      ),
    );
    return savedLocation != null;
  }
}
