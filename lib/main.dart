/// Where the app starts.
///
/// Paths are resolved here; `CollectionSessionRoot` owns opening and closing
/// the current database-backed provider scope so import can replace it safely.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/app/collection_session_root.dart';
import 'package:incremental_reader/storage/platform/app_paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final paths = await AppPaths.resolve();
  paths.ensureCreated();
  runApp(CollectionSessionRoot(paths: paths));
}
