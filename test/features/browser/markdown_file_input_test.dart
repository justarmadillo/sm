/// Opening a converter's markdown, loose or zipped, together with its images.
///
/// Marker saves each figure beside the markdown. The property under test is
/// that every figure the markdown links arrives with it, pointed at its stored
/// copy, and that anything that cannot arrive is counted rather than dropped
/// in silence.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/features/browser/markdown_file_input.dart';
import 'package:incremental_reader/features/reader/reader_image_input.dart';

void main() {
  final Uint8List png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
    'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  final String pngSha256 = sha256.convert(png).toString();
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir-markdown-file-');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  /// Writes a zip of [entries] and returns it.
  File zipOf(Map<String, List<int>> entries) {
    final Archive archive = Archive();
    entries.forEach(
      (String name, List<int> bytes) =>
          archive.addFile(ArchiveFile.bytes(name, bytes)),
    );
    return File('${workspace.path}/paper.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));
  }

  group('a zipped Marker folder', () {
    test('arrives with its figures pointed at their stored copies', () async {
      final File zip = zipOf(<String, List<int>>{
        'paper/paper.md': utf8.encode(
          '# Paper\n\n<span id="page-1-0"></span>![](_page_1_Figure_0.png)',
        ),
        'paper/_page_1_Figure_0.png': png,
        'paper/paper_meta.json': utf8.encode('{}'),
      });

      final MarkdownWithImages opened = await readMarkdownFile(
        zip,
        canReadFolder: false,
      );

      expect(opened.markdown, '# Paper\n\n![](ir-asset:$pngSha256)');
      expect(opened.images.single.sha256, pngSha256);
      expect(opened.missingImageCount, 0);
      expect(opened.fileName, 'paper.zip');
      expect(opened.shouldZipFolderForImages, isFalse);
    });

    test('counts a figure the zip does not hold, and keeps its link', () async {
      final File zip = zipOf(<String, List<int>>{
        'paper.md': utf8.encode('![](missing.png)\n\n![](here.png)'),
        'here.png': png,
      });

      final MarkdownWithImages opened = await readMarkdownFile(
        zip,
        canReadFolder: false,
      );

      expect(opened.markdown, '![](missing.png)\n\n![](ir-asset:$pngSha256)');
      expect(opened.missingImageCount, 1);
    });

    test('finds a figure by name when the folders do not match', () async {
      final File zip = zipOf(<String, List<int>>{
        'paper.md': utf8.encode('![](figures/fig.png)'),
        'export/fig.png': png,
      });

      final MarkdownWithImages opened = await readMarkdownFile(
        zip,
        canReadFolder: false,
      );

      expect(opened.markdown, '![](ir-asset:$pngSha256)');
    });

    test('never follows a link out of the zip', () async {
      final File zip = zipOf(<String, List<int>>{
        'paper.md': utf8.encode('![](../outside.png)'),
        'outside.png': png,
      });

      final MarkdownWithImages opened = await readMarkdownFile(
        zip,
        canReadFolder: false,
      );

      expect(opened.missingImageCount, 1);
      expect(opened.images, isEmpty);
    });

    test('counts a file that is not an image it can show', () async {
      final File zip = zipOf(<String, List<int>>{
        'paper.md': utf8.encode('![](broken.png)'),
        'broken.png': utf8.encode('not an image'),
      });

      final MarkdownWithImages opened = await readMarkdownFile(
        zip,
        canReadFolder: false,
      );

      expect(opened.missingImageCount, 1);
      expect(opened.images, isEmpty);
    });

    test('skips an image too large to store without reading it', () async {
      final File zip = zipOf(<String, List<int>>{
        'paper.md': utf8.encode('![](huge.png)'),
        'huge.png': Uint8List(kMaximumSourceImageBytes + 1),
      });

      final MarkdownWithImages opened = await readMarkdownFile(
        zip,
        canReadFolder: false,
      );

      expect(opened.missingImageCount, 1);
    });

    test('needs a markdown file', () async {
      final File zip = zipOf(<String, List<int>>{'fig.png': png});

      expect(
        () => readMarkdownFile(zip, canReadFolder: false),
        throwsA(
          isA<MarkdownFileInputException>().having(
            (MarkdownFileInputException error) => error.message,
            'message',
            'This zip has no markdown file',
          ),
        ),
      );
    });

    test('takes one Marker folder at a time', () async {
      final File zip = zipOf(<String, List<int>>{
        'first/first.md': utf8.encode('# First'),
        'second/second.md': utf8.encode('# Second'),
      });

      expect(
        () => readMarkdownFile(zip, canReadFolder: false),
        throwsA(
          isA<MarkdownFileInputException>().having(
            (MarkdownFileInputException error) => error.message,
            'message',
            'This zip has 2 markdown files — zip one Marker folder at a time',
          ),
        ),
      );
    });
  });

  group('a markdown file on disk', () {
    test('brings the figures saved in its folder', () async {
      final Directory folder = Directory('${workspace.path}/paper')
        ..createSync();
      Directory('${folder.path}/images').createSync();
      File('${folder.path}/images/fig.png').writeAsBytesSync(png);
      final File markdown = File('${folder.path}/paper.md')
        ..writeAsStringSync('# Paper\n\n![](images/fig.png)');

      final MarkdownWithImages opened = await readMarkdownFile(
        markdown,
        canReadFolder: true,
      );

      expect(opened.markdown, '# Paper\n\n![](ir-asset:$pngSha256)');
      expect(opened.images, hasLength(1));
      expect(opened.fileName, 'paper.md');
    });

    test('never reads outside its folder', () async {
      final Directory folder = Directory('${workspace.path}/paper')
        ..createSync();
      File('${workspace.path}/outside.png').writeAsBytesSync(png);
      final File markdown = File('${folder.path}/paper.md')
        ..writeAsStringSync('![](../outside.png)');

      final MarkdownWithImages opened = await readMarkdownFile(
        markdown,
        canReadFolder: true,
      );

      expect(opened.images, isEmpty);
      expect(opened.missingImageCount, 1);
    });

    test('says to zip the folder when the folder cannot be read', () async {
      File('${workspace.path}/fig.png').writeAsBytesSync(png);
      final File markdown = File('${workspace.path}/paper.md')
        ..writeAsStringSync('![](fig.png)');

      final MarkdownWithImages opened = await readMarkdownFile(
        markdown,
        canReadFolder: false,
      );

      expect(opened.images, isEmpty);
      expect(opened.missingImageCount, 1);
      expect(opened.shouldZipFolderForImages, isTrue);
    });
  });
}
