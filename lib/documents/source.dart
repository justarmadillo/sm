/// An imported document the user reads incrementally.
///
/// A source is an immutable markdown snapshot plus a reading position. It is
/// never "read" or "unread": position answers *how far have I processed this*,
/// and the element's schedule answers *when do I process more*. Conflating the
/// two is the single most common way to get incremental reading wrong, so they
/// live in different aggregates entirely — schedule and priority are not on
/// this class.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:incremental_reader/documents/markdown_block_parser.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:meta/meta.dart';

/// The place a reader continues from.
///
/// Two markers, deliberately: the explicit one is authoritative and drives
/// scheduling; the soft one is a safety net for a session that ended without
/// the user placing a marker. Only the explicit marker counts as progress.
@immutable
final class ResumePosition {
  const ResumePosition({this.marker, this.softPosition});

  /// Nothing recorded yet: reading starts at the top.
  static const ResumePosition none = ResumePosition();

  /// Explicitly placed by the user and authoritative for scheduling.
  final ReaderAnchor? marker;

  /// Last stable scroll position, auto-persisted on pause, close, or process
  /// death. Shown as a secondary indicator; never counts as progress.
  final ReaderAnchor? softPosition;

  /// Where the reader should open, preferring the explicit marker.
  ReaderAnchor? get openAt => marker ?? softPosition;

  /// Whether the soft position is ahead of the explicit marker and therefore
  /// worth showing as a distinct "you were here" indicator.
  bool get hasUnconfirmedPosition =>
      softPosition != null && softPosition != marker;

  ResumePosition withMarker(ReaderAnchor anchor) =>
      ResumePosition(marker: anchor, softPosition: softPosition);

  ResumePosition withSoftPosition(ReaderAnchor anchor) =>
      ResumePosition(marker: marker, softPosition: anchor);

  /// Promotes the soft position to the authoritative marker.
  ResumePosition confirmSoftPosition() {
    final soft = softPosition;
    if (soft == null) return this;
    return ResumePosition(marker: soft, softPosition: soft);
  }

  @override
  bool operator ==(Object other) =>
      other is ResumePosition &&
      other.marker == marker &&
      other.softPosition == softPosition;

  @override
  int get hashCode => Object.hash(marker, softPosition);

  @override
  String toString() => 'ResumePosition(marker: $marker, soft: $softPosition)';
}

/// An imported document at one revision of its text.
@immutable
final class Source {
  const Source({
    required this.id,
    required this.title,
    required this.markdown,
    required this.contentHash,
    required this.wordCount,
    required this.importedAtUtc,
    this.resume = ResumePosition.none,
    this.contentRevision = kInitialContentRevision,
  });

  /// Builds a source from raw markdown, normalizing and hashing it.
  ///
  /// Importing changed content creates a new source rather than mutating this
  /// one: every anchor in the collection addresses [markdown] exactly.
  factory Source.import({
    required String id,
    required String title,
    required String markdown,
    required DateTime importedAtUtc,
  }) {
    final normalized = normalizeMarkdown(markdown);
    return Source(
      id: id,
      title: title,
      markdown: normalized,
      contentHash: sha256.convert(utf8.encode(normalized)).toString(),
      wordCount: countWords(normalized),
      importedAtUtc: importedAtUtc.toUtc(),
    );
  }

  final String id;
  final String title;

  /// Normalized markdown at [contentRevision]. Every anchor addresses it.
  final String markdown;

  /// Version of [markdown], advanced by one per applied splice.
  final int contentRevision;

  /// Lowercase hex SHA-256 of [markdown].
  final String contentHash;

  /// Approximate word count, used for the reminder line and progress.
  final int wordCount;

  final DateTime importedAtUtc;

  /// Explicit and soft reading positions.
  final ResumePosition resume;

  Source copyWith({
    String? title,
    ResumePosition? resume,
    String? markdown,
    String? contentHash,
    int? wordCount,
    int? contentRevision,
  }) => Source(
    id: id,
    title: title ?? this.title,
    markdown: markdown ?? this.markdown,
    contentHash: contentHash ?? this.contentHash,
    wordCount: wordCount ?? this.wordCount,
    importedAtUtc: importedAtUtc,
    resume: resume ?? this.resume,
    contentRevision: contentRevision ?? this.contentRevision,
  );

  /// The same source carrying [text] as its markdown at [contentRevision].
  ///
  /// Hash and word count are re-derived here so no caller can persist a
  /// source whose summary fields disagree with its text.
  Source withMarkdown(String text, {required int contentRevision}) => Source(
    id: id,
    title: title,
    markdown: text,
    contentHash: sha256.convert(utf8.encode(text)).toString(),
    wordCount: countWords(text),
    importedAtUtc: importedAtUtc,
    resume: resume,
    contentRevision: contentRevision,
  );

  @override
  bool operator ==(Object other) => other is Source && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Source($id "$title" $wordCount words)';
}

/// Counts whitespace-separated words in [text].
int countWords(String text) {
  var count = 0;
  var inWord = false;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    final isSpace =
        unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D;
    if (isSpace) {
      inWord = false;
    } else if (!inWord) {
      inWord = true;
      count++;
    }
  }
  return count;
}
