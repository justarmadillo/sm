/// The one border between seconds and what the user reads and types.
///
/// Every video range in the collection is stored as a count of seconds and
/// shown as a clock time, so a disagreement between these two functions
/// misplaces clips rather than crashing — which is why the round trip is
/// tested as a property and not only on the examples.
library;

import 'package:incremental_reader/documents/video_time.dart';
import 'package:test/test.dart';

void main() {
  group('parseVideoTime', () {
    test('a bare number is seconds', () {
      expect(parseVideoTime('0'), 0);
      expect(parseVideoTime('45'), 45);
    });

    test('m:ss and h:mm:ss', () {
      expect(parseVideoTime('4:12'), 252);
      expect(parseVideoTime('0:07'), 7);
      expect(parseVideoTime('1:04:12'), 3852);
    });

    test('surrounding and interior whitespace is ignored', () {
      expect(parseVideoTime('  4:12 '), 252);
      expect(parseVideoTime('1: 04 :12'), 3852);
    });

    // A ninety-minute lecture is typed as 90:00 by anyone who has not been
    // taught otherwise, and rejecting it teaches distrust of the field.
    test('minutes past sixty are accepted when no hour is given', () {
      expect(parseVideoTime('90:00'), 5400);
      expect(parseVideoTime('61:00'), 3660);
    });

    test('sixty or more seconds is a typo, every time', () {
      expect(parseVideoTime('4:75'), isNull);
      expect(parseVideoTime('1:04:60'), isNull);
    });

    test('minutes past sixty are a typo once an hour is given', () {
      expect(parseVideoTime('1:70:00'), isNull);
    });

    test('anything that is not a time is null, never zero', () {
      expect(parseVideoTime(''), isNull);
      expect(parseVideoTime('   '), isNull);
      expect(parseVideoTime('abc'), isNull);
      expect(parseVideoTime('4:ab'), isNull);
      expect(parseVideoTime('-5'), isNull);
      expect(parseVideoTime('4:-12'), isNull);
      expect(parseVideoTime('1:2:3:4'), isNull);
    });
  });

  group('formatVideoTime', () {
    test('under an hour carries no hour field', () {
      expect(formatVideoTime(0), '0:00');
      expect(formatVideoTime(7), '0:07');
      expect(formatVideoTime(252), '4:12');
      expect(formatVideoTime(3599), '59:59');
    });

    test('an hour and past it pads the minutes', () {
      expect(formatVideoTime(3600), '1:00:00');
      expect(formatVideoTime(3852), '1:04:12');
      expect(formatVideoTime(36000), '10:00:00');
    });
  });

  test('every second round-trips through both functions', () {
    for (var seconds = 0; seconds < 40000; seconds += 7) {
      expect(
        parseVideoTime(formatVideoTime(seconds)),
        seconds,
        reason: 'failed at $seconds (${formatVideoTime(seconds)})',
      );
    }
  });
}
