import 'package:incremental_reader/settings/app_settings.dart';
import 'package:test/test.dart';

void main() {
  group('SM20 settings round trip', () {
    test('shipped defaults survive encoding and decoding', () {
      const AppSettings defaults = AppSettings();
      expect(AppSettings.fromMap(defaults.toMap()), defaults);
    });

    test('every scheduler and application section survives editing', () {
      final List<int> matrix = List<int>.generate(400, (int i) => i * 7);
      final AppSettings edited = AppSettings(
        studyDay: const StudyDaySettings(
          zoneId: 'Europe/Berlin',
          rolloverMinutes: 300,
        ),
        queue: const QueueSettings(
          topicPercent: 37,
          itemRandomization: 18,
          topicRandomization: 72,
          autoSort: false,
          randomizeFinalDrill: true,
          confirmStageTransitions: false,
        ),
        remember: const RememberSettings(
          firstIntervalLowDays: 3,
          firstIntervalHighDays: 11,
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
          autoEnabled: false,
          defaultProfile: SmartPostponeSettings(
            rootElementId: 42,
            scope: SmartPostponeScope.branch,
            method: SmartPostponeMethod.parameters,
            profileName: 'Research branch',
            subbranchMode: SmartPostponeSubbranchMode.conservative,
            protectedCount: 123,
            includeNonOutstanding: true,
            simulate: true,
            itemDelayPercent: 31,
            topicDelayPercent: 81,
            itemMaximumDelayDays: 75,
            topicMaximumDelayDays: 180,
            itemMinimumDelayDays: 4,
            topicMinimumDelayDays: 9,
            skipItems: true,
            skipTopics: true,
            itemAgeCutoffDays: 700,
            topicAgeCutoffDays: 900,
            itemForgettingIndexCutoff: 9,
            topicAFactorCutoff: 1.45,
            itemPostponeCountCutoff: 71,
            topicPostponeCountCutoff: 131,
            itemPriorityThreshold: 7.5,
            topicPriorityThreshold: 2.25,
            modifyItemByForgettingIndex: false,
            modifyTopicByAFactor: false,
          ),
        ),
        mercy: MercySettings(
          mode: MercyMode.random,
          reschedulingDays: 28,
          gatheringDays: 45,
          dailyCap: 77,
          includeFuture: true,
          importanceWeight: 8,
          latenessWeight: 6,
          investmentWeight: 5,
          easinessWeight: 2,
          recencyWeight: 3,
          intervalFactorMatrix: matrix,
        ),
        reader: const ReaderSettings(reminderWords: 800),
        diagnostics: const DiagnosticsSettings(
          logEnabled: false,
          logMaxBytes: 65536,
          logRetainedFiles: 9,
          showContentInPanel: true,
        ),
      );

      expect(AppSettings.fromMap(edited.toMap()), edited);
    });

    test('an absent Mercy matrix round-trips as absent', () {
      final AppSettings restored = AppSettings.fromMap(
        const AppSettings().toMap(),
      );
      expect(restored.mercy.intervalFactorMatrix, isNull);
    });

    test('the flat form contains no replaced scheduler keys', () {
      final Map<String, String> stored = const AppSettings().toMap();
      expect(
        stored.keys.where((String key) => key.startsWith('topic.')),
        isEmpty,
      );
      expect(
        stored.keys.where((String key) => key.startsWith('profile.days.')),
        isEmpty,
      );
      expect(stored, isNot(contains('queue.max_cards')));
      expect(stored, isNot(contains('queue.study_more_step')));
      expect(stored, isNot(contains('postpone.auto_base_fraction')));
      expect(stored, isNot(contains('reader.default_later_days')));
    });
  });

  group('total decoding', () {
    test('an empty store yields the shipped defaults', () {
      expect(
        AppSettings.fromMap(const <String, String>{}),
        const AppSettings(),
      );
    });

    test('malformed values fall back independently', () {
      final AppSettings settings = AppSettings.fromMap(<String, String>{
        'queue.topic_percent': 'not a number',
        'queue.auto_sort': 'perhaps',
        'remember.first_interval_low_days': '',
        'card.desired_retention': 'NaN',
        'card.learning_steps': 'x, y, z',
        'postpone.default.scope': 'future-build-value',
        'postpone.default.topic_a_factor_cutoff': 'Infinity',
        'mercy.mode': 'unknown',
        'mercy.interval_factor_matrix': '1,2,3',
        'diagnostics.log_enabled': 'perhaps',
      });

      const AppSettings defaults = AppSettings();
      expect(settings.queue.topicPercent, defaults.queue.topicPercent);
      expect(settings.queue.autoSort, defaults.queue.autoSort);
      expect(
        settings.remember.firstIntervalLowDays,
        defaults.remember.firstIntervalLowDays,
      );
      expect(settings.cards.desiredRetention, defaults.cards.desiredRetention);
      expect(
        settings.cards.learningStepMinutes,
        defaults.cards.learningStepMinutes,
      );
      expect(
        settings.postpone.defaultProfile.scope,
        defaults.postpone.defaultProfile.scope,
      );
      expect(
        settings.postpone.defaultProfile.topicAFactorCutoff,
        defaults.postpone.defaultProfile.topicAFactorCutoff,
      );
      expect(settings.mercy.mode, defaults.mercy.mode);
      expect(settings.mercy.intervalFactorMatrix, isNull);
      expect(settings.diagnostics.logEnabled, defaults.diagnostics.logEnabled);
    });

    test('out-of-range values use the executable and UI bounds', () {
      final AppSettings settings = AppSettings.fromMap(<String, String>{
        'study.rollover_minutes': '99999',
        'queue.topic_percent': '-1',
        'queue.item_randomization': '101',
        'remember.first_interval_low_days': '0',
        'remember.first_interval_high_days': '999',
        'card.desired_retention': '0.999',
        'postpone.default.protected_count': '50000',
        'postpone.default.item_delay_percent': '0',
        'postpone.default.topic_delay_percent': '5000',
        'postpone.default.item_maximum_delay_days': '999',
        'postpone.default.topic_maximum_delay_days': '999',
        'postpone.default.item_minimum_delay_days': '0',
        'postpone.default.topic_minimum_delay_days': '999',
        'postpone.default.item_age_cutoff_days': '1',
        'postpone.default.topic_age_cutoff_days': '5000',
        'postpone.default.item_forgetting_index_cutoff': '2',
        'postpone.default.topic_a_factor_cutoff': '0.2',
        'postpone.default.item_postpone_count_cutoff': '999',
        'postpone.default.topic_postpone_count_cutoff': '0',
        'postpone.default.item_priority_threshold': '0',
        'postpone.default.topic_priority_threshold': '0',
        'mercy.rescheduling_days': '9999',
        'mercy.gathering_days': '0',
        'mercy.daily_cap': '9000',
      });

      expect(settings.studyDay.rolloverMinutes, 1439);
      expect(settings.queue.topicPercent, 0);
      expect(settings.queue.itemRandomization, 100);
      expect(settings.remember.firstIntervalLowDays, 1);
      expect(settings.remember.firstIntervalHighDays, 365);
      expect(settings.cards.desiredRetention, 0.99);

      final SmartPostponeSettings smart = settings.postpone.defaultProfile;
      expect(smart.protectedCount, 20000);
      expect(smart.itemDelayPercent, 1);
      expect(smart.topicDelayPercent, 1900);
      expect(smart.itemMaximumDelayDays, 300);
      expect(smart.topicMaximumDelayDays, 500);
      expect(smart.itemMinimumDelayDays, 1);
      expect(smart.topicMinimumDelayDays, 100);
      expect(smart.itemAgeCutoffDays, 2);
      expect(smart.topicAgeCutoffDays, 4000);
      expect(smart.itemForgettingIndexCutoff, 3);
      expect(smart.topicAFactorCutoff, 1.01);
      expect(smart.itemPostponeCountCutoff, 255);
      expect(smart.topicPostponeCountCutoff, 1);
      expect(smart.itemPriorityThreshold, 0.01);
      expect(smart.topicPriorityThreshold, 0.0001);
      expect(settings.mercy.reschedulingDays, 3650);
      expect(settings.mercy.gatheringDays, 1);
      expect(settings.mercy.dailyCap, 5000);
    });

    test('unknown and legacy keys are ignored', () {
      expect(
        AppSettings.fromMap(<String, String>{
          'something.from.the.future': '42',
          'queue.max_cards': '1',
          'topic.base_a_factor': '4',
          'postpone.auto_base_fraction': '0.9',
        }),
        const AppSettings(),
      );
    });

    test('booleans accept human-readable forms', () {
      for (final String yes in <String>['true', 'TRUE', '1', 'yes']) {
        expect(
          AppSettings.fromMap(<String, String>{
            'queue.auto_sort': yes,
          }).queue.autoSort,
          isTrue,
        );
      }
      for (final String no in <String>['false', 'FALSE', '0', 'no']) {
        expect(
          AppSettings.fromMap(<String, String>{
            'queue.auto_sort': no,
          }).queue.autoSort,
          isFalse,
        );
      }
    });
  });

  group('defaults from the supplied scheduler sources', () {
    test('queue and Remember use the application initialization values', () {
      const QueueSettings queue = QueueSettings();
      expect(queue.topicPercent, 20);
      expect(queue.itemRandomization, 0);
      expect(queue.topicRandomization, 0);
      expect(queue.autoSort, isTrue);
      expect(const RememberSettings().firstIntervalLowDays, 1);
      expect(const RememberSettings().firstIntervalHighDays, 1);
    });

    test('Smart Postpone matches the binary-derived Default profile', () {
      const SmartPostponeSettings smart = SmartPostponeSettings();
      expect(smart.method, SmartPostponeMethod.topCount);
      expect(smart.protectedCount, 50);
      expect(smart.itemDelayPercent, 20);
      expect(smart.topicDelayPercent, 50);
      expect(smart.itemMaximumDelayDays, 50);
      expect(smart.topicMaximumDelayDays, 100);
      expect(smart.itemMinimumDelayDays, 1);
      expect(smart.topicMinimumDelayDays, 6);
      expect(smart.itemAgeCutoffDays, 500);
      expect(smart.topicAgeCutoffDays, 800);
      expect(smart.itemForgettingIndexCutoff, 6);
      expect(smart.topicAFactorCutoff, 1.03);
      expect(smart.itemPostponeCountCutoff, 50);
      expect(smart.topicPostponeCountCutoff, 100);
      expect(smart.itemPriorityThreshold, 6);
      expect(smart.topicPriorityThreshold, 3);
      expect(smart.subbranchMode, SmartPostponeSubbranchMode.ignore);
      expect(smart.modifyItemByForgettingIndex, isTrue);
      expect(smart.modifyTopicByAFactor, isTrue);
    });

    test('Mercy weights use the executable record order defaults', () {
      const MercySettings mercy = MercySettings();
      expect(mercy.importanceWeight, 10);
      expect(mercy.latenessWeight, 3);
      expect(mercy.investmentWeight, 4);
      expect(mercy.easinessWeight, 1);
      expect(mercy.recencyWeight, 1);
    });

    test('card memory retains its pinned FSRS defaults', () {
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

  group('named Smart Postpone profiles', () {
    const SmartPostponeSettings research = SmartPostponeSettings(
      profileName: 'Research',
      scope: SmartPostponeScope.branch,
      method: SmartPostponeMethod.parameters,
      subbranchMode: SmartPostponeSubbranchMode.conservative,
      rootElementId: 91,
      protectedCount: 12,
      includeNonOutstanding: true,
      simulate: true,
      itemDelayPercent: 33,
      topicDelayPercent: 77,
      itemMaximumDelayDays: 60,
      topicMaximumDelayDays: 150,
      itemMinimumDelayDays: 2,
      topicMinimumDelayDays: 8,
      skipItems: true,
      skipTopics: false,
      itemAgeCutoffDays: 600,
      topicAgeCutoffDays: 900,
      itemForgettingIndexCutoff: 11,
      topicAFactorCutoff: 1.25,
      itemPostponeCountCutoff: 44,
      topicPostponeCountCutoff: 88,
      itemPriorityThreshold: 7.5,
      topicPriorityThreshold: 2.5,
      modifyItemByForgettingIndex: false,
      modifyTopicByAFactor: false,
    );

    test('every profile field survives the flat storage round trip', () {
      final AppSettings edited = const AppSettings()
          .copyWith(
            postpone: const PostponeSettings()
                .saveNamedProfile('Research', research)
                .saveNamedProfile(
                  'Light',
                  const SmartPostponeSettings(protectedCount: 5),
                ),
          )
          .copyWith();
      final AppSettings decoded = AppSettings.fromMap(edited.toMap());

      expect(decoded, edited);
      expect(decoded.postpone.profileNamed('Research'), research);
      expect(decoded.postpone.profileNamed('Light')?.protectedCount, 5);
    });

    test('branch assignments round trip and resolve to a managed profile', () {
      final PostponeSettings postpone = const PostponeSettings()
          .saveNamedProfile('Research', research)
          .assignBranchProfile(91, 'Research')
          .assignBranchProfile(7, PostponeSettings.defaultProfileName);
      final AppSettings decoded = AppSettings.fromMap(
        const AppSettings().copyWith(postpone: postpone).toMap(),
      );

      expect(decoded.postpone.branchProfileAssignments, <int, String>{
        7: PostponeSettings.defaultProfileName,
        91: 'Research',
      });
      expect(
        decoded.postpone.profileNamed(
          decoded.postpone.branchProfileAssignments[91]!,
        ),
        research,
      );
    });

    test('the key is authoritative when a stored record name drifts', () {
      final PostponeSettings postpone = const PostponeSettings()
          .saveNamedProfile('Research', research);
      final Map<String, String> stored = const AppSettings()
          .copyWith(postpone: postpone)
          .toMap();

      expect(
        AppSettings.fromMap(
          stored,
        ).postpone.profileNamed('Research')?.profileName,
        'Research',
      );
      // A record whose embedded name disagrees with its key must not appear
      // twice, or a branch assignment could resolve to a phantom profile.
      expect(AppSettings.fromMap(stored).postpone.profileNames, <String>[
        PostponeSettings.defaultProfileName,
        'Research',
      ]);
    });

    test('Default is reserved and always present', () {
      const PostponeSettings postpone = PostponeSettings();
      expect(postpone.profileNames, <String>[
        PostponeSettings.defaultProfileName,
      ]);
      expect(
        postpone.profileNamed(PostponeSettings.defaultProfileName),
        postpone.defaultProfile,
      );
      expect(
        () => postpone.saveNamedProfile(
          PostponeSettings.defaultProfileName,
          research,
        ),
        throwsArgumentError,
      );
      expect(
        () => postpone.saveNamedProfile('  ', research),
        throwsArgumentError,
      );
      expect(
        postpone.replaceDefault(research).defaultProfile.profileName,
        PostponeSettings.defaultProfileName,
      );
      expect(
        postpone.deleteNamedProfile(PostponeSettings.defaultProfileName),
        postpone,
      );
    });

    test('deleting a profile deletes every assignment that used it', () {
      final PostponeSettings postpone = const PostponeSettings()
          .saveNamedProfile('Research', research)
          .saveNamedProfile('Light', const SmartPostponeSettings())
          .assignBranchProfile(91, 'Research')
          .assignBranchProfile(92, 'Research')
          .assignBranchProfile(93, 'Light');

      final PostponeSettings pruned = postpone.deleteNamedProfile('Research');
      expect(pruned.namedProfiles.keys, <String>['Light']);
      expect(pruned.branchProfileAssignments, <int, String>{93: 'Light'});
      expect(
        pruned.unassignBranchProfile(93).branchProfileAssignments,
        isEmpty,
      );
    });

    test(
      'assignment rejects an unmanaged profile and an out-of-range root',
      () {
        const PostponeSettings postpone = PostponeSettings();
        expect(
          () => postpone.assignBranchProfile(1, 'Missing'),
          throwsArgumentError,
        );
        expect(
          () => postpone.assignBranchProfile(-1, 'Default'),
          throwsRangeError,
        );
      },
    );

    test('clearing the registry is durable rather than a missing key', () {
      final PostponeSettings populated = const PostponeSettings()
          .saveNamedProfile('Research', research)
          .assignBranchProfile(91, 'Research');
      final Map<String, String> stored = const AppSettings()
          .copyWith(postpone: populated)
          .toMap();
      final Map<String, String> cleared = const AppSettings()
          .copyWith(postpone: populated.deleteNamedProfile('Research'))
          .toMap();

      expect(stored['postpone.named_profiles'], isNotEmpty);
      expect(stored['postpone.branch_profiles'], isNotEmpty);
      // An emptied registry is written as an explicit empty value, so the
      // deletion survives the next launch instead of decoding back to the
      // shipped defaults the way a missing key would.
      expect(cleared['postpone.named_profiles'], isEmpty);
      expect(cleared['postpone.branch_profiles'], isEmpty);
      expect(AppSettings.fromMap(cleared).postpone.namedProfiles, isEmpty);
      expect(
        AppSettings.fromMap(cleared).postpone.branchProfileAssignments,
        isEmpty,
      );
    });

    test('a corrupt registry decodes as empty instead of throwing', () {
      final Map<String, String> stored = const AppSettings().toMap()
        ..['postpone.named_profiles'] = '{not json'
        ..['postpone.branch_profiles'] = '[1,2,3]';

      final PostponeSettings decoded = AppSettings.fromMap(stored).postpone;
      expect(decoded.namedProfiles, isEmpty);
      expect(decoded.branchProfileAssignments, isEmpty);
    });

    test('unusable registry entries are skipped individually', () {
      final Map<String, String> stored = const AppSettings().toMap()
        ..['postpone.named_profiles'] =
            '{"Default":{"protected_count":1},"Light":{"protected_count":9},'
            '"Broken":7}'
        ..['postpone.branch_profiles'] =
            '{"91":"Light","not-a-root":"Light","92":"","93":null}';

      final PostponeSettings decoded = AppSettings.fromMap(stored).postpone;
      // Default is reserved: a stored record under that key must not shadow
      // the permanent automatic-postpone slot.
      expect(decoded.namedProfiles.keys, <String>['Light']);
      expect(decoded.defaultProfile, const SmartPostponeSettings());
      expect(decoded.branchProfileAssignments, <int, String>{91: 'Light'});
    });

    test('a partial profile record keeps the remaining defaults', () {
      final Map<String, String> stored = const AppSettings().toMap()
        ..['postpone.named_profiles'] =
            '{"Light":{"protected_count":9,"item_delay_percent":"bad"}}';

      final SmartPostponeSettings? light = AppSettings.fromMap(
        stored,
      ).postpone.profileNamed('Light');
      expect(light?.protectedCount, 9);
      expect(
        light?.itemDelayPercent,
        const SmartPostponeSettings().itemDelayPercent,
      );
      expect(light?.profileName, 'Light');
    });
  });
}
