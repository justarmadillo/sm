/// Plain-text excerpts shared by collection lists.
library;

/// Collapses whitespace and limits [text] to [maximumCharacters].
///
/// The ellipsis occupies the final character, so every returned excerpt fits
/// the same width contract whether or not it needed truncating.
String singleLineExcerpt(String text, {required int maximumCharacters}) {
  final String singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (singleLine.length <= maximumCharacters) return singleLine;
  return '${singleLine.substring(0, maximumCharacters - 1).trimRight()}…';
}
