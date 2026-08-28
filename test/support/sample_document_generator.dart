/// A deterministic long-document generator.
///
/// M0 has to prove the Reader on the size of source it will actually meet —
/// 10–50k-word chapters — before any of the import pipeline exists. The output
/// is seeded, so a scroll or anchor test that fails once fails again.
library;

import 'dart:math';

const List<String> _words = <String>[
  'memory',
  'interval',
  'retrieval',
  'schedule',
  'extract',
  'passage',
  'attention',
  'priority',
  'queue',
  'encoding',
  'consolidation',
  'forgetting',
  'cortex',
  'hippocampus',
  'protocol',
  'evidence',
  'threshold',
  'stability',
  'difficulty',
  'retention',
  'spacing',
  'lapse',
  'formulation',
  'context',
  'inference',
  'compression',
  'abstraction',
  'hierarchy',
  'provenance',
  'boundary',
  'transition',
  'invariant',
  'cadence',
  'gradient',
  'signal',
];

const List<String> _unicodeWords = <String>[
  'café',
  'naïve',
  '日本語',
  'Größe',
  'ελληνικά',
  'мозг',
  '👍',
  'σ-algebra',
];

/// Generates roughly [targetWords] words of structured markdown.
///
/// The document mixes every construct the Reader must map exactly, so a
/// performance fixture doubles as a correctness fixture.
String generateSampleMarkdown({
  required int targetWords,
  int seed = 20260820,
  String title = 'Sample Chapter',
}) {
  final random = Random(seed);
  final buffer = StringBuffer()
    ..writeln('# $title')
    ..writeln();

  var words = 0;
  var section = 0;

  String sentence(int length) {
    final parts = <String>[];
    for (var i = 0; i < length; i++) {
      final useUnicode = random.nextInt(40) == 0;
      final word = useUnicode
          ? _unicodeWords[random.nextInt(_unicodeWords.length)]
          : _words[random.nextInt(_words.length)];
      parts.add(switch (random.nextInt(24)) {
        0 => '**$word**',
        1 => '*$word*',
        2 => '`$word()`',
        3 => '[$word](https://example.com/$word)',
        _ => word,
      });
    }
    words += length;
    final text = parts.join(' ');
    return '${text[0].toUpperCase()}${text.substring(1)}.';
  }

  String paragraph() {
    final sentences = <String>[
      for (var i = 0; i < 3 + random.nextInt(4); i++)
        sentence(8 + random.nextInt(12)),
    ];
    return sentences.join(' ');
  }

  while (words < targetWords) {
    section++;
    buffer
      ..writeln('## Section $section')
      ..writeln();

    for (var i = 0; i < 2 + random.nextInt(3); i++) {
      buffer
        ..writeln(paragraph())
        ..writeln();
    }

    switch (section % 5) {
      case 0:
        buffer.writeln('```dart');
        buffer.writeln('int interval(int step) => step * ${section % 7 + 1};');
        buffer.writeln('```');
        words += 8;
      case 1:
        for (var i = 1; i <= 3; i++) {
          buffer.writeln('- ${sentence(6 + random.nextInt(6))}');
        }
      case 2:
        buffer.writeln('> ${sentence(10)}');
        buffer.writeln('> ${sentence(8)}');
      case 3:
        buffer.writeln(r'$$');
        buffer.writeln(r'\int_0^{\infty} e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}');
        buffer.writeln(r'$$');
        words += 10;
      case 4:
        buffer.writeln('| Step | Interval |');
        buffer.writeln('|------|----------|');
        for (var i = 1; i <= 3; i++) {
          buffer.writeln('| $i | ${i * section} days |');
        }
        words += 12;
    }
    buffer.writeln();
  }

  return buffer.toString();
}
