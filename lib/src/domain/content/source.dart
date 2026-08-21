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
import 'package:meta/meta.dart';

import 'markdown_block_parser.dart';
import 'reader_anchor.dart';

/// Which topic interval sequence paces a source.
enum ReadingPace {
  /// `1,2,3,5,7,10,14,21,30` — material being worked through now.
  focused,

  /// `1,3,7,14,30,60,120,240,365` — the default.
  normal,

  /// `7,14,30,60,120,240,365,730` — background material.
  slow,
}

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

/// An immutable imported document.
@immutable
final class Source {
  const Source({
    required this.id,
    required this.title,
    required this.markdown,
    required this.contentHash,
    required this.wordCount,
    required this.importedAtUtc,
    this.pace = ReadingPace.normal,
    this.resume = ResumePosition.none,
    this.folderId,
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
    ReadingPace pace = ReadingPace.normal,
    String? folderId,
  }) {
    final normalized = normalizeMarkdown(markdown);
    return Source(
      id: id,
      title: title,
      markdown: normalized,
      contentHash: sha256.convert(utf8.encode(normalized)).toString(),
      wordCount: countWords(normalized),
      importedAtUtc: importedAtUtc.toUtc(),
      pace: pace,
      folderId: folderId,
    );
  }

  final String id;
  final String title;

  /// Normalized original markdown. Never edited after import.
  final String markdown;

  /// Lowercase hex SHA-256 of [markdown].
  final String contentHash;

  /// Approximate word count, used for the reminder line and progress.
  final int wordCount;

  final DateTime importedAtUtc;

  /// Interval sequence this source is paced by.
  final ReadingPace pace;

  /// Explicit and soft reading positions.
  final ResumePosition resume;

  /// Folder in the user-organized upper tree, or null when unfiled.
  final String? folderId;

  Source copyWith({
    String? title,
    ReadingPace? pace,
    ResumePosition? resume,
    String? folderId,
    bool clearFolder = false,
  }) => Source(
    id: id,
    title: title ?? this.title,
    markdown: markdown,
    contentHash: contentHash,
    wordCount: wordCount,
    importedAtUtc: importedAtUtc,
    pace: pace ?? this.pace,
    resume: resume ?? this.resume,
    folderId: clearFolder ? null : (folderId ?? this.folderId),
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
