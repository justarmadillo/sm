/// What the app promises about storing settings.
///
/// A flat key/value store: the typed shape lives in settings/.
library;

/// User settings and the values the schedulers read.
abstract interface class SettingsRepository {
  /// The value stored under [key], or null when it has never been set.
  Future<String?> findValue(String key);

  /// Stores [value] under [key], replacing any value already there.
  Future<void> saveValue(String key, String value);

  /// Every stored setting, as key to value.
  Future<Map<String, String>> listAllValues();

  /// Stores many settings in one batch, replacing what was there.
  Future<void> saveAllValues(Map<String, String> values);

  /// Removes the setting [key], returning it to its shipped default.
  Future<void> deleteKey(String key);
}
