/// Points a converter's relative image links at the app's own image store.
///
/// Marker, and converters like it, save each figure as a file beside the
/// markdown and link it by a relative path. Once the markdown is imported
/// nothing can follow that path, so at import each link is rewritten to the
/// `ir-asset:` reference of the copy the app stored.
library;

import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/inline_markup.dart';
import 'package:incremental_reader/documents/markdown_block_parser.dart';

/// Relative image paths in [markdown], decoded and without a leading `./`,
/// each listed once, in reading order.
///
/// Found with the Reader's own parser, so exactly the images the Reader would
/// draw are listed: image syntax inside a code block is example text.
List<String> listRelativeImageReferences(String markdown) {
  final Set<String> paths = <String>{};
  for (final _ImageLink image in _imageLinks(normalizeMarkdown(markdown))) {
    final String? path = image.relativePath;
    if (path != null) paths.add(path);
  }
  return paths.toList();
}

/// [markdown] with every image whose relative path is a key of [sha256ByPath]
/// pointing at that stored copy instead.
///
/// The whole link is rewritten as `![alt](ir-asset:…)`, which drops an
/// optional title: the Reader never shows one. An image with no stored copy
/// is left exactly as written, so the Reader shows it as missing rather than
/// hiding that it was never found.
String rewriteImageReferences(
  String markdown,
  Map<String, String> sha256ByPath,
) {
  final String normalized = normalizeMarkdown(markdown);
  final StringBuffer rewritten = StringBuffer();
  var copiedUpTo = 0;
  for (final _ImageLink image in _imageLinks(normalized)) {
    final String? sha256 = sha256ByPath[image.relativePath];
    if (sha256 == null) continue;
    rewritten
      ..write(normalized.substring(copiedUpTo, image.start))
      ..write('![${image.alt}](ir-asset:$sha256)');
    copiedUpTo = image.end;
  }
  rewritten.write(normalized.substring(copiedUpTo));
  return rewritten.toString();
}

/// One image the Reader would draw, located in the whole markdown.
final class _ImageLink {
  const _ImageLink({
    required this.start,
    required this.end,
    required this.alt,
    required this.url,
  });

  /// UTF-16 index of the image's `!`.
  final int start;

  /// UTF-16 index one past the image's closing `)`.
  final int end;

  /// Alt text exactly as written, escapes included.
  final String alt;

  /// Destination with any title and angle brackets already removed.
  final String url;

  /// [url] as a path relative to the markdown file, or null when it points
  /// anywhere else: a stored copy, the web, inline data, or an absolute path.
  String? get relativePath {
    final bool hasScheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:').hasMatch(url);
    if (url.isEmpty || hasScheme) return null;
    if (url.startsWith('/') || url.startsWith(r'\') || url.startsWith('#')) {
      return null;
    }
    var path = url;
    while (path.startsWith('./')) {
      path = path.substring(2);
    }
    try {
      return Uri.decodeComponent(path);
    } on ArgumentError {
      // A lone `%` is a legal file name character; keep the path as written.
      return path;
    }
  }
}

/// Every image in [markdown], in reading order.
///
/// [markdown] must already be normalized by [normalizeMarkdown], because the
/// block offsets address exactly the text they were parsed from.
List<_ImageLink> _imageLinks(String markdown) {
  final List<_ImageLink> images = <_ImageLink>[];
  for (final Block block in parseMarkdownBlocks(
    markdown,
    sourceId: 'image-references',
  )) {
    for (final InlineSegment segment in block.inline.segments) {
      if (!segment.styles.contains(InlineStyle.image)) continue;
      final int rawStart = block.content.rawIndexAt(segment.contentStart);
      final int rawEnd = block.content.rawIndexAt(segment.contentEnd - 1) + 1;
      images.add(
        _ImageLink(
          start: block.sourceStartUtf16 + rawStart,
          end: block.sourceStartUtf16 + rawEnd,
          alt: segment.imageAlt ?? '',
          url: segment.imageUrl ?? '',
        ),
      );
    }
  }
  return images;
}
