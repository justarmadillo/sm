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
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/features/reader/widgets/block_span_builder.dart';
import 'package:incremental_reader/features/reader/widgets/block_view.dart';
import 'package:incremental_reader/features/reader/widgets/reader_selection.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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
    this.onGutterTap,
    this.onExtractMarksTap,
    this.extractMarks = const <String, int>{},
    this.extractHighlights = const <String, List<BlockHighlight>>{},
    this.onVisiblePositionChanged,
    this.initialAnchor,
    this.editingBlockId,
    this.isBusy = false,
    this.onEditCommit,
    this.onEditCancel,
    this.onEditDelete,
    super.key,
  });

  final Document document;
  final ReaderSelectionController controller;

  /// The block currently open in the editor, if any.
  final String? editingBlockId;

  /// Whether a commit is in flight, so the editor can refuse a second one.
  final bool isBusy;

  final void Function(Block block, String markdown)? onEditCommit;
  final void Function(Block block)? onEditCancel;
  final void Function(Block block)? onEditDelete;
  final ReaderTypography typography;

  /// The authoritative resume marker, drawn as a filled dot.
  final ReaderAnchor? marker;

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

  /// The reading column itself, which is narrower than this widget and is
  /// where the scrollbar actually sits.
  final GlobalKey _columnKey = GlobalKey();

  ReaderAnchor? _lastReportedAnchor;
  Offset? _pressOrigin;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _positions.itemPositions.addListener(_onVisibleBlocksChanged);
    final anchor = widget.initialAnchor;
    if (anchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpToAnchor(anchor));
    }
  }

  @override
  void didUpdateWidget(ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Any new document, not merely a new source. Editing re-derives the
    // document of the *same* source, and a controller left on the previous one
    // resolves selections against text that is no longer stored: the range it
    // produces hashes a passage the source can no longer yield, and extraction
    // then refuses it as "no longer matching".
    if (!identical(oldWidget.document, widget.document)) {
      widget.controller.setDocument(widget.document);
      _lastReportedAnchor = null;
    }
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_onVisibleBlocksChanged);
    _keyboardFocus.dispose();
    super.dispose();
  }

  /// Scrolls so that [anchor]'s block is at the top of the viewport.
  ///
  /// Works for unmounted blocks: the list resolves an index, not an offset.
  void jumpToAnchor(ReaderAnchor anchor, {double alignment = 0.08}) {
    final index = widget.document.blockIndexAtOffset(anchor.utf8Offset);
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
    final index = widget.document.blockIndexAtOffset(anchor.utf8Offset);
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
        .where((ItemPosition position) => position.itemTrailingEdge > 0)
        .fold<ItemPosition?>(
          null,
          (ItemPosition? best, ItemPosition position) =>
              best == null || position.itemLeadingEdge < best.itemLeadingEdge
              ? position
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

  void _onVisibleBlocksChanged() {
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
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    // Reading shortcuts belong to the reading surface, and only while it is
    // the thing the keyboard is pointed at. A key event travels up from
    // whatever holds focus, so without this the page-down binding on Space
    // would fire for a space typed into a field nested inside this view —
    // the caret would stay put and the article would jump.
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
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
    // Which block carries the dot is a rendering question, answered from the
    // stored offset every build. Nothing persists a block id.
    final marker = widget.marker;
    final markerBlockId = marker == null
        ? null
        : widget.document.blockForAnchor(marker)?.id;

    final bool isEditing = widget.editingBlockId != null;

    return Focus(
      focusNode: _keyboardFocus,
      // Autofocus would take the caret away from the editor the moment a
      // rebuild put this widget back in the tree.
      autofocus: !isEditing,
      onKeyEvent: isEditing ? null : _onKeyEvent,
      child: _selectionGestures(
        isEditing: isEditing,
        child: Center(
          child: ConstrainedBox(
            key: _columnKey,
            constraints: BoxConstraints(
              maxWidth: widget.typography.columnWidth,
            ),
            child: _scrollbarTheme(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (BuildContext context, Widget? child) =>
                    _blockList(markerBlockId),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Raw pointer events rather than a drag recognizer: a selection drag must
  /// not enter the gesture arena against the scrollable, and on desktop a
  /// mouse drag does not scroll anyway, so there is nothing to arbitrate.
  ///
  /// While a block is open in the editor these are all off. They are not
  /// merely unnecessary — the double-tap recognizer holds the gesture arena
  /// for its timeout, so every click inside the editor waits on it, and the
  /// tap handler would pull keyboard focus back out of the field the user is
  /// typing in.
  Widget _selectionGestures({required bool isEditing, required Widget child}) {
    return Listener(
      onPointerDown: isEditing ? null : _onPointerDown,
      onPointerMove: isEditing ? null : _onPointerMove,
      onPointerUp: isEditing ? null : _onPointerUp,
      onPointerCancel: isEditing ? null : _onPointerCancel,
      // A wheel tick means the user is travelling, not selecting. Without
      // this a press that never became a drag stayed armed, and the first
      // pixel of pointer movement after the page had scrolled underneath it
      // swept a selection from wherever that stale origin now pointed.
      onPointerSignal: isEditing ? null : (PointerSignalEvent _) => _endDrag(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: isEditing
            ? null
            : () {
                // Clicking the text is also how the reader takes keyboard
                // focus back from a toolbar button.
                _keyboardFocus.requestFocus();
                widget.controller.clear();
              },
        onDoubleTapDown: isEditing
            ? null
            : (TapDownDetails details) =>
                  widget.controller.selectWordAt(details.globalPosition),
        child: child,
      ),
    );
  }

  /// A permanently visible, draggable scrollbar: in a 50k-word chapter it is
  /// both the position indicator and the only quick way to travel, exactly as
  /// in a document viewer.
  Widget _scrollbarTheme({required Widget child}) {
    return ScrollbarTheme(
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
      child: child,
    );
  }

  /// One [BlockView] per block, built lazily so a long document costs only
  /// what is on screen.
  Widget _blockList(String? markerBlockId) {
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
          isMarkerPainted: block.id == markerBlockId,
          extractMarks: widget.extractMarks[block.id] ?? 0,
          onGutterTap: widget.onGutterTap == null ? null : _onBlockGutterTap,
          onExtractMarksTap: widget.onExtractMarksTap,
          isEditing: widget.editingBlockId == block.id,
          isBusy: widget.isBusy,
          onEditCommit: widget.onEditCommit,
          onEditCancel: widget.onEditCancel,
          onEditDelete: widget.onEditDelete,
          onParagraphMounted: widget.controller.registerParagraph,
          onParagraphUnmounted: widget.controller.unregisterParagraph,
        );
      },
    );
  }

  /// Resolves a gutter click to a precise in-block anchor, falling back to the
  /// block's own start when the click misses any character.
  void _onBlockGutterTap(Block block, Offset position) {
    final anchor =
        widget.controller.anchorAtGlobalPosition(position, blockId: block.id) ??
        ReaderAnchor(
          utf8Offset: block.sourceStartUtf8,
          contentRevision: widget.document.contentRevision,
        );
    widget.onGutterTap!(anchor);
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
  ///
  /// Measured against the reading column, not against this widget. The column
  /// is centred and capped at the configured width, so on a wide window the
  /// scrollbar sits well inside this widget's right edge — and a strip taken
  /// off that edge protected nothing but empty margin.
  bool _canStartSelectionAt(Offset global) {
    final column = _columnKey.currentContext?.findRenderObject();
    if (column is RenderBox && column.hasSize) {
      final double right = column
          .localToGlobal(Offset(column.size.width, 0))
          .dx;
      if (global.dx > right - _kScrollbarStrip) return false;
    }
    return widget.controller.isInsideTextColumn(global);
  }

  void _onPointerDown(PointerDownEvent event) {
    // Whatever the press turns out to be, it supersedes any earlier one: a
    // press left armed by an event the reader chose to ignore must not be
    // able to start a selection later.
    _endDrag();
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
    _isDragging = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final origin = _pressOrigin;
    if (origin == null) return;
    if (!_isDragging) {
      if ((event.position - origin).distance < _kDragSlop) return;
      _isDragging = true;
      widget.controller.beginAt(origin);
    }
    widget.controller.extendTo(event.position);
  }

  void _onPointerUp(PointerUpEvent event) => _endDrag();

  void _onPointerCancel(PointerCancelEvent event) => _endDrag();

  void _endDrag() {
    _pressOrigin = null;
    _isDragging = false;
  }
}
