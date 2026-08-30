/// The two draggable ends of a touch selection.
///
/// A mouse adjusts a selection by dragging it, so on the desktop there is
/// nothing missing. A finger has no such gesture: a long press takes a word,
/// and taking one word more than that meant starting the whole selection
/// again. These are the grips that make the two ends movable.
///
/// Placed in the screen's stack beside the selection toolbar rather than
/// inside the reading surface, and for the same reason: both read where the
/// text has been laid out, and a widget nested inside the reader's own
/// `LayoutBuilder` would be asking a paragraph for its geometry in the middle
/// of laying that paragraph out.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/reader/widgets/reader_selection.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// Diameter of the round knob at each end of a selection.
const double _kKnobDiameter = 14;

/// The square a finger has to land in to grab a knob.
///
/// Much larger than the knob itself: the knob marks where the end of the
/// selection is, and a fingertip covers far more than that.
const double _kKnobTouchTarget = 44;

/// Whether this platform draws draggable ends on a selection.
bool hasSelectionKnobs(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => true,
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => false,
    };

/// Draws a knob at each end of the current selection, if there is one.
///
/// Rebuilt from [ReaderSelectionController.selectionOnScreen] rather than from
/// the controller alone, so the knobs stay on the words they mark while the
/// page scrolls under them.
class SelectionKnobLayer extends StatelessWidget {
  const SelectionKnobLayer({
    required this.controller,
    required this.toSurfaceSpace,
    super.key,
  });

  final ReaderSelectionController controller;

  /// Converts a screen point into the host stack's own coordinates.
  final Offset? Function(Offset global) toSurfaceSpace;

  @override
  Widget build(BuildContext context) {
    if (!hasSelectionKnobs(context)) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller.selectionOnScreen,
      builder: (BuildContext context, Widget? child) {
        final ({Rect? start, Rect? end}) edges = controller
            .selectionEdgeBoxesGlobal();
        return Stack(
          children: <Widget>[
            if (edges.start != null) ..._knob(edges.start!, isStartEdge: true),
            if (edges.end != null) ..._knob(edges.end!, isStartEdge: false),
          ],
        );
      },
    );
  }

  /// One knob, or nothing while the host stack has not been laid out yet.
  ///
  /// The grab point is the vertical middle of the character's box rather than
  /// the bottom of it, because a hit test at the very bottom edge of a line
  /// lands on the line underneath.
  List<Widget> _knob(Rect edge, {required bool isStartEdge}) {
    final Offset grabGlobal = Offset(
      isStartEdge ? edge.left : edge.right,
      edge.center.dy,
    );
    final Offset? foot = toSurfaceSpace(
      isStartEdge ? edge.bottomLeft : edge.bottomRight,
    );
    if (foot == null) return const <Widget>[];
    return <Widget>[
      _SelectionKnob(
        foot: foot,
        grabGlobal: grabGlobal,
        isStartEdge: isStartEdge,
        controller: controller,
      ),
    ];
  }
}

/// One end of a selection, as something a finger can move.
class _SelectionKnob extends StatefulWidget {
  const _SelectionKnob({
    required this.foot,
    required this.grabGlobal,
    required this.isStartEdge,
    required this.controller,
  });

  /// Where the marked character's box ends, in the host stack's coordinates.
  final Offset foot;

  /// The same point in screen coordinates, used to hit-test the text.
  final Offset grabGlobal;

  final bool isStartEdge;
  final ReaderSelectionController controller;

  @override
  State<_SelectionKnob> createState() => _SelectionKnobState();
}

class _SelectionKnobState extends State<_SelectionKnob> {
  /// Distance from the finger to the character it is moving.
  ///
  /// Held for the length of one drag: the knob hangs below and beside the
  /// character it marks, so without this the selection would jump by exactly
  /// that much the moment the finger touched down.
  Offset _fingerToCharacter = Offset.zero;

  @override
  Widget build(BuildContext context) {
    const double radius = _kKnobDiameter / 2;
    // Beside the character rather than on it: a knob centred on the last
    // letter covers the letter it is there to point at.
    final Offset centre = Offset(
      widget.foot.dx + (widget.isStartEdge ? -radius : radius),
      widget.foot.dy + radius,
    );
    return Positioned(
      left: centre.dx - _kKnobTouchTarget / 2,
      top: centre.dy - _kKnobTouchTarget / 2,
      width: _kKnobTouchTarget,
      height: _kKnobTouchTarget,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Swallows the tap that would otherwise reach the reading surface and
        // clear the very selection this knob belongs to.
        onTap: () {},
        onPanStart: (DragStartDetails details) {
          _fingerToCharacter = widget.grabGlobal - details.globalPosition;
          widget.controller.beginEdgeDrag(isStartEdge: widget.isStartEdge);
        },
        onPanUpdate: (DragUpdateDetails details) => widget.controller.extendTo(
          details.globalPosition + _fingerToCharacter,
        ),
        child: Center(
          child: Container(
            width: _kKnobDiameter,
            height: _kKnobDiameter,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
