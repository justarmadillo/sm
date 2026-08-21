/// Settings storage.
///
/// Two properties matter and neither is about any individual value: every
/// setting round-trips through the flat key/value form, and decoding is total,
/// because a collection that cannot be opened because one row is malformed is
/// a collection that has been lost.
library;

import 'package:incremental_reader/src/domain/settings/app_settings.dart';
import 'package:test/test.dart';

void main() {
  group('round trip', () {
    test('the shipped defaults survive encoding and decoding', () {
      const AppSettings defaults = AppSettings();
      expect(AppSettings.fromMap(defaults.toMap()), defaults);
    });

    test('every section survives being edited', () {
      final AppSettings edited = const AppSettings().copyWith(
        studyDay: const StudyDaySettings(
          zoneId: 'Europe/Berlin',
          rolloverMinutes: 300,
        ),
        queue: const QueueSettings(
          maxCards: 120,
          maxNewCards: 7,
          maxTopics: 33,
          cardsPerTopic: 6,
          minTopicEvery: 9,
          randomization: 0.12,
          priorityWeight: 0.6,
          overdueWeight: 0.35,
          protectedPercentile: 0.08,
          overloadTolerance: 1.5,
          maxSharePerRoot: 0.4,
          autoPostpone: false,
          autoSort: false,
          studyMoreStep: 15,
        ),
        topics: const TopicSchedulerSettings(
          pacing: TopicPacingMode.intervalProfile,
          baseAFactor: 1.8,
          priorityFloor: 0.6,
          prioritySpan: 0.9,
          completionFloor: 0.65,
          completionSpan: 0.7,
          unconvertedExtractFactor: 0.8,
          convertedExtractFactor: 1.4,
          yieldEnabled: true,
          yieldWeight: 0.5,
          yieldSmoothing: 0.25,
          yieldReferenceDensity: 6,
          minAFactor: 0.9,
          maxAFactor: 8,
          sourceFirstIntervalSpan: 25,
          sourceFirstIntervalMax: 40,
          extractFirstIntervalSpan: 12,
          extractFirstIntervalMax: 20,
          autoFinishSources: false,
          extractFinishPromptAfter: 5,
        ),
        cards: const CardSettings(
          desiredRetention: 0.85,
          learningStepMinutes: <int>[2, 15, 45],
          relearningStepMinutes: <int>[5, 20],
          maximumIntervalDays: 1000,
          enableFuzzing: false,
          leechLapses: 5,
          burySiblings: false,
        ),
        postpone: const PostponeSettings(
          laterMinFraction: 0.05,
          laterMaxFraction: 0.4,
          laterMaxDays: 200,
          autoBaseFraction: 0.2,
          autoPriorityMultiplier: 6,
          autoDispersal: 0.3,
          autoMaxDays: 900,
          mercyHorizonDays: 21,
          mercyDailyCap: 40,
        ),
        reader: const ReaderSettings(reminderWords: 800, defaultLaterDays: 2),
        diagnostics: const DiagnosticsSettings(
          logEnabled: false,
          logMaxBytes: 65536,
          logRetainedFiles: 9,
          showContentInPanel: true,
        ),
        intervalProfiles: const <String, List<int>>{
          'focused': <int>[1, 2, 4],
          'normal': <int>[2, 5, 11],
          'slow': <int>[10, 30],
          'extract': <int>[1, 4, 9],
        },
      );

      expect(AppSettings.fromMap(edited.toMap()), edited);
    });

    test('a custom interval profile survives', () {
      final AppSettings withCustom = const AppSettings().copyWith(
        intervalProfiles: <String, List<int>>{
          ...AppSettings.defaultIntervalProfileDays,
          'cramming': <int>[1, 1, 2, 3],
        },
      );
      final AppSettings restored = AppSettings.fromMap(withCustom.toMap());
      expect(restored.intervalProfiles['cramming'], <int>[1, 1, 2, 3]);
    });
  });

  group('decoding is total', () {
    test('an empty store yields the shipped defaults', () {
      expect(AppSettings.fromMap(const <String, String>{}), const AppSettings());
    });

    test('malformed values fall back rather than throwing', () {
      final AppSettings settings = AppSettings.fromMap(<String, String>{
        'queue.max_cards': 'not a number',
        'queue.randomization': '',
        'card.desired_retention': 'NaN',
        'card.learning_steps': 'x, y, z',
        'topic.pacing_mode': 'something-a-newer-build-knows',
        'diagnostics.log_enabled': 'perhaps',
        'profile.days.normal': 'nonsense',
      });

      const AppSettings defaults = AppSettings();
      expect(settings.queue.maxCards, defaults.queue.maxCards);
      expect(settings.queue.randomization, defaults.queue.randomization);
      expect(settings.cards.desiredRetention, defaults.cards.desiredRetention);
      expect(
        settings.cards.learningStepMinutes,
        defaults.cards.learningStepMinutes,
      );
      expect(
        settings.topics.pacing,
        TopicPacingMode.aFactor,
        reason: 'an unknown mode degrades to the default, not to a crash',
      );
      expect(settings.diagnostics.logEnabled, defaults.diagnostics.logEnabled);
      expect(
        settings.intervalProfiles['normal'],
        defaults.intervalProfiles['normal'],
      );
    });

    test('out-of-range values are clamped into something usable', () {
      final AppSettings settings = AppSettings.fromMap(<String, String>{
        'queue.randomization': '9',
        'queue.protected_percentile': '0.99',
        'queue.overload_tolerance': '0.1',
        'card.desired_retention': '0.999',
        'topic.min_a_factor': '0.001',
        'study.rollover_minutes': '99999',
      });

      expect(settings.queue.randomization, 1);
      expect(settings.queue.protectedPercentile, 0.5);
      expect(settings.queue.overloadTolerance, 1);
      expect(settings.cards.desiredRetention, 0.99);
      expect(settings.topics.minAFactor, 0.5);
      expect(settings.studyDay.rolloverMinutes, 1439);
    });

    test('unknown keys are ignored', () {
      expect(
        AppSettings.fromMap(<String, String>{
          'something.from.the.future': '42',
        }),
        const AppSettings(),
      );
    });

    test('booleans accept the forms a human might type', () {
      for (final String yes in <String>['true', 'TRUE', '1', 'yes']) {
        expect(
          AppSettings.fromMap(<String, String>{
            'card.enable_fuzzing': yes,
          }).cards.enableFuzzing,
          isTrue,
        );
      }
      for (final String no in <String>['false', 'FALSE', '0', 'no']) {
        expect(
          AppSettings.fromMap(<String, String>{
            'card.enable_fuzzing': no,
          }).cards.enableFuzzing,
          isFalse,
        );
      }
    });
  });

  group('defaults match the specification', () {
    test('the queue ships SuperMemo’s shape', () {
      const QueueSettings queue = QueueSettings();
      expect(queue.maxCards, 200);
      expect(queue.maxNewCards, 20);
      expect(queue.maxTopics, 50);
      expect(queue.cardsPerTopic, 4);
      expect(queue.randomization, 0.05);
      expect(queue.protectedPercentile, 0.01);
    });

    test('the interval sequences are the ones the plan names', () {
      const Map<String, List<int>> profiles =
          AppSettings.defaultIntervalProfileDays;
      expect(profiles['focused'], <int>[1, 2, 3, 5, 7, 10, 14, 21, 30]);
      expect(profiles['normal'], <int>[1, 3, 7, 14, 30, 60, 120, 240, 365]);
      expect(profiles['slow'], <int>[7, 14, 30, 60, 120, 240, 365, 730]);
      expect(profiles['extract'], <int>[1, 3, 7, 14, 30, 60, 120]);
    });

    test('FSRS ships its pinned defaults', () {
      const CardSettings cards = CardSettings();
      expect(cards.desiredRetention, 0.90);
      expect(cards.learningStepMinutes, <int>[1, 10]);
      expect(cards.relearningStepMinutes, <int>[10]);
      expect(cards.maximumIntervalDays, 36500);
      expect(cards.enableFuzzing, isTrue);
    });

    test('the study day rolls over at 04:00', () {
      expect(const StudyDaySettings().rolloverMinutes, 240);
    });
  });
}
