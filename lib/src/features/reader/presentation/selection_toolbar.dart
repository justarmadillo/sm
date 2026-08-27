/// The floating toolbar that follows a selection.
///
/// Extraction and marker placement are the two things a reader does with a
/// passage, and both were previously only reachable from the bottom bar or a
/// keyboard shortcut — far from where the user is actually looking. This puts
/// them at the selection, which is also the only place that knows the exact
/// position the user pointed at.
library;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Height reserved for the toolbar when deciding whether it fits above.
const double _kToolbarHeight = 40;

/// A compact toolbar anchored to [anchorRect] in global coordinates.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    required this.anchorRect,
    required this.viewportSize,
    required this.onExtract,
    required this.onSetMarker,
    required this.onCopy,
    required this.onEditBlock,
    required this.canSetMarker,
    required this.canExtract,
    this.extractHint,
    super.key,
  });

  /// Rectangle of the selection, in the coordinates of the stack that hosts
  /// this toolbar rather than of the screen.
  final Rect anchorRect;

  /// Size of that stack, used to keep the toolbar on screen.
  final Size viewportSize;

  final VoidCallback onExtract;
  final VoidCallback onSetMarker;
  final VoidCallback onCopy;

  /// Opens the block the selection started in for editing.
  ///
  /// Null while editing would be meaningless — browsing a source it does not
  /// own, for instance — so the action disappears rather than failing.
  final VoidCallback? onEditBlock;

  /// Whether placing a marker is meaningful in the current mode.
  final bool canSetMarker;

  /// Whether this selection can become an extract.
  final bool canExtract;

  /// Why extraction is unavailable, shown as a tooltip when it is disabled.
  final String? extractHint;

  @override
  Widget build(BuildContext context) {
    // Prefer sitting above the selection so the toolbar never covers the text
    // the user just chose; flip below only when there is no room.
    final fitsAbove = anchorRect.top - _kToolbarHeight - 10 > 0;
    final top = fitsAbove
        ? anchorRect.top - _kToolbarHeight - 8
        : anchorRect.bottom + 8;

    const width = 380.0;
    final maxLeft = (viewportSize.width - width - 12).clamp(
      12.0,
      viewportSize.width,
    );
    final left = (anchorRect.center.dx - width / 2).clamp(12.0, maxLeft);

    return Positioned(
      left: left,
      top: top.clamp(
        8.0,
        (viewportSize.height - _kToolbarHeight - 8).clamp(8.0, double.infinity),
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: _kToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ToolbarButton(
                icon: Icons.content_cut,
                label: 'Extract',
                shortcut: 'Ctrl+E',
                onPressed: canExtract ? onExtract : null,
                disabledHint: extractHint,
                emphasized: true,
              ),
              const _ToolbarDivider(),
              _ToolbarButton(
                icon: Icons.place_outlined,
                label: 'Marker',
                shortcut: 'Ctrl+M',
                onPressed: canSetMarker ? onSetMarker : null,
                disabledHint: 'Browsing cannot move the marker',
              ),
              const _ToolbarDivider(),
              _ToolbarButton(
                icon: Icons.copy_all_outlined,
                label: 'Copy',
                onPressed: onCopy,
              ),
              const _ToolbarDivider(),
              _ToolbarButton(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onPressed: onEditBlock,
                disabledHint: 'Browsing cannot edit this source',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.shortcut,
    this.onPressed,
    this.disabledHint,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String? shortcut;
  final VoidCallback? onPressed;
  final String? disabledHint;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? AppColors.muted.withValues(alpha: 0.5)
        : emphasized
        ? AppColors.accent
        : AppColors.text;

    return Tooltip(
      message: enabled
          ? (shortcut == null ? label : '$label  ·  $shortcut')
          : (disabledHint ?? label),
      waitDuration: const Duration(milliseconds: 400),
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, size: 15, color: color),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 18, color: AppColors.border);
}
