import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/mercy/mercy.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/settings/mercy_settings.dart';
import 'package:test/test.dart';

void main() {
  group('Mercy matrix and score', () {
    test('requires the live 20 by 20 UInt16 matrix', () {
      expect(
        () => Sm20MercyMatrix(List<int>.filled(399, 1000)),
        throwsArgumentError,
      );
      expect(
        () => Sm20MercyMatrix(<int>[...List<int>.filled(399, 1000), 0x10000]),
        throwsRangeError,
      );
      final Sm20MercyMatrix matrix = _matrix();
      expect(matrix.valueAt(0, 0), 2000);
      expect(matrix.valueAt(6, 1), 1500);
      expect(matrix.valueAt(6, 2), 1250);
    });

    test('uses matrix row 6, fixed FI 3, and exact five-part score', () {
      final Sm20MercyCandidate candidate = _candidate(
        'scored',
        rank: 'B',
        scheduled: 100,
        lastReview: 90,
        repetitions: 3,
        lapses: 2,
      );
      final Sm20MercyScore score = const Sm20MercyEngine().scoreCandidate(
        candidate,
        today: _day(100),
        reschedulingDays: 5,
        matrix: _matrix(),
        weights: const Sm20MercyWeights(),
        priorityPercent: 25,
      );

      expect(score.investmentBase, 3.75);
      expect(score.recency, closeTo(0.7357142857142858, 1e-15));
      expect(score.investment, closeTo(0.2546439628482972, 1e-15));
      expect(score.importance, 0.75);
      expect(score.lateness, closeTo(0.4554112554112555, 1e-15));
      expect(score.easiness, closeTo(0.3967099567099567, 1e-15));
      expect(score.value, 579854);
    });

    test('caps repetition count at twenty in the matrix product', () {
      final List<int> values = List<int>.filled(400, 1000);
      values[0] = 2000;
      for (var column = 1; column < 20; column += 1) {
        values[6 * 20 + column] = 1100;
      }
      final Sm20MercyEngine engine = const Sm20MercyEngine();
      final Sm20MercyScore twenty = engine.scoreCandidate(
        _candidate('twenty', repetitions: 20, lastReview: 0),
        today: _day(100),
        reschedulingDays: 1,
        matrix: Sm20MercyMatrix(values),
        weights: const Sm20MercyWeights(),
        priorityPercent: 50,
      );
      final Sm20MercyScore above = engine.scoreCandidate(
        _candidate('above', repetitions: 200, lastReview: 0),
        today: _day(100),
        reschedulingDays: 1,
        matrix: Sm20MercyMatrix(values),
        weights: const Sm20MercyWeights(),
        priorityPercent: 50,
      );

      expect(above.investmentBase, twenty.investmentBase);
      expect(above.value, twenty.value);
    });
  });

  group('Mercy gathering, ordering, and assignment', () {
    test('collection gathering is items first, topics second, in horizon', () {
      final List<Sm20MercyCandidate> source = <Sm20MercyCandidate>[
        _candidate('topic-1', type: ElementType.source, scheduled: 100),
        _candidate('item-1', scheduled: 99),
        _candidate('topic-2', type: ElementType.extract, scheduled: 101),
        _candidate('item-future', scheduled: 102),
        _candidate('item-pending', scheduled: 100, isScheduled: false),
        _candidate('item-deleted', scheduled: 100, isDeleted: true),
        _candidate('item-old', scheduled: 89),
      ];
      final Sm20MercyPlan plan = _plan(
        candidates: source,
        gatherMode: Sm20MercyGatherMode.collection,
        gatheringDays: 2,
        reschedulingDays: 2,
        mode: MercyMode.sourceOrder,
        learningStart: 90,
      );

      expect(
        plan.gathered.map((Sm20MercyCandidate value) => value.ref.id),
        <String>['item-1', 'topic-1', 'topic-2'],
      );
    });

    test('assignment reverses each exact ceil(N/R) block', () {
      final List<Sm20MercyCandidate> source = <Sm20MercyCandidate>[
        for (var index = 0; index < 5; index += 1)
          _candidate('$index', rank: 'R$index'),
      ];
      final Sm20MercyPlan plan = _plan(
        candidates: source,
        reschedulingDays: 2,
        mode: MercyMode.sourceOrder,
      );

      expect(plan.blockSize, 3);
      expect(
        plan.assignments.map((Sm20MercyAssignment value) => value.ref.id),
        <String>['2', '1', '0', '4', '3'],
      );
      expect(
        plan.assignments.map((Sm20MercyAssignment value) => value.targetDay),
        <StudyDay>[_day(100), _day(100), _day(100), _day(101), _day(101)],
      );
    });

    test('score modes use exact descending heap keys', () {
      final List<Sm20MercyCandidate> source = <Sm20MercyCandidate>[
        _candidate('middle', rank: 'B'),
        _candidate('least', rank: 'C'),
        _candidate('most', rank: 'A'),
      ];
      final PriorityScale scale = PriorityScale(
        source.map((Sm20MercyCandidate value) => value.priority),
      );
      Sm20MercyPlan run(MercyMode mode) => _plan(
        candidates: source,
        reschedulingDays: 1,
        mode: mode,
        scale: scale,
        weights: const Sm20MercyWeights(
          importance: 1,
          lateness: 0,
          investment: 0,
          easiness: 0,
          recency: 0,
        ),
      );

      expect(
        run(MercyMode.highScoreFirst).ordered.map((value) => value!.ref.id),
        <String>['most', 'middle', 'least'],
      );
      expect(
        run(MercyMode.lowScoreFirst).ordered.map((value) => value!.ref.id),
        <String>['least', 'middle', 'most'],
      );
      expect(
        run(MercyMode.sourceOrder).ordered.map((value) => value!.ref.id),
        <String>['middle', 'least', 'most'],
      );
    });

    test(
      'mode 3 uses N fixed-range draws and retains deleted placeholders',
      () {
        final List<Sm20MercyCandidate> source = <Sm20MercyCandidate>[
          _candidate('a'),
          _candidate('deleted', isDeleted: true),
          _candidate('b'),
          _candidate('c'),
        ];
        final List<String?> expected = <String?>['a', null, 'b', 'c'];
        final Sm20Prng expectedPrng = Sm20Prng(seed: 0x12345678);
        for (var index = 0; index < expected.length; index += 1) {
          final int other = expectedPrng.nextInt(expected.length);
          final String? value = expected[index];
          expected[index] = expected[other];
          expected[other] = value;
        }
        final Sm20Prng actualPrng = Sm20Prng(seed: 0x12345678);
        final Sm20MercyPlan plan = _plan(
          candidates: source,
          mode: MercyMode.random,
          prng: actualPrng,
        );

        expect(plan.randomDraws, 4);
        expect(actualPrng.state, expectedPrng.state);
        expect(
          plan.ordered.map((Sm20MercyCandidate? value) => value?.ref.id),
          expected,
        );
        expect(plan.deletedPlaceholderCount, 1);
        expect(plan.assignments, hasLength(3));
        expect(
          plan.assignments.map((Sm20MercyAssignment value) => value.ref.id),
          isNot(contains('deleted')),
        );
      },
    );
  });

  group('Mercy capacity planner', () {
    test('R/G edits enforce horizon relation and recompute N and C', () {
      final Sm20ScheduledCounts counts = _counts(<int, int>{
        98: 3,
        99: 2,
        100: 4,
        101: 1,
        102: 5,
      });
      final Sm20MercyCapacity nonfuture = const Sm20MercyCapacityPlanner()
          .afterHorizonEdit(
            today: _day(100),
            collectionLearningStartDay: _day(98),
            reschedulingDays: 3,
            gatheringDays: 10,
            includeFuture: false,
            scheduledCounts: counts,
          );
      final Sm20MercyCapacity future = const Sm20MercyCapacityPlanner()
          .afterHorizonEdit(
            today: _day(100),
            collectionLearningStartDay: _day(98),
            reschedulingDays: 3,
            gatheringDays: 2,
            includeFuture: true,
            scheduledCounts: counts,
          );
      final Sm20MercyCapacity gatheringEdited = const Sm20MercyCapacityPlanner()
          .afterHorizonEdit(
            today: _day(100),
            collectionLearningStartDay: _day(98),
            reschedulingDays: 5,
            gatheringDays: 2,
            includeFuture: true,
            scheduledCounts: counts,
            editedField: Sm20MercyHorizonField.gatheringDays,
          );

      expect(nonfuture.candidateCount, 15);
      expect(nonfuture.elementsPerDay, 5);
      expect(nonfuture.gatheringDays, 3);
      expect(future.candidateCount, 15);
      expect(future.elementsPerDay, 5);
      expect(future.gatheringDays, 3);
      expect(gatheringEdited.reschedulingDays, 2);
      expect(gatheringEdited.gatheringDays, 2);
      expect(gatheringEdited.candidateCount, 10);
      expect(gatheringEdited.elementsPerDay, 5);
    });

    test('nonfuture daily-cap solver follows balance and allocation loop', () {
      final Sm20MercyCapacity result = const Sm20MercyCapacityPlanner()
          .afterDailyCapEdit(
            today: _day(100),
            collectionLearningStartDay: _day(98),
            elementsPerDay: 3,
            gatheringDays: 1,
            includeFuture: false,
            scheduledCounts: _counts(<int, int>{98: 3, 99: 2, 100: 4, 101: 1}),
          );

      expect(result.candidateCount, 10);
      expect(result.reschedulingDays, 4);
      expect(result.gatheringDays, 4);
    });

    test('future solver adds scheduled counts beyond gathering horizon', () {
      final Sm20MercyCapacity result = const Sm20MercyCapacityPlanner()
          .afterDailyCapEdit(
            today: _day(100),
            collectionLearningStartDay: _day(98),
            elementsPerDay: 3,
            gatheringDays: 2,
            includeFuture: true,
            scheduledCounts: _counts(<int, int>{
              98: 3,
              99: 2,
              100: 4,
              101: 1,
              102: 5,
            }),
          );

      expect(result.candidateCount, 15);
      expect(result.reschedulingDays, 5);
      expect(result.gatheringDays, 5);
    });

    test('subset nonfuture path uses ceil(N/C) without collection ledger', () {
      final Sm20MercyCapacity result = const Sm20MercyCapacityPlanner()
          .afterDailyCapEdit(
            today: _day(100),
            collectionLearningStartDay: _day(0),
            elementsPerDay: 7,
            gatheringDays: 1,
            includeFuture: false,
            scheduledCounts: Sm20ScheduledCounts(const <StudyDay, int>{}),
            subsetCandidateCount: 15,
          );

      expect(result.candidateCount, 15);
      expect(result.reschedulingDays, 3);
      expect(result.gatheringDays, 3);
    });

    test('control caps and long-horizon warning use exact boundaries', () {
      expect(
        () => const Sm20MercyCapacityPlanner().afterDailyCapEdit(
          today: _day(100),
          collectionLearningStartDay: _day(0),
          elementsPerDay: 5001,
          gatheringDays: 1,
          includeFuture: false,
          scheduledCounts: Sm20ScheduledCounts(const <StudyDay, int>{}),
        ),
        throwsRangeError,
      );
      expect(
        const Sm20MercyCapacity(
          candidateCount: 1,
          elementsPerDay: 1,
          reschedulingDays: 1825,
          gatheringDays: 1825,
          includeFuture: false,
        ).warnsAboutLongHorizon,
        isFalse,
      );
      expect(
        const Sm20MercyCapacity(
          candidateCount: 1,
          elementsPerDay: 1,
          reschedulingDays: 1826,
          gatheringDays: 1825,
          includeFuture: false,
        ).warnsAboutLongHorizon,
        isTrue,
      );
    });
  });
}

Sm20MercyPlan _plan({
  required Iterable<Sm20MercyCandidate> candidates,
  Sm20MercyGatherMode gatherMode = Sm20MercyGatherMode.subset,
  int gatheringDays = 1,
  int reschedulingDays = 1,
  MercyMode mode = MercyMode.highScoreFirst,
  int learningStart = 0,
  PriorityScale? scale,
  Sm20MercyWeights weights = const Sm20MercyWeights(),
  Sm20Prng? prng,
}) => const Sm20MercyEngine().plan(
  candidates: candidates,
  gatherMode: gatherMode,
  today: _day(100),
  collectionLearningStartDay: _day(learningStart),
  gatheringDays: gatheringDays,
  reschedulingDays: reschedulingDays,
  mode: mode,
  matrix: _matrix(),
  weights: weights,
  priorityScale:
      scale ??
      PriorityScale(
        candidates.map((Sm20MercyCandidate value) => value.priority),
      ),
  prng: prng ?? Sm20Prng(seed: 0),
);

Sm20MercyCandidate _candidate(
  String id, {
  ElementType type = ElementType.card,
  String rank = 'M',
  int scheduled = 100,
  int? lastReview = 90,
  int repetitions = 1,
  int lapses = 0,
  bool isScheduled = true,
  bool isDeleted = false,
}) => Sm20MercyCandidate(
  ref: ElementRef(id: id, type: type),
  priority: PriorityRank(rank),
  scheduledDay: _day(scheduled),
  lastReviewDay: lastReview == null ? null : _day(lastReview),
  repetitionCount: repetitions,
  lapseCount: lapses,
  storedInterval: 10,
  isScheduled: isScheduled,
  isDeleted: isDeleted,
);

Sm20MercyMatrix _matrix() {
  final List<int> values = List<int>.filled(400, 1000);
  values[0] = 2000;
  values[6 * 20 + 1] = 1500;
  values[6 * 20 + 2] = 1250;
  return Sm20MercyMatrix(values);
}

Sm20ScheduledCounts _counts(Map<int, int> values) =>
    Sm20ScheduledCounts(<StudyDay, int>{
      for (final MapEntry<int, int> entry in values.entries)
        _day(entry.key): entry.value,
    });

StudyDay _day(int epochDay) => const StudyDay(
  year: 1970,
  month: 1,
  day: 1,
  zoneId: 'UTC',
).addDays(epochDay);
