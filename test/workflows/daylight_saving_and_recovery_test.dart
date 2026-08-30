/// Study days across a daylight-saving transition, and what happens when a
/// command fails part-way.
///
/// Both are gate items, and both are about the same property: a scheduling
/// decision must be a function of recorded state, so that a clock that jumps
/// or a write that fails leaves the collection describing what really
/// happened rather than what was half-attempted.
library;

import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/review/review_commands.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/review_log.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:test/test.dart';

import '../support/app_harness.dart';

const String _markdown = '''
# Chapter

A paragraph long enough to parse into one readable block.
''';

/// A zone that springs forward one hour at a fixed instant.
///
/// Standing in for a real timezone database keeps the transition exact and the
/// test independent of where the machine happens to be.
final class _SpringForwardZone implements TimeZoneRules {
  const _SpringForwardZone();

  /// 01:00 UTC on 29 March 2026, when much of Europe moves to summer time.
  static final DateTime transition = DateTime.utc(2026, 3, 29, 1);

  @override
  String get zoneId => 'Test/SpringForward';

  @override
  int offsetMinutesAt(DateTime instantUtc) =>
      instantUtc.isBefore(transition) ? 60 : 120;
}

void main() {
  group('daylight saving', () {
    late AppHarness harness;
    late FakeClock clock;

    setUp(() {
      // The evening before the transition, local time 22:00 (+01:00).
      clock = FakeClock(DateTime.utc(2026, 3, 28, 21));
      harness = AppHarness(clock: clock, zone: const _SpringForwardZone());
    });

    tearDown(() => harness.close());

    test('the study day is unchanged by the clocks going forward', () async {
      expect((await harness.today()).toString(), '2026-03-28');

      // 02:30 UTC on the 29th: 04:30 local *after* the jump, so the rollover
      // has passed and it is a new study day.
      clock.setTo(DateTime.utc(2026, 3, 29, 2, 30));
      expect((await harness.today()).toString(), '2026-03-29');

      // 01:30 UTC: 03:30 local, still before the 04:00 rollover.
      clock.setTo(DateTime.utc(2026, 3, 29, 1, 30));
      expect((await harness.today()).toString(), '2026-03-28');
    });

    test(
      'an interval scheduled across the transition lands on the right day',
      () async {
        final Source source = (await harness.reader.importSource(
          ImportSource(
            harness.operation(),
            title: 'Chapter',
            markdown: _markdown,
            timestampUtc: clock.nowUtc(),
          ),
        )).unwrap();
        final ElementRef ref = ElementRef(
          id: source.id,
          type: ElementType.source,
        );
        // Three days on, straight over the boundary.
        final Result<TopicState> done = await harness.reader.reschedule(
          RescheduleTopic(
            harness.operation(),
            ref: ref,
            intervalDays: 3,
            timestampUtc: clock.nowUtc(),
          ),
        );
        expect(done.isOk, isTrue, reason: '${done.failureOrNull}');
        // SM20 has no presentation overlay: a manual reschedule replaces the
        // canonical due date itself, so the stored schedule is the answer and
        // there is nothing to resolve on top of it.
        Future<StudyDay> canonicalDue() async =>
            (await harness.learning.findTopic(ref))!.schedule.algorithmicDueDay;
        expect((await canonicalDue()).toString(), '2026-03-31');

        final StudyDay due = await canonicalDue();

        // On the day itself, and not an hour early or late.
        clock.setTo(DateTime.utc(2026, 3, 31, 1, 30));
        expect(
          due <= await harness.today(),
          isFalse,
          reason: '03:30 local is still the previous study day',
        );
        clock.setTo(DateTime.utc(2026, 3, 31, 2, 30));
        expect(due <= await harness.today(), isTrue);
      },
    );

    test('day boundaries stay contiguous across the jump', () async {
      final StudyDayCalendar calendar = await harness.context.calendar();
      for (final String day in <String>[
        '2026-03-27',
        '2026-03-28',
        '2026-03-29',
        '2026-03-30',
      ]) {
        final StudyDay studyDay = StudyDay.parse(
          day,
          zoneId: 'Test/SpringForward',
        );
        final DateTime start = calendar.startOfDayUtc(studyDay);
        final DateTime end = calendar.endOfDayUtc(studyDay);

        expect(calendar.dayOf(start), studyDay, reason: day);
        expect(
          calendar.dayOf(end),
          studyDay.addDays(1),
          reason: 'the next day begins exactly where $day ends',
        );
        expect(
          calendar.contains(studyDay, end.subtract(const Duration(seconds: 1))),
          isTrue,
        );
      }
    });

    test(
      'a changed rollover takes effect without reopening anything',
      () async {
        expect((await harness.today()).toString(), '2026-03-28');

        // Move the rollover to 23:00 local: 22:00 local is now still the 27th.
        await harness.tuneSettings(
          (AppSettings s) =>
              s.copyWith(studyDay: s.studyDay.copyWith(rolloverMinutes: 1380)),
        );
        expect((await harness.today()).toString(), '2026-03-27');
      },
    );
  });

  group('failure recovery', () {
    late AppHarness harness;
    late FakeClock clock;

    setUp(() {
      clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
      harness = AppHarness(clock: clock);
    });

    tearDown(() => harness.close());

    Future<Source> importFixture() async => (await harness.reader.importSource(
      ImportSource(
        harness.operation(),
        title: 'Chapter',
        markdown: _markdown,
        timestampUtc: clock.nowUtc(),
      ),
    )).unwrap();

    test('a rejected command writes nothing at all', () async {
      final Source source = await importFixture();
      final ElementRef ref = ElementRef(
        id: source.id,
        type: ElementType.source,
      );
      final int logBefore = (await harness.learning.listReviewLogForElement(
        ref,
      )).length;

      final Result<TopicState> rejected = await harness.reader.reschedule(
        RescheduleTopic(
          harness.operation(),
          ref: ref,
          intervalDays: -5,
          timestampUtc: clock.nowUtc(),
        ),
      );

      expect(rejected.failureOrNull, isA<ValidationFailure>());
      expect(
        await harness.learning.listReviewLogForElement(ref),
        hasLength(logBefore),
      );
      expect(
        (await harness.learning.listRecentActivity()).where(
          (r) => r.type == 'topic.rescheduled',
        ),
        isEmpty,
      );
    });

    test('a command against a missing element fails without a trace', () async {
      final Result<TopicState> missing = await harness.reader.completeEncounter(
        CompleteTopicEncounter(
          harness.operation(),
          ref: const ElementRef(id: 'nope', type: ElementType.source),
          timestampUtc: clock.nowUtc(),
        ),
      );

      expect(missing.failureOrNull, isA<NotFoundFailure>());
      expect(
        await harness.learning.listRecentReviewLog(),
        isEmpty,
        reason: 'nothing happened, so nothing is recorded as having happened',
      );
    });

    test('a retried terminal command commits exactly once', () async {
      final Source source = await importFixture();
      final ElementRef ref = ElementRef(
        id: source.id,
        type: ElementType.source,
      );
      final CompleteTopicEncounter command = CompleteTopicEncounter(
        harness.operation(),
        ref: ref,
        timestampUtc: clock.nowUtc(),
      );

      final Result<TopicState> first = await harness.reader.completeEncounter(
        command,
      );
      expect(first.isOk, isTrue, reason: '${first.failureOrNull}');
      final StudyDay due = first.unwrap().schedule.dueDay;

      final Result<TopicState> retry = await harness.reader.completeEncounter(
        command,
      );
      // A retry returns the first attempt's result rather than an error: the
      // caller cannot know whether its first send reached the database, and
      // the guarantee it needs is that the work happened exactly once.
      expect(retry.isOk, isTrue, reason: '${retry.failureOrNull}');
      expect(retry.unwrap().schedule.dueDay, due);

      final TopicState after = (await harness.learning.findTopic(ref))!;
      expect(after.schedule.dueDay, due);
      expect(after.encounters, 1);
      expect(
        (await harness.learning.listReviewLogForElement(ref)).where(
          (ReviewLogEntry e) => e.eventType == ReviewLogEventType.topicRead,
        ),
        hasLength(1),
      );
    });

    test(
      'a failure is reported to diagnostics with its operation id',
      () async {
        final Result<CardState> undone = await harness.review.undoLastReview(
          UndoLastReview(harness.operation(), timestampUtc: clock.nowUtc()),
        );
        expect(undone.failureOrNull, isA<ConflictFailure>());

        // The conflict is an expected outcome rather than a crash, so the
        // command returns it instead of throwing — the log stays for the
        // unexpected ones.
        expect(
          harness.diagnostics.events.where(
            (e) => e.failure is UnexpectedFailure,
          ),
          isEmpty,
        );
      },
    );

    test(
      'an unexpected error is wrapped, logged, and does not escape',
      () async {
        final Source source = await importFixture();
        // Removing the pacing row leaves a schedule with no topic behind it,
        // which is the shape a partially-restored backup can have.
        await harness.database.customStatement(
          'DELETE FROM topic_states WHERE element_id = ?',
          <Object?>[source.id],
        );

        final Result<TopicState> result = await harness.reader
            .completeEncounter(
              CompleteTopicEncounter(
                harness.operation(),
                ref: ElementRef(id: source.id, type: ElementType.source),
                timestampUtc: clock.nowUtc(),
              ),
            );

        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isA<NotFoundFailure>());
      },
    );
  });
}
