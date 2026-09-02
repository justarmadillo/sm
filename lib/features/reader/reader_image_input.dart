/// Reads and validates images chosen from the system picker or clipboard.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:path/path.dart' as path;
import 'package:super_clipboard/super_clipboard.dart';

/// Maximum encoded size accepted for one source image.
const int kMaximumSourceImageBytes = 32 * 1024 * 1024;

/// Platform-neutral seam used by the Reader and replaced by widget tests.
abstract interface class ReaderImageInput {
  Future<List<SourceImageImport>> chooseImages();

  Future<List<SourceImageImport>> readClipboardImage();
}

/// User-facing validation failure for one selected image.
final class ReaderImageInputException implements Exception {
  const ReaderImageInputException(
    this.message, {
    this.validImages = const <SourceImageImport>[],
  });

  final String message;

  /// Images that passed when other files in the same selection did not.
  final List<SourceImageImport> validImages;

  @override
  String toString() => message;
}

/// Uses native selection and clipboard APIs, copying bytes before returning.
final class SystemReaderImageInput implements ReaderImageInput {
  const SystemReaderImageInput();

  static const List<XTypeGroup> _imageTypes = <XTypeGroup>[
    XTypeGroup(
      label: 'images',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'wbmp'],
      mimeTypes: <String>[
        'image/png',
        'image/jpeg',
        'image/webp',
        'image/gif',
        'image/bmp',
        'image/vnd.wap.wbmp',
      ],
    ),
  ];

  @override
  Future<List<SourceImageImport>> chooseImages() async {
    final files = await openFiles(acceptedTypeGroups: _imageTypes);
    final images = <SourceImageImport>[];
    var skippedCount = 0;
    for (final file in files) {
      try {
        images.add(
          await prepareSourceImage(
            await file.readAsBytes(),
            altText: path.basenameWithoutExtension(file.name),
          ),
        );
      } on Object {
        skippedCount++;
      }
    }
    if (skippedCount > 0) {
      throw ReaderImageInputException(
        '$skippedCount selected image${skippedCount == 1 ? ' was' : 's were'} '
        'skipped because the file was unsupported or unreadable',
        validImages: images,
      );
    }
    return images;
  }

  @override
  Future<List<SourceImageImport>> readClipboardImage() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      throw const ReaderImageInputException(
        'Image paste is not available on this device',
      );
    }
    final reader = await clipboard.read();
    const formats = <FileFormat>[
      Formats.png,
      Formats.jpeg,
      Formats.webp,
      Formats.gif,
      Formats.bmp,
    ];
    for (final format in formats) {
      if (!reader.canProvide(format)) continue;
      final bytes = await _readClipboardFile(reader, format);
      if (bytes != null) {
        return <SourceImageImport>[
          await prepareSourceImage(bytes, altText: 'Pasted image'),
        ];
      }
    }
    throw const ReaderImageInputException('The clipboard has no image');
  }
}

Future<Uint8List?> _readClipboardFile(
  ClipboardReader reader,
  FileFormat format,
) async {
  final completer = Completer<Uint8List?>();
  final progress = reader.getFile(format, (DataReaderFile file) async {
    try {
      completer.complete(await file.readAll());
    } on Object catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  }, onError: completer.completeError);
  if (progress == null) return null;
  return completer.future;
}

/// Validates encoded bytes with Flutter's decoder before any file is stored.
Future<SourceImageImport> prepareSourceImage(
  Uint8List bytes, {
  required String altText,
}) async {
  if (bytes.isEmpty) {
    throw const ReaderImageInputException('The image is empty');
  }
  if (bytes.length > kMaximumSourceImageBytes) {
    throw const ReaderImageInputException('Images must be 32 MiB or smaller');
  }
  final mime = _imageMime(bytes);
  if (mime == null) {
    throw const ReaderImageInputException(
      'Use a PNG, JPEG, WebP, GIF, BMP, or WBMP image',
    );
  }

  ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodec(bytes);
  } on Object {
    throw const ReaderImageInputException('This image could not be decoded');
  }
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final widthPx = image.width;
    final heightPx = image.height;
    image.dispose();
    return SourceImageImport(
      bytes: bytes,
      altText: escapeImageAltText(altText),
      sha256: sha256.convert(bytes).toString(),
      mime: mime,
      widthPx: widthPx,
      heightPx: heightPx,
    );
  } finally {
    codec.dispose();
  }
}

/// Escapes the Markdown punctuation that can terminate or reshape alt text.
String escapeImageAltText(String altText) {
  final trimmed = altText.trim().isEmpty ? 'Image' : altText.trim();
  return trimmed.replaceAllMapped(
    RegExp(r'[\\\[\]]'),
    (Match match) => '\\${match.group(0)}',
  );
}

String? _imageMime(Uint8List bytes) {
  bool starts(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  if (starts(<int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return 'image/png';
  }
  if (starts(<int>[0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (starts('GIF87a'.codeUnits) || starts('GIF89a'.codeUnits)) {
    return 'image/gif';
  }
  if (starts('BM'.codeUnits)) return 'image/bmp';
  if (bytes.length >= 12 &&
      starts('RIFF'.codeUnits) &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  if (starts(<int>[0x00, 0x00]) || starts(<int>[0x00, 0x01])) {
    return 'image/vnd.wap.wbmp';
  }
  return null;
}
