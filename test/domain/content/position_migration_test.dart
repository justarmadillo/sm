/// The migration rules, exhaustively, plus the property that protects them.
///
/// This is the load-bearing test of the editable reader. Every stored position
/// in the collection moves through `migrateOffset`, and the one failure mode
/// that matters is not a crash — it is a position that lands somewhere
/// plausible and wrong. The property test at the end is the guard against
/// exactly that: it checks the *characters* a position points at, not the
/// number it holds.
library;

import 'dart:math';

import 'package:incremental_reader/src/core/utf8_offsets.dart';
import 'package:incremental_reader/src/domain/content/position_migration.dart';
import 'package:incremental_reader/src/domain/content/reader_anchor.dart';
import 'package:incremental_reader/src/domain/content/text_splice.dart';
import 'package:test/test.dart';

void main() {
  group('the three rules', () {
    // Replaces bytes 10..20 with four bytes: shift = -6.
    final splice = TextSplice.normalized(
      startUtf8: 10,
      endUtf8: 20,
      inserted: 'abcd',
    );

    test('a position before the edit does not move', () {
      expect(migrateOffset(0, splice), const MigratedPosition(0));
      expect(migrateOffset(9, splice), const MigratedPosition(9));
    });

    test('a position after the edit shifts by the exact difference', () {
      expect(splice.shift, -6);
      expect(migrateOffset(21, splice), const MigratedPosition(15));
      expect(migrateOffset(100, splice), const MigratedPosition(94));
    });

    test('a position inside the removed text collapses and is reported', () {
      expect(
        migrateOffset(15, splice),
        const MigratedPosition(10, wasInsideEdit: true),
      );
    });

    test('the leading boundary stays where it was', () {
      expect(migrateOffset(10, splice), const MigratedPosition(10));
    });

    test('the trailing boundary lands after the inserted text', () {
      // Not at `a`: the position that was at the end of the replaced range is
      // now at the end of what replaced it.
      expect(migrateOffset(20, splice), const MigratedPosition(14));
    });

    test('a pure deletion puts the trailing boundary at the start', () {
      final deletion = TextSplice.delete(10, 20);
      expect(migrateOffset(20, deletion), const MigratedPosition(10));
    });
  });

  group('gravity', () {
    final insertion = TextSplice.normalized(
      startUtf8: 10,
      endUtf8: 10,
      inserted: 'new text',
    );

    test('left gravity keeps a position before text inserted at it', () {
      // A reading marker: text typed at the marker has not been read, so the
      // marker must not jump over it.
      expect(
        migrateOffset(10, insertion, gravity: PositionGravity.left),
        const MigratedPosition(10),
      );
    });

    test('right gravity moves a position after text inserted at it', () {
      expect(
        migrateOffset(10, insertion, gravity: PositionGravity.right),
        MigratedPosition(10 + insertion.insertedLength),
      );
    });

    test('an insertion at a boundary never counts as inside the edit', () {
      for (final gravity in PositionGravity.values) {
        expect(
          migrateOffset(10, insertion, gravity: gravity).wasInsideEdit,
          isFalse,
        );
      }
    });
  });

  group('ranges', () {
    test('a range does not grow when text is typed at its start', () {
      final splice = TextSplice.normalized(
        startUtf8: 10,
        endUtf8: 10,
        inserted: 'xyz',
      );
      final migrated = migrateRange(10, 20, splice);
      expect(migrated.startUtf8, 13, reason: 'start has right gravity');
      expect(migrated.endUtf8, 23);
      expect(migrated.touchedByEdit, isFalse);
    });

    test('a range does not grow when text is typed at its end', () {
      final splice = TextSplice.normalized(
        startUtf8: 20,
        endUtf8: 20,
        inserted: 'xyz',
      );
      final migrated = migrateRange(10, 20, splice);
      expect(migrated.startUtf8, 10);
      expect(migrated.endUtf8, 20, reason: 'end has left gravity');
      expect(migrated.touchedByEdit, isFalse);
    });

    test('an insertion strictly inside a range does touch it', () {
      final splice = TextSplice.normalized(
        startUtf8: 15,
        endUtf8: 15,
        inserted: 'xyz',
      );
      final migrated = migrateRange(10, 20, splice);
      expect(migrated.touchedByEdit, isTrue);
      expect(migrated.endUtf8, 23);
    });

    test('deleting the whole range empties it', () {
      final migrated = migrateRange(10, 20, TextSplice.delete(5, 25));
      expect(migrated.isEmpty, isTrue);
      expect(migrated.startUtf8, 5);
      expect(migrated.touchedByEdit, isTrue);
    });

    test('a range entirely before the edit is untouched', () {
      final migrated = migrateRange(0, 5, TextSplice.delete(10, 20));
      expect(migrated, const MigratedRange(
        startUtf8: 0,
        endUtf8: 5,
        touchedByEdit: false,
      ));
    });

    test('a range entirely after the edit shifts but is untouched', () {
      final migrated = migrateRange(30, 40, TextSplice.delete(10, 20));
      expect(migrated.startUtf8, 20);
      expect(migrated.endUtf8, 30);
      expect(migrated.touchedByEdit, isFalse);
    });

    test('a migrated range is never inverted', () {
      final migrated = migrateRange(12, 14, TextSplice.delete(10, 20));
      expect(migrated.startUtf8, lessThanOrEqualTo(migrated.endUtf8));
    });
  });

  group('property: an edit never relocates a surviving position', () {
    // The contract, stated exactly. For a splice replacing `[a, b)`:
    //
    // * a position at or before `a` keeps every character before it, so the
    //   text preceding it is byte-identical afterwards;
    // * a position at or after `b` keeps every character after it, so the text
    //   following it is byte-identical afterwards;
    // * a position strictly between them pointed at text that no longer
    //   exists, and must say so.
    //
    // Checking the surrounding *text* rather than the arithmetic is the point:
    // an off-by-one that still produces a legal offset would pass a numeric
    // assertion and fail this one.
    test('across 400 random splice sequences', () {
      final random = Random(20260827);

      for (var trial = 0; trial < 400; trial++) {
        var text = _randomText(random);
        var positions = <int?>[
          for (var i = 0; i < 12; i++) _boundary(text, random),
        ];

        for (var step = 0; step < 6 && text.isNotEmpty; step++) {
          final splice = _randomSplice(text, random);
          if (splice.validateAgainst(text) != null) continue;
          final next = splice.applyTo(text);

          final migrated = <int?>[];
          for (final position in positions) {
            if (position == null) {
              migrated.add(null);
              continue;
            }
            final result = migrateOffset(position, splice);
            final where =
                'trial $trial step $step: offset $position across $splice';

            if (result.wasInsideEdit) {
              expect(
                position > splice.startUtf8 && position < splice.endUtf8,
                isTrue,
                reason: '$where was reported lost but was not inside the edit',
              );
              // Its text is gone; it promises nothing from here on.
              migrated.add(null);
              continue;
            }

            if (position <= splice.startUtf8) {
              expect(
                _prefix(next, result.utf8Offset),
                _prefix(text, position),
                reason: '$where should have kept the text before it',
              );
            } else {
              expect(
                position >= splice.endUtf8,
                isTrue,
                reason: '$where fell inside the edit without being reported',
              );
              expect(
                _suffix(next, result.utf8Offset),
                _suffix(text, position),
                reason: '$where should have kept the text after it',
              );
            }
            migrated.add(result.utf8Offset);
          }

          positions = migrated;
          text = next;
        }
      }
    });

    test('every offset a splice produces lands on a character boundary', () {
      final random = Random(4242);
      for (var trial = 0; trial < 200; trial++) {
        var text = _randomText(random);
        for (var step = 0; step < 4 && text.isNotEmpty; step++) {
          final splice = _randomSplice(text, random);
          if (splice.validateAgainst(text) != null) continue;
          final next = splice.applyTo(text);
          final index = Utf8OffsetIndex(next);
          for (final probe in <int>[
            0,
            splice.startUtf8,
            splice.endUtf8,
            utf8Length(text),
          ]) {
            for (final gravity in PositionGravity.values) {
              final migrated = migrateOffset(
                probe,
                splice,
                gravity: gravity,
              ).utf8Offset;
              expect(
                index.toUtf8(index.toUtf16(migrated)),
                migrated,
                reason: 'migration produced a mid-character offset',
              );
              expect(migrated, inInclusiveRange(0, index.byteLength));
            }
          }
          text = next;
        }
      }
    });
  });
}

/// Everything before [offset], for comparing what a position still sits after.
String _prefix(String text, int offset) {
  final index = Utf8OffsetIndex(text);
  return text.substring(0, index.toUtf16(offset.clamp(0, index.byteLength)));
}

/// Everything from [offset] on.
String _suffix(String text, int offset) {
  final index = Utf8OffsetIndex(text);
  return text.substring(index.toUtf16(offset.clamp(0, index.byteLength)));
}

/// A byte offset that is guaranteed to sit on a character boundary.
int _boundary(String text, Random random) {
  final index = Utf8OffsetIndex(text);
  if (text.isEmpty) return 0;
  return index.toUtf8(random.nextInt(text.length + 1));
}

TextSplice _randomSplice(String text, Random random) {
  final a = _boundary(text, random);
  final b = _boundary(text, random);
  final start = a <= b ? a : b;
  final end = a <= b ? b : a;
  final inserted = random.nextBool() ? _randomText(random, short: true) : '';
  if (start == end && inserted.isEmpty) return TextSplice.delete(start, end + 1);
  return TextSplice(startUtf8: start, endUtf8: end, inserted: inserted);
}

/// Text with plenty of multi-byte characters, so boundary handling is
/// exercised rather than assumed.
String _randomText(Random random, {bool short = false}) {
  const alphabet = <String>[
    'a',
    'b',
    ' ',
    '\n',
    'é', // two bytes
    '中', // three bytes
    '🌱', // four bytes, a surrogate pair in Dart
    '**',
    '# ',
  ];
  final length = short ? 1 + random.nextInt(8) : 20 + random.nextInt(60);
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(alphabet[random.nextInt(alphabet.length)]);
  }
  return buffer.toString();
}
