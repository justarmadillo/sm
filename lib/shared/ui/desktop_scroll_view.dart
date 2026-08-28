/// Desktop list scrolling with a persistent, interactive scrollbar and
/// keyboard movement when the list itself has focus.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

class DesktopListView extends StatefulWidget {
  const DesktopListView({required this.children, this.padding, super.key});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  State<DesktopListView> createState() => _DesktopListViewState();
}

class _DesktopListViewState extends State<DesktopListView> {
  final ScrollController _controller = ScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'desktop list');

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!node.hasPrimaryFocus || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final double delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 48,
      LogicalKeyboardKey.arrowUp => -48,
      _ => 0,
    };
    if (delta == 0 || !_controller.hasClients) {
      return KeyEventResult.ignored;
    }
    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    unawaited(
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
      ),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focusNode,
    autofocus: true,
    onKeyEvent: _onKeyEvent,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _focusNode.requestFocus,
      child: ScrollbarTheme(
        data: ScrollbarThemeData(
          thumbVisibility: const WidgetStatePropertyAll<bool>(true),
          thickness: const WidgetStatePropertyAll<double>(10),
          radius: const Radius.circular(5),
          interactive: true,
          thumbColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) =>
                states.contains(WidgetState.dragged) ||
                    states.contains(WidgetState.hovered)
                ? AppColors.muted.withValues(alpha: 0.65)
                : AppColors.muted.withValues(alpha: 0.38),
          ),
        ),
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          interactive: true,
          child: ScrollConfiguration(
            behavior: const _ExplicitScrollbarBehavior(),
            child: SingleChildScrollView(
              controller: _controller,
              padding: widget.padding,
              child: Column(children: widget.children),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ExplicitScrollbarBehavior extends MaterialScrollBehavior {
  const _ExplicitScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
