/// Editing one block in place.
///
/// The editor replaces a single block with a text field holding that block's
/// raw markdown, and nothing else on the page changes. That is not only a
/// visual choice: the block's byte range is known before the user types a
/// character, so committing produces an exact splice with nothing to infer.
/// A whole-document editor would have to recover the edit by diffing, and a
/// diff over repeated text picks one of several equally plausible answers —
/// silently relocating every position that followed the one it guessed wrong.
///
/// See `plans/reader/EDITABLE_READER.md` §11.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:incremental_reader/src/app/theme.dart';
import 'package:incremental_reader/src/domain/content/block.dart';

/// A text field holding one block's raw markdown.
class BlockEditor extends StatefulWidget {
  const BlockEditor({
    required this.block,
    required this.typography,
    required this.onCommit,
    required this.onCancel,
    this.onDelete,
    this.isBusy = false,
    super.key,
  });

  final Block block;
  final ReaderTypography typography;

  /// Called with the new raw markdown. Blank removes the block.
  final void Function(String markdown) onCommit;

  final VoidCallback onCancel;

  /// Removes the block outright, separator included.
  final VoidCallback? onDelete;

  /// Whether a previous commit is still in flight.
  final bool isBusy;

  @override
  State<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<BlockEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.block.raw,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Opening straight into the field is the whole point of the gesture; a
    // second click to start typing would make editing feel like a mode.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isDirty => _controller.text != widget.block.raw;

  void _commit() {
    if (widget.isBusy) return;
    widget.onCommit(_controller.text);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final pressed = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    // Enter alone inserts a newline: markdown blocks are multi-line, and a
    // list or a quote cannot be edited otherwise.
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        (pressed.isControlPressed || pressed.isMetaPressed)) {
      _commit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final typography = widget.typography;

    // Keys that mean "move around the article" are stopped at the editor's
    // edge rather than left to travel up the tree. A key event rises from
    // whatever holds focus, and the reading surface, the scrollable, and the
    // screen's own bindings all sit above this field — any one of them acting
    // on a space, an arrow, or a page key would move the article out from
    // under a caret that is trying to type. Swallowing them here does not
    // depend on knowing which of those would have answered.
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
          LogicalKeyboardKey.space,
          LogicalKeyboardKey.pageUp,
          LogicalKeyboardKey.pageDown,
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.home,
          LogicalKeyboardKey.end,
        ])
          SingleActivator(key): const DoNothingAndStopPropagationIntent(),
      },
      child: _buildBody(typography),
    );
  }

  Widget _buildBody(ReaderTypography typography) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.codeBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Focus(
            onKeyEvent: _handleKey,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              maxLines: null,
              autocorrect: false,
              enableSuggestions: false,
              enabled: !widget.isBusy,
              style: typography.code.copyWith(height: 1.45),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 6),
          // Wrapped rather than a Row: the reading column is user-adjustable
          // and can be narrower than these controls laid out in a line, and an
          // overflowing action row would put Save off the edge of the screen.
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Editing raw markdown  ·  Ctrl+Enter saves, Esc cancels',
                    style: typography.code.copyWith(
                      fontSize: typography.fontSize * 0.72,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                if (widget.onDelete != null)
                  TextButton(
                    onPressed: widget.isBusy ? null : widget.onDelete,
                    child: const Text('Delete block'),
                  ),
                TextButton(
                  onPressed: widget.isBusy ? null : widget.onCancel,
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: widget.isBusy || !_isDirty ? null : _commit,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
