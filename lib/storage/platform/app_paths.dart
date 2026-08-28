/// Where the application keeps its files.
///
/// The live database goes in platform-local application support — never in a
/// folder a sync client watches. Backups sit beside it in their own directory
/// so a restore never has to guess which file is which.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolved locations for one installation.
final class AppPaths {
  const AppPaths({required this.root});

  /// Resolves the platform's application-support directory.
  static Future<AppPaths> resolve() async {
    final directory = await getApplicationSupportDirectory();
    return AppPaths(
      root: Directory(p.join(directory.path, 'IncrementalReader')),
    );
  }

  /// Root of everything this installation owns.
  final Directory root;

  /// Directory holding the live database.
  Directory get databaseDirectory => Directory(p.join(root.path, 'db'));

  /// The live database file.
  File get databaseFile =>
      File(p.join(databaseDirectory.path, 'incremental_reader.sqlite'));

  /// Directory holding rolling backups.
  Directory get backupDirectory => Directory(p.join(root.path, 'backups'));

  /// Directory holding copied and cached images.
  Directory get assetDirectory => Directory(p.join(root.path, 'assets'));

  /// Directory holding rotating diagnostic logs.
  Directory get logDirectory => Directory(p.join(root.path, 'logs'));

  /// Creates every directory this installation needs.
  void ensureCreated() {
    for (final directory in <Directory>[
      root,
      databaseDirectory,
      backupDirectory,
      assetDirectory,
      logDirectory,
    ]) {
      directory.createSync(recursive: true);
    }
  }
}
