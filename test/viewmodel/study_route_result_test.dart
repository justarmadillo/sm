/// What a study screen reports back to the session loop.
///
/// The distinction exists because ending a visit and completing a repetition
/// are different events: Later Today and Dismiss both close the screen, and
/// neither advances a schedule.
library;

import 'package:incremental_reader/src/features/queue/presentation/study_route_result.dart';
import 'package:test/test.dart';

void main() {
  test('a repetition both advances the session and is counted', () {
    expect(StudyRouteResult.committed.advancesSession, isTrue);
    expect(StudyRouteResult.committed.isRepetition, isTrue);
  });

  test('a move advances the session without being counted', () {
    // This is what made "completed this session" climb on every press of
    // Study: Later Today closed the reader and the loop counted it as work.
    expect(StudyRouteResult.moved.advancesSession, isTrue);
    expect(StudyRouteResult.moved.isRepetition, isFalse);
  });

  test('cancelling stops the session and counts nothing', () {
    expect(StudyRouteResult.canceled.advancesSession, isFalse);
    expect(StudyRouteResult.canceled.isRepetition, isFalse);
  });
}
