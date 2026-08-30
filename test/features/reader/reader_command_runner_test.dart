import 'dart:io';

import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/reader/reader_command_runner.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/scheduling/daily_queue/queue_policy.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:test/test.dart';

import '../../support/anchors.dart';
import '../../support/app_harness.dart';

const String _markdown = '''
# Chapter One

A first paragraph that the reader will stop in the middle of.

A second paragraph, further down the page.

A third paragraph, further still.
''';

/// This suite's fixtures, over the shared stack.
extension _Fixtures on AppHarness {
  OperationId nextOperation() => operation();

  Future<Source> importFixture({String title = 'Chapter'}) async {
    final result = await reader.importSource(
      ImportSource(nextOperation(), title: title, markdown: _markdown),
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.unwrap();
  }

  Future<TopicStateSnapshot> topicOf(String sourceId) async {
    final ElementRef ref = ElementRef(id: sourceId, type: ElementType.source);
    final topic = await learning.findTopic(ref);
    // There is no overlay to resolve any more: SM20 rewrites the canonical
    // due date, so the stored schedule is the whole answer.
    return TopicStateSnapshot(
      dueDay: topic!.schedule.algorithmicDueDay.toString(),
      storedInterval: topic.storedInterval,
      repetitionCountOrZero: topic.repetitionCount,
      status: topic.status,
      lifecycle: topic.schedule.lifecycle,
    );
  }

  /// Whether [ref] may be presented on [day], through the one eligibility
  /// path the queue itself uses.
  Future<bool> isEligibleOn(ElementRef ref, String day) async {
    final StudyDay studyDay = StudyDay.parse(day, zoneId: 'UTC');
    for (final QueueCandidate candidate in await queue.loadCandidates(
      studyDay,
    )) {
      if (candidate.ref != ref) continue;
      return candidate.isDue(
        nowUtc: DateTime.utc(studyDay.year, studyDay.month, studyDay.day, 23),
        today: studyDay,
      );
    }
    return false;
  }
}

/// Flattened topic facts, so a test can assert "nothing changed" in one line.
final class TopicStateSnapshot {
  const TopicStateSnapshot({
    required this.dueDay,
    required this.storedInterval,
    required this.repetitionCountOrZero,
    required this.status,
    required this.lifecycle,
  });

  final String dueDay;
  final int storedInterval;
  final int repetitionCountOrZero;
  final Sm20ElementStatus status;
  final ElementLifecycle lifecycle;

  @override
  bool operator ==(Object other) =>
      other is TopicStateSnapshot &&
      other.dueDay == dueDay &&
      other.storedInterval == storedInterval &&
      other.repetitionCountOrZero == repetitionCountOrZero &&
      other.status == status &&
      other.lifecycle == lifecycle;

  @override
  int get hashCode => Object.hash(
    dueDay,
    storedInterval,
    repetitionCountOrZero,
    status,
    lifecycle,
  );

  @override
  String toString() =>
      'due=$dueDay interval=$storedInterval reps=$repetitionCountOrZero '
      '${status.name} ${lifecycle.name}';
}

void main() {
  late AppHarness harness;
  late FakeClock clock;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(database: openInMemoryDatabase(), clock: clock);
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
      // A freshly imported source is Pending with no interval yet.
      expect(snapshot.storedInterval, 0);
      expect(snapshot.status, Sm20ElementStatus.pending);
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
      final blank = await harness.reader.importSource(
        ImportSource(harness.nextOperation(), title: 'x', markdown: '   '),
      );
      expect(blank.failureOrNull, isA<ValidationFailure>());

      final untitled = await harness.reader.importSource(
        ImportSource(harness.nextOperation(), title: '  ', markdown: '# hi'),
      );
      expect(untitled.failureOrNull, isA<ValidationFailure>());

      expect(await harness.content.listSources(), isEmpty);
    });

    test('records what was imported without recording the content', () async {
      await harness.importFixture();
      final activity = await harness.learning.listRecentActivity();
      final imported = activity.firstWhere(
        (ActivityRecord r) => r.type == kSourceImportedType,
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
      final anchor = anchorIn(document!.blocks[1], 21);
      final result = await harness.reader.moveResumeMarker(
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

        await harness.reader.saveSoftPosition(
          SaveSoftPosition(
            harness.nextOperation(),
            sourceId: source.id,
            anchor: anchorIn(document!.blocks[2], 0),
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
      final before = (await harness.learning.listRecentActivity()).length;

      for (var i = 0; i < 3; i++) {
        await harness.reader.saveSoftPosition(
          SaveSoftPosition(
            harness.nextOperation(),
            sourceId: source.id,
            anchor: anchorIn(document!.blocks[i], 0),
          ),
        );
      }
      expect((await harness.learning.listRecentActivity()).length, before);
    });

    test('confirming the soft position promotes it to the marker', () async {
      final source = await harness.importFixture();
      final document = await harness.content.findDocument(source.id);
      final anchor = anchorIn(document!.blocks[2], 4);

      await harness.reader.saveSoftPosition(
        SaveSoftPosition(
          harness.nextOperation(),
          sourceId: source.id,
          anchor: anchor,
        ),
      );
      final confirmed = await harness.reader.confirmSoftPosition(
        ConfirmSoftPosition(harness.nextOperation(), sourceId: source.id),
      );

      expect(confirmed.unwrap().resume.marker, anchor);
      expect(confirmed.unwrap().resume.hasUnconfirmedPosition, isFalse);
    });

    test('an anchor from another source is rejected', () async {
      final source = await harness.importFixture();
      final result = await harness.reader.moveResumeMarker(
        MoveResumeMarker(
          harness.nextOperation(),
          sourceId: source.id,
          anchor: const ReaderAnchor(utf8Offset: 1 << 30),
        ),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('Done', () {
    test('advances the schedule once and logs the encounter', () async {
      final source = await harness.importFixture();
      final ref = ElementRef(id: source.id, type: ElementType.source);

      final result = await harness.reader.completeEncounter(
        CompleteTopicEncounter(
          harness.nextOperation(),
          ref: ref,
          foregroundMs: 90000,
        ),
      );

      expect(result.isOk, isTrue);
      final snapshot = await harness.topicOf(source.id);
      expect(snapshot.dueDay, '2026-03-06');
      // The first repetition memorizes the topic and stores the interval it
      // chose, which is what puts the due day one day out.
      expect(snapshot.status, Sm20ElementStatus.memorized);
      expect(snapshot.storedInterval, 1);

      final logged = (await harness.learning.listRecentActivity()).firstWhere(
        (ActivityRecord r) => r.type == 'topic.encounter_completed',
      );
      expect(logged.durationMs, 90000);
      // SM20 records what the repetition actually decided: the interval it
      // came from, the one it selected, and the A on both sides.
      expect(logged.metadata!['stored_interval'], 1);
      expect(logged.metadata!['old_interval'], 0);
      expect(logged.metadata!['next_due'], '2026-03-06');
    });

    test('is exactly-once for a retried operation id', () async {
      final source = await harness.importFixture();
      final ref = ElementRef(id: source.id, type: ElementType.source);
      final operation = harness.nextOperation();

      final first = await harness.reader.completeEncounter(
        CompleteTopicEncounter(operation, ref: ref),
      );
      final retry = await harness.reader.completeEncounter(
        CompleteTopicEncounter(operation, ref: ref),
      );

      expect(first.isOk, isTrue);
      // A repeated operation id returns the result the first attempt produced
      // rather than an error: a retried command is the same command, and the
      // caller cannot tell whether its first attempt reached the database.
      expect(retry.isOk, isTrue, reason: '${retry.failureOrNull}');
      expect(retry.unwrap().schedule.dueDay, first.unwrap().schedule.dueDay);

      final snapshot = await harness.topicOf(source.id);
      expect(
        snapshot.repetitionCountOrZero,
        1,
        reason: 'the retry must not advance again',
      );
      expect(snapshot.dueDay, first.unwrap().schedule.dueDay.toString());
      expect(
        (await harness.learning.listRecentActivity()).where(
          (ActivityRecord r) => r.type == 'topic.encounter_completed',
        ),
        hasLength(1),
      );
    });

    test('a distinct operation advances again', () async {
      final source = await harness.importFixture();
      final ref = ElementRef(id: source.id, type: ElementType.source);

      await harness.reader.completeEncounter(
        CompleteTopicEncounter(harness.nextOperation(), ref: ref),
      );
      clock.advance(const Duration(days: 1));
      await harness.reader.completeEncounter(
        CompleteTopicEncounter(harness.nextOperation(), ref: ref),
      );

      final snapshot = await harness.topicOf(source.id);
      expect(snapshot.repetitionCountOrZero, 2);
      expect(snapshot.dueDay, '2026-03-08');
    });

    test('advances the dataset generation', () async {
      final source = await harness.importFixture();
      final before = (await harness.transfer.findDatasetIdentity()).generation;
      await harness.reader.completeEncounter(
        CompleteTopicEncounter(
          harness.nextOperation(),
          ref: ElementRef(id: source.id, type: ElementType.source),
        ),
      );
      expect(
        (await harness.transfer.findDatasetIdentity()).generation,
        greaterThan(before),
      );
    });
  });

  group('Later', () {
    test('rewrites the canonical due without advancing the sequence', () async {
      final source = await harness.importFixture();
      final ref = ElementRef(id: source.id, type: ElementType.source);

      await harness.reader.postpone(
        PostponeElement(
          harness.nextOperation(),
          ref: ref,
          until: StudyDay.parse('2026-03-08', zoneId: 'UTC'),
        ),
      );

      final snapshot = await harness.topicOf(source.id);
      // SM20 has no deferral overlay. Later is the section 8.1 low-level
      // reschedule, so it moves the canonical due date itself — and that is
      // the point: there is no second, shadow due date to disagree with it.
      expect(snapshot.dueDay, '2026-03-08');
      // What it must not do is count as a repetition.
      expect(
        snapshot.status,
        Sm20ElementStatus.memorized,
        reason: 'a nonmemorized element is admitted by the reschedule',
      );
      final TopicState topic = (await harness.learning.findTopic(
        ElementRef(id: source.id, type: ElementType.source),
      ))!;
      expect(
        topic.aFactor,
        closeTo(1.2, 1e-9),
        reason: 'a low-level reschedule never touches A',
      );
    });

    test('a postponed source drops out of today and returns later', () async {
      final source = await harness.importFixture();
      await harness.reader.postpone(
        PostponeElement(
          harness.nextOperation(),
          ref: ElementRef(id: source.id, type: ElementType.source),
          until: StudyDay.parse('2026-03-08', zoneId: 'UTC'),
        ),
      );

      final ElementRef ref = ElementRef(
        id: source.id,
        type: ElementType.source,
      );
      expect(await harness.isEligibleOn(ref, '2026-03-05'), isFalse);
      expect(await harness.isEligibleOn(ref, '2026-03-07'), isFalse);
      expect(await harness.isEligibleOn(ref, '2026-03-08'), isTrue);
    });
  });

  group('lifecycle', () {
    test(
      'Dismiss removes a source from the queue but keeps its content',
      () async {
        // SM20 knows pending, memorized, dismissed and deleted. There is no
        // Finish: stopping a source while keeping it is exactly Dismiss.
        final source = await harness.importFixture();
        await harness.reader.dismiss(
          DismissElement(
            harness.nextOperation(),
            ref: ElementRef(id: source.id, type: ElementType.source),
          ),
        );

        expect(
          (await harness.topicOf(source.id)).lifecycle,
          ElementLifecycle.dismissed,
        );
        expect(
          await harness.isEligibleOn(
            ElementRef(id: source.id, type: ElementType.source),
            '2026-03-05',
          ),
          isFalse,
        );
        expect(await harness.content.findSource(source.id), isNotNull);
      },
    );

    test('Undismiss restores only the status byte, not the schedule', () async {
      final source = await harness.importFixture();
      final ref = ElementRef(id: source.id, type: ElementType.source);
      await harness.reader.completeEncounter(
        CompleteTopicEncounter(harness.nextOperation(), ref: ref),
      );
      await harness.reader.dismiss(
        DismissElement(harness.nextOperation(), ref: ref),
      );

      clock.advance(const Duration(days: 10));
      await harness.reader.undismiss(
        UndismissSource(harness.nextOperation(), ref: ref),
      );

      final snapshot = await harness.topicOf(source.id);
      expect(snapshot.lifecycle, ElementLifecycle.active);
      // Section 9.7: Undismiss changes the status byte and nothing else. It
      // deliberately does not put back the interval, the repetition count,
      // or the priority that Dismiss cleared, so the element returns as
      // Pending rather than resuming where it left off.
      expect(snapshot.status, Sm20ElementStatus.pending);
      expect(snapshot.storedInterval, 0);
    });

    test(
      'deleting a source retains content and independent descendants',
      () async {
        final source = await harness.importFixture();
        await harness.reader.deleteSource(
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

    Future<AppHarness> openHarness() async {
      final AppHarness opened = AppHarness(
        database: openDatabaseAt(
          File('${workspace.path}/db/$kDatabaseFileName'),
        ),
        clock: FakeClock(DateTime.utc(2026, 3, 5, 10)),
      );
      return opened;
    }

    test('resumes mid-paragraph after a full restart', () async {
      final first = await openHarness();
      final source = await first.importFixture();
      final document = await first.content.findDocument(source.id);
      final anchor = anchorIn(document!.blocks[1], 21);
      await first.reader.moveResumeMarker(
        MoveResumeMarker(
          first.nextOperation(),
          sourceId: source.id,
          anchor: anchor,
        ),
      );
      final beforeSchedule = await first.topicOf(source.id);
      await first.database.close();

      final second = await openHarness();
      addTearDown(second.database.close);
      final reopened = await second.content.findSource(source.id);
      final reopenedDocument = await second.content.findDocument(source.id);

      expect(reopened!.resume.marker, anchor);
      expect(await second.topicOf(source.id), beforeSchedule);
      // The marker still lands on the same character it was placed on,
      // mid-word rather than at a block boundary.
      expect(
        reopenedDocument!.blockForAnchor(anchor)!.rawSlice(21, 27),
        't the ',
      );
    });

    test(
      'a session killed without a marker reopens at the soft position',
      () async {
        final first = await openHarness();
        final source = await first.importFixture();
        final document = await first.content.findDocument(source.id);
        final soft = anchorIn(document!.blocks[2], 0);
        await first.reader.saveSoftPosition(
          SaveSoftPosition(
            first.nextOperation(),
            sourceId: source.id,
            anchor: soft,
          ),
        );
        // Deliberately not closed: the process is gone, and whatever was
        // written must already be durable in the file.
        addTearDown(first.database.close);

        final second = await openHarness();
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
