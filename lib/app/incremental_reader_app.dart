/// Application bootstrap: Riverpod scope, theme, and the first screen.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/daily_queue/queue_screen.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';

/// Root widget.
///
/// The ProviderScope wrapping this widget is created in `main`, because the
/// database and paths have to be resolved before the first frame.
class IncrementalReaderApp extends StatelessWidget {
  const IncrementalReaderApp({
    this.startupMessage,
    this.startupMessageIsError = false,
    super.key,
  });

  final String? startupMessage;
  final bool startupMessageIsError;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Incremental Reader',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    // Studying is what the app is for, so it is what opens. The knowledge
    // tree is one click away rather than in front of every session.
    home: _StartupMessage(
      message: startupMessage,
      isError: startupMessageIsError,
      child: const QueueScreen(),
    ),
  );
}

final class _StartupMessage extends StatefulWidget {
  const _StartupMessage({
    required this.message,
    required this.isError,
    required this.child,
  });

  final String? message;
  final bool isError;
  final Widget child;

  @override
  State<_StartupMessage> createState() => _StartupMessageState();
}

final class _StartupMessageState extends State<_StartupMessage> {
  @override
  void initState() {
    super.initState();
    if (widget.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((Duration elapsed) {
        if (!mounted) return;
        showToast(context, widget.message!, isError: widget.isError);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
