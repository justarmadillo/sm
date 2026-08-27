/// Reads and writes the collection's configuration.
///
/// Settings are stored as flat key/value rows but are consumed as one typed
/// `AppSettings` value, so no caller has to know a key name or parse a number.
/// The value is cached because the schedulers ask for it on every command and
/// on every queue build; the cache is invalidated by writes and by an explicit
/// `reload`, never by a timer.
library;

import '../../core/result.dart';
import '../../domain/settings/app_settings.dart';
import '../ports/repositories.dart';

/// Loads, caches, and persists [AppSettings].
final class SettingsStore {
  SettingsStore(SettingsRepository repository) : _repository = repository;

  final SettingsRepository _repository;
  AppSettings? _cached;

  /// The current settings, loading them once and caching the result.
  Future<AppSettings> load() async => _cached ??= await _read();

  /// The current settings, ignoring the cache.
  Future<AppSettings> reload() async => _cached = await _read();

  /// The cached value, or the shipped defaults if nothing is loaded yet.
  ///
  /// For call sites that cannot await — a widget build, a synchronous getter.
  /// Anything that decides a schedule must use [load] instead.
  AppSettings get currentOrDefaults => _cached ?? const AppSettings();

  /// Persists [settings], writing only the keys that actually changed.
  ///
  /// Writing the whole map every time would churn rows and make the settings
  /// table's history useless for working out when a constant was retuned.
  Future<Result<AppSettings>> save(AppSettings settings) async {
    try {
      // The UI constrains every field, but commands and imports can also build
      // AppSettings directly. Round-trip once so persisted values always obey
      // the same executable/UI domains as decoded values.
      final AppSettings canonical = AppSettings.fromMap(settings.toMap());
      final Map<String, String> next = canonical.toMap();
      final Map<String, String> stored = await _repository.readAll();
      final changed = <String, String>{
        for (final MapEntry<String, String> entry in next.entries)
          if (stored[entry.key] != entry.value) entry.key: entry.value,
      };
      if (changed.isNotEmpty) await _repository.writeAll(changed);
      for (final String key in stored.keys) {
        if (!next.containsKey(key) && _isReplacedSchedulerKey(key)) {
          await _repository.remove(key);
        }
      }
      _cached = canonical;
      return Ok<AppSettings>(canonical);
    } on Object catch (error, stackTrace) {
      return Err<AppSettings>(
        StorageFailure(
          'could not save settings',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Drops the cache so the next [load] re-reads from storage.
  void invalidate() => _cached = null;

  Future<AppSettings> _read() async =>
      AppSettings.fromMap(await _repository.readAll());
}

bool _isReplacedSchedulerKey(String key) =>
    key.startsWith('topic.') ||
    key.startsWith('profile.days.') ||
    _replacedSchedulerKeys.contains(key);

const Set<String> _replacedSchedulerKeys = <String>{
  'queue.max_cards',
  'queue.max_new_cards',
  'queue.max_topics',
  'queue.cards_per_topic',
  'queue.min_topic_every',
  'queue.randomization',
  'queue.protected_percentile',
  'queue.auto_postpone',
  'queue.study_more_step',
  'postpone.later_min_fraction',
  'postpone.later_max_fraction',
  'postpone.later_max_days',
  'postpone.auto_base_fraction',
  'postpone.auto_priority_multiplier',
  'postpone.auto_dispersal',
  'postpone.auto_max_days',
  'postpone.mercy_horizon_days',
  'postpone.mercy_daily_cap',
  'reader.default_later_days',
};
