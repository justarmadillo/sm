import 'dart:io';

import 'package:incremental_reader/src/application/ports/repositories.dart';
import 'package:incremental_reader/src/application/reader/reader_commands.dart';
import 'package:incremental_reader/src/application/reader/reader_handlers.dart';
import 'package:incremental_reader/src/core/clock.dart';
import 'package:incremental_reader/src/core/ids.dart';
import 'package:incremental_reader/src/core/result.dart';
import 'package:incremental_reader/src/core/tracing.dart';
import 'package:incremental_reader/src/data/database/app_database.dart';
import 'package:incremental_reader/src/data/database/connection.dart';
import 'package:incremental_reader/src/data/repositories/drift_repositories.dart';
import 'package:incremental_reader/src/domain/content/reader_anchor.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/interval_profile.dart';
import 'package:incremental_reader/src/domain/scheduling/priority_rank.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:test/test.dart';

const String _markdown = '''
# Chapter One

A first paragraph that the reader will stop in the middle of.

A second paragraph, further down the page.

A third paragraph, further still.
''';

/// Everything a handler needs, wired to a real database.
final class _Harness {
  _Harness(this.database, this.clock)
    : content = DriftContentRepository(database),
      learning = DriftLearningRepository(database),
      transfer = DriftTransferRepository(
        database,
        FakeIdGenerator(prefix: 'dataset'),
        'test-device',
      ),
      diagnostics = RecordingDiagnosticSink();

  final AppDatabase database;
  final FakeClock clock;
  final DriftContentRepository content;
  final DriftLearningRepository learning;
  final DriftTransferRepository transfer;
  final RecordingDiagnosticSink diagnostics;

  late final ReaderHandlers handlers = ReaderHandlers(
    content: content,
    learning: learning,
    transfer: transfer,
    transactions: DriftTransactionRunner(database),
    clock: clock,
    ids: FakeIdGenerator(),
    calendar: const StudyDayCalendar(zone: FixedOffsetZone.utc),
    profiles: IntervalProfiles.defaults(),
    diagnostics: diagnostics,
  );

  int _operations = 0;

  /// A fresh operation id, as a ViewModel would mint one per user action.
  OperationId nextOperation() => OperationId('op-${++_operations}');

  Future<Source> importFixture({String title = 'Chapter'}) async {
    final result = await handlers.importSource(
      ImportSource(nextOperation(), title: title, markdown: _markdown),
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.unwrap();
  }

  Future<TopicStateSnapshot> topicOf(String sourceId) async {
    final topic = await learning.findTopic(
      ElementRef(id: sourceId, type: ElementType.source),
    );
    return TopicStateSnapshot(
      dueDay: topic!.schedule.dueDay.toString(),
      effectiveDueDay: topic.schedule.effectiveDueDay.toString(),
      stepIndex: topic.stepIndex,
      lifecycle: topic.schedule.lifecycle,
      deferralKind: topic.schedule.deferralKind,
    );
  }
}

/// Flattened topic facts, so a test can assert "nothing changed" in one line.
final class TopicStateSnapshot {
  const TopicStateSnapshot({
    required this.dueDay,
    required this.effectiveDueDay,
    required this.stepIndex,
    required this.lifecycle,
    required this.deferralKind,
  });

  final String dueDay;
  final String effectiveDueDay;
  final int stepIndex;
  final ElementLifecycle lifecycle;
  final DeferralKind deferralKind;

  @override
  bool operator ==(Object other) =>
      other is TopicStateSnapshot &&
      other.dueDay == dueDay &&
      other.effectiveDueDay == effectiveDueDay &&
      other.stepIndex == stepIndex &&
      other.lifecycle == lifecycle &&
      other.deferralKind == deferralKind;

  @override
  int get hashCode =>
      Object.hash(dueDay, effectiveDueDay, stepIndex, lifecycle, deferralKind);

  @override
  String toString() =>
      'due=$dueDay effective=$effectiveDueDay '
      'step=$stepIndex ${lifecycle.name} ${deferralKind.name}';
}

void main() {
  late _Harness harness;
  late FakeClock clock;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = _Harness(openInMemoryDatabase(), clock);
  });

  tearDown(() => harness.database.close());

  group('import', () {
    test('creates a source, its blocks, and a schedule due today', () async {
      final source = await harness.importFixture(title: 'Chapter One');

      expect(source.title, 'Chapter One');
      expect(source.wordCount, greaterThan(20));

      final document = await harness.content.findDocument(source.id);
      expect(document!.blocks, hasLength(4));

      final snapshot = await harness.topicOf(source.id);
      expect(snapshot.dueDay, '2026-03-05');
      expect(snapshot.stepIndex, 0);
      expect(snapshot.lifecycle, ElementLifecycle.active);
    });

    test('new sources start at the middle priority', () async {
      final source = await harness.importFixture();
      final schedule = await harness.learning.findSchedule(
        ElementRef(id: source.id, type: ElementType.source),
      );
      expect(schedule!.priority, PriorityRank.middle);
    });

    test('rejects empty markdown and empty titles', () async {
      final blank = await harness.handlers.importSource(
        ImportSource(harness.nextOperation(), title: 'x', markdown: '   '),
      );
      expect(blank.failureOrNull, isA<ValidationFailure>());

      final untitled = await harness.handlers.importSource(
        ImportSource(harness.nextOperation(), title: '  ', markdown: '# hi'),
      );
      expect(untitled.failureOrNull, isA<ValidationFailure>());

      expect(await harness.content.listSources(), isEmpty);
    });

    test('records what was imported without recording the content', () async {
      await harness.importFixture();
      final activity = await harness.learning.recentActivity();
      final imported = activity.firstWhere(
        (ActivityRecord r) => r.kind == kSourceImportedKind,
      );
      expect(imported.metadata!['blocks'], 4);
      expect(imported.metadata.toString(), isNot(contains('paragraph')));
    });
  });

  group('reading position never touches the schedule', () {
    test('moving the marker leaves the schedule exactly as it was', () async {
      final source = await harness.importFixture();
      final before = await harness.topicOf(source.id);
      final document = await harness.content.findDocument(source.id);

      // Mid-paragraph, not at a block boundary.
      final anchor = ReaderAnchor(
        blockId: document!.blocks[1].id,
        utf8Offset: 21,
      );
      final result = await harness.handlers.moveResumeMarker(
        MoveResumeMarker(
          harness.nextOperation(),
          sourceId: source.id,
          anchor: anchor,
        ),
      );

      expect(result.unwrap().resume.marker, anchor);
      expect(await harness.topicOf(source.id), before);
    });

    test(
      'saving a soft position changes neither schedule nor marker',
      () async {
        final source = await harness.importFixture();
        final before = await harness.topicOf(source.id);
        final document = await harness.content.findDocument(source.id);

        await harness.handlers.saveSoftPosition(
          SaveSoftPosition(
            harness.nextOperation(),
            sourceId: source.id,
            anchor: ReaderAnchor(
              blockId: document!.blocks[2].id,
              utf8Offset: 0,
            ),
          ),
        );

        final stored = await harness.content.findSource(source.id);
        expect(stored!.resume.softPosition, isNotNull);
        expect(stored.resume.marker, isNull);
        expect(await harness.topicOf(source.id), before);
      },
    );

    test('a soft position is not an event worth logging', () async {
      final source = await harness.importFixture();
      final document = await harness.content.findDocument(source.id);
      final before = (await harness.learning.recentActivity()).length;

      for (var i = 0; i < 3; i++) {
        await harness.handlers.saveSoftPosition(
          SaveSoftPosition(
            harness.nextOperation(),
            sourceId: source.id,
            anchor: ReaderAnchor(
              blockId: document!.blocks[i].id,
              utf8Offset: 0,
            ),
          ),
        );
      }
      expect((await harness.learning.recentActivity()).length, before);
    });

    test('confirming the soft position promotes it to the marker', () async {
      final source = await harness.importFixture();
      final document = await harness.content.findDocument(source.id);
      final anchor = ReaderAnchor(
        blockId: document!.blocks[2].id,
        utf8Offset: 4,
      );

      await harness.handlers.saveSoftPosition(
        SaveSoftPosition(
          harness.nextOperation(),
          sourceId: source.id,
          anchor: anchor,
        ),
      );
      final confirmed = await harness.handlers.confirmSoftPosition(
        ConfirmSoftPosition(harness.nextOperation(), sourceId: source.id),
      );

      expect(confirmed.unwrap().resume.marker, anchor);
      expect(confirmed.unwrap().resume.hasUnconfirmedPosition, isFalse);
    });

    test('an anchor from another source is rejected', () async {
      final source = await harness.importFixture();
      final result = await harness.handlers.moveResumeMarker(
        MoveResumeMarker(
          harness.nextOperation(),
          sourceId: source.id,
          anchor: const ReaderAnchor(blockId: 'other:0', utf8Offset: 0),
        ),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('Done', () {
    test('advances the schedule once and logs the encounter', () async {
      final source = await harness.importFixture();
      final ref = ElementRef(id: source.id, type: ElementType.source);

      final result = await harness.handlers.completeEncounter(
        CompleteTopicEncounter(
          harness.nextOperation(),
          ref: ref,
          foregroundMs: 90000,
        ),
      );

      expect(result.isOk, isTrue);
      final snapshot = await harness.topicOf(source.id);
      expect(snapshot.dueDay, '2026-03-06');
      expect(snapshot.stepIndex, 1);

      final logged = (await harness.learning.recentActivity()).firstWhere(
        (ActivityRecord r) => r.kind == 'topic.encounter_completed',
      );
      expect(logged.durationMs, 90000);
      expect(logged.metadata!['interval_days'], 1);
    });

    test('is exactly-once for a retried operation id', () async {
      final source = await harness.importFixture();
      final ref = ElementRef(id: source.id, type: ElementType.source);
      final operation = harness.nextOperation();

      final first = await harness.handlers.completeEncounter(
        CompleteTopicEncounter(operation, ref: ref),
      );
      final retry = await harness.handlers.completeEncounter(
        CompleteTopicEncounter(operation, ref: ref),
      );

      expect(first.isOk, isTrue);
      expect(retry.failureOrNull, isA<ConflictFailure>());

      final snapshot = await harness.topicOf(source.id);
      expect(snapshot.stepIndex, 1, reason: 'the retry must not advance again');
      expect(snapshot.dueDay, '2026-03-06');
      expect(
        (await harness.learning.recentActivity()).where(
          (ActivityRecord r) => r.kind == 'topic.encounter_completed',
        ),
        hasLength(1),
      );
    });

    test('a distinct operation advances again', () async {
      final source = await harness.importFixture();
      final ref = ElementRef(id: source.id, type: ElementType.source);

      await harness.handlers.completeEncounter(
        CompleteTopicEncounter(harness.nextOperation(), ref: ref),
      );
      clock.advance(const Duration(days: 1));
      await harness.handlers.completeEncounter(
        CompleteTopicEncounter(harness.nextOperation(), ref: ref),
      );

      final snapshot = await harness.topicOf(source.id);
      expect(snapshot.stepIndex, 2);
      expect(snapshot.dueDay, '2026-03-09');
    });

    test('advances the dataset generation', () async {
      final source = await harness.importFixture();
      final before = (await harness.transfer.currentIdentity()).generation;
      await harness.handlers.completeEncounter(
        CompleteTopicEncounter(
          harness.nextOperation(),
          ref: ElementRef(id: source.id, type: ElementType.source),
        ),
      );
      expect(
        (await harness.transfer.currentIdentity()).generation,
        greaterThan(before),
      );
    });
  });

  group('Later', () {
    test('moves eligibility without advancing the sequence', () async {
      final source = await harness.importFixture();
      final ref = ElementRef(id: source.id, type: ElementType.source);

      await harness.handlers.postpone(
        PostponeElement(
          harness.nextOperation(),
          ref: ref,
          until: StudyDay.parse('2026-03-08', zoneId: 'UTC'),
        ),
      );

      final snapshot = await harness.topicOf(source.id);
      expect(snapshot.stepIndex, 0);
      expect(snapshot.dueDay, '2026-03-05');
      expect(snapshot.effectiveDueDay, '2026-03-08');
      expect(snapshot.deferralKind, DeferralKind.manual);
    });

    test('a postponed source drops out of today and returns later', () async {
      final source = await harness.importFixture();
      await harness.handlers.postpone(
        PostponeElement(
          harness.nextOperation(),
          ref: ElementRef(id: source.id, type: ElementType.source),
          until: StudyDay.parse('2026-03-08', zoneId: 'UTC'),
        ),
      );

      Future<int> eligibleOn(String day) async =>
          (await harness.learning.listEligible(
            day: StudyDay.parse(day, zoneId: 'UTC'),
            types: <ElementType>{ElementType.source},
          )).length;

      expect(await eligibleOn('2026-03-05'), 0);
      expect(await eligibleOn('2026-03-07'), 0);
      expect(await eligibleOn('2026-03-08'), 1);
    });
  });

  group('lifecycle', () {
    test(
      'Finish removes a source from the queue but keeps its content',
      () async {
        final source = await harness.importFixture();
        await harness.handlers.finishSource(
          FinishSource(harness.nextOperation(), sourceId: source.id),
        );

        expect(
          (await harness.topicOf(source.id)).lifecycle,
          ElementLifecycle.finished,
        );
        expect(
          await harness.learning.listEligible(
            day: StudyDay.parse('2026-03-05', zoneId: 'UTC'),
            types: <ElementType>{ElementType.source},
          ),
          isEmpty,
        );
        expect(await harness.content.findSource(source.id), isNotNull);
      },
    );

    test(
      'reactivating a finished source makes it due today at its step',
      () async {
        final source = await harness.importFixture();
        final ref = ElementRef(id: source.id, type: ElementType.source);
        await harness.handlers.completeEncounter(
          CompleteTopicEncounter(harness.nextOperation(), ref: ref),
        );
        await harness.handlers.finishSource(
          FinishSource(harness.nextOperation(), sourceId: source.id),
        );

        clock.advance(const Duration(days: 10));
        await harness.handlers.reactivate(
          ReactivateElement(harness.nextOperation(), ref: ref),
        );

        final snapshot = await harness.topicOf(source.id);
        expect(snapshot.lifecycle, ElementLifecycle.active);
        expect(snapshot.dueDay, '2026-03-15');
        expect(snapshot.stepIndex, 1, reason: 'a pause is not a reset');
      },
    );

    test('changing pace keeps the position and the interval step', () async {
      final source = await harness.importFixture();
      final ref = ElementRef(id: source.id, type: ElementType.source);
      await harness.handlers.completeEncounter(
        CompleteTopicEncounter(harness.nextOperation(), ref: ref),
      );

      await harness.handlers.setReadingPace(
        SetReadingPace(
          harness.nextOperation(),
          sourceId: source.id,
          pace: ReadingPace.slow,
        ),
      );

      final topic = await harness.learning.findTopic(ref);
      expect(topic!.profileId, 'slow');
      expect(topic.stepIndex, 1);
      expect(
        (await harness.content.findSource(source.id))!.pace,
        ReadingPace.slow,
      );
    });

    test(
      'deleting a source retains content and independent descendants',
      () async {
        final source = await harness.importFixture();
        await harness.handlers.deleteSource(
          DeleteSource(harness.nextOperation(), sourceId: source.id),
        );

        expect(await harness.content.findSource(source.id), isNotNull);
        expect(await harness.content.findDocument(source.id), isNotNull);
        final topic = await harness.learning.findTopic(
          ElementRef(id: source.id, type: ElementType.source),
        );
        expect(topic!.schedule.lifecycle, ElementLifecycle.deleted);
      },
    );
  });

  group('restart', () {
    late Directory workspace;

    setUp(() {
      workspace = Directory.systemTemp.createTempSync('ir_restart_');
    });

    tearDown(() {
      // A test that deliberately never closes a connection leaves the file
      // locked on Windows; the temp directory is disposable either way.
      try {
        if (workspace.existsSync()) workspace.deleteSync(recursive: true);
      } on FileSystemException {
        // Nothing to do: the OS reclaims it.
      }
    });

    _Harness openHarness() => _Harness(
      openDatabaseAt(File('${workspace.path}/db/$kDatabaseFileName')),
      FakeClock(DateTime.utc(2026, 3, 5, 10)),
    );

    test('resumes mid-paragraph after a full restart', () async {
      final first = openHarness();
      final source = await first.importFixture();
      final document = await first.content.findDocument(source.id);
      final anchor = ReaderAnchor(
        blockId: document!.blocks[1].id,
        utf8Offset: 21,
      );
      await first.handlers.moveResumeMarker(
        MoveResumeMarker(
          first.nextOperation(),
          sourceId: source.id,
          anchor: anchor,
        ),
      );
      final beforeSchedule = await first.topicOf(source.id);
      await first.database.close();

      final second = openHarness();
      addTearDown(second.database.close);
      final reopened = await second.content.findSource(source.id);
      final reopenedDocument = await second.content.findDocument(source.id);

      expect(reopened!.resume.marker, anchor);
      expect(await second.topicOf(source.id), beforeSchedule);
      // The marker still lands on the same character it was placed on,
      // mid-word rather than at a block boundary.
      expect(
        reopenedDocument!.blockById(anchor.blockId)!.rawSlice(21, 27),
        't the ',
      );
    });

    test(
      'a session killed without a marker reopens at the soft position',
      () async {
        final first = openHarness();
        final source = await first.importFixture();
        final document = await first.content.findDocument(source.id);
        final soft = ReaderAnchor(
          blockId: document!.blocks[2].id,
          utf8Offset: 0,
        );
        await first.handlers.saveSoftPosition(
          SaveSoftPosition(
            first.nextOperation(),
            sourceId: source.id,
            anchor: soft,
          ),
        );
        // Deliberately not closed: the process is gone, and whatever was
        // written must already be durable in the file.
        addTearDown(first.database.close);

        final second = openHarness();
        addTearDown(second.database.close);
        final reopened = await second.content.findSource(source.id);

        expect(reopened!.resume.marker, isNull);
        expect(reopened.resume.softPosition, soft);
        expect(reopened.resume.openAt, soft);
        expect(reopened.resume.hasUnconfirmedPosition, isTrue);
        expect(
          (await second.topicOf(source.id)).dueDay,
          '2026-03-05',
          reason: 'being interrupted is not progress',
        );
      },
    );
  });
}
