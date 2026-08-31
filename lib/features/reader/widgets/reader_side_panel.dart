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
///
/// An entry does not have to name something the article already says. It is
/// the reader's own map of the ideas in the source: a heading can label a
/// passage that exists, or hold an idea the text never states outright, and
/// the hierarchy between entries is the reader's, not the author's. That is
/// why every entry can be renamed, indented, and moved — the outline is
/// written *against* the article rather than extracted from it.
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
                outline: outline,
                contentRevision: document.contentRevision,
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
        Expanded(
          child: _TabChip(
            label: 'Outline',
            count: outlineCount,
            selected: tab == ReaderPanelTab.outline,
            onTap: () => onTabChanged(ReaderPanelTab.outline),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _TabChip(
            label: 'Extracts',
            count: extractCount,
            selected: tab == ReaderPanelTab.extracts,
            onTap: () => onTabChanged(ReaderPanelTab.extracts),
          ),
        ),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
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

/// One toolbar button's slot, tighter than Material's 48-pixel tap target:
/// seven of those are wider than the 280-pixel panel they have to fit in.
const double _kOutlineToolbarButtonSize = 32;

/// What the outline toolbar can do to the selected entry.
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
/// Stateful for three things: which row the toolbar is aimed at, which row is
/// being renamed, and which row a new heading is being added under. The
/// structure itself is never held here — it is re-derived from the document
/// after every edit, so what is on screen is always what is in the text.
class _OutlineList extends StatefulWidget {
  const _OutlineList({
    required this.outline,
    required this.contentRevision,
    required this.currentBlockId,
    required this.onGoToBlock,
    required this.editing,
  });

  final List<OutlineEntry> outline;

  /// Which parse of the document [outline] was read from. A new number means
  /// every block id in the list is new as well, because a block is addressed
  /// by its position in the parse.
  final int contentRevision;

  final String? currentBlockId;
  final void Function(String blockId) onGoToBlock;
  final OutlineEditing editing;

  @override
  State<_OutlineList> createState() => _OutlineListState();
}

class _OutlineListState extends State<_OutlineList> {
  /// Where the selected heading sat, top to bottom. Null while the panel is
  /// using its initial current-or-first heading selection.
  ///
  /// The selection is deliberately not a block id. A block is addressed by
  /// its position in the parse, so moving a section renumbers every id after
  /// it — and the toolbar exists precisely so that moves can be made one
  /// after another without reselecting between them.
  int? _selectedPosition;

  /// What the selected heading said, which is how it is found again after an
  /// edit has moved it.
  String _selectedText = '';

  String? _renamingBlockId;
  String? _addingAfterBlockId;

  /// The entry the toolbar acts on.
  ///
  /// The words come first and the position second: after a move the heading
  /// still says the same thing somewhere else, and after a removal there are
  /// no matching words left, which is exactly when landing on whatever now
  /// occupies that position is the useful answer.
  OutlineEntry? get _selectedEntry {
    final int? position = _selectedPosition;
    if (widget.outline.isEmpty) return null;
    if (position == null) {
      final String? currentBlockId = widget.currentBlockId;
      return currentBlockId == null
          ? widget.outline.first
          : outlineEntryOf(widget.outline, currentBlockId) ??
                widget.outline.first;
    }
    OutlineEntry? nearest;
    for (final OutlineEntry entry in widget.outline) {
      if (entry.text != _selectedText) continue;
      if (nearest == null ||
          (entry.position - position).abs() <
              (nearest.position - position).abs()) {
        nearest = entry;
      }
    }
    return nearest ??
        widget.outline[position.clamp(0, widget.outline.length - 1)];
  }

  /// An edit has landed and the document has been parsed again.
  ///
  /// Both half-typed fields name block ids from the parse before it, so they
  /// are dropped. The selection is kept, but re-pinned to where its heading
  /// actually ended up, so the next button press acts on the same heading.
  @override
  void didUpdateWidget(_OutlineList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentRevision == widget.contentRevision) return;
    final OutlineEntry? kept = _selectedEntry;
    _renamingBlockId = null;
    _addingAfterBlockId = null;
    _selectedPosition = kept?.position;
    _selectedText = kept?.text ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.outline.isEmpty) {
      return const _EmptyPanel(
        'No headings yet. The outline is your own map of the ideas in this '
        'source rather than a summary of it: an entry can name a passage '
        'that is already here, or hold a thought the text never states. '
        'Select a line and choose Edit to make it a heading — "# Title" — '
        'and it appears here, ready to be renamed, indented and moved.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _OutlineToolbar(
          selectedEntry: _selectedEntry,
          outline: widget.outline,
          isBusy: widget.editing.isBusy,
          onAction: _run,
        ),
        Expanded(child: _list()),
      ],
    );
  }

  Widget _list() => ListView.builder(
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
                setState(() {
                  _renamingBlockId = null;
                  // The selection follows the heading by its words, so the
                  // new words have to be recorded before the edit lands.
                  if (entry.position == _selectedPosition) {
                    _selectedText = text;
                  }
                });
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

  /// One heading. Tapping it scrolls the reader to it and aims the toolbar at
  /// it: the row the user is looking at is the row they mean.
  Widget _row(OutlineEntry entry) {
    final bool isCurrent = entry.blockId == widget.currentBlockId;
    final bool isSelected = entry.blockId == _selectedEntry?.blockId;
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.accent.withValues(alpha: 0.16)
            : isCurrent
            ? AppColors.accent.withValues(alpha: 0.08)
            : Colors.transparent,
        // The bar down the left says which row the toolbar will act on, which
        // the tint alone cannot: the reading position is tinted too.
        border: Border(
          left: BorderSide(
            width: 2,
            color: isSelected ? AppColors.accent : Colors.transparent,
          ),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _OutlineHierarchyGuidePainter(level: entry.level),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 8 + (entry.level - 1) * _kOutlineIndentStep,
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedPosition = entry.position;
                  _selectedText = entry.text;
                });
                widget.onGoToBlock(entry.blockId);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
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
                    color: isCurrent || isSelected
                        ? AppColors.accent
                        : AppColors.text,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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

/// VS Code-like vertical guides make a deeply nested branch readable without
/// spending horizontal space on tree controls.
final class _OutlineHierarchyGuidePainter extends CustomPainter {
  const _OutlineHierarchyGuidePainter({required this.level});

  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint guidePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    for (var ancestorLevel = 1; ancestorLevel < level; ancestorLevel++) {
      final double horizontalPosition =
          3 + (ancestorLevel - 1) * _kOutlineIndentStep;
      canvas.drawLine(
        Offset(horizontalPosition, 0),
        Offset(horizontalPosition, size.height),
        guidePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_OutlineHierarchyGuidePainter oldDelegate) =>
      oldDelegate.level != level;
}

/// The outline's commands, on a bar above the headings.
///
/// A bar rather than a menu on every row: reorganising an outline is a run of
/// small moves — indent, indent, move up — and a menu that has to be reopened
/// between each one turns a minute of thinking into a minute of tapping. What
/// it costs is a selection, which is what the highlighted row is.
class _OutlineToolbar extends StatelessWidget {
  const _OutlineToolbar({
    required this.selectedEntry,
    required this.outline,
    required this.isBusy,
    required this.onAction,
  });

  /// The entry every button acts on, or null when the outline is empty.
  final OutlineEntry? selectedEntry;

  final List<OutlineEntry> outline;

  /// Whether an edit is already in flight, in which case nothing may start a
  /// second one.
  final bool isBusy;

  final void Function(_OutlineAction action, OutlineEntry entry) onAction;

  @override
  Widget build(BuildContext context) {
    final OutlineEntry? entry = selectedEntry;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          _button(
            entry,
            _OutlineAction.outdent,
            Icons.format_indent_decrease,
            'Outdent',
            isAllowed: entry != null && entry.level > 1,
          ),
          _button(
            entry,
            _OutlineAction.indent,
            Icons.format_indent_increase,
            'Indent',
            isAllowed: entry != null && entry.level < 6,
          ),
          _button(
            entry,
            _OutlineAction.moveUp,
            Icons.arrow_upward,
            'Move section up',
            isAllowed:
                entry != null && previousSiblingOf(outline, entry) != null,
          ),
          _button(
            entry,
            _OutlineAction.moveDown,
            Icons.arrow_downward,
            'Move section down',
            isAllowed: entry != null && nextSiblingOf(outline, entry) != null,
          ),
          const Spacer(),
          _button(
            entry,
            _OutlineAction.rename,
            Icons.edit_outlined,
            'Rename',
            isAllowed: entry != null,
          ),
          _button(
            entry,
            _OutlineAction.addAfter,
            Icons.add,
            'Add heading below',
            isAllowed: entry != null,
          ),
          _button(
            entry,
            _OutlineAction.remove,
            Icons.remove_circle_outline,
            'Remove heading',
            isAllowed: entry != null,
          ),
        ],
      ),
    );
  }

  /// One command. Every button keeps its slot when it cannot run, so the bar
  /// does not reshuffle itself as the selection moves down the outline.
  Widget _button(
    OutlineEntry? entry,
    _OutlineAction action,
    IconData icon,
    String tooltip, {
    required bool isAllowed,
  }) {
    final bool isEnabled = isAllowed && !isBusy && entry != null;
    return SizedBox(
      width: _kOutlineToolbarButtonSize,
      height: _kOutlineToolbarButtonSize,
      child: IconButton(
        tooltip: entry == null ? '$tooltip — tap a heading first' : tooltip,
        onPressed: isEnabled ? () => onAction(action, entry) : null,
        icon: Icon(icon, size: 16),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: _kOutlineToolbarButtonSize,
          height: _kOutlineToolbarButtonSize,
        ),
        color: AppColors.accent,
        disabledColor: AppColors.muted.withValues(alpha: 0.3),
      ),
    );
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
