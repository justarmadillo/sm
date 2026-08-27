import 'package:incremental_reader/src/domain/content/block.dart';
import 'package:incremental_reader/src/domain/content/document.dart';
import 'package:incremental_reader/src/domain/content/inline_markup.dart';
import 'package:incremental_reader/src/domain/content/reader_anchor.dart';
import 'package:test/test.dart';
import '../../support/anchors.dart';

/// Exercises every construct the Reader has to map exactly: formatting,
/// links, code, math, Unicode, escapes, lists, quotes, and tables.
const String fixture = '''
# Heading One

A paragraph with **bold**, *italic*, `code()`, a [link](https://example.com), and \$E = mc^2\$ inline math.

Unicode: café, 日本語, and an emoji 👍 in text.

- First item
- Second item with **emphasis**

> A quote line
> continued here

```dart
void main() {
  print('hi');
}
```

| A | B |
|---|---|
| 1 | 2 |

\$\$
\\int_0^1 x^2 dx
\$\$

Escaped \\*not italic\\* here.
''';

void main() {
  final document = Document.parse(sourceId: 'src', markdown: fixture);

  Block blockOfType(BlockType type, {int nth = 0}) {
    final matches = document.blocks.where((Block b) => b.type == type).toList();
    expect(
      matches.length,
      greaterThan(nth),
      reason: 'no ${type.name} block #$nth in fixture',
    );
    return matches[nth];
  }

  /// Selects [needle] in a block's rendered text and returns the exact
  /// markdown those rendered characters came from.
  String sourceFor(Block block, String needle) {
    final start = block.renderedText.indexOf(needle);
    expect(start, isNonNegative, reason: '"$needle" not rendered in $block');
    return block.rawSliceForRendered(start, start + needle.length);
  }

  group('block parsing', () {
    test('splits the fixture into the expected block types', () {
      final types = document.blocks.map((Block b) => b.type).toList();
      expect(types, <BlockType>[
        BlockType.heading,
        BlockType.paragraph,
        BlockType.paragraph,
        BlockType.listItem,
        BlockType.listItem,
        BlockType.quote,
        BlockType.codeBlock,
        BlockType.table,
        BlockType.mathBlock,
        BlockType.paragraph,
      ]);
    });

    test('every block raw text matches its recorded source offsets', () {
      for (final block in document.blocks) {
        expect(
          fixture.substring(block.sourceStartUtf16, block.sourceEndUtf16),
          block.raw,
          reason: 'raw text does not match offsets for $block',
        );
      }
    });

    test('blocks are ordered and never overlap', () {
      for (var i = 1; i < document.blocks.length; i++) {
        expect(
          document.blocks[i].sourceStartUtf8,
          greaterThanOrEqualTo(document.blocks[i - 1].sourceEndUtf8),
          reason: 'block $i overlaps its predecessor',
        );
      }
    });

    test('heading strips its syntax from content but not from raw', () {
      final heading = blockOfType(BlockType.heading);
      expect(heading.headingLevel, 1);
      expect(heading.raw, '# Heading One');
      expect(heading.renderedText, 'Heading One');
    });

    test('code block keeps its content verbatim and records the language', () {
      final code = blockOfType(BlockType.codeBlock);
      expect(code.codeLanguage, 'dart');
      expect(code.renderedText, "void main() {\n  print('hi');\n}");
      expect(code.raw.startsWith('```dart'), isTrue);
      expect(code.raw.trimRight().endsWith('```'), isTrue);
    });

    test('math block keeps its body verbatim', () {
      final math = blockOfType(BlockType.mathBlock);
      expect(math.renderedText, r'\int_0^1 x^2 dx');
    });

    test('list items drop their markers from rendered text', () {
      expect(blockOfType(BlockType.listItem).renderedText, 'First item');
      expect(
        blockOfType(BlockType.listItem, nth: 1).renderedText,
        'Second item with emphasis',
      );
    });

    test('a multi-line quote joins its lines without the markers', () {
      final quote = blockOfType(BlockType.quote);
      expect(quote.renderedText, 'A quote line continued here');
      expect(quote.raw, '> A quote line\n> continued here');
    });
  });

  group('inline rendering', () {
    test('a formatted paragraph renders without its markup', () {
      final paragraph = blockOfType(BlockType.paragraph);
      expect(
        paragraph.renderedText,
        'A paragraph with bold, italic, code(), a link, and E = mc^2 inline math.',
      );
    });

    test('styles are attached to the runs they came from', () {
      final paragraph = blockOfType(BlockType.paragraph);
      InlineSegment segmentOf(String text) => paragraph.inline.segments
          .firstWhere((InlineSegment s) => s.text == text);

      expect(segmentOf('bold').styles, contains(InlineStyle.strong));
      expect(segmentOf('italic').styles, contains(InlineStyle.emphasis));
      expect(segmentOf('code()').styles, contains(InlineStyle.code));
      expect(segmentOf('link').styles, contains(InlineStyle.link));
      expect(segmentOf('link').linkHref, 'https://example.com');
      expect(segmentOf('E = mc^2').styles, contains(InlineStyle.math));
    });

    test('rendered runs tile the rendered text with no gaps', () {
      for (final block in document.blocks) {
        var cursor = 0;
        for (final segment in block.inline.segments) {
          expect(segment.renderedStart, cursor, reason: 'gap in $block');
          cursor = segment.renderedEnd;
        }
        expect(
          cursor,
          block.renderedText.length,
          reason: 'short run in $block',
        );
      }
    });
  });

  group('rendered selection maps back to exact markdown', () {
    test('plain text', () {
      final paragraph = blockOfType(BlockType.paragraph);
      expect(sourceFor(paragraph, 'A paragraph with'), 'A paragraph with');
    });

    test('strong and emphasis resolve to their inner text', () {
      final paragraph = blockOfType(BlockType.paragraph);
      expect(sourceFor(paragraph, 'bold'), 'bold');
      expect(sourceFor(paragraph, 'italic'), 'italic');
    });

    test('inline code resolves inside the backticks', () {
      expect(sourceFor(blockOfType(BlockType.paragraph), 'code()'), 'code()');
    });

    test('a link resolves to its label, not its destination', () {
      expect(sourceFor(blockOfType(BlockType.paragraph), 'link'), 'link');
    });

    test('inline math resolves to its TeX body', () {
      expect(
        sourceFor(blockOfType(BlockType.paragraph), 'E = mc^2'),
        'E = mc^2',
      );
    });

    test('a run spanning markup keeps the markup in the source slice', () {
      final paragraph = blockOfType(BlockType.paragraph);
      expect(sourceFor(paragraph, 'bold, italic'), 'bold**, *italic');
    });

    test('accented, CJK, and astral characters', () {
      final unicode = blockOfType(BlockType.paragraph, nth: 1);
      expect(sourceFor(unicode, 'café'), 'café');
      expect(sourceFor(unicode, '日本語'), '日本語');
      expect(sourceFor(unicode, '👍'), '👍');
    });

    test(
      'escapes resolve to the escaped source, not the rendered character',
      () {
        final escaped = blockOfType(BlockType.paragraph, nth: 2);
        expect(escaped.renderedText, 'Escaped *not italic* here.');
        expect(sourceFor(escaped, 'not italic'), 'not italic');
        expect(sourceFor(escaped, 'Escaped'), 'Escaped');
      },
    );

    test('inside a list item and a quote', () {
      expect(
        sourceFor(blockOfType(BlockType.listItem), 'First item'),
        'First item',
      );
      expect(
        sourceFor(blockOfType(BlockType.listItem, nth: 1), 'emphasis'),
        'emphasis',
      );
      expect(
        sourceFor(blockOfType(BlockType.quote), 'quote line'),
        'quote line',
      );
    });

    test('inside a code block, where every character is literal', () {
      expect(
        sourceFor(blockOfType(BlockType.codeBlock), "print('hi')"),
        "print('hi')",
      );
    });
  });

  group('anchor round trips', () {
    test('every rendered position survives a round trip through UTF-8', () {
      for (final block in document.blocks) {
        for (var i = 0; i <= block.renderedText.length; i++) {
          // The low half of a surrogate pair is not a text position; it snaps
          // back to the start of its code point by design.
          if (i < block.renderedText.length &&
              _isLowSurrogate(block.renderedText.codeUnitAt(i))) {
            expect(
              block.utf8ToRendered(block.renderedToUtf8(i)),
              i - 1,
              reason: 'surrogate half did not snap at $i in $block',
            );
            continue;
          }
          final utf8Offset = block.renderedToUtf8(i);
          final back = block.utf8ToRendered(utf8Offset);
          final segment = _segmentAt(block, i);
          if (segment == null || segment.isIdentity) {
            expect(back, i, reason: 'round trip failed at $i in $block');
          } else {
            // Runs whose rendered length differs from their source length
            // collapse to a boundary rather than guessing an interior point.
            expect(
              back,
              anyOf(segment.renderedStart, segment.renderedEnd),
              reason: 'non-identity run did not collapse at $i in $block',
            );
          }
        }
      }
    });

    test('anchors resolve for blocks that were never rendered', () {
      // Nothing in the pipeline mounts a widget: a freshly parsed document
      // answers coordinate questions for every block immediately.
      final fresh = Document.parse(sourceId: 'src', markdown: fixture);
      final last = fresh.blocks.last;
      final anchor = anchorIn(last, 0);
      expect(fresh.documentOffsetOf(anchor), last.sourceStartUtf8);
      expect(fresh.blockById(last.id), same(last));
    });
  });

  group('document coordinates', () {
    test('document offsets and anchors round trip', () {
      for (final block in document.blocks) {
        final anchor = anchorIn(block, 0);
        final offset = document.documentOffsetOf(anchor)!;
        expect(document.anchorAt(offset), anchor);
      }
    });

    test('an offset between blocks resolves to the next block', () {
      final first = document.blocks.first;
      final anchor = document.anchorAt(first.sourceEndUtf8 + 1);
      expect(document.blockForAnchor(anchor)?.id, document.blocks[1].id);
      expect(anchor.utf8Offset, document.blocks[1].sourceStartUtf8);
    });

    test('a cross-block range returns the exact original markdown', () {
      final start = anchorIn(document.blocks[3], 0);
      final end = anchorIn(
        document.blocks[5],
        document.blocks[5].lengthUtf8,
      );
      final slice = document.markdownBetween(start, end);
      expect(
        slice,
        fixture.substring(
          document.blocks[3].sourceStartUtf16,
          document.blocks[5].sourceEndUtf16,
        ),
      );
      expect(slice.startsWith('- First item'), isTrue);
      expect(slice.endsWith('> continued here'), isTrue);
    });

    test('a selection range verifies its own text', () {
      final start = anchorIn(document.blocks[0], 2);
      final end = anchorIn(document.blocks[0], 13);
      final markdown = document.markdownBetween(start, end);
      final range = SelectionRange.of(
        startAnchor: start,
        endAnchor: end,
        markdown: markdown,
      );
      expect(markdown, 'Heading One');
      expect(range.matches(markdown), isTrue);
      expect(range.matches('Heading Two'), isFalse);
      expect(document.isSameBlock(range), isTrue);
      expect(range.isCollapsed, isFalse);
    });

    test('an inverted or unknown range yields nothing', () {
      final a = anchorIn(document.blocks[2], 5);
      final b = anchorIn(document.blocks[1], 5);
      expect(document.markdownBetween(a, b), '');
      expect(
        document.markdownBetween(const ReaderAnchor(utf8Offset: 0), a).isEmpty,
        isFalse,
        reason: 'offset 0 is a real place; only inverted ranges are empty',
      );
    });
  });

  group('line ending normalization', () {
    test('CRLF input produces the same blocks as LF input', () {
      final crlf = Document.parse(
        sourceId: 'src',
        markdown: fixture.replaceAll('\n', '\r\n'),
      );
      expect(crlf.markdown, fixture);
      expect(
        crlf.blocks.map((Block b) => b.raw).toList(),
        document.blocks.map((Block b) => b.raw).toList(),
      );
    });
  });
}

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

InlineSegment? _segmentAt(Block block, int renderedIndex) {
  for (final segment in block.inline.segments) {
    if (renderedIndex >= segment.renderedStart &&
        renderedIndex < segment.renderedEnd) {
      return segment;
    }
  }
  return null;
}
