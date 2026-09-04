/// What a video element knows about itself, and what is left to mine in it.
library;

import 'package:incremental_reader/documents/video.dart';
import 'package:test/test.dart';

final DateTime _createdAt = DateTime.utc(2026, 1, 1);

VideoElement _element({
  String id = 'v1',
  String? parentVideoElementId,
  String? title,
  String note = '',
  int startSeconds = 0,
  int endSeconds = 1200,
  int? resumeSeconds,
}) => VideoElement(
  id: id,
  videoId: 'video-1',
  parentVideoElementId: parentVideoElementId,
  title: title,
  note: note,
  startSeconds: startSeconds,
  endSeconds: endSeconds,
  resumeSeconds: resumeSeconds,
  createdAtUtc: _createdAt,
);

void main() {
  group('what kind of range this is', () {
    test('a parent is the only thing that makes it a clip', () {
      expect(_element().isClip, isFalse);
      expect(_element(parentVideoElementId: 'v1').isClip, isTrue);
    });

    test('rangeSeconds is a length', () {
      expect(_element(startSeconds: 252, endSeconds: 450).rangeSeconds, 198);
    });
  });

  group('progress', () {
    // Nothing has been entered, so nothing is claimed. Playback is external;
    // a zero here would be a number the user never typed.
    test('is unknown until the user says where they got to', () {
      expect(_element().watchedFraction, isNull);
      expect(_element().hasReachedEnd, isFalse);
    });

    test('is measured across the range, not from the video start', () {
      final VideoElement clip = _element(
        parentVideoElementId: 'v1',
        startSeconds: 200,
        endSeconds: 400,
        resumeSeconds: 300,
      );
      expect(clip.watchedFraction, 0.5);
    });

    test('reaching the end is at or past it', () {
      expect(
        _element(endSeconds: 400, resumeSeconds: 399).hasReachedEnd,
        false,
      );
      expect(_element(endSeconds: 400, resumeSeconds: 400).hasReachedEnd, true);
    });
  });

  group('what a list calls it', () {
    test('the title when there is one', () {
      expect(
        _element(title: 'Retinal detachment').displayTitle,
        'Retinal detachment',
      );
    });

    test('the times when there is not, and when it is blank', () {
      expect(
        _element(startSeconds: 252, endSeconds: 450).displayTitle,
        '4:12 – 7:30',
      );
      expect(
        _element(title: '   ', startSeconds: 252, endSeconds: 450).displayTitle,
        '4:12 – 7:30',
      );
    });
  });

  group('secondsOutside', () {
    test('nothing cut yet leaves the whole range', () {
      expect(
        secondsOutside(
          startSeconds: 0,
          endSeconds: 100,
          covered: const <(int, int)>[],
        ),
        100,
      );
    });

    test('fully covered leaves nothing', () {
      expect(
        secondsOutside(
          startSeconds: 0,
          endSeconds: 100,
          covered: const <(int, int)>[(0, 100)],
        ),
        0,
      );
    });

    test('a gap between two clips is what is left', () {
      expect(
        secondsOutside(
          startSeconds: 0,
          endSeconds: 100,
          covered: const <(int, int)>[(0, 40), (60, 100)],
        ),
        20,
      );
    });

    test('overlapping clips are not double counted', () {
      expect(
        secondsOutside(
          startSeconds: 0,
          endSeconds: 100,
          covered: const <(int, int)>[(0, 50), (30, 70)],
        ),
        30,
      );
    });

    test('clips arrive in any order', () {
      expect(
        secondsOutside(
          startSeconds: 0,
          endSeconds: 100,
          covered: const <(int, int)>[(60, 100), (0, 40)],
        ),
        20,
      );
    });

    // A clip cut from the parent video can start before this element's own
    // range, and must not be counted as covering time outside it.
    test('clips are clamped to the range being asked about', () {
      expect(
        secondsOutside(
          startSeconds: 200,
          endSeconds: 400,
          covered: const <(int, int)>[(0, 250), (380, 900)],
        ),
        130,
      );
    });

    test('a clip entirely outside the range covers nothing', () {
      expect(
        secondsOutside(
          startSeconds: 200,
          endSeconds: 400,
          covered: const <(int, int)>[(0, 100), (500, 600)],
        ),
        200,
      );
    });
  });
}
