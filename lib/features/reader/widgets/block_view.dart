/// Renders one block of a document.
///
/// Structural syntax that is not content — the `-` of a list item, the rule of
/// a thematic break, the frame around a code block — is drawn as widgets
/// *outside* the paragraph. Anything inside the paragraph would shift the
/// character offsets the selection layer depends on.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/features/reader/widgets/block_editor.dart';
import 'package:incremental_reader/features/reader/widgets/block_span_builder.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// Width of the margin strip that carries the marker and extract marks.
const double kReaderGutterWidth = 30;

/// One rendered block, with a stable key on its paragraph for hit-testing.
class BlockView extends StatefulWidget {
  const BlockView({
    required this.block,
    required this.typography,
    required this.onParagraphMounted,
    required this.onParagraphUnmounted,
    this.highlights = const <BlockHighlight>[],
    this.isMarkerPainted = false,
    this.isSoftMarkerPainted = false,
    this.extractMarks = 0,
    this.onGutterTap,
    this.onExtractMarksTap,
    this.isEditing = false,
    this.isBusy = false,
    this.onEditCommit,
    this.onEditCancel,
    this.onEditDelete,
    super.key,
  });

  final Block block;
  final ReaderTypography typography;
  final List<BlockHighlight> highlights;

  /// Called when this block's paragraph enters the tree.
  final void Function(String blockId, GlobalKey key) onParagraphMounted;

  /// Called when it leaves, so stale render objects are never hit-tested.
  final void Function(String blockId) onParagraphUnmounted;

  /// Whether the authoritative resume marker sits at this block.
  final bool isMarkerPainted;

  /// Whether the soft "you were here" position sits at this block.
  final bool isSoftMarkerPainted;

  /// How many extracts begin in this block.
  final int extractMarks;

  /// Tapping the empty gutter moves the resume marker to this block.
  final void Function(Block block, Offset globalPosition)? onGutterTap;

  /// Tapping an extract mark opens the extracts taken from this block.
  final void Function(Block block)? onExtractMarksTap;

  /// Whether this block is currently open in the editor.
  ///
  /// Exactly one block may be, and only its rendering changes: every other
  /// block on the page keeps its normal appearance and stays selectable.
  final bool isEditing;

  /// Whether a commit is still in flight.
  final bool isBusy;

  /// Called with the block's new raw markdown.
  final void Function(Block block, String markdown)? onEditCommit;

  final void Function(Block block)? onEditCancel;

  final void Function(Block block)? onEditDelete;

  @override
  State<BlockView> createState() => _BlockViewState();
}

class _BlockViewState extends State<BlockView> {
  final GlobalKey _paragraphKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (!widget.isEditing) {
      widget.onParagraphMounted(widget.block.id, _paragraphKey);
    }
  }

  @override
  void didUpdateWidget(BlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id) {
      widget.onParagraphUnmounted(oldWidget.block.id);
      if (!widget.isEditing) {
        widget.onParagraphMounted(widget.block.id, _paragraphKey);
      }
      return;
    }
    if (oldWidget.isEditing == widget.isEditing) return;
    // Entering the editor removes the paragraph; leaving it puts one back.
    if (widget.isEditing) {
      widget.onParagraphUnmounted(widget.block.id);
    } else {
      widget.onParagraphMounted(widget.block.id, _paragraphKey);
    }
  }

  @override
  void dispose() {
    widget.onParagraphUnmounted(widget.block.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final typography = widget.typography;

    return Padding(
      padding: EdgeInsets.only(bottom: typography.paragraphSpacing),
      child: Stack(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(width: kReaderGutterWidth),
              Expanded(child: _buildBody(block, typography)),
            ],
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: kReaderGutterWidth,
            child: _Gutter(
              isMarkerPainted: widget.isMarkerPainted,
              isSoftMarkerPainted: widget.isSoftMarkerPainted,
              extractMarks: widget.extractMarks,
              onTapDown: widget.onGutterTap == null
                  ? null
                  : (TapDownDetails details) =>
                        widget.onGutterTap!(block, details.globalPosition),
              onExtractsTap: widget.onExtractMarksTap == null
                  ? null
                  : () => widget.onExtractMarksTap!(block),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Block block, ReaderTypography typography) {
    if (widget.isEditing && widget.onEditCommit != null) {
      // The paragraph is gone while editing, so its render object must not
      // stay registered for hit-testing: a selection resolved against a
      // paragraph that is no longer on screen would produce offsets from a
      // layout nobody can see.
      return BlockEditor(
        block: block,
        typography: typography,
        isBusy: widget.isBusy,
        onCommit: (String markdown) => widget.onEditCommit!(block, markdown),
        onCancel: () => widget.onEditCancel?.call(block),
        onDelete: widget.onEditDelete == null
            ? null
            : () => widget.onEditDelete!(block),
      );
    }

    final paragraph = RichText(
      key: _paragraphKey,
      text: buildBlockSpan(block, typography, highlights: widget.highlights),
      textAlign: TextAlign.start,
    );

    switch (block.type) {
      case BlockType.thematicBreak:
        // A rule has no content. The empty paragraph still renders so the
        // block keeps a registered render object and a zero-length range.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: AppColors.border, height: 1),
            ),
            paragraph,
          ],
        );

      case BlockType.codeBlock:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.codeBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: paragraph,
          ),
        );

      case BlockType.mathBlock:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.codeBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          child: paragraph,
        );

      case BlockType.quote:
        return Container(
          padding: const EdgeInsets.only(left: 14),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.border, width: 3)),
          ),
          child: paragraph,
        );

      case BlockType.listItem:
        return Padding(
          padding: EdgeInsets.only(left: 16.0 * block.listDepth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 26,
                child: Text(
                  block.ordered ? '${block.listMarker}' : '•',
                  style: typography.body.copyWith(color: AppColors.muted),
                ),
              ),
              Expanded(child: paragraph),
            ],
          ),
        );

      case BlockType.table:
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DefaultTextStyle.merge(
            style: typography.code,
            child: paragraph,
          ),
        );

      case BlockType.heading:
      case BlockType.paragraph:
        return paragraph;
    }
  }
}

/// The empty margin beside a block.
///
/// Clicking it places the resume marker, which is the one gesture that counts
/// as reading progress.
///
/// Two different signals share this strip, so they are separated by *axis*
/// rather than stacked: the extract bar runs vertically along the block edge,
/// the marker dot sits in its own column beside it. Stacking them meant a
/// block with both showed two competing badges within ten pixels of each
/// other, which is what made a well-worked page look like noise.
class _Gutter extends StatelessWidget {
  const _Gutter({
    required this.isMarkerPainted,
    required this.isSoftMarkerPainted,
    required this.extractMarks,
    this.onTapDown,
    this.onExtractsTap,
  });

  final bool isMarkerPainted;
  final bool isSoftMarkerPainted;
  final int extractMarks;
  final GestureTapDownCallback? onTapDown;
  final VoidCallback? onExtractsTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: onTapDown,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          if (extractMarks > 0)
            Positioned(
              left: kReaderGutterWidth - 9,
              top: 1,
              bottom: 1,
              child: _ExtractBar(count: extractMarks, onTap: onExtractsTap),
            ),
          Positioned(
            top: 5,
            left: 2,
            child: isMarkerPainted
                ? const _MarkerDot(color: AppColors.accent, filled: true)
                : isSoftMarkerPainted
                ? const _MarkerDot(color: AppColors.softMarker, filled: false)
                : const SizedBox(width: 10, height: 10),
          ),
        ],
      ),
    );
  }
}

/// Persistent evidence that a passage has already been processed.
///
/// A rule beside the block rather than a badge: it says *how much* of the page
/// is spent, scales to any number of extracts without stacking, and stays
/// quiet enough to live on every worked paragraph of a 50k-word chapter.
class _ExtractBar extends StatelessWidget {
  const _ExtractBar({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: count == 1 ? '1 extract here' : '$count extracts here',
    waitDuration: const Duration(milliseconds: 400),
    child: MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          button: true,
          label: count == 1 ? '1 extract' : '$count extracts',
          // The touch target is the whole 9px column; only the rule is
          // painted, so the strip stays visually thin.
          child: SizedBox(
            width: 9,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: AppColors.extractInk.withValues(
                    alpha: count > 1 ? 0.75 : 0.5,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Semantics(
    label: filled ? 'Resume marker' : 'Last position',
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: 2),
      ),
    ),
  );
}
