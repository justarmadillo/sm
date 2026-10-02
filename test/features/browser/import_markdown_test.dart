/// Importing opened markdown through the Browser's view model keeps the
/// images the file brought with it.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/files/source_asset_file_store.dart';

void main() {
  late AppDatabase database;
  late Directory workspace;
  late ProviderContainer container;

  setUp(() {
    database = openInMemoryDatabase();
    workspace = Directory.systemTemp.createTempSync('ir-import-markdown-');
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(
          FakeClock(DateTime.utc(2026, 3, 5, 10)),
        ),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator()),
        sourceAssetFileStoreProvider.overrideWithValue(
          SourceAssetFileStore(
            assetDirectory: Directory('${workspace.path}/assets'),
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  test('the images an opened file brought are stored with it', () async {
    final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final SourceImageImport figure = SourceImageImport(
      bytes: bytes,
      altText: 'Figure',
      sha256: sha256.convert(bytes).toString(),
      mime: 'image/png',
      widthPx: 640,
      heightPx: 480,
    );
    final BrowserViewModel browser = container.read(
      browserViewModelProvider.notifier,
    );
    await container.read(browserViewModelProvider.future);

    final String? sourceId = await browser.importMarkdown(
      title: 'Paper',
      markdown: '# Paper\n\n![](${figure.srcRef})',
      images: <SourceImageImport>[figure],
    );

    expect(sourceId, isNotNull);
    expect(
      await container
          .read(sourceAssetRepositoryProvider)
          .listSourceAssets(sourceId!),
      hasLength(1),
    );
  });
}
