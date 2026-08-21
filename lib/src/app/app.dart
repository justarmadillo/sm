/// Application bootstrap: Riverpod scope, theme, and the first screen.
library;

import 'package:flutter/material.dart';
import '../features/library/presentation/library_screen.dart';
import 'theme.dart';

/// Root widget.
///
/// The ProviderScope wrapping this widget is created in `main`, because the
/// database and paths have to be resolved before the first frame.
class IncrementalReaderApp extends StatelessWidget {
  const IncrementalReaderApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Incremental Reader',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const LibraryScreen(),
  );
}
