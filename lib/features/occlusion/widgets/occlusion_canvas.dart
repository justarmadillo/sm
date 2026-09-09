/// Interactive normalized rectangle editor for image occlusion.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/features/reader/widgets/block_span_builder.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// Draws masks by dragging, selects them by tapping, and deletes with Delete.
class OcclusionCanvas extends StatefulWidget {
  const OcclusionCanvas({
    required this.imageProvider,
    required this.imageWidthPx,
    required this.imageHeightPx,
    required this.regions,
    required this.newRegionId,
    required this.onChanged,
    super.key,
  });

  final ImageProvider imageProvider;
  final int imageWidthPx;
  final int imageHeightPx;
  final List<OcclusionRegion> regions;
  final String Function() newRegionId;
  final ValueChanged<List<OcclusionRegion>> onChanged;

  @override
  State<OcclusionCanvas> createState() => _OcclusionCanvasState();
}

class _OcclusionCanvasState extends State<OcclusionCanvas> {
  final FocusNode _focus = FocusNode();
  String? _selectedId;
  Offset? _dragStart;
  Offset? _dragCurrent;
  OcclusionRegion? _transformStartRegion;
  OcclusionRegion? _transformReplacement;
  Offset _transformDelta = Offset.zero;
  _RegionInteraction? _transformInteraction;
  String? _hoveredRegionId;
  _RegionInteraction? _hoveredInteraction;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final size = fittedReaderImageSize(
        widthPx: widget.imageWidthPx,
        heightPx: widget.imageHeightPx,
        maxWidth: constraints.maxWidth,
      );
      return Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, KeyEvent event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.delete ||
                  event.logicalKey == LogicalKeyboardKey.backspace)) {
            _deleteSelected();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Align(
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image(image: widget.imageProvider, fit: BoxFit.fill),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (DragStartDetails details) {
                    _focus.requestFocus();
                    setState(() {
                      _selectedId = null;
                      _dragStart = details.localPosition;
                      _dragCurrent = details.localPosition;
                    });
                  },
                  onPanUpdate: (DragUpdateDetails details) =>
                      setState(() => _dragCurrent = details.localPosition),
                  onPanEnd: (_) => _finishDrawing(size),
                ),
                for (final region in widget.regions)
                  _regionBox(_displayRegion(region), size),
                if (_draftRect case final Rect draft)
                  Positioned.fromRect(
                    rect: draft,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.mask,
                          border: Border.all(
                            color: AppColors.accentBright,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Rect? get _draftRect {
    final start = _dragStart;
    final current = _dragCurrent;
    return start == null || current == null
        ? null
        : Rect.fromPoints(start, current);
  }

  OcclusionRegion _displayRegion(OcclusionRegion region) {
    final OcclusionRegion? replacement = _transformReplacement;
    return replacement?.id == region.id ? replacement! : region;
  }

  Widget _regionBox(OcclusionRegion region, Size size) {
    final bool isSelected = region.id == _selectedId;
    final Size regionSize = Size(
      region.width * size.width,
      region.height * size.height,
    );
    return Positioned(
      left: region.left * size.width,
      top: region.top * size.height,
      width: region.width * size.width,
      height: region.height * size.height,
      child: MouseRegion(
        cursor: _cursorFor(region.id),
        onHover: (PointerHoverEvent event) =>
            _updateHover(region.id, event.localPosition, regionSize),
        onExit: (_) => _clearHover(region.id),
        child: Listener(
          key: ValueKey<String>('occlusion-region-${region.id}'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (PointerDownEvent event) =>
              _startTransform(region, event.localPosition, regionSize),
          onPointerMove: (PointerMoveEvent event) =>
              _updateTransform(event.delta, size),
          onPointerUp: (_) => _finishTransform(),
          onPointerCancel: (_) => _finishTransform(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.mask,
              border: Border.all(
                color: isSelected ? AppColors.accentBright : Colors.white70,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: isSelected
                ? Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned(
                        top: 0,
                        left: 0,
                        child: IconButton(
                          tooltip: 'Delete mask',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 18,
                            height: 18,
                          ),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          color: Colors.white,
                          onPressed: _deleteSelected,
                          icon: const Icon(Icons.close, size: 14),
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
      ),
    );
  }

  void _finishDrawing(Size size) {
    final rect = _draftRect;
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });
    if (rect == null || rect.width < 8 || rect.height < 8) return;
    final region = OcclusionRegion(
      id: widget.newRegionId(),
      left: (rect.left / size.width).clamp(0, 1),
      top: (rect.top / size.height).clamp(0, 1),
      width: (rect.width / size.width).clamp(0, 1),
      height: (rect.height / size.height).clamp(0, 1),
    );
    _selectedId = region.id;
    widget.onChanged(<OcclusionRegion>[...widget.regions, region]);
  }

  void _startTransform(
    OcclusionRegion region,
    Offset localPosition,
    Size regionSize,
  ) {
    _focus.requestFocus();
    setState(() => _selectedId = region.id);
    _transformStartRegion = region;
    _transformReplacement = null;
    _transformDelta = Offset.zero;
    _transformInteraction = _interactionAt(localPosition, regionSize);
  }

  void _updateTransform(Offset delta, Size canvasSize) {
    final OcclusionRegion? start = _transformStartRegion;
    final _RegionInteraction? interaction = _transformInteraction;
    if (start == null || interaction == null) return;
    _transformDelta += delta;
    final double horizontalDelta = _transformDelta.dx / canvasSize.width;
    final double verticalDelta = _transformDelta.dy / canvasSize.height;
    final double minimumWidth = math.min(0.01, start.width);
    final double minimumHeight = math.min(0.01, start.height);
    double left = start.left;
    double top = start.top;
    double right = start.left + start.width;
    double bottom = start.top + start.height;

    if (interaction == _RegionInteraction.move) {
      left = (start.left + horizontalDelta)
          .clamp(0.0, 1.0 - start.width)
          .toDouble();
      top = (start.top + verticalDelta)
          .clamp(0.0, 1.0 - start.height)
          .toDouble();
      right = left + start.width;
      bottom = top + start.height;
    } else {
      if (interaction.movesLeft) {
        left = (start.left + horizontalDelta)
            .clamp(0.0, right - minimumWidth)
            .toDouble();
      }
      if (interaction.movesRight) {
        right = (right + horizontalDelta)
            .clamp(left + minimumWidth, 1.0)
            .toDouble();
      }
      if (interaction.movesTop) {
        top = (start.top + verticalDelta)
            .clamp(0.0, bottom - minimumHeight)
            .toDouble();
      }
      if (interaction.movesBottom) {
        bottom = (bottom + verticalDelta)
            .clamp(top + minimumHeight, 1.0)
            .toDouble();
      }
    }

    final OcclusionRegion replacement = OcclusionRegion(
      id: start.id,
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
    );
    setState(() => _transformReplacement = replacement);
  }

  void _finishTransform() {
    final OcclusionRegion? replacement = _transformReplacement;
    _transformStartRegion = null;
    _transformReplacement = null;
    _transformDelta = Offset.zero;
    _transformInteraction = null;
    if (replacement == null) return;
    widget.onChanged(<OcclusionRegion>[
      for (final existing in widget.regions)
        existing.id == replacement.id ? replacement : existing,
    ]);
  }

  void _updateHover(String regionId, Offset position, Size regionSize) {
    final _RegionInteraction interaction = _interactionAt(position, regionSize);
    if (_hoveredRegionId == regionId && _hoveredInteraction == interaction) {
      return;
    }
    setState(() {
      _hoveredRegionId = regionId;
      _hoveredInteraction = interaction;
    });
  }

  void _clearHover(String regionId) {
    if (_hoveredRegionId != regionId) return;
    setState(() {
      _hoveredRegionId = null;
      _hoveredInteraction = null;
    });
  }

  MouseCursor _cursorFor(String regionId) {
    if (_hoveredRegionId != regionId) return SystemMouseCursors.click;
    return switch (_hoveredInteraction) {
      _RegionInteraction.left ||
      _RegionInteraction.right => SystemMouseCursors.resizeColumn,
      _RegionInteraction.top ||
      _RegionInteraction.bottom => SystemMouseCursors.resizeRow,
      _RegionInteraction.topLeft || _RegionInteraction.bottomRight =>
        SystemMouseCursors.resizeUpLeftDownRight,
      _RegionInteraction.topRight ||
      _RegionInteraction.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
      _ => SystemMouseCursors.move,
    };
  }

  /// Treats a narrow strip inside every border as its resize grip.
  _RegionInteraction _interactionAt(Offset position, Size regionSize) {
    final double horizontalGrip = math.min(10, regionSize.width / 3);
    final double verticalGrip = math.min(10, regionSize.height / 3);
    final bool isAtLeft = position.dx <= horizontalGrip;
    final bool isAtRight = position.dx >= regionSize.width - horizontalGrip;
    final bool isAtTop = position.dy <= verticalGrip;
    final bool isAtBottom = position.dy >= regionSize.height - verticalGrip;
    if (isAtLeft && isAtTop) return _RegionInteraction.topLeft;
    if (isAtRight && isAtTop) return _RegionInteraction.topRight;
    if (isAtLeft && isAtBottom) return _RegionInteraction.bottomLeft;
    if (isAtRight && isAtBottom) return _RegionInteraction.bottomRight;
    if (isAtLeft) return _RegionInteraction.left;
    if (isAtRight) return _RegionInteraction.right;
    if (isAtTop) return _RegionInteraction.top;
    if (isAtBottom) return _RegionInteraction.bottom;
    return _RegionInteraction.move;
  }

  void _deleteSelected() {
    final selectedId = _selectedId;
    if (selectedId == null) return;
    widget.onChanged(
      widget.regions
          .where((region) => region.id != selectedId)
          .toList(growable: false),
    );
    setState(() => _selectedId = null);
  }
}

enum _RegionInteraction {
  move,
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  bool get movesLeft => this == left || this == topLeft || this == bottomLeft;
  bool get movesRight =>
      this == right || this == topRight || this == bottomRight;
  bool get movesTop => this == top || this == topLeft || this == topRight;
  bool get movesBottom =>
      this == bottom || this == bottomLeft || this == bottomRight;
}
