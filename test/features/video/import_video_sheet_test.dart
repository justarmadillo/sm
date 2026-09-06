/// Portable thumbnail encoding used by local and clipboard video images.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/video/import_video_sheet.dart';

void main() {
  test('chosen thumbnail bytes become a portable image data URI', () {
    final SourceImageImport image = SourceImageImport(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      altText: 'Preview',
      sha256: 'unused by thumbnail encoding',
      mime: 'image/png',
      widthPx: 2,
      heightPx: 1,
    );

    expect(videoThumbnailDataUrl(image), 'data:image/png;base64,AQID');
  });
}
