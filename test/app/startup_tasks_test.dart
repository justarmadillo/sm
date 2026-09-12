/// Automatic backup cadence decisions at application startup.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/startup_tasks.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/settings/backup_settings.dart';

void main() {
  const StudyDay today = StudyDay(
    year: 2026,
    month: 9,
    day: 9,
    zoneId: 'Europe/Berlin',
  );

  test('daily backup is due on the next study day', () {
    expect(
      isAutomaticBackupDue(
        today: today,
        lastBackupDay: '2026-09-08',
        interval: AutomaticBackupInterval.daily,
      ),
      isTrue,
    );
    expect(
      isAutomaticBackupDue(
        today: today,
        lastBackupDay: '2026-09-09',
        interval: AutomaticBackupInterval.daily,
      ),
      isFalse,
    );
  });

  test('three-day and weekly intervals use elapsed study days', () {
    expect(
      isAutomaticBackupDue(
        today: today,
        lastBackupDay: '2026-09-06',
        interval: AutomaticBackupInterval.everyThreeDays,
      ),
      isTrue,
    );
    expect(
      isAutomaticBackupDue(
        today: today,
        lastBackupDay: '2026-09-03',
        interval: AutomaticBackupInterval.weekly,
      ),
      isFalse,
    );
    expect(
      isAutomaticBackupDue(
        today: today,
        lastBackupDay: '2026-09-02',
        interval: AutomaticBackupInterval.weekly,
      ),
      isTrue,
    );
  });

  test('missing or malformed bookkeeping never disables backups', () {
    for (final String? lastBackupDay in <String?>[null, '', 'not-a-day']) {
      expect(
        isAutomaticBackupDue(
          today: today,
          lastBackupDay: lastBackupDay,
          interval: AutomaticBackupInterval.weekly,
        ),
        isTrue,
      );
    }
  });
}
