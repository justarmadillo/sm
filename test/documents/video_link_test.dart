/// Platform detection and the timestamped links built from it.
///
/// The property under test is not "the URL is right" but "the app never
/// claims a timestamp it did not deliver": `hasTimestamp` is what the screen
/// renders its seek hint from, so a false positive there is what makes the
/// app look broken on an unsupported site.
library;

import 'package:incremental_reader/documents/video.dart';
import 'package:incremental_reader/documents/video_link.dart';
import 'package:test/test.dart';

void main() {
  group('detectVideoPlatform', () {
    test('every YouTube host the user might paste', () {
      for (final String url in <String>[
        'https://www.youtube.com/watch?v=abc123',
        'https://youtube.com/watch?v=abc123',
        'https://m.youtube.com/watch?v=abc123',
        'https://youtu.be/abc123',
        'HTTPS://WWW.YOUTUBE.COM/watch?v=abc123',
      ]) {
        expect(detectVideoPlatform(url), VideoPlatform.youtube, reason: url);
      }
    });

    test('vumedi', () {
      expect(
        detectVideoPlatform('https://www.vumedi.com/video/some-talk/'),
        VideoPlatform.vumedi,
      );
    });

    test('anything else is other, including nonsense', () {
      expect(
        detectVideoPlatform('https://example.com/talk'),
        VideoPlatform.other,
      );
      expect(detectVideoPlatform('not a url'), VideoPlatform.other);
      expect(detectVideoPlatform(''), VideoPlatform.other);
    });

    // A path or a title that mentions YouTube is not a YouTube link, and
    // treating it as one builds a parameter for the wrong player.
    test('the host decides, not the rest of the URL', () {
      expect(
        detectVideoPlatform('https://example.com/youtube.com/watch?v=x'),
        VideoPlatform.other,
      );
    });
  });

  group('videoOpenLink on YouTube', () {
    test('adds the time to a URL that already has a query', () {
      expect(
        videoOpenLink(
          url: 'https://www.youtube.com/watch?v=abc123',
          platform: VideoPlatform.youtube,
          atSeconds: 252,
        ),
        const VideoOpenLink(
          url: 'https://www.youtube.com/watch?v=abc123&t=252s',
          hasTimestamp: true,
        ),
      );
    });

    test('adds the time to a URL that has no query', () {
      expect(
        videoOpenLink(
          url: 'https://youtu.be/abc123',
          platform: VideoPlatform.youtube,
          atSeconds: 252,
        ),
        const VideoOpenLink(
          url: 'https://youtu.be/abc123?t=252s',
          hasTimestamp: true,
        ),
      );
    });

    // Two `t` parameters are undefined, and a link copied out of YouTube at
    // some other moment already carries one.
    test('replaces a timestamp the pasted link already carried', () {
      expect(
        videoOpenLink(
          url: 'https://youtu.be/abc123?t=10s',
          platform: VideoPlatform.youtube,
          atSeconds: 252,
        ).url,
        'https://youtu.be/abc123?t=252s',
      );
    });

    test('zero is still a timestamp', () {
      expect(
        videoOpenLink(
          url: 'https://youtu.be/abc123',
          platform: VideoPlatform.youtube,
          atSeconds: 0,
        ),
        const VideoOpenLink(
          url: 'https://youtu.be/abc123?t=0s',
          hasTimestamp: true,
        ),
      );
    });
  });

  group('videoOpenLink everywhere else', () {
    test('vumedi is returned untouched and says so', () {
      const String url = 'https://www.vumedi.com/video/some-talk/';
      expect(
        videoOpenLink(url: url, platform: VideoPlatform.vumedi, atSeconds: 252),
        const VideoOpenLink(url: url, hasTimestamp: false),
      );
    });

    test('an unknown site is returned untouched and says so', () {
      const String url = 'https://example.com/talk?ref=1';
      expect(
        videoOpenLink(url: url, platform: VideoPlatform.other, atSeconds: 252),
        const VideoOpenLink(url: url, hasTimestamp: false),
      );
    });
  });
}
