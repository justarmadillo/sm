/// Selects a persistent backup folder and mirrors packages into it.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// A folder value suitable for persistence in application settings.
final class SelectedAutomaticBackupFolder {
  const SelectedAutomaticBackupFolder({
    required this.location,
    required this.label,
  });

  /// A Windows path or Android document-tree URI.
  final String location;

  final String label;
}

/// Keeps platform folder permissions outside backup and Settings logic.
class AutomaticBackupFolderAccess {
  const AutomaticBackupFolderAccess();

  static const MethodChannel _androidChannel = MethodChannel(
    'incremental_reader/automatic_backup',
  );

  bool get isSupported => Platform.isWindows || Platform.isAndroid;

  /// Opens the native folder picker and returns a restart-safe selection.
  Future<SelectedAutomaticBackupFolder?> chooseFolder() async {
    if (Platform.isWindows) {
      final String? location = await getDirectoryPath();
      if (location == null) return null;
      return SelectedAutomaticBackupFolder(location: location, label: location);
    }
    if (Platform.isAndroid) {
      final Map<Object?, Object?>? selected = await _androidChannel
          .invokeMapMethod<Object?, Object?>('chooseFolder');
      if (selected == null) return null;
      final String? location = selected['location'] as String?;
      final String? label = selected['label'] as String?;
      if (location == null || location.isEmpty) {
        throw StateError('Android returned an empty backup folder');
      }
      return SelectedAutomaticBackupFolder(
        location: location,
        label: label?.trim().isNotEmpty == true ? label!.trim() : location,
      );
    }
    return null;
  }

  /// Copies [packageFile] into a folder selected on the current platform.
  Future<void> saveBackup({
    required File packageFile,
    required String directoryLocation,
  }) async {
    if (Platform.isWindows) {
      final Directory directory = Directory(directoryLocation);
      if (!directory.existsSync()) {
        throw FileSystemException(
          'The selected backup folder is no longer available',
          directoryLocation,
        );
      }
      if (p.equals(
        p.absolute(packageFile.parent.path),
        p.absolute(directory.path),
      )) {
        return;
      }
      await packageFile.copy(
        p.join(directory.path, p.basename(packageFile.path)),
      );
      return;
    }
    if (Platform.isAndroid) {
      final bool? didSave = await _androidChannel
          .invokeMethod<bool>('saveBackup', <String, String>{
            'sourcePath': packageFile.path,
            'directoryLocation': directoryLocation,
            'fileName': p.basename(packageFile.path),
          });
      if (didSave != true) {
        throw StateError('Android could not write the automatic backup');
      }
      return;
    }
    throw UnsupportedError(
      'Automatic backup folders are available on Windows and Android',
    );
  }
}
