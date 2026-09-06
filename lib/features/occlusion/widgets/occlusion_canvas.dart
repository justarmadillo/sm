/// Interactive normalized rectangle editor for image occlusion.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/features/reader/widgets/block_span_builder.dart';

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
                for (final region in widget.regions) _regionBox(region, size),
                if (_draftRect case final Rect draft)
                  Positioned.fromRect(
                    rect: draft,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF242A32),
                          border: Border.all(color: Colors.teal, width: 2),
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

  Widget _regionBox(OcclusionRegion region, Size size) {
    final isSelected = region.id == _selectedId;
    return Positioned(
      left: region.left * size.width,
      top: region.top * size.height,
      width: region.width * size.width,
      height: region.height * size.height,
      child: GestureDetector(
        onTap: () => setState(() => _selectedId = region.id),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF242A32),
            border: Border.all(
              color: isSelected ? Colors.tealAccent : Colors.white70,
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
                          width: 32,
                          height: 32,
                        ),
                        color: Colors.white,
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerMove: (PointerMoveEvent event) =>
                            _resize(region, event.delta, size),
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.open_in_full,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : null,
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

  void _resize(OcclusionRegion region, Offset delta, Size size) {
    final maximumWidth = 1 - region.left;
    final maximumHeight = 1 - region.top;
    final replacement = OcclusionRegion(
      id: region.id,
      left: region.left,
      top: region.top,
      width: math.max(
        0.01,
        math.min(maximumWidth, region.width + delta.dx / size.width),
      ),
      height: math.max(
        0.01,
        math.min(maximumHeight, region.height + delta.dy / size.height),
      ),
    );
    widget.onChanged(<OcclusionRegion>[
      for (final existing in widget.regions)
        existing.id == region.id ? replacement : existing,
    ]);
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
