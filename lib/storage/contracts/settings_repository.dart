/// What the app promises about storing settings.
///
/// A flat key/value store: the typed shape lives in settings/.
library;


/// User settings and the values the schedulers read.
abstract interface class SettingsRepository {
  /// Reads the setting [key], or null when unset.
  Future<String?> read(String key);

  /// Writes the setting [key].
  Future<void> write(String key, String value);

  /// Every stored setting.
  Future<Map<String, String>> readAll();

  /// Writes many settings in one batch, replacing what was there.
  Future<void> writeAll(Map<String, String> values);

  /// Removes the setting [key], returning it to its shipped default.
  Future<void> remove(String key);
}
