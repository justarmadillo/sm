/// Application bootstrap: Riverpod scope, theme, and the first screen.
library;

import 'package:flutter/material.dart';
import '../features/queue/presentation/queue_screen.dart';
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
    // Studying is what the app is for, so it is what opens. The knowledge
    // tree is one click away rather than in front of every session.
    home: const QueueScreen(),
  );
}
