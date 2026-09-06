/// Displays a video thumbnail supplied as a remote link or embedded image.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A cosmetic preview that fails quietly when a remote image disappears.
class VideoThumbnail extends StatelessWidget {
  const VideoThumbnail({
    required this.source,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String source;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: SizedBox(width: width, height: height, child: _image()),
  );

  Widget _image() {
    final Uint8List? embeddedBytes = _embeddedImageBytes(source);
    if (embeddedBytes != null) {
      return Image.memory(embeddedBytes, fit: fit, errorBuilder: _error);
    }
    return Image.network(source, fit: fit, errorBuilder: _error);
  }

  Widget _error(BuildContext context, Object error, StackTrace? stackTrace) =>
      const SizedBox.shrink();
}

/// Reads only base64 image data URIs created by the import dialog.
Uint8List? _embeddedImageBytes(String source) {
  final RegExpMatch? match = RegExp(
    r'^data:image/[^;,]+;base64,(.+)$',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(source);
  if (match == null) return null;
  try {
    return base64Decode(match.group(1)!);
  } on FormatException {
    return null;
  }
}
