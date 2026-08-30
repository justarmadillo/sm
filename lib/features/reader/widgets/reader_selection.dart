/// Block-aware text selection with exact source coordinates.
///
/// Flutter's own `SelectionArea` reports the *text* a user selected, not where
/// it came from, which is useless for extraction: two identical sentences in a
/// chapter are indistinguishable. This controller instead asks each laid-out
/// paragraph for the character offset under the pointer, and because the span
/// tree's flattened text equals the block's rendered text exactly, that offset
/// maps straight back to a UTF-8 source offset.
///
/// Working from character offsets rather than pixels is also what makes the
/// mapping survive font changes, text scaling, and window resizes: the layout
/// moves, the character indices do not.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/inline_markup.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/reader_coordinates.dart';
import 'package:incremental_reader/features/reader/widgets/block_span_builder.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// A selection expressed in rendered character coordinates.
@immutable
final class ReaderSelection {
  const ReaderSelection({
    required this.startBlockId,
    required this.startRendered,
    required this.endBlockId,
    required this.endRendered,
  });

  final String startBlockId;
  final int startRendered;
  final String endBlockId;
  final int endRendered;

  /// Whether the selection covers no characters.
  bool get isCollapsed =>
      startBlockId == endBlockId && startRendered == endRendered;

  /// Whether both ends are in the same block.
  bool get isSameBlock => startBlockId == endBlockId;

  @override
  bool operator ==(Object other) =>
      other is ReaderSelection &&
      other.startBlockId == startBlockId &&
      other.startRendered == startRendered &&
      other.endBlockId == endBlockId &&
      other.endRendered == endRendered;

  @override
  int get hashCode =>
      Object.hash(startBlockId, startRendered, endBlockId, endRendered);

  @override
  String toString() =>
      'ReaderSelection($startBlockId@$startRendered -> $endBlockId@$endRendered)';
}

/// Tracks the current selection and the paragraphs currently laid out.
///
/// Only mounted blocks can be hit-tested, which is exactly right: the user can
/// only drag across what is on screen. Anchors, by contrast, resolve for every
/// block whether mounted or not.
final class ReaderSelectionController extends ChangeNotifier {
  ReaderSelectionController(this._document)
    : _coordinates = ReaderCoordinates(_document);

  Document _document;

  /// The one conversion path from screen positions to stored offsets.
  ReaderCoordinates _coordinates;

  final Map<String, GlobalKey> _paragraphs = <String, GlobalKey>{};

  ReaderSelection? _selection;
  String? _anchorBlockId;
  int _anchorRendered = 0;

  final _ViewportMoves _viewportMoves = _ViewportMoves();
  bool _isViewportMoveQueued = false;
  bool _isDisposed = false;

  /// Fires when the selection changes *or* the text scrolls under it.
  ///
  /// Anything anchored to where the selection sits on screen — the floating
  /// toolbar, the drag handles — has to follow both. The document itself
  /// listens to this controller directly instead, because repainting every
  /// mounted paragraph on each scroll tick would cost far more than it buys.
  late final Listenable selectionOnScreen = Listenable.merge(<Listenable>[
    this,
    _viewportMoves,
  ]);

  /// The document being read.
  Document get document => _document;

  /// The current selection, or null when nothing is selected.
  ReaderSelection? get selection => _selection;

  /// Whether a non-empty selection exists.
  bool get hasSelection => _selection != null && !_selection!.isCollapsed;

  /// M2 extraction is intentionally limited to one block.
  bool get canExtract => hasSelection && _selection!.isSameBlock;

  /// Points the controller at a different document and clears state.
  void setDocument(Document document) {
    _document = document;
    _coordinates = ReaderCoordinates(document);
    // The selection goes: it was measured in a layout of text that has been
    // replaced, so carrying it across would produce coordinates into a
    // document nobody is looking at any more.
    _selection = null;
    _anchorBlockId = null;
    // The paragraph map deliberately survives. Its entries are maintained by
    // the blocks themselves as they mount and unmount, so clearing it here
    // would drop the live render objects of every block that stayed on screen
    // — and nothing would put them back, because an unchanged block does not
    // re-register.
    _notifyWhenSafe();
  }

  /// Notifies listeners, waiting for the end of the frame if one is running.
  ///
  /// Re-pointing at a new document happens in `didUpdateWidget`, which runs
  /// inside build. Notifying there marks listening builders dirty mid-build,
  /// which the framework rejects outright — so the news waits for the frame
  /// to finish. The state itself is already updated, so nothing reads a stale
  /// document in the meantime.
  void _notifyWhenSafe() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final bool building =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (!building) {
      notifyListeners();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  /// Says the text may have moved under the selection.
  ///
  /// Reported after the frame rather than during it: a scroll callback runs
  /// before layout, so a listener reading a paragraph's position now would
  /// place itself against where the text used to be. One pending report at a
  /// time, because a fling produces a callback per pixel.
  void reportViewportMoved() {
    if (_isViewportMoveQueued || _isDisposed) return;
    _isViewportMoveQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _isViewportMoveQueued = false;
      if (_isDisposed) return;
      _viewportMoves.notifyMoved();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _viewportMoves.dispose();
    super.dispose();
  }

  /// Registers a laid-out paragraph so it can be hit-tested.
  void registerParagraph(String blockId, GlobalKey key) {
    _paragraphs[blockId] = key;
  }

  /// Removes a paragraph only if it is still the registered render object.
  ///
  /// Flutter can mount a replacement sliver before disposing the old one. An
  /// old paragraph must not unregister the new paragraph that replaced it.
  void unregisterParagraph(String blockId, GlobalKey key) {
    if (identical(_paragraphs[blockId], key)) {
      _paragraphs.remove(blockId);
    }
  }

  /// Whether [blockId] currently has a paragraph that can be hit-tested.
  ///
  /// False for a block that is scrolled away *and* for one open in the editor:
  /// a field is not a paragraph, and resolving a selection against the layout
  /// it replaced would produce offsets from something nobody can see.
  bool isParagraphMounted(String blockId) => _paragraphs.containsKey(blockId);

  /// Whether [globalPosition] falls within the horizontal span of the text.
  ///
  /// Deliberately a *column* test, not a glyph test: readers start a
  /// selection in the ragged space after a short line or in the gap between
  /// paragraphs, and demanding a hit on a character makes selection feel
  /// broken. What it does exclude is everything beside the column — the
  /// marker gutter on the left and the scrollbar on the right — so a press
  /// there is left to the widget that owns it.
  bool isInsideTextColumn(Offset globalPosition) {
    var left = double.infinity;
    var right = double.negativeInfinity;
    for (final entry in _paragraphs.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderParagraph || !renderObject.hasSize) continue;
      final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (rect.left < left) left = rect.left;
      if (rect.right > right) right = rect.right;
    }
    // Nothing laid out yet: allow the press. The guard exists to protect the
    // scrollbar, and failing closed would silently disable selection.
    if (left > right) return true;
    return globalPosition.dx >= left - 4 && globalPosition.dx <= right + 4;
  }

  /// Starts a selection at the character under [globalPosition].
  void beginAt(Offset globalPosition) {
    final hit = _hitTest(globalPosition);
    if (hit == null) return;
    _anchorBlockId = hit.blockId;
    _anchorRendered = hit.renderedIndex;
    _selection = ReaderSelection(
      startBlockId: hit.blockId,
      startRendered: hit.renderedIndex,
      endBlockId: hit.blockId,
      endRendered: hit.renderedIndex,
    );
    notifyListeners();
  }

  /// Extends the in-progress selection to [globalPosition].
  void extendTo(Offset globalPosition) {
    final anchorBlockId = _anchorBlockId;
    if (anchorBlockId == null) return;
    final hit = _hitTest(globalPosition);
    if (hit == null) return;

    final anchorIndex = _document.indexOfBlock(anchorBlockId);
    final focusIndex = _document.indexOfBlock(hit.blockId);
    if (anchorIndex == null || focusIndex == null) return;

    final anchorFirst =
        focusIndex > anchorIndex ||
        (focusIndex == anchorIndex && hit.renderedIndex >= _anchorRendered);

    final next = anchorFirst
        ? ReaderSelection(
            startBlockId: anchorBlockId,
            startRendered: _anchorRendered,
            endBlockId: hit.blockId,
            endRendered: hit.renderedIndex,
          )
        : ReaderSelection(
            startBlockId: hit.blockId,
            startRendered: hit.renderedIndex,
            endBlockId: anchorBlockId,
            endRendered: _anchorRendered,
          );

    if (next == _selection) return;
    _selection = next;
    notifyListeners();
  }

  /// Pins the end the user is *not* dragging, before a handle moves.
  ///
  /// The handle then travels through [extendTo], the same path a
  /// press-and-sweep takes, so dragging one handle past the other flips the
  /// two ends rather than collapsing the selection to nothing.
  void beginEdgeDrag({required bool isStartEdge}) {
    final selection = _selection;
    if (selection == null) return;
    _anchorBlockId = isStartEdge
        ? selection.endBlockId
        : selection.startBlockId;
    _anchorRendered = isStartEdge
        ? selection.endRendered
        : selection.startRendered;
  }

  /// Selects the word under [globalPosition].
  void selectWordAt(Offset globalPosition) {
    final hit = _hitTest(globalPosition);
    if (hit == null) return;
    final block = _document.blockById(hit.blockId);
    if (block == null) return;

    final text = block.renderedText;
    var start = hit.renderedIndex.clamp(0, text.length);
    var end = start;
    while (start > 0 && !_isBreak(text.codeUnitAt(start - 1))) {
      start--;
    }
    while (end < text.length && !_isBreak(text.codeUnitAt(end))) {
      end++;
    }
    if (start == end) return;

    _anchorBlockId = hit.blockId;
    _anchorRendered = start;
    _selection = ReaderSelection(
      startBlockId: hit.blockId,
      startRendered: start,
      endBlockId: hit.blockId,
      endRendered: end,
    );
    notifyListeners();
  }

  /// Drops the selection.
  void clear() {
    if (_selection == null) return;
    _selection = null;
    _anchorBlockId = null;
    notifyListeners();
  }

  /// Highlights to paint for [block] under the current selection.
  List<BlockHighlight> highlightsFor(Block block) {
    final selection = _selection;
    if (selection == null || selection.isCollapsed) {
      return const <BlockHighlight>[];
    }
    final startIndex = _document.indexOfBlock(selection.startBlockId);
    final endIndex = _document.indexOfBlock(selection.endBlockId);
    if (startIndex == null || endIndex == null) return const <BlockHighlight>[];
    if (block.index < startIndex || block.index > endIndex) {
      return const <BlockHighlight>[];
    }

    final start = block.index == startIndex ? selection.startRendered : 0;
    final end = block.index == endIndex
        ? selection.endRendered
        : block.renderedText.length;
    if (end <= start) return const <BlockHighlight>[];
    return <BlockHighlight>[
      BlockHighlight(start: start, end: end, color: AppColors.selection),
    ];
  }

  /// Anchor at the exact start of the current selection, or null.
  ///
  /// Used by the selection toolbar to place the resume marker where the user
  /// actually pointed, rather than rounding to the start of the block.
  ReaderAnchor? selectionStartAnchor() {
    final selection = _selection;
    if (selection == null) return null;
    final block = _document.blockById(selection.startBlockId);
    if (block == null) return null;
    return _coordinates.anchorForRendered(block, selection.startRendered);
  }

  /// Screen rectangle covering the current selection, or null.
  ///
  /// Only mounted blocks contribute: a selection that scrolled off screen has
  /// no on-screen bounds, and the caller should hide whatever it was anchoring
  /// rather than guess a position.
  Rect? selectionBoundsGlobal() {
    final selection = _selection;
    if (selection == null || selection.isCollapsed) return null;

    Rect? bounds;
    for (final entry in _paragraphs.entries) {
      final block = _document.blockById(entry.key);
      if (block == null) continue;
      final highlights = highlightsFor(block);
      if (highlights.isEmpty) continue;

      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderParagraph || !renderObject.hasSize) continue;

      final boxes = renderObject.getBoxesForSelection(
        TextSelection(
          baseOffset: highlights.first.start,
          extentOffset: highlights.first.end,
        ),
      );
      for (final box in boxes) {
        final rect = box.toRect().shift(
          renderObject.localToGlobal(Offset.zero),
        );
        bounds = bounds == null ? rect : bounds.expandToInclude(rect);
      }
    }
    return bounds;
  }

  /// The selection as domain anchors plus the exact markdown it covers.
  ///
  /// Returns null when nothing is selected or the blocks are unknown.
  ({SelectionRange range, String markdown})? resolveSelection() {
    final selection = _selection;
    if (selection == null || selection.isCollapsed) return null;

    final startBlock = _document.blockById(selection.startBlockId);
    final endBlock = _document.blockById(selection.endBlockId);
    if (startBlock == null || endBlock == null) return null;

    final startAnchor = _coordinates.anchorForRendered(
      startBlock,
      selection.startRendered,
    );
    final endAnchor = _coordinates.anchorForRendered(
      endBlock,
      selection.endRendered,
      edge: RenderedEdge.trailing,
    );
    final markdown = _document.markdownBetween(startAnchor, endAnchor);
    if (markdown.isEmpty) return null;

    return (
      range: SelectionRange.of(
        startAnchor: startAnchor,
        endAnchor: endAnchor,
        markdown: markdown,
      ),
      markdown: markdown,
    );
  }

  /// Screen rectangles of the first and last selected characters.
  ///
  /// What a drag handle needs: where each end of the selection actually is,
  /// rather than the one rectangle around the whole of it. A side whose block
  /// has scrolled away comes back null, because a handle placed for text that
  /// is not laid out would point at nothing.
  ({Rect? start, Rect? end}) selectionEdgeBoxesGlobal() {
    final selection = _selection;
    if (selection == null || selection.isCollapsed) {
      return (start: null, end: null);
    }
    return (
      start: _edgeBoxGlobal(selection.startBlockId, isStartEdge: true),
      end: _edgeBoxGlobal(selection.endBlockId, isStartEdge: false),
    );
  }

  /// The first or last painted box of the selection within one block.
  Rect? _edgeBoxGlobal(String blockId, {required bool isStartEdge}) {
    final block = _document.blockById(blockId);
    final key = _paragraphs[blockId];
    final renderObject = key?.currentContext?.findRenderObject();
    if (block == null ||
        renderObject is! RenderParagraph ||
        !renderObject.hasSize) {
      return null;
    }
    final highlights = highlightsFor(block);
    if (highlights.isEmpty) return null;
    final boxes = renderObject.getBoxesForSelection(
      TextSelection(
        baseOffset: highlights.first.start,
        extentOffset: highlights.first.end,
      ),
    );
    if (boxes.isEmpty) return null;
    final box = isStartEdge ? boxes.first : boxes.last;
    return box.toRect().shift(renderObject.localToGlobal(Offset.zero));
  }

  /// Exact source anchor under [globalPosition], optionally constrained to a
  /// specific block (used by its gutter).
  ReaderAnchor? anchorAtGlobalPosition(
    Offset globalPosition, {
    String? blockId,
  }) {
    final hit = _hitTest(globalPosition, blockId: blockId);
    if (hit == null) return null;
    final block = _document.blockById(hit.blockId);
    if (block == null) return null;
    return _coordinates.anchorForRendered(block, hit.renderedIndex);
  }

  /// Global caret position for [anchor], or null while its block is unmounted.
  Offset? globalOffsetForAnchor(ReaderAnchor anchor) {
    final block = _document.blockForAnchor(anchor);
    final key = block == null ? null : _paragraphs[block.id];
    final renderObject = key?.currentContext?.findRenderObject();
    if (block == null ||
        !_document.containsAnchor(anchor) ||
        renderObject is! RenderParagraph ||
        !renderObject.hasSize) {
      return null;
    }
    final rendered = _coordinates.renderedIndexForDocument(
      block,
      anchor.utf8Offset,
    );
    final local = renderObject.getOffsetForCaret(
      TextPosition(offset: rendered),
      Rect.zero,
    );
    return renderObject.localToGlobal(local);
  }

  /// The block and character offset under [globalPosition].
  ///
  /// When the pointer is in the space between blocks, the vertically nearest
  /// mounted paragraph wins, so a drag through a paragraph gap keeps
  /// extending instead of stalling.
  _BlockPosition? _hitTest(Offset globalPosition, {String? blockId}) {
    _BlockPosition? best;
    var bestDistance = double.infinity;

    for (final entry in _paragraphs.entries) {
      if (blockId != null && entry.key != blockId) continue;
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderParagraph || !renderObject.hasSize) continue;

      final topLeft = renderObject.localToGlobal(Offset.zero);
      final rect = topLeft & renderObject.size;
      final distance = rect.contains(globalPosition)
          ? 0.0
          : globalPosition.dy < rect.top
          ? rect.top - globalPosition.dy
          : globalPosition.dy - rect.bottom;
      if (distance >= bestDistance) continue;

      final local = renderObject.globalToLocal(globalPosition);
      final clamped = Offset(
        local.dx.clamp(0.0, renderObject.size.width),
        local.dy.clamp(0.0, renderObject.size.height),
      );
      final position = renderObject.getPositionForOffset(clamped);
      bestDistance = distance;
      best = _BlockPosition(entry.key, position.offset);
      if (distance == 0) break;
    }
    return best;
  }

  static bool _isBreak(int unit) =>
      unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D;
}

/// The "the text scrolled" half of [ReaderSelectionController.selectionOnScreen].
///
/// A notifier of its own rather than a flag on the controller: the block list
/// listens to the controller, and it must not be rebuilt by scrolling.
final class _ViewportMoves extends ChangeNotifier {
  void notifyMoved() => notifyListeners();
}

final class _BlockPosition {
  const _BlockPosition(this.blockId, this.renderedIndex);

  final String blockId;
  final int renderedIndex;
}
