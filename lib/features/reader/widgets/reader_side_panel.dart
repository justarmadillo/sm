/// The Reader's side panel: outline and extracts.
///
/// A 50k-word chapter is not navigable by scrolling alone, and extraction
/// leaves no trace in the text itself — the gutter marks only show what is on
/// screen. The panel answers both: where am I in the structure, and what have
/// I already taken out of this source.
///
/// The outline is also editable, and that is not a second feature bolted on:
/// the entries *are* the document's heading lines, so renaming one, indenting
/// it, or moving it is an ordinary edit to the source markdown. Nothing here
/// is stored beside the text, which is why it survives without anything
/// having to be saved.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/outline.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// What the outline may do to the document it lists.
///
/// Carried as one object rather than six loose callbacks: they always travel
/// together, and every one of them is the same kind of thing — an edit to a
/// heading line, applied to the source text.
@immutable
final class OutlineEditing {
  const OutlineEditing({
    required this.onRename,
    required this.onAddAfter,
    required this.onRemove,
    required this.onChangeLevel,
    required this.onMoveSection,
    this.isBusy = false,
  });

  /// Rewrites the heading's words, keeping its level.
  final void Function(OutlineEntry entry, String text) onRename;

  /// Adds a heading of the same level after the whole of that entry's
  /// section.
  final void Function(OutlineEntry entry, String text) onAddAfter;

  /// Removes the heading line. The paragraphs under it stay where they are:
  /// deleting a title is not the same request as deleting a chapter.
  final void Function(OutlineEntry entry) onRemove;

  /// Promotes or demotes the heading, which is what changes the hierarchy.
  final void Function(OutlineEntry entry, int level) onChangeLevel;

  /// Moves the heading and everything under it past its neighbouring section.
  final void Function(OutlineEntry entry, {required bool shouldMoveUp})
  onMoveSection;

  /// Whether an edit is already in flight, in which case nothing may start
  /// a second one.
  final bool isBusy;
}

/// Which list the panel is showing.
enum ReaderPanelTab {
  /// Headings, as a navigable outline.
  outline,

  /// Extracts taken from this source.
  extracts,
}

/// How wide the panel is when it sits beside the reading column.
const double kReaderSidePanelWidth = 280;

/// The panel of outline and extracts, docked beside the reading column on a
/// wide window and slid over it in a drawer on a narrow one.
class ReaderSidePanel extends StatelessWidget {
  const ReaderSidePanel({
    required this.document,
    required this.extracts,
    required this.tab,
    required this.onTabChanged,
    required this.onGoToBlock,
    required this.onGoToExtract,
    required this.onClose,
    required this.outlineEditing,
    this.currentBlockId,
    this.focusedExtractId,
    this.width,
    super.key,
  });

  final Document document;

  /// What the outline's own rows may change about the document.
  final OutlineEditing outlineEditing;
  final List<Extract> extracts;
  final ReaderPanelTab tab;
  final ValueChanged<ReaderPanelTab> onTabChanged;

  /// Scrolls the reader to a block.
  final void Function(String blockId) onGoToBlock;

  /// Scrolls to an extract *and* marks it in the text. Choosing an extract
  /// only to arrive at an unmarked paragraph is the failure this replaces.
  final void Function(Extract extract) onGoToExtract;

  final VoidCallback onClose;

  /// Topmost visible block, highlighted in the outline.
  final String? currentBlockId;

  /// The extract currently painted in the text, shown selected here too.
  final String? focusedExtractId;

  /// How wide to draw. Null inside a drawer, which sets its own width.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final List<OutlineEntry> outline = outlineOf(document);

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelHeader(
            tab: tab,
            outlineCount: outline.length,
            extractCount: extracts.length,
            onTabChanged: onTabChanged,
            onClose: onClose,
          ),
          Expanded(
            child: switch (tab) {
              ReaderPanelTab.outline => _OutlineList(
                // Keyed on the revision so the row being renamed, and any
                // half-typed new heading, are dropped the moment an edit
                // lands: the block ids they name belong to the parse before
                // it and no longer exist.
                key: ValueKey<int>(document.contentRevision),
                outline: outline,
                currentBlockId: currentBlockId,
                onGoToBlock: onGoToBlock,
                editing: outlineEditing,
              ),
              ReaderPanelTab.extracts => _ExtractList(
                extracts: extracts,
                focusedExtractId: focusedExtractId,
                onGoToExtract: onGoToExtract,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.tab,
    required this.outlineCount,
    required this.extractCount,
    required this.onTabChanged,
    required this.onClose,
  });

  final ReaderPanelTab tab;
  final int outlineCount;
  final int extractCount;
  final ValueChanged<ReaderPanelTab> onTabChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: <Widget>[
        _TabChip(
          label: 'Outline',
          count: outlineCount,
          selected: tab == ReaderPanelTab.outline,
          onTap: () => onTabChanged(ReaderPanelTab.outline),
        ),
        const SizedBox(width: 6),
        _TabChip(
          label: 'Extracts',
          count: extractCount,
          selected: tab == ReaderPanelTab.extracts,
          onTap: () => onTabChanged(ReaderPanelTab.extracts),
        ),
        const Spacer(),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close, size: 16),
          tooltip: 'Hide panel',
          visualDensity: VisualDensity.compact,
          color: AppColors.muted,
        ),
      ],
    ),
  );
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label  $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.accent : AppColors.muted,
        ),
      ),
    ),
  );
}

/// Horizontal step per outline level.
const double _kOutlineIndentStep = 11;

/// The menu button's slot, tighter than Material's 48-pixel tap target.
///
/// At the default size one button would be taller than the two lines of
/// heading beside it, and the panel is 280 pixels wide: the outline would
/// scroll twice as far for the same document.
const double _kOutlineMenuSize = 30;

/// What one outline row's menu can do.
enum _OutlineAction {
  rename,
  addAfter,
  indent,
  outdent,
  moveUp,
  moveDown,
  remove,
}

/// The headings, as a list that can be rewritten in place.
///
/// Stateful only for the two things the user is in the middle of typing: which
/// row is being renamed, and which row a new heading is being added under. The
/// structure itself is never held here — it is re-derived from the document
/// after every edit, so what is on screen is always what is in the text.
class _OutlineList extends StatefulWidget {
  const _OutlineList({
    required this.outline,
    required this.currentBlockId,
    required this.onGoToBlock,
    required this.editing,
    super.key,
  });

  final List<OutlineEntry> outline;
  final String? currentBlockId;
  final void Function(String blockId) onGoToBlock;
  final OutlineEditing editing;

  @override
  State<_OutlineList> createState() => _OutlineListState();
}

class _OutlineListState extends State<_OutlineList> {
  String? _renamingBlockId;
  String? _addingAfterBlockId;

  @override
  Widget build(BuildContext context) {
    if (widget.outline.isEmpty) {
      return const _EmptyPanel(
        'This source has no headings yet. Select a line in the text and '
        'choose Edit to make it one — "# Title" — and it appears here, '
        'ready to be renamed, indented and moved.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: widget.outline.length,
      itemBuilder: (BuildContext context, int index) {
        final OutlineEntry entry = widget.outline[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (entry.blockId == _renamingBlockId)
              _OutlineField(
                level: entry.level,
                initialText: entry.text,
                onCancel: () => setState(() => _renamingBlockId = null),
                onSubmit: (String text) {
                  setState(() => _renamingBlockId = null);
                  widget.editing.onRename(entry, text);
                },
              )
            else
              _row(entry),
            if (entry.blockId == _addingAfterBlockId)
              _OutlineField(
                level: entry.level,
                initialText: '',
                onCancel: () => setState(() => _addingAfterBlockId = null),
                onSubmit: (String text) {
                  setState(() => _addingAfterBlockId = null);
                  widget.editing.onAddAfter(entry, text);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _row(OutlineEntry entry) {
    final bool isCurrent = entry.blockId == widget.currentBlockId;
    return Container(
      color: isCurrent
          ? AppColors.accent.withValues(alpha: 0.08)
          : Colors.transparent,
      padding: EdgeInsets.only(
        left: 10 + (entry.level - 1) * _kOutlineIndentStep,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              onTap: () => widget.onGoToBlock(entry.blockId),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  entry.text.isEmpty ? '(untitled heading)' : entry.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: entry.level <= 2 ? 12.5 : 12,
                    height: 1.35,
                    fontWeight: entry.level <= 2
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isCurrent ? AppColors.accent : AppColors.text,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: _kOutlineMenuSize,
            height: _kOutlineMenuSize,
            child: _menu(entry),
          ),
        ],
      ),
    );
  }

  /// Everything one entry can become, in one menu.
  ///
  /// A menu rather than a row of icons: seven controls beside a title in a
  /// 280-pixel panel would leave the title no width at all, and the title is
  /// the only part that says which heading this is.
  Widget _menu(OutlineEntry entry) {
    final OutlineEntry? above = previousSiblingOf(widget.outline, entry);
    final OutlineEntry? below = nextSiblingOf(widget.outline, entry);
    return PopupMenuButton<_OutlineAction>(
      enabled: !widget.editing.isBusy,
      tooltip: 'Heading actions',
      icon: const Icon(Icons.more_vert, size: 16, color: AppColors.muted),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 180),
      onSelected: (_OutlineAction action) => _run(action, entry),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_OutlineAction>>[
        const PopupMenuItem<_OutlineAction>(
          value: _OutlineAction.rename,
          child: Text('Rename'),
        ),
        const PopupMenuItem<_OutlineAction>(
          value: _OutlineAction.addAfter,
          child: Text('Add heading below'),
        ),
        PopupMenuItem<_OutlineAction>(
          value: _OutlineAction.indent,
          enabled: entry.level < 6,
          child: const Text('Indent'),
        ),
        PopupMenuItem<_OutlineAction>(
          value: _OutlineAction.outdent,
          enabled: entry.level > 1,
          child: const Text('Outdent'),
        ),
        PopupMenuItem<_OutlineAction>(
          value: _OutlineAction.moveUp,
          enabled: above != null,
          child: const Text('Move section up'),
        ),
        PopupMenuItem<_OutlineAction>(
          value: _OutlineAction.moveDown,
          enabled: below != null,
          child: const Text('Move section down'),
        ),
        const PopupMenuItem<_OutlineAction>(
          value: _OutlineAction.remove,
          child: Text('Remove heading'),
        ),
      ],
    );
  }

  void _run(_OutlineAction action, OutlineEntry entry) {
    switch (action) {
      case _OutlineAction.rename:
        setState(() {
          _addingAfterBlockId = null;
          _renamingBlockId = entry.blockId;
        });
      case _OutlineAction.addAfter:
        setState(() {
          _renamingBlockId = null;
          _addingAfterBlockId = entry.blockId;
        });
      case _OutlineAction.indent:
        widget.editing.onChangeLevel(entry, entry.level + 1);
      case _OutlineAction.outdent:
        widget.editing.onChangeLevel(entry, entry.level - 1);
      case _OutlineAction.moveUp:
        widget.editing.onMoveSection(entry, shouldMoveUp: true);
      case _OutlineAction.moveDown:
        widget.editing.onMoveSection(entry, shouldMoveUp: false);
      case _OutlineAction.remove:
        widget.editing.onRemove(entry);
    }
  }
}

/// One line being typed: a rename, or a heading being added.
class _OutlineField extends StatefulWidget {
  const _OutlineField({
    required this.level,
    required this.initialText,
    required this.onSubmit,
    required this.onCancel,
  });

  final int level;
  final String initialText;
  final void Function(String text) onSubmit;
  final VoidCallback onCancel;

  @override
  State<_OutlineField> createState() => _OutlineFieldState();
}

class _OutlineFieldState extends State<_OutlineField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      10 + (widget.level - 1) * _kOutlineIndentStep,
      4,
      6,
      4,
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(fontSize: 12.5, color: AppColors.text),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            // Enter commits, because this is one line of text and there is
            // nothing else the key could usefully mean here.
            onSubmitted: _commit,
          ),
        ),
        IconButton(
          tooltip: 'Cancel',
          onPressed: widget.onCancel,
          icon: const Icon(Icons.close, size: 15),
          visualDensity: VisualDensity.compact,
          color: AppColors.muted,
        ),
        IconButton(
          tooltip: 'Save',
          onPressed: () => _commit(_controller.text),
          icon: const Icon(Icons.check, size: 16),
          visualDensity: VisualDensity.compact,
          color: AppColors.accent,
        ),
      ],
    ),
  );

  /// Blank means the user changed their mind, not that they want an empty
  /// heading: a `##` with no words is invisible in the text and unfindable in
  /// the outline.
  void _commit(String text) {
    if (text.trim().isEmpty) {
      widget.onCancel();
      return;
    }
    widget.onSubmit(text);
  }
}

class _ExtractList extends StatelessWidget {
  const _ExtractList({
    required this.extracts,
    required this.focusedExtractId,
    required this.onGoToExtract,
  });

  final List<Extract> extracts;
  final String? focusedExtractId;
  final void Function(Extract extract) onGoToExtract;

  @override
  Widget build(BuildContext context) {
    if (extracts.isEmpty) {
      return const _EmptyPanel(
        'Nothing extracted yet. Select a passage and press Extract to turn it '
        'into its own scheduled element.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: extracts.length,
      itemBuilder: (BuildContext context, int index) {
        final extract = extracts[index];
        return _extractTile(extract, isFocused: extract.id == focusedExtractId);
      },
    );
  }

  /// One extract, tinted more strongly while it is the one painted in the
  /// document, so the list and the text agree on what is selected.
  Widget _extractTile(Extract extract, {required bool isFocused}) {
    return InkWell(
      onTap: () => onGoToExtract(extract),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
        decoration: BoxDecoration(
          color: AppColors.extractInk.withValues(
            alpha: isFocused ? 0.12 : 0.04,
          ),
          border: Border.all(
            color: AppColors.extractInk.withValues(
              alpha: isFocused ? 0.55 : 0.18,
            ),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              extract.markdown,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.text,
                fontWeight: isFocused ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 5),
            _tileFooter(extract, isFocused: isFocused),
          ],
        ),
      ),
    );
  }

  /// Says whether the extract still matches the source words, and whether
  /// tapping will paint it or clear it.
  Widget _tileFooter(Extract extract, {required bool isFocused}) {
    return Row(
      children: <Widget>[
        Text(
          extract.isVerbatim ? 'as selected' : 'edited',
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
        const Spacer(),
        Text(
          isFocused ? 'shown in text' : 'show in text',
          style: TextStyle(
            fontSize: 10,
            color: isFocused
                ? AppColors.extractInk
                : AppColors.muted.withValues(alpha: 0.8),
            fontWeight: isFocused ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      message,
      style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
    ),
  );
}
