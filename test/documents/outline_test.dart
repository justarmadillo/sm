/// The outline as a structure that can be rewritten.
///
/// The Reader's outline panel is the document's own heading lines, so what is
/// pinned here is the mapping in both directions: which bytes a heading owns,
/// which entry is its sibling, and that moving a section moves its paragraphs
/// with it rather than the heading alone.
library;

import 'package:incremental_reader/documents/block_edit.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/outline.dart';
import 'package:incremental_reader/documents/text_splice.dart';
import 'package:test/test.dart';

const String _markdown = '''
# Memory

An opening paragraph under the title.

## Spacing

Spacing beats massing for durable retention.

### Intervals

Intervals grow with each successful recall.

## Testing

Testing beats rereading, and by a wide margin.
''';

Document _parse(String markdown) =>
    Document.parse(sourceId: 'source', markdown: markdown);

/// The document as it reads after [splice] is applied to it.
String _spliced(Document document, TextSplice splice) =>
    document.markdown.substring(
      0,
      document.utf8Index.toUtf16(splice.startUtf8),
    ) +
    splice.inserted +
    document.markdown.substring(document.utf8Index.toUtf16(splice.endUtf8));

void main() {
  late Document document;
  late List<OutlineEntry> outline;

  setUp(() {
    document = _parse(_markdown);
    outline = outlineOf(document);
  });

  group('reading the structure', () {
    test('every heading becomes an entry, in document order', () {
      expect(outline.map((OutlineEntry entry) => entry.text), <String>[
        'Memory',
        'Spacing',
        'Intervals',
        'Testing',
      ]);
      expect(outline.map((OutlineEntry entry) => entry.level), <int>[
        1,
        2,
        3,
        2,
      ]);
    });

    test('a heading owns everything down to the next one at its level', () {
      final OutlineEntry spacing = outline[1];
      final String section = document.markdownSlice(
        spacing.sectionStartUtf8,
        spacing.sectionEndUtf8,
      );

      // Its own paragraph and the whole of the deeper heading below it.
      expect(section, startsWith('## Spacing'));
      expect(section, contains('### Intervals'));
      expect(section, contains('Intervals grow'));
      expect(section, isNot(contains('## Testing')));
    });

    test('the last heading owns the rest of the document', () {
      final OutlineEntry testing = outline.last;
      expect(testing.sectionEndUtf8, document.blocks.last.sourceEndUtf8);
      expect(
        document.markdownSlice(
          testing.sectionStartUtf8,
          testing.sectionEndUtf8,
        ),
        contains('Testing beats rereading'),
      );
    });
  });

  group('siblings', () {
    test('a deeper heading has no sibling above it', () {
      // Intervals sits under Spacing, so the entry above it is its parent and
      // not something it may be swapped with.
      expect(previousSiblingOf(outline, outline[2]), isNull);
      expect(nextSiblingOf(outline, outline[2]), isNull);
    });

    test('two headings at the same level under one parent are siblings', () {
      expect(nextSiblingOf(outline, outline[1])?.text, 'Testing');
      expect(previousSiblingOf(outline, outline[3])?.text, 'Spacing');
    });

    test('the first and last of a group have nothing beyond them', () {
      expect(previousSiblingOf(outline, outline[1]), isNull);
      expect(nextSiblingOf(outline, outline[3]), isNull);
    });
  });

  group('moving a section', () {
    test('moving down carries the paragraphs and the nested heading', () {
      final TextSplice? splice = spliceForSectionSwap(
        document,
        outline[1].blockId,
        shouldMoveUp: false,
      );

      expect(splice, isNotNull);
      final List<String> headings = <String>[
        for (final OutlineEntry entry in outlineOf(
          _parse(_spliced(document, splice!)),
        ))
          entry.text,
      ];
      expect(headings, <String>['Memory', 'Testing', 'Spacing', 'Intervals']);
    });

    test('moving up is the exact reverse of moving down', () {
      final TextSplice down = spliceForSectionSwap(
        document,
        outline[1].blockId,
        shouldMoveUp: false,
      )!;
      final Document moved = _parse(_spliced(document, down));
      final OutlineEntry spacing = outlineEntryOf(
        outlineOf(moved),
        outlineOf(moved)[2].blockId,
      )!;

      final TextSplice up = spliceForSectionSwap(
        moved,
        spacing.blockId,
        shouldMoveUp: true,
      )!;

      expect(_spliced(moved, up), document.markdown);
    });

    test('a heading with no sibling that way refuses to move', () {
      expect(
        spliceForSectionSwap(document, outline[1].blockId, shouldMoveUp: true),
        isNull,
      );
      expect(
        spliceForSectionSwap(document, outline[2].blockId, shouldMoveUp: false),
        isNull,
      );
    });

    test('a block that is not a heading refuses to move', () {
      final String paragraphId = document.blocks[1].id;
      expect(
        spliceForSectionSwap(document, paragraphId, shouldMoveUp: false),
        isNull,
      );
    });
  });

  group('rewriting one heading', () {
    test('a level change is a new heading line at the same place', () {
      expect(headingMarkdown(level: 3, text: '  Spacing  '), '### Spacing');
    });

    test('the level is clamped to what markdown can express', () {
      expect(headingMarkdown(level: 9, text: 'Deep'), '###### Deep');
      expect(headingMarkdown(level: 0, text: 'Top'), '# Top');
    });
  });
}
