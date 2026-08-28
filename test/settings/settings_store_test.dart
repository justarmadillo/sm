import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/postpone_settings.dart';
import 'package:incremental_reader/settings/queue_settings.dart';
import 'package:incremental_reader/settings/settings_store.dart';
import 'package:incremental_reader/settings/smart_postpone_settings.dart';
import 'package:incremental_reader/storage/contracts/settings_repository.dart';
import 'package:test/test.dart';

void main() {
  test(
    'save canonicalizes values and removes replaced scheduler rows',
    () async {
      final _MemorySettingsRepository repository =
          _MemorySettingsRepository(<String, String>{
            'queue.max_cards': '200',
            'topic.base_a_factor': '1.8',
            'profile.days.normal': '1,3,7',
            'postpone.auto_base_fraction': '0.2',
            'reader.default_later_days': '5',
            'unrelated.plugin.setting': 'preserve me',
          });
      final SettingsStore store = SettingsStore(repository);

      final result = await store.save(
        const AppSettings(
          queue: QueueSettings(topicPercent: 900),
          postpone: PostponeSettings(
            defaultProfile: SmartPostponeSettings(protectedCount: 99999),
          ),
        ),
      );

      expect(result.isOk, isTrue);
      expect(result.unwrap().queue.topicPercent, 100);
      expect(result.unwrap().postpone.defaultProfile.protectedCount, 20000);
      expect(repository.values['queue.topic_percent'], '100');
      expect(repository.values['postpone.default.protected_count'], '20000');
      expect(repository.values, isNot(contains('queue.max_cards')));
      expect(repository.values, isNot(contains('topic.base_a_factor')));
      expect(repository.values, isNot(contains('profile.days.normal')));
      expect(repository.values, isNot(contains('postpone.auto_base_fraction')));
      expect(repository.values, isNot(contains('reader.default_later_days')));
      expect(repository.values['unrelated.plugin.setting'], 'preserve me');
    },
  );
}

final class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository(Map<String, String> initial)
    : values = <String, String>{...initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<Map<String, String>> readAll() async => <String, String>{...values};

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> writeAll(Map<String, String> next) async {
    values.addAll(next);
  }

  @override
  Future<void> deleteKey(String key) async {
    values.remove(key);
  }
}
