/// Image insertion through the Reader's real transaction and file store.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:incremental_reader/features/reader/reader_command_runner.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/drift/drift_source_asset_repository.dart';
import 'package:incremental_reader/storage/files/source_asset_file_store.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

void main() {
  test('stores an image once and replays the insertion once', () async {
    final AppHarness harness = AppHarness(operationPrefix: 'image');
    addTearDown(harness.database.close);
    final Directory workspace = Directory.systemTemp.createTempSync(
      'ir-reader-image-',
    );
    addTearDown(() {
      if (workspace.existsSync()) workspace.deleteSync(recursive: true);
    });
    final DriftSourceAssetRepository assets = DriftSourceAssetRepository(
      harness.database,
    );
    final SourceAssetFileStore assetFiles = SourceAssetFileStore(
      assetDirectory: Directory('${workspace.path}/assets'),
    );
    final ReaderCommandRunner reader = ReaderCommandRunner(
      content: harness.content,
      learning: harness.learning,
      search: harness.search,
      transfer: harness.transfer,
      assets: assets,
      assetFiles: () => assetFiles,
      transactions: harness.transactions,
      context: harness.context,
      clock: harness.clock,
      ids: FakeIdGenerator(prefix: 'image-command'),
    );
    final imported = await reader.importSource(
      ImportSource(
        const OperationId('import-image-source'),
        title: 'Images',
        markdown: '# Images\n\nText before the image.',
      ),
    );
    final source = imported.unwrap();
    final document = (await harness.content.findDocument(source.id))!;
    final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final String imageSha256 = sha256.convert(bytes).toString();
    final InsertSourceImages command = InsertSourceImages(
      const OperationId('insert-one-image'),
      sourceId: source.id,
      afterBlockId: document.blocks.last.id,
      images: <SourceImageImport>[
        SourceImageImport(
          bytes: bytes,
          altText: 'Diagram',
          sha256: imageSha256,
          mime: 'image/png',
          widthPx: 640,
          heightPx: 480,
        ),
      ],
      baseContentRevision: document.contentRevision,
    );

    expect((await reader.insertSourceImages(command)).isOk, isTrue);
    expect((await reader.insertSourceImages(command)).isOk, isTrue);

    final updated = (await harness.content.findSource(source.id))!;
    expect(
      RegExp('ir-asset:$imageSha256').allMatches(updated.markdown),
      hasLength(1),
    );
    expect(await assets.listSourceAssets(source.id), hasLength(1));
    expect(await assetFiles.hasVerifiedBlob(imageSha256), isTrue);
  });
}
