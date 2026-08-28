/// Editing a source's text, end to end, against a real database.
///
/// The properties under test are the ones a reader has to keep for years:
/// positions land on the same words afterwards, extracts survive edits to the
/// text they came from, a degraded link says so instead of pointing somewhere
/// plausible, and nothing about scheduling moves — editing an article is not a
/// repetition of it.
library;

import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/extract/extraction_commands.dart';
import 'package:incremental_reader/features/reader/reader_command_runner.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:test/test.dart';

import '../support/anchors.dart';
import '../support/app_harness.dart';

const String _markdown = '''
# Chlorophyll

Photosynthesis converts light into chemical energy.

Chlorophyll absorbs blue and red light most strongly.

A third paragraph, further still.
''';

void main() {
  late AppHarness harness;

  setUp(() => harness = AppHarness());
  tearDown(() => harness.database.close());

  Future<Source> importFixture() async {
    final result = await harness.reader.importSource(
      ImportSource(
        harness.operation(),
        title: 'Chlorophyll',
        markdown: _markdown,
      ),
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.unwrap();
  }

  Future<Document> documentOf(String sourceId) async =>
      (await harness.content.findDocument(sourceId))!;

  /// Replaces the block containing [needle] with [markdown].
  Future<Result<SourceEdited>> editBlockWith(
    String sourceId,
    String needle,
    String markdown,
  ) async {
    final document = await documentOf(sourceId);
    final block = document.blocks.firstWhere(
      (Block b) => b.raw.contains(needle),
    );
    return harness.reader.editSourceBlock(
      EditSourceBlock(
        harness.operation(),
        sourceId: sourceId,
        blockId: block.id,
        markdown: markdown,
        baseContentRevision: document.contentRevision,
      ),
    );
  }

  /// Extracts exactly [needle] out of the block that contains it.
  Future<Extract> extractPhrase(String sourceId, String needle) async {
    final document = await documentOf(sourceId);
    final block = document.blocks.firstWhere(
      (Block b) => b.renderedText.contains(needle),
    );
    final renderedStart = block.renderedText.indexOf(needle);
    final start = anchorAtRendered(block, renderedStart);
    final end = anchorAtRendered(block, renderedStart + needle.length);
    final result = await harness.extraction.createExtract(
      CreateExtract(
        harness.operation(),
        parentId: sourceId,
        hasSourceAsParent: true,
        range: SelectionRange.of(
          startAnchor: start,
          endAnchor: end,
          markdown: document.markdownBetween(start, end),
        ),
      ),
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.unwrap();
  }

  group('applying an edit', () {
    test('replaces the block and advances the content revision', () async {
      final source = await importFixture();
      expect(source.contentRevision, 1);

      final result = await editBlockWith(
        source.id,
        'Photosynthesis',
        'Photosynthesis converts sunlight into sugar.',
      );

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      final edited = result.unwrap();
      expect(edited.didChange, isTrue);
      expect(edited.source.contentRevision, 2);
      expect(edited.source.markdown, contains('sunlight into sugar'));
      expect(edited.source.markdown, isNot(contains('chemical energy')));
      expect(
        edited.source.markdown,
        contains('Chlorophyll absorbs blue and red light'),
        reason: 'the surrounding blocks are untouched',
      );
    });

    test('rebuilds the block cache from the new text', () async {
      final source = await importFixture();
      await editBlockWith(
        source.id,
        'Photosynthesis',
        'One.\n\nTwo.\n\nThree.',
      );

      final document = await documentOf(source.id);
      expect(document.contentRevision, 2);
      expect(
        document.blocks.map((Block b) => b.raw).toList(),
        containsAllInOrder(<String>['One.', 'Two.', 'Three.']),
      );
      for (var i = 0; i < document.blocks.length; i++) {
        expect(document.blocks[i].index, i, reason: 'blocks are renumbered');
      }
    });

    test('recomputes the hash and word count', () async {
      final source = await importFixture();
      final edited = (await editBlockWith(
        source.id,
        'A third paragraph',
        'A third paragraph, now much longer than it used to be indeed.',
      )).unwrap();

      final stored = (await harness.content.findSource(source.id))!;
      expect(stored.contentHash, edited.source.contentHash);
      expect(stored.wordCount, greaterThan(source.wordCount));
    });

    test('an edit that changes nothing writes nothing', () async {
      final source = await importFixture();
      final document = await documentOf(source.id);
      final block = document.blocks.firstWhere(
        (Block b) => b.raw.contains('Photosynthesis'),
      );

      final result = await harness.reader.editSourceBlock(
        EditSourceBlock(
          harness.operation(),
          sourceId: source.id,
          blockId: block.id,
          markdown: block.raw,
          baseContentRevision: document.contentRevision,
        ),
      );

      expect(result.isOk, isTrue);
      expect(result.unwrap().didChange, isFalse);
      expect(result.unwrap().source.contentRevision, 1);
      expect(await harness.content.listSourceEdits(source.id), isEmpty);
    });

    test('an unknown block is refused', () async {
      final source = await importFixture();
      final result = await harness.reader.editSourceBlock(
        EditSourceBlock(
          harness.operation(),
          sourceId: source.id,
          blockId: 'nothing-like-this',
          markdown: 'text',
          baseContentRevision: 1,
        ),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('reading positions', () {
    test('a marker after the edit lands on the same words', () async {
      final source = await importFixture();
      final document = await documentOf(source.id);
      final third = document.blocks.last;
      final marker = anchorIn(third, 2);
      final before = document.markdownSlice(
        marker.utf8Offset,
        third.sourceEndUtf8,
      );

      await harness.reader.moveResumeMarker(
        MoveResumeMarker(
          harness.operation(),
          sourceId: source.id,
          anchor: marker,
        ),
      );
      final edited = (await editBlockWith(
        source.id,
        'Photosynthesis',
        'Short.',
      )).unwrap();

      final moved = edited.source.resume.marker!;
      expect(moved.utf8Offset, isNot(marker.utf8Offset));
      expect(moved.contentRevision, 2);
      expect(
        edited.document.markdownSlice(
          moved.utf8Offset,
          edited.document.lengthUtf8,
        ),
        before,
        reason: 'the marker still sits in front of exactly the same text',
      );
      expect(edited.outcome!.markerWasInsideEdit, isFalse);
    });

    test('a marker before the edit does not move at all', () async {
      final source = await importFixture();
      final document = await documentOf(source.id);
      final marker = anchorIn(document.blocks.first, 2);

      await harness.reader.moveResumeMarker(
        MoveResumeMarker(
          harness.operation(),
          sourceId: source.id,
          anchor: marker,
        ),
      );
      final edited = (await editBlockWith(
        source.id,
        'A third paragraph',
        'Rewritten entirely.',
      )).unwrap();

      expect(edited.source.resume.marker!.utf8Offset, marker.utf8Offset);
    });

    test('a marker inside deleted text collapses and is reported', () async {
      final source = await importFixture();
      final document = await documentOf(source.id);
      final target = document.blocks.firstWhere(
        (Block b) => b.raw.contains('Photosynthesis'),
      );
      final marker = anchorIn(target, 10);

      await harness.reader.moveResumeMarker(
        MoveResumeMarker(
          harness.operation(),
          sourceId: source.id,
          anchor: marker,
        ),
      );
      final edited = (await harness.reader.deleteSourceBlock(
        DeleteSourceBlock(
          harness.operation(),
          sourceId: source.id,
          blockId: target.id,
          baseContentRevision: document.contentRevision,
        ),
      )).unwrap();

      expect(edited.outcome!.markerWasInsideEdit, isTrue);
      expect(
        edited.source.resume.marker!.utf8Offset,
        target.sourceStartUtf8,
        reason: 'collapsed to the nearest surviving place',
      );
      expect(edited.source.markdown, isNot(contains('Photosynthesis')));
      expect(
        edited.source.markdown,
        contains('# Chlorophyll\n\nChlorophyll absorbs'),
        reason: 'the separator went with the block, not one blank line extra',
      );
    });
  });

  group('extract provenance', () {
    test('an extract before the edit keeps its exact link', () async {
      final source = await importFixture();
      final extract = await extractPhrase(source.id, 'Photosynthesis');

      await editBlockWith(
        source.id,
        'A third paragraph',
        'Rewritten entirely.',
      );

      final stored = (await harness.content.findExtract(extract.id))!;
      expect(stored.provenance.state, ProvenanceState.verbatim);
      expect(stored.provenance.startUtf8, extract.provenance.startUtf8);
      expect(stored.markdown, extract.markdown);
    });

    test('an extract after the edit shifts and stays verbatim', () async {
      final source = await importFixture();
      final extract = await extractPhrase(source.id, 'Chlorophyll absorbs');

      await editBlockWith(
        source.id,
        'Photosynthesis',
        'Much shorter.',
      );

      final stored = (await harness.content.findExtract(extract.id))!;
      final document = await documentOf(source.id);
      expect(stored.provenance.state, ProvenanceState.verbatim);
      expect(
        stored.provenance.startUtf8,
        lessThan(extract.provenance.startUtf8),
      );
      expect(
        document.markdownSlice(
          stored.provenance.startUtf8,
          stored.provenance.endUtf8,
        ),
        'Chlorophyll absorbs',
        reason: 'the recorded range still covers the extracted words',
      );
    });

    test('editing the text an extract came from marks it stale', () async {
      final source = await importFixture();
      final extract = await extractPhrase(source.id, 'Chlorophyll absorbs');

      final edited = (await editBlockWith(
        source.id,
        'Chlorophyll absorbs',
        'Chlorophyll reflects green light instead.',
      )).unwrap();

      final stored = (await harness.content.findExtract(extract.id))!;
      expect(stored.provenance.state, ProvenanceState.stale);
      expect(
        stored.markdown,
        extract.markdown,
        reason: 'the extract keeps its own copy of the text, untouched',
      );
      expect(edited.outcome!.changedProvenance, hasLength(1));
    });

    test('deleting the text an extract came from orphans it', () async {
      final source = await importFixture();
      final extract = await extractPhrase(source.id, 'Chlorophyll absorbs');
      final document = await documentOf(source.id);
      final target = document.blocks.firstWhere(
        (Block b) => b.raw.contains('Chlorophyll absorbs'),
      );

      await harness.reader.deleteSourceBlock(
        DeleteSourceBlock(
          harness.operation(),
          sourceId: source.id,
          blockId: target.id,
          baseContentRevision: document.contentRevision,
        ),
      );

      final stored = (await harness.content.findExtract(extract.id))!;
      expect(stored.provenance.state, ProvenanceState.orphaned);
      expect(stored.markdown, extract.markdown);
    });

    test('a degraded link is never quietly repaired', () async {
      final source = await importFixture();
      final extract = await extractPhrase(source.id, 'Chlorophyll absorbs');

      // Break it, then put the original words back. The bytes match again,
      // which is a coincidence, not evidence that the passage is the same one.
      await editBlockWith(
        source.id,
        'Chlorophyll absorbs',
        'Chlorophyll reflects green light instead.',
      );
      await editBlockWith(
        source.id,
        'Chlorophyll reflects',
        'Chlorophyll absorbs blue and red light most strongly.',
      );

      final stored = (await harness.content.findExtract(extract.id))!;
      expect(stored.provenance.state, ProvenanceState.stale);
    });
  });

  group('nothing about scheduling moves', () {
    test('an edit leaves every scheduling row byte-identical', () async {
      final source = await importFixture();
      await extractPhrase(source.id, 'Chlorophyll absorbs');

      final before = await harness.schedulingSnapshot();
      await editBlockWith(
        source.id,
        'Chlorophyll absorbs',
        'Chlorophyll reflects green light instead.',
      );
      final after = await harness.schedulingSnapshot();

      expect(after, before);
    });
  });

  group('concurrency and replay', () {
    test('editing against a stale revision is refused outright', () async {
      final source = await importFixture();
      final document = await documentOf(source.id);
      final block = document.blocks.first;

      await editBlockWith(source.id, 'Photosynthesis', 'First edit wins.');

      final result = await harness.reader.editSourceBlock(
        EditSourceBlock(
          harness.operation(),
          sourceId: source.id,
          blockId: block.id,
          markdown: '# Second edit',
          baseContentRevision: 1,
        ),
      );

      expect(result.failureOrNull, isA<ConflictFailure>());
      final stored = (await harness.content.findSource(source.id))!;
      expect(stored.contentRevision, 2, reason: 'nothing was written');
      expect(stored.markdown, startsWith('# Chlorophyll'));
    });

    test('a resent command applies exactly once', () async {
      final source = await importFixture();
      final document = await documentOf(source.id);
      final block = document.blocks.firstWhere(
        (Block b) => b.raw.contains('Photosynthesis'),
      );
      final command = EditSourceBlock(
        harness.operation(),
        sourceId: source.id,
        blockId: block.id,
        markdown: 'Applied once.',
        baseContentRevision: 1,
      );

      final first = await harness.reader.editSourceBlock(command);
      final second = await harness.reader.editSourceBlock(command);

      expect(first.isOk, isTrue);
      expect(second.isOk, isTrue, reason: '${second.failureOrNull}');
      expect(second.unwrap().source.contentRevision, 2);
      expect(await harness.content.listSourceEdits(source.id), hasLength(1));
      expect(
        'Applied once.'.allMatches(second.unwrap().source.markdown),
        hasLength(1),
      );
    });
  });

  group('undo', () {
    test('restores byte-identical text and positions', () async {
      final source = await importFixture();
      final document = await documentOf(source.id);
      final marker = anchorIn(document.blocks.last, 4);
      await harness.reader.moveResumeMarker(
        MoveResumeMarker(
          harness.operation(),
          sourceId: source.id,
          anchor: marker,
        ),
      );

      await editBlockWith(source.id, 'Photosynthesis', 'Something else.');
      final undone = (await harness.reader.undoSourceEdit(
        UndoSourceEdit(harness.operation(), sourceId: source.id),
      )).unwrap();

      expect(undone.source.markdown, source.markdown);
      expect(undone.source.contentHash, source.contentHash);
      expect(
        undone.source.resume.marker!.utf8Offset,
        marker.utf8Offset,
        reason: 'the marker came back to the character it was placed on',
      );
    });

    test('is recorded as a new forward edit, never a rewind', () async {
      final source = await importFixture();
      await editBlockWith(source.id, 'Photosynthesis', 'Something else.');
      await harness.reader.undoSourceEdit(
        UndoSourceEdit(harness.operation(), sourceId: source.id),
      );

      final journal = await harness.content.listSourceEdits(source.id);
      expect(journal, hasLength(2));
      expect(journal.first.contentRevision, 2);
      expect(journal.last.contentRevision, 3);
      expect(journal.last.isUndo, isTrue);
      expect((await harness.content.findSource(source.id))!.contentRevision, 3);
    });

    test('restores an extract that the edit had orphaned', () async {
      final source = await importFixture();
      final extract = await extractPhrase(source.id, 'Chlorophyll absorbs');
      final document = await documentOf(source.id);
      final target = document.blocks.firstWhere(
        (Block b) => b.raw.contains('Chlorophyll absorbs'),
      );

      await harness.reader.deleteSourceBlock(
        DeleteSourceBlock(
          harness.operation(),
          sourceId: source.id,
          blockId: target.id,
          baseContentRevision: document.contentRevision,
        ),
      );
      await harness.reader.undoSourceEdit(
        UndoSourceEdit(harness.operation(), sourceId: source.id),
      );

      final restored = (await harness.content.findExtract(extract.id))!;
      final after = await documentOf(source.id);
      expect(
        after.markdownSlice(
          restored.provenance.startUtf8,
          restored.provenance.endUtf8,
        ),
        'Chlorophyll absorbs',
        reason: 'the range points at the passage again',
      );
      expect(
        restored.provenance.state,
        ProvenanceState.verbatim,
        reason:
            'undo leaves no trace of the edit, provenance included: the '
            'recorded pre-edit values are restored rather than re-derived',
      );
    });

    test('undoing with nothing to undo is refused', () async {
      final source = await importFixture();
      final result = await harness.reader.undoSourceEdit(
        UndoSourceEdit(harness.operation(), sourceId: source.id),
      );
      expect(result.failureOrNull, isA<ConflictFailure>());
    });
  });

  group('block structure', () {
    test('deleting the only block leaves an empty source', () async {
      final result = await harness.reader.importSource(
        ImportSource(
          harness.operation(),
          title: 'One line',
          markdown: 'Only paragraph.',
        ),
      );
      final source = result.unwrap();
      final document = await documentOf(source.id);

      final edited = (await harness.reader.deleteSourceBlock(
        DeleteSourceBlock(
          harness.operation(),
          sourceId: source.id,
          blockId: document.blocks.single.id,
          baseContentRevision: 1,
        ),
      )).unwrap();

      expect(edited.source.markdown, isEmpty);
      expect(edited.document.isEmpty, isTrue);
      expect(edited.source.wordCount, 0);
    });

    test('inserting a block places it after its neighbour', () async {
      final source = await importFixture();
      final document = await documentOf(source.id);
      final first = document.blocks.first;

      final edited = (await harness.reader.insertSourceBlock(
        InsertSourceBlock(
          harness.operation(),
          sourceId: source.id,
          afterBlockId: first.id,
          markdown: 'An inserted note.',
          baseContentRevision: 1,
        ),
      )).unwrap();

      expect(edited.document.blocks[1].raw, 'An inserted note.');
      expect(edited.document.blocks.first.raw, first.raw);
    });

    test('multi-byte text either side of an edit survives exactly', () async {
      final result = await harness.reader.importSource(
        ImportSource(
          harness.operation(),
          title: 'Mixed',
          markdown: '🌱 Seedling é中\n\nMiddle paragraph.\n\n中é 🌱 tail',
        ),
      );
      final source = result.unwrap();
      final edited = (await editBlockWith(
        source.id,
        'Middle paragraph',
        'Replaced 中間 text.',
      )).unwrap();

      expect(edited.source.markdown, startsWith('🌱 Seedling é中'));
      expect(edited.source.markdown, endsWith('中é 🌱 tail'));
      expect(edited.source.markdown, contains('Replaced 中間 text.'));
    });
  });
}
