/// The virtualized reading surface.
///
/// Typical sources are 10–50k-word chapters, so blocks are mounted and
/// unmounted as the user scrolls. That is what makes the separation between
/// *anchors* and *widgets* load-bearing: scrolling to a marker 40k words down
/// must work when nothing near it has ever been laid out, so navigation is
/// driven by block index, not by pixel offset.
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../app/theme.dart';
import '../../../domain/content/block.dart';
import '../../../domain/content/document.dart';
import '../../../domain/content/reader_anchor.dart';
import 'block_span_builder.dart';
import 'block_view.dart';
import 'reader_selection.dart';

/// Distance a mouse must travel before a press becomes a drag at all.
///
/// Wider than a hit-test slop on purpose: at three pixels, the hand tremor in
/// an ordinary click produced a one-character selection, so every click on the
/// page left a stray highlight behind.
const double _kDragSlop = 6;

/// Width of the strip at the right edge reserved for the scrollbar.
const double _kScrollbarStrip = 18;

/// Renders a document with drag-selection and marker gutters.
class ReaderView extends StatefulWidget {
  const ReaderView({
    required this.document,
    required this.controller,
    this.typography = ReaderTypography.standard,
    this.marker,
    this.softPosition,
    this.onGutterTap,
    this.onExtractMarksTap,
    this.extractMarks = const <String, int>{},
    this.extractHighlights = const <String, List<BlockHighlight>>{},
    this.onVisiblePositionChanged,
    this.initialAnchor,
    super.key,
  });

  final Document document;
  final ReaderSelectionController controller;
  final ReaderTypography typography;

  /// The authoritative resume marker, drawn as a filled dot.
  final ReaderAnchor? marker;

  /// The soft position, drawn as an outlined dot.
  final ReaderAnchor? softPosition;

  /// Called when the user clicks empty gutter beside a block.
  final void Function(ReaderAnchor anchor)? onGutterTap;

  /// Called when the user clicks a block's extract mark.
  final void Function(Block block)? onExtractMarksTap;

  /// How many extracts cover each block, keyed by block id.
  final Map<String, int> extractMarks;

  /// Persistent washes marking already-extracted text, keyed by block id.
  ///
  /// Supplied rather than computed here so the Reader stays a renderer: the
  /// mapping from provenance to character ranges belongs beside the extracts.
  final Map<String, List<BlockHighlight>> extractHighlights;

  /// Reports the topmost fully visible block as the user scrolls, so the soft
  /// position can be persisted without the Reader owning that policy.
  final void Function(ReaderAnchor anchor)? onVisiblePositionChanged;

  /// Where to open. Resolved by block index, so it works for a block that has
  /// never been mounted.
  final ReaderAnchor? initialAnchor;

  @override
  State<ReaderView> createState() => ReaderViewState();
}

/// Public so callers can drive navigation from a toolbar or a queue action.
class ReaderViewState extends State<ReaderView> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ScrollOffsetController _offsetController = ScrollOffsetController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'reader');

  ReaderAnchor? _lastReportedAnchor;
  Offset? _pressOrigin;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _positions.itemPositions.addListener(_handlePositionsChanged);
    final anchor = widget.initialAnchor;
    if (anchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpToAnchor(anchor));
    }
  }

  @override
  void didUpdateWidget(ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.sourceId != widget.document.sourceId) {
      widget.controller.setDocument(widget.document);
      _lastReportedAnchor = null;
    }
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_handlePositionsChanged);
    _keyboardFocus.dispose();
    super.dispose();
  }

  /// Scrolls so that [anchor]'s block is at the top of the viewport.
  ///
  /// Works for unmounted blocks: the list resolves an index, not an offset.
  void jumpToAnchor(ReaderAnchor anchor, {double alignment = 0.08}) {
    final index = widget.document.indexOfBlock(anchor.blockId);
    if (index == null || !_scrollController.isAttached) return;
    _scrollController.jumpTo(index: index, alignment: alignment);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _alignMountedAnchor(
        anchor,
        alignment,
        const Duration(milliseconds: 1),
      ),
    );
  }

  /// Scrolls to [anchor] with an animation, for in-session navigation.
  Future<void> animateToAnchor(
    ReaderAnchor anchor, {
    double alignment = 0.08,
    Duration duration = const Duration(milliseconds: 250),
  }) async {
    final index = widget.document.indexOfBlock(anchor.blockId);
    if (index == null || !_scrollController.isAttached) return;
    await _scrollController.scrollTo(
      index: index,
      alignment: alignment,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
    await _alignMountedAnchor(anchor, alignment, duration);
  }

  /// The topmost block currently visible, or null before first layout.
  Block? get topVisibleBlock {
    final positions = _positions.itemPositions.value;
    if (positions.isEmpty) return null;
    final top = positions
        .where((ItemPosition p) => p.itemTrailingEdge > 0)
        .fold<ItemPosition?>(
          null,
          (ItemPosition? best, ItemPosition p) =>
              best == null || p.itemLeadingEdge < best.itemLeadingEdge
              ? p
              : best,
        );
    if (top == null) return null;
    return widget.document.blocks[top.index];
  }

  /// Exact text position currently nearest the top of the viewport.
  ReaderAnchor? get topVisibleAnchor {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final probe = renderObject.localToGlobal(
      Offset(renderObject.size.width / 2, 1),
    );
    return widget.controller.anchorAtGlobalPosition(probe);
  }

  void _handlePositionsChanged() {
    final callback = widget.onVisiblePositionChanged;
    if (callback == null) return;
    final anchor = topVisibleAnchor;
    if (anchor == null || anchor == _lastReportedAnchor) return;
    _lastReportedAnchor = anchor;
    callback(anchor);
  }

  Future<void> _alignMountedAnchor(
    ReaderAnchor anchor,
    double alignment,
    Duration duration,
  ) async {
    final caret = widget.controller.globalOffsetForAnchor(anchor);
    final renderObject = context.findRenderObject();
    if (caret == null || renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final target = top + renderObject.size.height * alignment;
    final delta = caret.dy - target;
    if (delta.abs() < 1) return;
    await _offsetController.animateScroll(
      offset: delta,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  /// Scrolls by [pixels], positive downward.
  Future<void> scrollBy(double pixels, {Duration? duration}) async {
    if (!_scrollController.isAttached) return;
    await _offsetController.animateScroll(
      offset: pixels,
      duration: duration ?? const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
    );
  }

  /// Scrolls one screenful, positive downward.
  ///
  /// Slightly less than a full viewport so a line of context carries over,
  /// which is the difference between paging and losing your place.
  Future<void> scrollPage(int pages) async {
    final height = context.size?.height ?? 600;
    await scrollBy(
      height * 0.85 * pages,
      duration: const Duration(milliseconds: 180),
    );
  }

  /// Jumps to the top of the document.
  void scrollToStart() {
    if (widget.document.blocks.isEmpty || !_scrollController.isAttached) return;
    _scrollController.jumpTo(index: 0);
  }

  /// Jumps to the end of the document.
  void scrollToEnd() {
    if (widget.document.blocks.isEmpty || !_scrollController.isAttached) return;
    _scrollController.jumpTo(index: widget.document.blocks.length - 1);
  }

  /// Gives the reading surface keyboard focus.
  void requestKeyboardFocus() => _keyboardFocus.requestFocus();

  /// Handles the keys a reader expects to move the page with.
  ///
  /// Intercepted at the focus node rather than registered as shortcuts so the
  /// arrow keys never reach focus traversal, which would jump between buttons
  /// instead of scrolling the text.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    const double line = 64;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        unawaited(scrollBy(line));
      case LogicalKeyboardKey.arrowUp:
        unawaited(scrollBy(-line));
      case LogicalKeyboardKey.pageDown:
      case LogicalKeyboardKey.space:
        unawaited(scrollPage(1));
      case LogicalKeyboardKey.pageUp:
        unawaited(scrollPage(-1));
      case LogicalKeyboardKey.home:
        scrollToStart();
      case LogicalKeyboardKey.end:
        scrollToEnd();
      case LogicalKeyboardKey.escape:
        widget.controller.clear();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final markerBlockId = widget.marker?.blockId;
    final softBlockId = widget.softPosition?.blockId;

    // Raw pointer events rather than a drag recognizer: a selection drag must
    // not enter the gesture arena against the scrollable, and on desktop a
    // mouse drag does not scroll anyway, so there is nothing to arbitrate.
    return Focus(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            // Clicking the text is also how the reader takes keyboard focus
            // back from a toolbar button.
            _keyboardFocus.requestFocus();
            widget.controller.clear();
          },
          onDoubleTapDown: (TapDownDetails details) =>
              widget.controller.selectWordAt(details.globalPosition),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.typography.columnWidth,
              ),
              // A permanently visible, draggable scrollbar: in a 50k-word
              // chapter it is both the position indicator and the only quick
              // way to travel, exactly as in a document viewer.
              child: ScrollbarTheme(
                data: ScrollbarThemeData(
                  thumbVisibility: const WidgetStatePropertyAll<bool>(true),
                  thickness: const WidgetStatePropertyAll<double>(9),
                  radius: const Radius.circular(5),
                  interactive: true,
                  thumbColor: WidgetStateProperty.resolveWith<Color>(
                    (Set<WidgetState> states) =>
                        states.contains(WidgetState.dragged) ||
                            states.contains(WidgetState.hovered)
                        ? AppColors.muted.withValues(alpha: 0.65)
                        : AppColors.muted.withValues(alpha: 0.35),
                  ),
                ),
                child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (BuildContext context, Widget? child) {
                    return ScrollablePositionedList.builder(
                      itemScrollController: _scrollController,
                      scrollOffsetController: _offsetController,
                      itemPositionsListener: _positions,
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                      itemCount: widget.document.blocks.length,
                      itemBuilder: (BuildContext context, int index) {
                        final block = widget.document.blocks[index];
                        return BlockView(
                          block: block,
                          typography: widget.typography,
                          highlights: _highlightsFor(block),
                          markerPainted: block.id == markerBlockId,
                          softMarkerPainted:
                              block.id == softBlockId &&
                              block.id != markerBlockId,
                          extractMarks: widget.extractMarks[block.id] ?? 0,
                          onGutterTap: widget.onGutterTap == null
                              ? null
                              : (Block block, Offset position) {
                                  final anchor =
                                      widget.controller.anchorAtGlobalPosition(
                                        position,
                                        blockId: block.id,
                                      ) ??
                                      ReaderAnchor(
                                        blockId: block.id,
                                        utf8Offset: 0,
                                      );
                                  widget.onGutterTap!(anchor);
                                },
                          onExtractMarksTap: widget.onExtractMarksTap,
                          onParagraphMounted:
                              widget.controller.registerParagraph,
                          onParagraphUnmounted:
                              widget.controller.unregisterParagraph,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// What to paint over [block]: the live selection first, then the
  /// persistent extract marks, because the span builder resolves an overlap
  /// by taking the first range that covers a character.
  List<BlockHighlight> _highlightsFor(Block block) {
    final selection = widget.controller.highlightsFor(block);
    final extracts =
        widget.extractHighlights[block.id] ?? const <BlockHighlight>[];
    if (extracts.isEmpty) return selection;
    if (selection.isEmpty) return extracts;
    return <BlockHighlight>[...selection, ...extracts];
  }

  /// Whether a press at [global] may begin a selection.
  ///
  /// The scrollbar strip is excluded by geometry rather than by hit-testing
  /// it: a wide code block can lay out past the viewport, so the text column
  /// alone is not enough to keep a thumb-drag from selecting.
  bool _canStartSelectionAt(Offset global) {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final local = renderObject.globalToLocal(global);
      if (local.dx > renderObject.size.width - _kScrollbarStrip) return false;
    }
    return widget.controller.isInsideTextColumn(global);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    if (event.buttons & kPrimaryMouseButton == 0) return;
    // Only presses that land in the reading column can begin a selection.
    // The scrollbar and the marker gutter live outside it, and a press there
    // belongs entirely to them: dragging the scrollbar thumb used to scroll
    // the page and sweep a selection across the text at the same time.
    if (!_canStartSelectionAt(event.position)) return;
    // Remember where the press landed, but do not select yet: a plain click
    // should clear the selection, not create an empty one.
    _pressOrigin = event.position;
    _dragging = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final origin = _pressOrigin;
    if (origin == null) return;
    if (!_dragging) {
      if ((event.position - origin).distance < _kDragSlop) return;
      _dragging = true;
      widget.controller.beginAt(origin);
    }
    widget.controller.extendTo(event.position);
  }

  void _handlePointerUp(PointerUpEvent event) => _endDrag();

  void _handlePointerCancel(PointerCancelEvent event) => _endDrag();

  void _endDrag() {
    _pressOrigin = null;
    _dragging = false;
  }
}
