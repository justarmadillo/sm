import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/extract/extract_command_runner.dart';
import 'package:incremental_reader/features/extract/extract_commands.dart';
import 'package:incremental_reader/features/priority/priority_commands.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/shared/utf8_offsets.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:test/test.dart';

import '../../support/anchors.dart';
import '../../support/app_harness.dart';

/// Deliberately awkward: formatting, links, code, math, Unicode, and a list,
/// so a round trip that only works for plain prose fails here.
const String _markdown = r'''
# Working Memory

The **capacity** of working memory is often quoted as *seven items*, a figure
from Miller's paper, but see `Cowan (2001)` and $n \approx 4$ for the modern
estimate.

Consolidation moves a trace from café-table recall into 日本語-robust storage,
and the transfer is not instant 👍.

- Spacing beats massing for durable retention.
- Testing beats rereading, even when rereading feels better.

> Forgetting is not the enemy of learning.
> It is the mechanism learning is measured against.
''';

/// This suite's fixtures, over the shared stack.
extension _Fixtures on AppHarness {
  OperationId nextOperation() => operation();

  Future<Source> importFixture() async {
    final result = await reader.importSource(
      ImportSource(
        nextOperation(),
        title: 'Working Memory',
        markdown: _markdown,
      ),
    );
    return result.unwrap();
  }
}

/// Pins the fixed-sequence pacing model.
///
/// These suites are about handler behaviour — exactly-once terminal commands,
/// interruption never counting as progress, lifecycle transitions — and the
/// A-factor's arithmetic is exercised in its own domain tests. Fixing the
/// model here keeps the dates in these assertions readable.

void main() {
  late AppHarness harness;
  late FakeClock clock;
  late Source source;
  late Document document;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(database: openInMemoryDatabase(), clock: clock);
    source = await harness.importFixture();
    document = (await harness.content.findDocument(source.id))!;
  });

  tearDown(() => harness.database.close());

  /// Builds a verified selection over rendered text in [block].
  SelectionRange selectRendered(Block block, String needle) {
    final start = block.renderedText.indexOf(needle);
    expect(start, isNonNegative, reason: '"$needle" is not in ${block.id}');
    final (int startUtf8, int endUtf8) = block.sourceRangeForRendered(
      start,
      start + needle.length,
    );
    final anchors = (anchorIn(block, startUtf8), anchorIn(block, endUtf8));
    final markdown = document.markdownBetween(anchors.$1, anchors.$2);
    return SelectionRange.of(
      startAnchor: anchors.$1,
      endAnchor: anchors.$2,
      markdown: markdown,
    );
  }

  Future<Result<Extract>> extract(SelectionRange range) =>
      harness.extraction.createExtract(
        CreateExtract(
          harness.nextOperation(),
          parentId: source.id,
          hasSourceAsParent: true,
          range: range,
        ),
      );

  Block blockOf(BlockType type, {int nth = 0}) =>
      document.blocks.where((Block b) => b.type == type).toList()[nth];

  group('selections preserve valid standalone Markdown', () {
    test('plain prose crossing a strong run keeps that run balanced', () async {
      final paragraph = blockOf(BlockType.paragraph);
      final result = await extract(
        selectRendered(paragraph, 'capacity of working memory'),
      );
      expect(result.unwrap().markdown, '**capacity** of working memory');
    });

    test('a run that starts and ends inside emphasis', () async {
      final paragraph = blockOf(BlockType.paragraph);
      final result = await extract(selectRendered(paragraph, 'seven items'));
      expect(result.unwrap().markdown, '*seven items*');
    });

    test('inline code remains inline code', () async {
      final paragraph = blockOf(BlockType.paragraph);
      final result = await extract(selectRendered(paragraph, 'Cowan (2001)'));
      expect(result.unwrap().markdown, '`Cowan (2001)`');
    });

    test('inline math remains inline math', () async {
      final paragraph = blockOf(BlockType.paragraph);
      final result = await extract(selectRendered(paragraph, r'n \approx 4'));
      expect(result.unwrap().markdown, r'$n \approx 4$');
    });

    test('accented, CJK, and astral characters survive intact', () async {
      final paragraph = blockOf(BlockType.paragraph, nth: 1);
      expect(
        (await extract(
          selectRendered(paragraph, 'café-table'),
        )).unwrap().markdown,
        'café-table',
      );
      expect(
        (await extract(
          selectRendered(paragraph, '日本語-robust'),
        )).unwrap().markdown,
        '日本語-robust',
      );
      expect(
        (await extract(
          selectRendered(paragraph, 'instant 👍'),
        )).unwrap().markdown,
        'instant 👍',
      );
    });

    test('inside a list item and a quote', () async {
      expect(
        (await extract(
          selectRendered(blockOf(BlockType.listItem), 'Spacing beats massing'),
        )).unwrap().markdown,
        'Spacing beats massing',
      );
      expect(
        (await extract(
          selectRendered(blockOf(BlockType.quote), 'not the enemy'),
        )).unwrap().markdown,
        'not the enemy',
      );
    });

    test('a whole block retains its content and exact provenance', () async {
      final paragraph = blockOf(BlockType.paragraph, nth: 1);
      final range = selectRendered(paragraph, paragraph.renderedText);
      final result = await extract(range);
      final stored = result.unwrap();
      expect(stored.markdown, contains('café-table'));
      expect(stored.provenance.startAnchor, range.startAnchor);
      expect(stored.provenance.endAnchor, range.endAnchor);
    });
  });

  group('the parent is untouched', () {
    test(
      'extracting changes neither the text nor the reading position',
      () async {
        final before = await harness.content.findSource(source.id);
        await extract(selectRendered(blockOf(BlockType.paragraph), 'capacity'));
        final after = await harness.content.findSource(source.id);

        expect(after!.markdown, before!.markdown);
        expect(after.contentHash, before.contentHash);
        expect(after.resume, before.resume);
      },
    );

    test('extracting does not advance the source schedule', () async {
      final ref = ElementRef(id: source.id, type: ElementType.source);
      final before = await harness.learning.findTopic(ref);
      await extract(selectRendered(blockOf(BlockType.paragraph), 'capacity'));
      final after = await harness.learning.findTopic(ref);

      // SM20 keeps the source's own repetition state untouched by an
      // extraction: same stored interval, same canonical due day. There is no
      // deferral field to check any more, because a postponement rewrites the
      // due date itself rather than shadowing it.
      expect(after!.storedInterval, before!.storedInterval);
      expect(after.repetitionCount, before.repetitionCount);
      expect(after.schedule.dueDay, before.schedule.dueDay);
    });

    test('the blocks the parent was parsed into are unchanged', () async {
      final before = document.blocks.map((Block b) => b.raw).toList();
      await extract(selectRendered(blockOf(BlockType.paragraph), 'capacity'));
      final after = (await harness.content.findDocument(
        source.id,
      ))!.blocks.map((Block b) => b.raw).toList();
      expect(after, before);
    });
  });

  group('the extract is independent', () {
    test('is memorized at interval one, due the next study day', () async {
      final created = (await extract(
        selectRendered(blockOf(BlockType.paragraph), 'capacity'),
      )).unwrap();
      final topic = await harness.learning.findTopic(
        ElementRef(id: created.id, type: ElementType.extract),
      );

      expect(topic!.schedule.dueDay.toString(), '2026-03-06');
      // SM20 has no per-element interval profile and no step ladder. Section
      // 6.2 memorizes the child at interval one, which both puts it on
      // tomorrow and counts as its first repetition.
      expect(topic.status, Sm20ElementStatus.memorized);
      expect(topic.storedInterval, 1);
      expect(topic.repetitionCount, 1);
    });

    test(
      'inherits the parent priority once, and does not track it after',
      () async {
        final sourceRef = ElementRef(id: source.id, type: ElementType.source);
        final raised = PriorityRank.above(PriorityRank.middle);
        await harness.priority.setRank(
          SetPriority(harness.nextOperation(), ref: sourceRef, rank: raised),
        );

        final created = (await extract(
          selectRendered(blockOf(BlockType.paragraph), 'capacity'),
        )).unwrap();
        final extractRef = ElementRef(
          id: created.id,
          type: ElementType.extract,
        );
        // Section 6.2 draws the child's priority target from a band around
        // the parent's own target rather than seating it next to the parent,
        // so the only structural claim available is that the child joined the
        // ranked population in its own right.
        final PriorityRank childRank = (await harness.learning.findSchedule(
          extractRef,
        ))!.priority;
        final List<ElementSchedule> ordered = await harness.learning
            .listSchedulesByPriority();
        expect(ordered.map((ElementSchedule s) => s.ref), contains(extractRef));

        // Re-ranking the parent afterwards must not cascade.
        final PriorityRank childBefore = childRank;
        await harness.priority.setRank(
          SetPriority(
            harness.nextOperation(),
            ref: sourceRef,
            rank: PriorityRank.below(PriorityRank.middle),
          ),
        );
        expect(
          (await harness.learning.findSchedule(extractRef))!.priority,
          childBefore,
          reason: 'a later parent move does not drag its descendants',
        );
      },
    );

    test(
      'records the parent, the root source, and the exact selection',
      () async {
        final paragraph = blockOf(BlockType.paragraph);
        final range = selectRendered(paragraph, 'seven items');
        final created = (await extract(range)).unwrap();

        expect(created.provenance.parentId, source.id);
        expect(created.provenance.hasSourceAsParent, isTrue);
        expect(created.provenance.sourceId, source.id);
        expect(created.provenance.startAnchor, range.startAnchor);
        expect(created.provenance.selectedTextHash, range.selectedTextHash);
        expect(document.isSameBlock(created.provenance.range), isTrue);
        expect(created.isVerbatim, isTrue);
      },
    );

    test('dismissing the parent leaves the extract scheduled', () async {
      final created = (await extract(
        selectRendered(blockOf(BlockType.paragraph), 'capacity'),
      )).unwrap();
      // SM20 has no Finish; Dismiss is what stops scheduling a parent, and
      // it must not touch descendants.
      await harness.reader.dismiss(
        DismissElement(
          harness.nextOperation(),
          ref: ElementRef(id: source.id, type: ElementType.source),
        ),
      );

      final topic = await harness.learning.findTopic(
        ElementRef(id: created.id, type: ElementType.extract),
      );
      expect(topic!.schedule.lifecycle, ElementLifecycle.active);
      expect(topic.schedule.dueDay.toString(), '2026-03-06');
    });

    test('editing refines the text without rescheduling', () async {
      final created = (await extract(
        selectRendered(blockOf(BlockType.paragraph), 'capacity'),
      )).unwrap();
      final ref = ElementRef(id: created.id, type: ElementType.extract);
      final before = await harness.learning.findTopic(ref);

      clock.advance(const Duration(hours: 2));
      final edited = await harness.extraction.editExtract(
        EditExtract(
          harness.nextOperation(),
          extractId: created.id,
          markdown: 'working memory capacity is about four items',
        ),
      );

      expect(
        edited.unwrap().markdown,
        'working memory capacity is about four items',
      );
      expect(edited.unwrap().isVerbatim, isFalse);
      final after = await harness.learning.findTopic(ref);
      expect(after!.schedule.dueDay, before!.schedule.dueDay);
      expect(after.storedInterval, before.storedInterval);
    });
  });

  group('overlapping extracts', () {
    test('two overlapping selections both exist independently', () async {
      final paragraph = blockOf(BlockType.paragraph);
      final wide = (await extract(
        selectRendered(paragraph, 'capacity of working memory is often quoted'),
      )).unwrap();
      final narrow = (await extract(
        selectRendered(paragraph, 'working memory'),
      )).unwrap();

      expect(wide.id, isNot(narrow.id));
      expect(wide.markdown, contains('working memory'));
      expect(narrow.markdown, 'working memory');

      final all = await harness.content.listExtractsOfParent(source.id);
      expect(all, hasLength(2));
      expect(all.map((Extract e) => e.id).toSet(), <String>{
        wide.id,
        narrow.id,
      });
    });

    test('identical selections made twice are two separate extracts', () async {
      final paragraph = blockOf(BlockType.paragraph);
      final first = (await extract(
        selectRendered(paragraph, 'capacity'),
      )).unwrap();
      final second = (await extract(
        selectRendered(paragraph, 'capacity'),
      )).unwrap();

      expect(first.id, isNot(second.id));
      expect(first.markdown, second.markdown);
      expect(first.provenance.startAnchor, second.provenance.startAnchor);
    });

    test('a retried operation id creates only one extract', () async {
      final range = selectRendered(blockOf(BlockType.paragraph), 'capacity');
      final operation = harness.nextOperation();

      final first = await harness.extraction.createExtract(
        CreateExtract(
          operation,
          parentId: source.id,
          hasSourceAsParent: true,
          range: range,
        ),
      );
      final retry = await harness.extraction.createExtract(
        CreateExtract(
          operation,
          parentId: source.id,
          hasSourceAsParent: true,
          range: range,
        ),
      );

      expect(first.isOk, isTrue);
      expect(retry.failureOrNull, isA<ConflictFailure>());
      expect(
        await harness.content.listExtractsOfParent(source.id),
        hasLength(1),
      );
    });
  });

  group('undo', () {
    test(
      'removes the extract and its schedule, leaving the parent alone',
      () async {
        final sourceRef = ElementRef(id: source.id, type: ElementType.source);
        final beforeTopic = await harness.learning.findTopic(sourceRef);

        final created = (await extract(
          selectRendered(blockOf(BlockType.paragraph), 'capacity'),
        )).unwrap();
        final undone = await harness.extraction.undoExtract(
          UndoExtract(harness.nextOperation(), extractId: created.id),
        );

        expect(undone.isOk, isTrue);
        expect(await harness.content.findExtract(created.id), isNull);
        expect(
          await harness.learning.findSchedule(
            ElementRef(id: created.id, type: ElementType.extract),
          ),
          isNull,
        );
        expect(await harness.content.listExtractsOfParent(source.id), isEmpty);

        final afterTopic = await harness.learning.findTopic(sourceRef);
        expect(afterTopic!.storedInterval, beforeTopic!.storedInterval);
        expect(afterTopic.schedule.dueDay, beforeTopic.schedule.dueDay);
        expect(
          (await harness.content.findSource(source.id))!.markdown,
          source.markdown,
        );
      },
    );

    test('leaves neighbouring extracts untouched', () async {
      final paragraph = blockOf(BlockType.paragraph);
      final keep = (await extract(
        selectRendered(paragraph, 'seven items'),
      )).unwrap();
      final drop = (await extract(
        selectRendered(paragraph, 'capacity'),
      )).unwrap();

      await harness.extraction.undoExtract(
        UndoExtract(harness.nextOperation(), extractId: drop.id),
      );

      final remaining = await harness.content.listExtractsOfParent(source.id);
      expect(remaining.map((Extract e) => e.id), <String>[keep.id]);
    });

    test('refuses an older extract after a newer action', () async {
      final paragraph = blockOf(BlockType.paragraph);
      final older = (await extract(
        selectRendered(paragraph, 'seven items'),
      )).unwrap();
      await extract(selectRendered(paragraph, 'capacity'));

      final result = await harness.extraction.undoExtract(
        UndoExtract(harness.nextOperation(), extractId: older.id),
      );

      expect(result.failureOrNull, isA<ConflictFailure>());
      expect(await harness.content.findExtract(older.id), isNotNull);
    });

    test('refuses once something has been built on the extract', () async {
      final created = (await extract(
        selectRendered(blockOf(BlockType.paragraph), 'capacity'),
      )).unwrap();
      await harness.extraction.createExtract(
        CreateExtract(
          harness.nextOperation(),
          parentId: created.id,
          hasSourceAsParent: false,
          range: SelectionRange.of(
            startAnchor: const ReaderAnchor(utf8Offset: 0),
            endAnchor: ReaderAnchor(utf8Offset: utf8Length(created.markdown)),
            markdown: created.markdown,
          ),
        ),
      );

      final undone = await harness.extraction.undoExtract(
        UndoExtract(harness.nextOperation(), extractId: created.id),
      );
      expect(undone.failureOrNull, isA<ConflictFailure>());
      expect(await harness.content.findExtract(created.id), isNotNull);
    });
  });

  group('verification', () {
    test(
      'a selection whose hash does not match the source is refused',
      () async {
        final paragraph = blockOf(BlockType.paragraph);
        final honest = selectRendered(paragraph, 'seven items');
        final tampered = SelectionRange(
          startAnchor: honest.startAnchor,
          endAnchor: honest.endAnchor,
          selectedTextHash: hashSelection('something else entirely'),
        );

        final result = await extract(tampered);
        expect(result.failureOrNull, isA<ConflictFailure>());
        expect(await harness.content.listExtractsOfParent(source.id), isEmpty);
      },
    );

    test('an empty selection is refused', () async {
      final block = blockOf(BlockType.paragraph);
      final anchor = anchorIn(block, 4);
      final result = await extract(
        SelectionRange.of(startAnchor: anchor, endAnchor: anchor, markdown: ''),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('an unknown parent is refused', () async {
      final result = await harness.extraction.createExtract(
        CreateExtract(
          harness.nextOperation(),
          parentId: 'ghost',
          hasSourceAsParent: true,
          range: selectRendered(blockOf(BlockType.paragraph), 'capacity'),
        ),
      );
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('recursive extraction', () {
    test('an extract of an extract keeps the root source', () async {
      final first = (await extract(
        selectRendered(
          blockOf(BlockType.paragraph),
          'capacity of working memory',
        ),
      )).unwrap();

      final inner = Document.parse(
        sourceId: first.id,
        markdown: first.markdown,
      );
      final innerBlock = inner.blocks.first;
      final start = innerBlock.renderedText.indexOf('working memory');
      final (int startUtf8, int endUtf8) = innerBlock.sourceRangeForRendered(
        start,
        start + 'working memory'.length,
      );
      final startAnchor = anchorIn(innerBlock, startUtf8);
      final endAnchor = anchorIn(innerBlock, endUtf8);

      final second = await harness.extraction.createExtract(
        CreateExtract(
          harness.nextOperation(),
          parentId: first.id,
          hasSourceAsParent: false,
          range: SelectionRange.of(
            startAnchor: startAnchor,
            endAnchor: endAnchor,
            markdown: inner.markdownBetween(startAnchor, endAnchor),
          ),
        ),
      );

      final created = second.unwrap();
      expect(created.markdown, 'working memory');
      expect(created.provenance.parentId, first.id);
      expect(created.provenance.hasSourceAsParent, isFalse);
      expect(
        created.provenance.sourceId,
        source.id,
        reason: 'the root source is denormalized down the whole chain',
      );

      final edit = await harness.extraction.editExtract(
        EditExtract(
          harness.nextOperation(),
          extractId: first.id,
          markdown: 'coordinates would now be stale',
        ),
      );
      expect(edit.failureOrNull, isA<ConflictFailure>());
      expect(
        (await harness.content.findExtract(first.id))!.markdown,
        first.markdown,
      );
    });
  });

  group('transaction boundary', () {
    test('a scheduling failure rolls back content and generation', () async {
      await harness.database.customStatement('''
        CREATE TRIGGER reject_extract_schedule
        BEFORE INSERT ON element_schedules
        WHEN NEW.element_type = 1
        BEGIN
          SELECT RAISE(ABORT, 'injected schedule failure');
        END
      ''');
      final generationBefore =
          (await harness.transfer.findDatasetIdentity()).generation;

      final result = await extract(
        selectRendered(blockOf(BlockType.paragraph), 'capacity'),
      );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(await harness.content.listExtractsOfParent(source.id), isEmpty);
      expect(
        (await harness.transfer.findDatasetIdentity()).generation,
        generationBefore,
      );
    });
  });

  group('activity log', () {
    test('records creation metadata without the extracted text', () async {
      await extract(selectRendered(blockOf(BlockType.paragraph), 'capacity'));
      final record = (await harness.learning.listRecentActivity()).firstWhere(
        (ActivityRecord r) => r.type == kExtractCreatedType,
      );

      expect(record.metadata!['parent'], source.id);
      expect(record.metadata!['same_block'], isTrue);
      expect(record.metadata.toString(), isNot(contains('capacity')));
    });

    test('uses the command timestamp for the durable event', () async {
      final timestamp = DateTime.utc(2026, 3, 4, 23, 59);
      await harness.extraction.createExtract(
        CreateExtract(
          harness.nextOperation(),
          parentId: source.id,
          hasSourceAsParent: true,
          range: selectRendered(blockOf(BlockType.paragraph), 'capacity'),
          timestampUtc: timestamp,
        ),
      );

      final record = (await harness.learning.listRecentActivity()).firstWhere(
        (ActivityRecord r) => r.type == kExtractCreatedType,
      );
      expect(record.atUtc, timestamp);
    });
  });
}
