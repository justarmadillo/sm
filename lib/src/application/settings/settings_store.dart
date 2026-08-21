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
      final Map<String, String> next = settings.toMap();
      final Map<String, String> stored = await _repository.readAll();
      final changed = <String, String>{
        for (final MapEntry<String, String> entry in next.entries)
          if (stored[entry.key] != entry.value) entry.key: entry.value,
      };
      if (changed.isNotEmpty) await _repository.writeAll(changed);
      _cached = settings;
      return Ok<AppSettings>(settings);
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

  /// Restores every shipped default.
  Future<Result<AppSettings>> resetToDefaults() => save(const AppSettings());

  /// Drops the cache so the next [load] re-reads from storage.
  void invalidate() => _cached = null;

  Future<AppSettings> _read() async =>
      AppSettings.fromMap(await _repository.readAll());
}
