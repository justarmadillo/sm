/// Image insertion through the Reader's real transaction and file store.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:incremental_reader/features/reader/reader_command_runner.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/in_memory_diagnostic_sink.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/drift/drift_source_asset_repository.dart';
import 'package:incremental_reader/storage/files/source_asset_file_store.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

void main() {
  late AppHarness harness;
  late Directory workspace;
  late DriftSourceAssetRepository assets;
  late SourceAssetFileStore assetFiles;
  late ReaderCommandRunner reader;

  setUp(() {
    harness = AppHarness(operationPrefix: 'image');
    workspace = Directory.systemTemp.createTempSync('ir-reader-image-');
    assets = DriftSourceAssetRepository(harness.database);
    assetFiles = SourceAssetFileStore(
      assetDirectory: Directory('${workspace.path}/assets'),
    );
    reader = _readerWithImages(
      harness: harness,
      assets: assets,
      assetFiles: assetFiles,
    );
  });

  tearDown(() async {
    await harness.database.close();
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  test('stores an image once and replays the insertion once', () async {
    final imported = await reader.importSource(
      ImportSource(
        const OperationId('import-image-source'),
        title: 'Images',
        markdown: '# Images\n\nText before the image.',
      ),
    );
    final source = imported.unwrap();
    final document = (await harness.content.findDocument(source.id))!;
    final SourceImageImport image = _image(<int>[1, 2, 3, 4], 'Diagram');
    final InsertSourceImages command = InsertSourceImages(
      const OperationId('insert-one-image'),
      sourceId: source.id,
      afterBlockId: document.blocks.last.id,
      images: <SourceImageImport>[image],
      baseContentRevision: document.contentRevision,
    );

    expect((await reader.insertSourceImages(command)).isOk, isTrue);
    expect((await reader.insertSourceImages(command)).isOk, isTrue);

    final updated = (await harness.content.findSource(source.id))!;
    expect(
      RegExp('ir-asset:${image.sha256}').allMatches(updated.markdown),
      hasLength(1),
    );
    expect(await assets.listSourceAssets(source.id), hasLength(1));
    expect(await assetFiles.hasVerifiedBlob(image.sha256), isTrue);

    final editedDocument = (await harness.content.findDocument(source.id))!;
    final editedBlock = editedDocument.blocks.first;
    final SourceImageImport secondImage = _image(<int>[
      5,
      6,
      7,
      8,
    ], 'Inline diagram');
    final edited = await reader.editSourceBlock(
      EditSourceBlock(
        const OperationId('edit-with-image'),
        sourceId: source.id,
        blockId: editedBlock.id,
        markdown:
            '${editedBlock.raw}\n\n![Inline diagram](${secondImage.srcRef})',
        images: <SourceImageImport>[secondImage],
        baseContentRevision: editedDocument.contentRevision,
      ),
    );

    expect(edited.isOk, isTrue);
    expect(edited.unwrap().source.markdown, contains(secondImage.srcRef));
    expect(await assets.listSourceAssets(source.id), hasLength(2));
    expect(await assetFiles.hasVerifiedBlob(secondImage.sha256), isTrue);
  });

  group('importing a source with its images', () {
    final SourceImageImport figure = _image(<int>[1, 2, 3, 4], 'Figure');
    final SourceImageImport picture = _image(<int>[5, 6, 7, 8], 'Picture');

    test('stores each image once, with the source that shows it', () async {
      final imported = await reader.importSource(
        ImportSource(
          const OperationId('import-with-images'),
          title: 'Paper',
          markdown:
              '# Paper\n\n![](${figure.srcRef})\n\n'
              '![](${picture.srcRef})\n\n![](${figure.srcRef})',
          images: <SourceImageImport>[figure, picture, figure],
        ),
      );

      final source = imported.unwrap();
      expect(await assets.listSourceAssets(source.id), hasLength(2));
      expect(await assetFiles.hasVerifiedBlob(figure.sha256), isTrue);
      expect(await assetFiles.hasVerifiedBlob(picture.sha256), isTrue);
    });

    test('a replayed import adds no second source or image', () async {
      final ImportSource command = ImportSource(
        const OperationId('import-once'),
        title: 'Paper',
        markdown: '# Paper\n\n![](${figure.srcRef})',
        images: <SourceImageImport>[figure],
      );

      expect((await reader.importSource(command)).isOk, isTrue);
      expect((await reader.importSource(command)).isOk, isFalse);

      final sources = await harness.content.listSources();
      expect(sources, hasLength(1));
      expect(await assets.listSourceAssets(sources.single.id), hasLength(1));
    });

    test('refuses too many images before writing anything', () async {
      final List<SourceImageImport> images = <SourceImageImport>[
        for (var index = 0; index <= kMaximumImagesPerSource; index++)
          SourceImageImport(
            bytes: Uint8List(1),
            altText: 'Image',
            sha256: index.toRadixString(16).padLeft(64, '0'),
            mime: 'image/png',
            widthPx: 1,
            heightPx: 1,
          ),
      ];

      final result = await reader.importSource(
        ImportSource(
          const OperationId('import-too-many'),
          title: 'Atlas',
          markdown: '# Atlas',
          images: images,
        ),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(await harness.content.listSources(), isEmpty);
      expect(assetFiles.directory.existsSync(), isFalse);
    });

    test('a failed image write is recorded and leaves no source', () async {
      final File notAFolder = File('${workspace.path}/not-a-folder')
        ..writeAsStringSync('in the way');
      final InMemoryDiagnosticSink diagnostics = InMemoryDiagnosticSink();
      final ReaderCommandRunner failingReader = _readerWithImages(
        harness: harness,
        assets: assets,
        assetFiles: SourceAssetFileStore(
          assetDirectory: Directory('${notAFolder.path}/assets'),
        ),
        diagnostics: diagnostics,
      );

      final result = await failingReader.importSource(
        ImportSource(
          const OperationId('import-unwritable'),
          title: 'Paper',
          markdown: '# Paper\n\n![](${figure.srcRef})',
          images: <SourceImageImport>[figure],
        ),
      );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(await harness.content.listSources(), isEmpty);
      expect(
        diagnostics.events.where(
          (DiagnosticEvent event) => event.level == DiagnosticLevel.error,
        ),
        hasLength(1),
      );
    });
  });
}

/// A Reader runner whose image storage is real, in a temporary folder.
ReaderCommandRunner _readerWithImages({
  required AppHarness harness,
  required DriftSourceAssetRepository assets,
  required SourceAssetFileStore assetFiles,
  DiagnosticSink diagnostics = const NullDiagnosticSink(),
}) => ReaderCommandRunner(
  content: harness.content,
  videos: harness.videos,
  learning: harness.learning,
  search: harness.search,
  transfer: harness.transfer,
  assets: assets,
  assetFiles: () => assetFiles,
  transactions: harness.transactions,
  context: harness.context,
  clock: harness.clock,
  ids: FakeIdGenerator(prefix: 'image-command'),
  cramScope: harness.cramScope,
  diagnostics: diagnostics,
);

/// An already-validated image of [bytes]; the store checks the hash.
SourceImageImport _image(List<int> bytes, String altText) {
  final Uint8List imageBytes = Uint8List.fromList(bytes);
  return SourceImageImport(
    bytes: imageBytes,
    altText: altText,
    sha256: sha256.convert(imageBytes).toString(),
    mime: 'image/png',
    widthPx: 640,
    heightPx: 480,
  );
}
