/// A question formulated from an extract.
///
/// Formulating is a separate operation from capture, often days later, and it
/// never converts, reschedules, or removes the extract it came from: one
/// extract can produce several cards, or none at all, and still keep its own
/// place in the queue.
library;

import 'package:meta/meta.dart';

/// How a card is presented.
enum CardType {
  /// An explicit question and answer.
  qa,

  /// A passage with one or more deletions, stored in Anki's `{{c1::...}}`
  /// syntax so the text stays portable and human-readable.
  cloze,
}

/// One deletion inside a cloze card's text.
@immutable
final class ClozeDeletion {
  const ClozeDeletion({
    required this.ordinal,
    required this.start,
    required this.end,
    required this.answer,
    this.hint,
  });

  /// The `c1`, `c2`, ... number. Deletions sharing an ordinal are revealed
  /// together.
  final int ordinal;

  /// Start of the whole `{{cN::...}}` construct in the card text.
  final int start;

  /// End of the construct in the card text.
  final int end;

  /// Text hidden by this deletion.
  final String answer;

  /// Optional hint shown in place of the answer.
  final String? hint;

  @override
  bool operator ==(Object other) =>
      other is ClozeDeletion &&
      other.ordinal == ordinal &&
      other.start == start &&
      other.end == end &&
      other.answer == answer &&
      other.hint == hint;

  @override
  int get hashCode => Object.hash(ordinal, start, end, answer, hint);

  @override
  String toString() => 'ClozeDeletion(c$ordinal "$answer")';
}

/// Which kind of element a card was formulated from.
enum CardParentType {
  /// Straight from an imported article, without extracting first.
  source,

  /// From an extract, the usual path.
  extract,

  /// From a range of a video: the whole thing, or a clip cut from it.
  video,
}

/// The element a card came from.
///
/// SuperMemo has no rule that an item must descend from an extract: Alt+Z
/// works on whatever element is open, article included, and an item typed
/// into a branch has no textual parent at all. This models the same thing —
/// a parent is a reference to another element, or nothing.
@immutable
final class CardParent {
  const CardParent({required this.type, required this.id});

  /// A card formulated directly from an article.
  const CardParent.source(String id)
    : this(type: CardParentType.source, id: id);

  /// A card formulated from an extract.
  const CardParent.extract(String id)
    : this(type: CardParentType.extract, id: id);

  /// A card formulated from a video range, whose note is its text.
  const CardParent.video(String id) : this(type: CardParentType.video, id: id);

  final CardParentType type;
  final String id;

  bool get isSource => type == CardParentType.source;

  bool get isExtract => type == CardParentType.extract;

  bool get isVideo => type == CardParentType.video;

  @override
  bool operator ==(Object other) =>
      other is CardParent && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => 'CardParent(${type.name} $id)';
}

/// A formulated item the user is tested on.
@immutable
final class Card {
  const Card({
    required this.id,
    required this.parent,
    required this.type,
    required this.front,
    required this.back,
    required this.createdAtUtc,
    this.clozeOrdinal,
    this.editedAtUtc,
  });

  /// A question-and-answer card.
  factory Card.qa({
    required String id,
    required CardParent? parent,
    required String question,
    required String answer,
    required DateTime createdAtUtc,
  }) => Card(
    id: id,
    parent: parent,
    type: CardType.qa,
    front: question,
    back: answer,
    createdAtUtc: createdAtUtc.toUtc(),
  );

  /// A cloze card revealing deletion [ordinal] of [text].
  factory Card.cloze({
    required String id,
    required CardParent? parent,
    required String text,
    required int ordinal,
    required DateTime createdAtUtc,
  }) => Card(
    id: id,
    parent: parent,
    type: CardType.cloze,
    front: text,
    back: '',
    clozeOrdinal: ordinal,
    createdAtUtc: createdAtUtc.toUtc(),
  );

  final String id;

  /// Element this card was formulated from, or null for a standalone item.
  /// The parent keeps its own schedule and lifecycle regardless.
  final CardParent? parent;

  /// Parent extract id, when the parent is an extract.
  String? get extractId => parent?.isExtract ?? false ? parent!.id : null;

  /// Parent source id, when the card was formulated straight from an article.
  String? get sourceId => parent?.isSource ?? false ? parent!.id : null;

  /// Whether this is a question and answer or a cloze passage.
  ///
  /// The field keeps the name of the column it is read from. Renaming it
  /// would say nothing the type does not already say, and would leave the
  /// converter mapping `kind` to something else for no reason.
  final CardType type;

  /// Question text, or the full cloze passage.
  final String front;

  /// Answer text. Empty for cloze cards, whose answer is in [front].
  final String back;

  /// Which deletion this cloze card tests.
  final int? clozeOrdinal;

  final DateTime createdAtUtc;

  /// When the card text was last edited, including edits made during review.
  final DateTime? editedAtUtc;

  /// Every deletion in [front], for cloze cards.
  List<ClozeDeletion> get deletions => type == CardType.cloze
      ? parseClozeDeletions(front)
      : const <ClozeDeletion>[];

  Card copyWith({String? front, String? back, DateTime? editedAtUtc}) => Card(
    id: id,
    parent: parent,
    type: type,
    front: front ?? this.front,
    back: back ?? this.back,
    clozeOrdinal: clozeOrdinal,
    createdAtUtc: createdAtUtc,
    editedAtUtc: (editedAtUtc ?? this.editedAtUtc)?.toUtc(),
  );

  @override
  bool operator ==(Object other) => other is Card && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Card($id ${type.name})';
}

final RegExp _clozePattern = RegExp(r'\{\{c(\d+)::(.*?)(?:::(.*?))?\}\}');

/// Parses every `{{cN::answer}}` or `{{cN::answer::hint}}` in [text].
///
/// Ranges are derived rather than stored: the canonical syntax is the single
/// source of truth, so editing the text can never desynchronize them.
List<ClozeDeletion> parseClozeDeletions(String text) => <ClozeDeletion>[
  for (final match in _clozePattern.allMatches(text))
    ClozeDeletion(
      ordinal: int.parse(match.group(1)!),
      start: match.start,
      end: match.end,
      answer: match.group(2) ?? '',
      hint: match.group(3),
    ),
];

/// The distinct deletion ordinals present in [text], ascending.
List<int> clozeOrdinals(String text) {
  final ordinals = <int>{
    for (final deletion in parseClozeDeletions(text)) deletion.ordinal,
  }.toList()..sort();
  return ordinals;
}

/// [text] with deletion [ordinal] hidden and the others revealed.
String renderClozeQuestion(String text, int ordinal, {String blank = '[...]'}) {
  final buffer = StringBuffer();
  var cursor = 0;
  for (final deletion in parseClozeDeletions(text)) {
    buffer.write(text.substring(cursor, deletion.start));
    if (deletion.ordinal == ordinal) {
      buffer.write(deletion.hint == null ? blank : '[${deletion.hint}]');
    } else {
      buffer.write(deletion.answer);
    }
    cursor = deletion.end;
  }
  buffer.write(text.substring(cursor));
  return buffer.toString();
}

/// [text] with every deletion revealed.
String renderClozeAnswer(String text) {
  final buffer = StringBuffer();
  var cursor = 0;
  for (final deletion in parseClozeDeletions(text)) {
    buffer.write(text.substring(cursor, deletion.start));
    buffer.write(deletion.answer);
    cursor = deletion.end;
  }
  buffer.write(text.substring(cursor));
  return buffer.toString();
}
