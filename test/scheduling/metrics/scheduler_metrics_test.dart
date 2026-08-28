import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/metrics/scheduler_metrics.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:test/test.dart';

void main() {
  const String zone = 'Europe/Berlin';
  const StudyDay today = StudyDay(year: 2026, month: 8, day: 21, zoneId: zone);
  const ElementRef card = ElementRef(id: 'card-1', type: ElementType.card);
  const ElementRef source = ElementRef(
    id: 'source-1',
    type: ElementType.source,
  );
  const ElementRef extract = ElementRef(
    id: 'extract-1',
    type: ElementType.extract,
  );

  test('collects canonical SM20 schedule metrics without mutating input', () {
    final SchedulerMetricsInput input = SchedulerMetricsInput(
      asOfStudyDay: today,
      due: <DueMetricSample>[
        DueMetricSample(
          element: card,
          due: today.addDays(2),
          branchId: 'branch-a',
          estimatedForegroundMs: 12000,
        ),
        DueMetricSample(
          element: source,
          due: today.addDays(1),
          branchId: 'branch-a',
          estimatedForegroundMs: 60000,
        ),
        DueMetricSample(
          element: extract,
          due: today.addDays(-1),
          branchId: 'branch-b',
        ),
        DueMetricSample(
          element: const ElementRef(id: 'card-outside', type: ElementType.card),
          due: today.addDays(30),
          branchId: 'branch-b',
        ),
      ],
      activity: <DailySchedulerActivity>[
        DailySchedulerActivity(
          day: today,
          manualLaterCount: 4,
          actualCardReviews: 60,
          topicsCompleted: 15,
          cardOpportunities: 80,
          topicOpportunities: 20,
          cardForegroundMs: 800000,
          topicForegroundMs: 400000,
        ),
        DailySchedulerActivity(day: today.addDays(-40), manualLaterCount: 99),
      ],
      mercyBatches: <MercyBatchMetricSample>[
        MercyBatchMetricSample(batchId: 'mercy-1', studyDay: today, size: 24),
      ],
      priorityOutcomes: <PriorityOutcomeMetricSample>[
        PriorityOutcomeMetricSample(
          elementType: ElementType.card,
          priorityDecile: 1,
          latenessDays: 1,
          cardRecalled: true,
        ),
        PriorityOutcomeMetricSample(
          elementType: ElementType.card,
          priorityDecile: 1,
          latenessDays: 3,
          cardRecalled: false,
        ),
        PriorityOutcomeMetricSample(
          elementType: ElementType.source,
          priorityDecile: 1,
          latenessDays: 5,
        ),
      ],
      futureWorkload: <BranchWorkloadMetricSample>[
        BranchWorkloadMetricSample(
          branchId: 'branch-a',
          elementType: ElementType.card,
          count: 12,
          estimatedForegroundMs: 120000,
        ),
        BranchWorkloadMetricSample(
          branchId: 'branch-a',
          elementType: ElementType.extract,
          count: 3,
          estimatedForegroundMs: 180000,
        ),
      ],
      topicEncounters: <TopicEncounterMetricSample>[
        TopicEncounterMetricSample(
          policyVersion: 'sm20',
          intervalDays: 2,
          aFactor: 1.4,
        ),
        TopicEncounterMetricSample(
          policyVersion: 'sm20',
          intervalDays: 6,
          aFactor: 2.0,
        ),
      ],
    );

    final SchedulerMetricsSnapshot result = const SchedulerMetricsCollector()
        .collect(input);

    expect(result.policyVersion, schedulerMetricsPolicyVersion);
    expect(result.next30Days, hasLength(30));
    expect(result.next30Days[1].topics, 1);
    expect(result.next30Days[2].cards, 1);
    expect(result.overdueCards, 0);
    expect(result.overdueTopics, 1);
    expect(result.manualLaterCount, 4);
    expect(result.mercyCount, 1);
    expect(result.mercyBatchSizes, <int>[24]);
    expect(result.actualCardReviews, 60);
    expect(result.topicsCompleted, 15);
    expect(result.cardTopicOpportunityRatio.value, 4);
    expect(result.cardTopicForegroundTimeRatio.value, 2);
    expect(result.priorityDeciles.first.allLateness.median, 3);
    expect(result.priorityDeciles.first.cardLateness.median, 2);
    expect(result.priorityDeciles.first.measuredCardRetention, 0.5);
    expect(result.futureWorkloadByBranch.single.cardCount, 12);
    expect(result.futureWorkloadByBranch.single.topicCount, 3);
    expect(result.futureWorkloadByBranch.single.totalForegroundMs, 300000);
    expect(result.topicPolicies.single.intervals.median, 4);
    expect(result.topicPolicies.single.aFactors.median, 1.7);
  });

  test('deciles preserve zero-at-top and one-at-bottom semantics', () {
    expect(PriorityOutcomeMetricSample.decileForPriorityFraction(0), 1);
    expect(PriorityOutcomeMetricSample.decileForPriorityFraction(0.099), 1);
    expect(PriorityOutcomeMetricSample.decileForPriorityFraction(0.1), 2);
    expect(PriorityOutcomeMetricSample.decileForPriorityFraction(1), 10);
  });

  test('ratios remain undefined instead of inventing a zero denominator', () {
    const RatioMetric ratio = RatioMetric(numerator: 7, denominator: 0);
    expect(ratio.value, isNull);
  });
}
