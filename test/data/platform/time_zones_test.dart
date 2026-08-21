import 'package:incremental_reader/src/data/platform/time_zones.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:test/test.dart';

void main() {
  group('named home timezone resolution', () {
    test('uses real IANA DST rules instead of one fixed offset', () {
      final TimeZoneRules berlin = resolveTimeZone('Europe/Berlin');

      expect(berlin.zoneId, 'Europe/Berlin');
      expect(berlin.offsetMinutesAt(DateTime.utc(2026, 1, 15)), 60);
      expect(berlin.offsetMinutesAt(DateTime.utc(2026, 7, 15)), 120);
    });

    test('maps Windows names through the canonical CLDR zone', () {
      final TimeZoneRules berlin = resolveTimeZone('W. Europe Standard Time');
      final TimeZoneRules newYork = resolveTimeZone('eastern standard time');

      expect(berlin.zoneId, 'Europe/Berlin');
      expect(newYork.zoneId, 'America/New_York');
    });

    test('every shipped Windows mapping exists in the bundled database', () {
      for (final String windowsId in windowsTimeZoneMappings.keys) {
        expect(
          () => resolveTimeZone(windowsId),
          returnsNormally,
          reason: windowsId,
        );
      }
    });

    test('fails closed for machine, numeric, and unknown zones', () {
      for (final String id in <String>[
        '',
        'system',
        'UTC+01:00',
        'Europe/Definitely_Not_A_Zone',
      ]) {
        expect(
          () => resolveTimeZone(id),
          throwsA(isA<UnknownTimeZoneException>()),
          reason: id,
        );
      }
    });

    test('offers named IANA zones rather than machine/fixed offsets', () {
      expect(selectableZoneIds, containsAll(<String>['UTC', 'Europe/Berlin']));
      expect(selectableZoneIds, isNot(contains('system')));
      expect(selectableZoneIds, isNot(contains('UTC+01:00')));
      expect(selectableZoneIds, isNot(contains('Etc/GMT-1')));
    });
  });

  group('04:00 StudyDay in Europe/Berlin', () {
    final TimeZoneRules berlin = resolveTimeZone('Europe/Berlin');
    late StudyDayCalendar calendar;

    setUp(() {
      calendar = StudyDayCalendar(zone: berlin);
    });

    test('spring-forward rollover uses the post-transition offset', () {
      expect(
        calendar.dayOf(DateTime.utc(2026, 3, 29, 1, 59, 59)).toString(),
        '2026-03-28',
      );
      expect(
        calendar.dayOf(DateTime.utc(2026, 3, 29, 2)).toString(),
        '2026-03-29',
      );

      final StudyDay day = StudyDay.parse(
        '2026-03-29',
        zoneId: 'Europe/Berlin',
      );
      expect(calendar.startOfDayUtc(day), DateTime.utc(2026, 3, 29, 2));
    });

    test('fall-back rollover uses the post-transition offset', () {
      expect(
        calendar.dayOf(DateTime.utc(2026, 10, 25, 2, 59, 59)).toString(),
        '2026-10-24',
      );
      expect(
        calendar.dayOf(DateTime.utc(2026, 10, 25, 3)).toString(),
        '2026-10-25',
      );

      final StudyDay day = StudyDay.parse(
        '2026-10-25',
        zoneId: 'Europe/Berlin',
      );
      expect(calendar.startOfDayUtc(day), DateTime.utc(2026, 10, 25, 3));
    });

    test('clock rollback keeps exact instants ordered in one StudyDay', () {
      // Both instants display as 02:30 locally, on opposite sides of the fold.
      final DateTime firstOccurrence = DateTime.utc(2026, 10, 25, 0, 30);
      final DateTime secondOccurrence = DateTime.utc(2026, 10, 25, 1, 30);

      expect(firstOccurrence.isBefore(secondOccurrence), isTrue);
      expect(calendar.dayOf(firstOccurrence).toString(), '2026-10-24');
      expect(calendar.dayOf(secondOccurrence).toString(), '2026-10-24');
    });

    test('restarting near rollover produces the same boundary', () {
      final DateTime before = DateTime.utc(2026, 3, 29, 1, 59, 59);
      final DateTime after = DateTime.utc(2026, 3, 29, 2);
      final StudyDayCalendar restarted = StudyDayCalendar(
        zone: resolveTimeZone('Europe/Berlin'),
      );

      expect(restarted.dayOf(before), calendar.dayOf(before));
      expect(restarted.dayOf(after), calendar.dayOf(after));
      expect(
        restarted.startOfDayUtc(restarted.dayOf(after)),
        calendar.startOfDayUtc(calendar.dayOf(after)),
      );
    });

    test('travel does not substitute the destination or machine zone', () {
      final DateTime instant = DateTime.utc(2026, 3, 5, 3, 30);
      final StudyDay historical = calendar.dayOf(instant);
      final StudyDayCalendar destination = StudyDayCalendar(
        zone: resolveTimeZone('America/New_York'),
      );

      expect(historical.toString(), '2026-03-05');
      expect(historical.zoneId, 'Europe/Berlin');
      expect(destination.dayOf(instant).toString(), '2026-03-04');
      expect(
        () => destination.startOfDayUtc(historical),
        throwsArgumentError,
        reason: 'a historical StudyDay must not be reinterpreted in a new zone',
      );
      expect(historical.zoneId, 'Europe/Berlin');
    });

    test('intraday UTC instants remain ordered across rollover', () {
      final DateTime before = DateTime.utc(2026, 3, 29, 1, 59, 59);
      final DateTime after = DateTime.utc(2026, 3, 29, 2);

      expect(before.isBefore(after), isTrue);
      expect(calendar.dayOf(before).addDays(1), calendar.dayOf(after));
    });
  });
}
