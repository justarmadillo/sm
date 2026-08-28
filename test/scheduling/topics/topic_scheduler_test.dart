/// The SM20 topic/extract scheduler.
///
/// The expectations here are the deterministic vectors of section 16, taken
/// from the specification rather than from this implementation's own output,
/// so a rewrite that changes an answer fails instead of re-baselining itself.
/// Items 3, 4, 5 and 6 of that suite live here; the Real48, PRNG and
/// dispersion primitives they rest on are covered by `sm20_numeric_test`.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:test/test.dart';

/// A source topic carrying [interval] and a raw A of [aFactor].
TopicState _topic({
  required int interval,
  required double aFactor,
  Sm20ElementStatus status = Sm20ElementStatus.memorized,
  int repetitions = 1,
  StudyDay? lastReview,
}) {
  final StudyDay today = StudyDay.parse('2026-03-05', zoneId: 'UTC');
  const ElementRef ref = ElementRef(id: 'topic-1', type: ElementType.source);
  return TopicState(
    schedule: ElementSchedule(
      ref: ref,
      priority: PriorityRank.middle,
      dueDay: today,
      originalDueDay: today,
      lifecycle: ElementLifecycle.active,
    ),
    status: status,
    repetitionCount: repetitions,
    lapseCount: 0,
    storedInterval: interval,
    lastReviewDay: lastReview ?? today.addDays(-interval),
    aFactorRaw: DelphiReal48.fromDouble(aFactor),
    lastIntervalRatioRaw: DelphiReal48.fromDouble(1),
  );
}

void main() {
  group('next automatic interval (section 5.2)', () {
    // Every vector is stated for a fresh seed-zero stream, before any Real48
    // state change, exactly as section 5.2 lists them.
    const List<(double, int, int)> vectors = <(double, int, int)>[
      (2.0, 0, 8),
      (2.0, 1, 2),
      (2.0, 10, 20),
      (3.0, 100, 300),
      // A above the scheduling clamp still schedules as though it were 3.0.
      (6.0, 100, 300),
      (1.01, 100, 101),
    ];

    for (final (double a, int interval, int expected) in vectors) {
      test('A=$a, I=$interval yields $expected', () {
        final TopicScheduler scheduler = TopicScheduler(
          prng: Sm20Prng(seed: 0),
        );
        expect(
          scheduler.nextAutomaticInterval(
            _topic(interval: interval, aFactor: a),
          ),
          expected,
        );
      });
    }

    test('consumes exactly two draws from the shared stream', () {
      final Sm20Prng prng = Sm20Prng(seed: 0);
      final TopicScheduler scheduler = TopicScheduler(prng: prng);
      scheduler.nextAutomaticInterval(_topic(interval: 10, aFactor: 2));

      final Sm20Prng reference = Sm20Prng(seed: 0)
        ..advance()
        ..advance();
      expect(
        prng.state.seed,
        reference.state.seed,
        reason: 'one interval is two draws, no more and no fewer',
      );
    });

    test('never returns an interval that fails to grow', () {
      // The dispersion can land on or below the old interval; the scheduler
      // has to push it past, or a topic would stall on the same day forever.
      for (var seed = 0; seed < 40; seed += 1) {
        final TopicScheduler scheduler = TopicScheduler(
          prng: Sm20Prng(seed: seed),
        );
        expect(
          scheduler.nextAutomaticInterval(_topic(interval: 10, aFactor: 1.01)),
          greaterThan(10),
        );
      }
    });
  });

  group('A adaptation (section 16 item 4)', () {
    test('reproduces the three Real48 byte vectors', () {
      final DelphiReal48 two = DelphiReal48.fromDouble(2);
      expect(
        TopicScheduler.adjustAFactorRaw(two, 10, 20, isBulkOperation: false).bytes,
        _hex('82db0d417407'),
        reason: 'a grown interval raises A',
      );
      expect(
        TopicScheduler.adjustAFactorRaw(two, 20, 10, isBulkOperation: false).bytes,
        _hex('814be47d1771'),
        reason: 'a shrunk interval lowers A',
      );
      expect(
        TopicScheduler.adjustAFactorRaw(two, 10, 20, isBulkOperation: true).bytes,
        _hex('82ba189d8b01'),
        reason: 'a bulk repetition moves A far less',
      );
    });

    test('an unchanged interval leaves the stored bytes alone', () {
      final DelphiReal48 a = DelphiReal48.fromDouble(2);
      expect(
        TopicScheduler.adjustAFactorRaw(a, 10, 10, isBulkOperation: false).bytes,
        a.bytes,
      );
    });
  });

  group('blank-topic A and the text-length override (item 5)', () {
    test('a new topic stores the blank-topic bytes', () {
      final StudyDay today = StudyDay.parse('2026-03-05', zoneId: 'UTC');
      final TopicScheduler scheduler = TopicScheduler(prng: Sm20Prng(seed: 0));
      const ElementRef ref = ElementRef(id: 'new', type: ElementType.source);
      final TopicState created = scheduler.createFor(
        ref: ref,
        today: today,
        buildSchedule: (StudyDay due) => ElementSchedule(
          ref: ref,
          priority: PriorityRank.middle,
          dueDay: due,
          originalDueDay: due,
          lifecycle: ElementLifecycle.active,
        ),
      );
      expect(created.aFactorRaw.bytes, _hex('819a99999919'));
      expect(created.aFactor, closeTo(1.2, 1e-9));
      expect(created.status, Sm20ElementStatus.pending);
    });

    test('the override maps text length to A', () {
      expect(TopicScheduler.textLengthAFactor(0), 2.0);
      expect(TopicScheduler.textLengthAFactor(200), closeTo(1.625, 1e-9));
      expect(TopicScheduler.textLengthAFactor(1000), closeTo(1.375, 1e-9));
    });

    test('the override is monotone: longer text means a lower A', () {
      var previous = TopicScheduler.textLengthAFactor(1);
      for (final int length in <int>[50, 200, 500, 1000, 5000]) {
        final double current = TopicScheduler.textLengthAFactor(length);
        expect(current, lessThan(previous));
        previous = current;
      }
    });

    test('rejects a negative length rather than inventing an A', () {
      expect(() => TopicScheduler.textLengthAFactor(-1), throwsRangeError);
    });
  });

  group('Modify A', () {
    test('scales the distance above the A floor, not A itself', () {
      // Section 6.4: the multiplier applies to (A - 1.01), the floor being
      // the same minimum section 5.2 clamps to. A multiplier of one is
      // therefore identity, and no multiplier reaches the floor from above.
      final DelphiReal48 a = DelphiReal48.fromDouble(2);
      expect(TopicScheduler.modifyAFactorRaw(a, 1).value, closeTo(2, 1e-9));
      expect(
        TopicScheduler.modifyAFactorRaw(a, 0.5).value,
        closeTo(1.01 + 0.5 * (2 - 1.01), 1e-6),
      );
      expect(
        TopicScheduler.modifyAFactorRaw(a, 2).value,
        closeTo(1.01 + 2 * (2 - 1.01), 1e-6),
      );
    });
  });
}

List<int> _hex(String value) => <int>[
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
];
