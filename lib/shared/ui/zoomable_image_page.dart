/// Shows supplied image content on a fullscreen, zoomable black surface.
library;

import 'package:flutter/material.dart';

/// Opens image content separately so zoom never changes a caller's layout.
Future<void> openZoomableImage(
  BuildContext context, {
  required WidgetBuilder buildImage,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (BuildContext context) =>
        _ZoomableImagePage(buildImage: buildImage),
  ),
);

class _ZoomableImagePage extends StatefulWidget {
  const _ZoomableImagePage({required this.buildImage});

  final WidgetBuilder buildImage;

  @override
  State<_ZoomableImagePage> createState() => _ZoomableImagePageState();
}

class _ZoomableImagePageState extends State<_ZoomableImagePage> {
  final TransformationController _transformation = TransformationController();
  Offset _doubleTapPosition = Offset.zero;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  /// Returns to fit after any zoom, or puts the tapped point under the same
  /// finger at 2x when the image is currently fitted.
  void _toggleDoubleTapZoom() {
    if (_transformation.value.getMaxScaleOnAxis() > 1.01) {
      _transformation.value = Matrix4.identity();
      return;
    }
    _transformation.value = Matrix4.identity()
      ..setEntry(0, 0, 2)
      ..setEntry(1, 1, 2)
      ..setEntry(0, 3, -_doubleTapPosition.dx)
      ..setEntry(1, 3, -_doubleTapPosition.dy);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GestureDetector(
          onDoubleTapDown: (TapDownDetails details) {
            _doubleTapPosition = details.localPosition;
          },
          onDoubleTap: _toggleDoubleTapZoom,
          child: InteractiveViewer(
            transformationController: _transformation,
            minScale: 1,
            maxScale: 8,
            child: SizedBox.expand(child: widget.buildImage(context)),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Close image',
            ),
          ),
        ),
      ],
    ),
  );
}
