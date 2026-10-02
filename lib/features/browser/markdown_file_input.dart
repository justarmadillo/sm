/// Opens a markdown file, or a zip of one, together with the images it links.
///
/// Marker, the PDF converter, writes a folder: the markdown plus one image
/// file per figure, linked by relative paths. Reading only the markdown loses
/// every figure, so the files it links are read here too and handed on with it,
/// already validated, while the links are pointed at their `ir-asset:` copies.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:incremental_reader/documents/markdown_block_parser.dart';
import 'package:incremental_reader/documents/markdown_image_references.dart';
import 'package:incremental_reader/documents/marker_cleanup.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/reader/reader_image_input.dart';
import 'package:path/path.dart' as p;

/// Most bytes one zip may have read out of it: the markdown and its images.
const int _kMaximumZipBytes = 1024 * 1024 * 1024;

/// What an opened file holds, ready for the topic page.
@immutable
final class MarkdownWithImages {
  const MarkdownWithImages({
    required this.markdown,
    required this.fileName,
    required this.images,
    required this.missingImageCount,
    this.shouldZipFolderForImages = false,
  });

  /// Markdown whose images that were found point at their stored copies.
  final String markdown;

  /// Name of the opened file, the title when the markdown has no heading.
  final String fileName;

  /// Validated images the markdown links, not yet stored.
  final List<SourceImageImport> images;

  /// Linked images that were not found or could not be shown. Their links
  /// stay as written, so the Reader marks each one as missing.
  final int missingImageCount;

  /// Whether the images were left behind because only the markdown file, not
  /// its folder, reached the app. On Android a picked file arrives alone.
  final bool shouldZipFolderForImages;
}

/// User-facing reason an opened file cannot become a topic.
final class MarkdownFileInputException implements Exception {
  const MarkdownFileInputException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Platform-neutral seam used by the topic page and replaced by widget tests.
abstract interface class MarkdownFileInput {
  /// The chosen file's markdown and images, or null when nothing was chosen.
  Future<MarkdownWithImages?> chooseMarkdownFile();
}

/// Uses the platform's own file picker.
final class SystemMarkdownFileInput implements MarkdownFileInput {
  const SystemMarkdownFileInput();

  static const List<String> _extensions = <String>[
    'md',
    'markdown',
    'txt',
    'zip',
  ];

  @override
  Future<MarkdownWithImages?> chooseMarkdownFile() async {
    if (Platform.isAndroid) return _chooseOnAndroid();
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'Markdown or zip', extensions: _extensions),
      ],
    );
    if (file == null) return null;
    return readMarkdownFile(File(file.path), canReadFolder: true);
  }

  /// Android's document picker copies the file by path. file_selector would
  /// pass the whole zip through the method channel instead, which a folder of
  /// figures makes slow and memory-hungry.
  Future<MarkdownWithImages?> _chooseOnAndroid() async {
    final String? path = await FlutterFileDialog.pickFile(
      params: const OpenFileDialogParams(
        fileExtensionsFilter: _extensions,
        copyFileToCacheDir: true,
      ),
    );
    if (path == null) return null;
    final File copy = File(path);
    try {
      return await readMarkdownFile(copy, canReadFolder: false);
    } finally {
      try {
        if (copy.existsSync()) await copy.delete();
      } on FileSystemException {
        // Android may still hold the picker copy; its cache policy removes it.
      }
    }
  }
}

/// Reads [file], markdown or a zip holding one markdown file, together with
/// the images its markdown links.
///
/// [canReadFolder] is false where a picked file arrives without the folder
/// it sat in, as on Android: the markdown then comes alone.
Future<MarkdownWithImages> readMarkdownFile(
  File file, {
  required bool canReadFolder,
}) {
  if (p.extension(file.path).toLowerCase() == '.zip') {
    return _readZippedMarkdown(file);
  }
  return _readLooseMarkdown(file, canReadFolder: canReadFolder);
}

/// A markdown file on disk, with the images saved in its folder.
///
/// Links are only followed inside that folder. A converter never writes
/// `../`, and reading whatever a link climbs to would open files the user
/// never chose.
Future<MarkdownWithImages> _readLooseMarkdown(
  File file, {
  required bool canReadFolder,
}) async {
  final String markdown = normalizeMarkdown(await file.readAsString());
  final List<String> references = listRelativeImageReferences(markdown);
  final String folder = p.dirname(file.absolute.path);
  final Map<String, Uint8List> bytesByPath = <String, Uint8List>{};
  for (final String path in canReadFolder ? references : const <String>[]) {
    final String imagePath = p.normalize(p.join(folder, path));
    final File image = File(imagePath);
    if (!p.isWithin(folder, imagePath) || !image.existsSync()) continue;
    if (image.lengthSync() > kMaximumSourceImageBytes) continue;
    bytesByPath[path] = await image.readAsBytes();
  }
  return _withImageCopies(
    markdown: markdown,
    fileName: p.basename(file.path),
    bytesByPath: bytesByPath,
    shouldZipFolderForImages: !canReadFolder && references.isNotEmpty,
  );
}

/// A zip holding one markdown file and the images it links.
Future<MarkdownWithImages> _readZippedMarkdown(File zipFile) async {
  final InputFileStream input = InputFileStream(zipFile.path);
  late final Archive archive;
  try {
    archive = ZipDecoder().decodeStream(input);
  } finally {
    input.closeSync();
  }
  try {
    final _ZippedMarkdown zipped = _readZipEntries(archive);
    return await _withImageCopies(
      markdown: zipped.markdown,
      fileName: p.basename(zipFile.path),
      bytesByPath: zipped.bytesByPath,
    );
  } finally {
    // Entries reopen the zip when read; clearing closes it again, without
    // which Windows keeps the file locked.
    archive.clearSync();
  }
}

/// The markdown and linked image bytes read out of one zip.
final class _ZippedMarkdown {
  const _ZippedMarkdown({required this.markdown, required this.bytesByPath});

  final String markdown;
  final Map<String, Uint8List> bytesByPath;
}

/// Reads the zip's one markdown file and the images it links.
///
/// Entries are only ever read into memory, never written to disk under their
/// own names, so a crafted name cannot place a file anywhere.
_ZippedMarkdown _readZipEntries(Archive archive) {
  final Map<String, ArchiveFile> entriesByName = <String, ArchiveFile>{
    // `/` between folders whichever system made the zip; macOS resource
    // copies under `__MACOSX/` are not the user's files.
    for (final ArchiveFile entry in archive.files)
      if (entry.isFile && !entry.name.startsWith('__MACOSX/'))
        entry.name.replaceAll(r'\', '/'): entry,
  };
  final String markdownName = _onlyMarkdownName(entriesByName.keys);
  final ArchiveFile markdownEntry = entriesByName[markdownName]!;
  var bytesRead = markdownEntry.size;
  if (bytesRead > _kMaximumZipBytes) throw _zipTooLarge;
  final String markdown = normalizeMarkdown(
    utf8.decode(
      markdownEntry.readBytes() ?? Uint8List(0),
      allowMalformed: true,
    ),
  );
  final Map<String, Uint8List> bytesByPath = <String, Uint8List>{};
  for (final String path in listRelativeImageReferences(markdown)) {
    final ArchiveFile? entry = _zipEntryFor(
      path: path,
      markdownFolder: p.posix.dirname(markdownName),
      entriesByName: entriesByName,
    );
    if (entry == null || entry.size > kMaximumSourceImageBytes) continue;
    bytesRead += entry.size;
    if (bytesRead > _kMaximumZipBytes) throw _zipTooLarge;
    final Uint8List? bytes = entry.readBytes();
    if (bytes != null) bytesByPath[path] = bytes;
  }
  return _ZippedMarkdown(markdown: markdown, bytesByPath: bytesByPath);
}

const MarkdownFileInputException _zipTooLarge = MarkdownFileInputException(
  'This zip is too large to import',
);

/// The one markdown file among [names]. One Marker folder makes one topic,
/// and guessing which of several files the user meant would be wrong half
/// the time.
String _onlyMarkdownName(Iterable<String> names) {
  final List<String> markdownNames = names.where(_isMarkdownName).toList();
  if (markdownNames.isEmpty) {
    throw const MarkdownFileInputException('This zip has no markdown file');
  }
  if (markdownNames.length > 1) {
    throw MarkdownFileInputException(
      'This zip has ${markdownNames.length} markdown files — '
      'zip one Marker folder at a time',
    );
  }
  return markdownNames.single;
}

bool _isMarkdownName(String name) {
  final String extension = p.posix.extension(name).toLowerCase();
  return extension == '.md' || extension == '.markdown';
}

/// The entry [path] names relative to the markdown's folder or, failing
/// that, the one entry with the same file name: zips made by hand do not
/// always keep the converter's folders.
///
/// A path that climbs out of the zip names nothing.
ArchiveFile? _zipEntryFor({
  required String path,
  required String markdownFolder,
  required Map<String, ArchiveFile> entriesByName,
}) {
  final String entryName = p.posix.normalize(
    p.posix.join(markdownFolder, path),
  );
  if (entryName == '..' || entryName.startsWith('../')) return null;
  final ArchiveFile? sameFolder = entriesByName[entryName];
  if (sameFolder != null) return sameFolder;
  final String fileName = p.posix.basename(path);
  final List<ArchiveFile> sameName = <ArchiveFile>[
    for (final MapEntry<String, ArchiveFile> entry in entriesByName.entries)
      if (p.posix.basename(entry.key) == fileName) entry.value,
  ];
  return sameName.length == 1 ? sameName.single : null;
}

/// Validates each read image and points its links at the copy it will be
/// stored as, then removes the HTML Marker leaves in its markdown.
Future<MarkdownWithImages> _withImageCopies({
  required String markdown,
  required String fileName,
  required Map<String, Uint8List> bytesByPath,
  bool shouldZipFolderForImages = false,
}) async {
  final List<SourceImageImport> images = <SourceImageImport>[];
  final Map<String, String> sha256ByPath = <String, String>{};
  for (final MapEntry<String, Uint8List> file in bytesByPath.entries) {
    try {
      final SourceImageImport image = await prepareSourceImage(
        file.value,
        altText: p.posix.basenameWithoutExtension(file.key),
      );
      images.add(image);
      sha256ByPath[file.key] = image.sha256;
    } on ReaderImageInputException {
      // Not an image the Reader can show. It is counted as missing below and
      // its link stays as written, so the Reader marks the place it belonged.
    }
  }
  return MarkdownWithImages(
    markdown: cleanMarkerMarkdown(
      rewriteImageReferences(markdown, sha256ByPath),
    ),
    fileName: fileName,
    images: images,
    missingImageCount:
        listRelativeImageReferences(markdown).length - sha256ByPath.length,
    shouldZipFolderForImages: shouldZipFolderForImages,
  );
}
