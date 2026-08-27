/// Performance floor for the sizes the Reader actually meets.
///
/// The budgets are deliberately loose — this is a regression guard against an
/// accidental quadratic, not a benchmark. A parser that starts rescanning the
/// document per block will blow through them by orders of magnitude.
library;

import 'package:incremental_reader/src/domain/content/block.dart';
import 'package:incremental_reader/src/domain/content/document.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/features/reader/presentation/sample_corpus.dart';
import 'package:test/test.dart';

void main() {
  group('50k-word document', () {
    final markdown = generateSampleMarkdown(targetWords: 50000);

    test('the fixture really is chapter-sized', () {
      expect(countWords(markdown), greaterThan(45000));
    });

    test('parses into blocks well inside a frame budget', () {
      final stopwatch = Stopwatch()..start();
      final document = Document.parse(sourceId: 'big', markdown: markdown);
      stopwatch.stop();

      expect(document.blocks.length, greaterThan(500));
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'block parsing took ${stopwatch.elapsedMilliseconds} ms',
      );
    });

    test('inline layout is lazy, so opening a document is cheap', () {
      final document = Document.parse(sourceId: 'big', markdown: markdown);

      final firstScreen = Stopwatch()..start();
      for (final block in document.blocks.take(40)) {
        block.renderedText;
      }
      firstScreen.stop();

      final wholeDocument = Stopwatch()..start();
      for (final block in document.blocks) {
        block.renderedText;
      }
      wholeDocument.stop();

      expect(
        firstScreen.elapsedMilliseconds,
        lessThan(60),
        reason: 'a screenful cost ${firstScreen.elapsedMilliseconds} ms',
      );
      expect(
        wholeDocument.elapsedMilliseconds,
        lessThan(2000),
        reason: 'full inline pass took ${wholeDocument.elapsedMilliseconds} ms',
      );
    });

    test('inline layout is memoized, not recomputed per access', () {
      final document = Document.parse(sourceId: 'big', markdown: markdown);
      final blocks = document.blocks.take(200).toList();

      final cold = Stopwatch()..start();
      for (final block in blocks) {
        block.renderedText;
      }
      cold.stop();

      final warm = Stopwatch()..start();
      for (var i = 0; i < 20; i++) {
        for (final block in blocks) {
          block.renderedText;
        }
      }
      warm.stop();

      expect(
        warm.elapsedMicroseconds,
        lessThan(cold.elapsedMicroseconds * 10),
        reason: 'twenty warm passes should cost far less than twenty cold ones',
      );
    });

    test('anchor lookup is constant-time across the document', () {
      final document = Document.parse(sourceId: 'big', markdown: markdown);

      final stopwatch = Stopwatch()..start();
      for (final block in document.blocks) {
        final anchor = document.anchorAt(block.sourceStartUtf8);
        expect(document.blockForAnchor(anchor)?.id, block.id);
      }
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(200),
        reason:
            'resolving every anchor took ${stopwatch.elapsedMilliseconds} ms',
      );
    });

    test('a cross-document range slices without rescanning', () {
      final document = Document.parse(sourceId: 'big', markdown: markdown);
      final start = document.startAnchor;
      final end = document.endAnchor;

      final stopwatch = Stopwatch()..start();
      final slice = document.markdownBetween(start, end);
      stopwatch.stop();

      expect(slice.length, greaterThan(markdown.length ~/ 2));
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(50),
        reason: 'slicing took ${stopwatch.elapsedMilliseconds} ms',
      );
    });

    test('every block round-trips its raw text', () {
      final document = Document.parse(sourceId: 'big', markdown: markdown);
      for (final block in document.blocks) {
        expect(
          document.markdown.substring(
            block.sourceStartUtf16,
            block.sourceEndUtf16,
          ),
          block.raw,
          reason: 'offsets drifted at ${block.id}',
        );
      }
    });

    test('block types cover the constructs the generator emits', () {
      final document = Document.parse(sourceId: 'big', markdown: markdown);
      final present = document.blocks.map((Block b) => b.type).toSet();
      expect(
        present,
        containsAll(<BlockType>[
          BlockType.heading,
          BlockType.paragraph,
          BlockType.listItem,
          BlockType.quote,
          BlockType.codeBlock,
          BlockType.mathBlock,
          BlockType.table,
        ]),
      );
    });
  });
}
