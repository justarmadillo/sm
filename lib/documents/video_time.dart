/// Reading and writing the clock times a video range is expressed in.
///
/// One place, because a time typed into a dialog and a time drawn beside the
/// Open button must never disagree about what `4:12` means. Everything the
/// rest of the app handles is a plain count of seconds; these two functions
/// are the only border between that and what the user reads and types.
library;

/// Seconds meant by [text], or null when it is not a time.
///
/// Accepts `s`, `m:ss`, and `h:mm:ss`. The minutes field is deliberately
/// unbounded when no hour is given, because `90:00` is how a ninety-minute
/// lecture gets typed and rejecting it would teach the user to distrust the
/// field. The seconds field is bounded, because `4:75` is a typo every time.
int? parseVideoTime(String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final List<String> parts = trimmed.split(':');
  if (parts.length > 3) return null;

  final List<int> values = <int>[];
  for (final String part in parts) {
    final int? value = int.tryParse(part.trim());
    if (value == null || value < 0) return null;
    values.add(value);
  }

  return switch (values) {
    [final int seconds] => seconds,
    [final int minutes, final int seconds] when seconds < 60 =>
      minutes * 60 + seconds,
    [final int hours, final int minutes, final int seconds]
        when minutes < 60 && seconds < 60 =>
      hours * 3600 + minutes * 60 + seconds,
    _ => null,
  };
}

/// [seconds] written the way the user reads it: `4:12`, or `1:04:12`.
///
/// The hour field appears only once there is one, so a short clip is not
/// padded out with a leading zero it never needs.
String formatVideoTime(int seconds) {
  assert(seconds >= 0, 'negative time');
  final int safe = seconds < 0 ? 0 : seconds;
  final int hours = safe ~/ 3600;
  final int minutes = (safe % 3600) ~/ 60;
  final int remainder = safe % 60;
  final String paddedSeconds = remainder.toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$paddedSeconds';
  return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
}
