/// Portable Reader image references, sizing, and Markdown-safe alt text.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/markdown_inline_parser.dart';
import 'package:incremental_reader/features/reader/reader_image_input.dart';
import 'package:incremental_reader/features/reader/widgets/block_span_builder.dart';
import 'package:incremental_reader/features/reader/widgets/block_view.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

void main() {
  test('image markup occupies one rendered coordinate', () {
    final document = Document.parse(
      sourceId: 'source-1',
      markdown: '![Diagram](ir-asset:${'a' * 64})',
    );
    final block = document.blocks.single;

    expect(block.renderedText, kObjectReplacement);
    expect(
      buildBlockSpan(block, ReaderTypography.standard).toPlainText(),
      kObjectReplacement,
    );
    expect(block.rawSliceForRendered(0, 1), document.markdown);
  });

  test('unknown and remote images reserve the same deterministic extent', () {
    final local = Document.parse(
      sourceId: 'source-1',
      markdown: '![Local](ir-asset:${'b' * 64})',
    ).blocks.single;
    final remote = Document.parse(
      sourceId: 'source-1',
      markdown: '![Remote](https://example.com/image.png)',
    ).blocks.single;

    double measure(Block block) => measureBlockHeight(
      block,
      ReaderTypography.standard,
      bodyWidth: 300,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    );

    expect(measure(local), measure(remote));
  });

  test('alt text is trimmed and Markdown punctuation is escaped', () {
    expect(escapeImageAltText(r'  A [map]\draft  '), r'A \[map\]\\draft');
    expect(escapeImageAltText('   '), 'Image');
  });

  test('fitted image dimensions preserve aspect ratio and never enlarge', () {
    expect(
      fittedReaderImageSize(widthPx: 1200, heightPx: 600, maxWidth: 300),
      const Size(300, 150),
    );
    expect(
      fittedReaderImageSize(widthPx: 100, heightPx: 50, maxWidth: 300),
      const Size(100, 50),
    );
  });
}
