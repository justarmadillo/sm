/// An extract that carries a figure shows it, as the source it came from did.
///
/// An extract owns a copy of its text, but not of its images: they stay
/// owned by the root source. The screen therefore has to look them up there,
/// or every figure cut out of an imported paper shows as missing.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/extract/extract_screen.dart';
import 'package:incremental_reader/features/extract/extract_view_model.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/files/source_asset_file_store.dart';

import '../../support/anchors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Uint8List png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
    'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  late AppDatabase database;
  late Directory workspace;
  late ProviderContainer container;
  late String extractId;

  setUp(() async {
    database = openInMemoryDatabase();
    workspace = Directory.systemTemp.createTempSync('ir-extract-images-');
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
    final SourceImageImport figure = SourceImageImport(
      bytes: png,
      altText: 'Figure',
      sha256: sha256.convert(png).toString(),
      mime: 'image/png',
      widthPx: 1,
      heightPx: 1,
    );
    await container.read(browserViewModelProvider.future);
    final String sourceId = (await container
        .read(browserViewModelProvider.notifier)
        .importMarkdown(
          title: 'Paper',
          markdown:
              '# Paper\n\nThe figure below matters.\n\n'
              '![Figure](${figure.srcRef})\n\nAfter the figure.',
          images: <SourceImageImport>[figure],
        ))!;

    final ReaderRequest request = ReaderRequest(
      sourceId: sourceId,
      mode: ReaderMode.scheduled,
    );
    final ReaderUiState reader = await container.read(
      readerViewModelProvider(request).future,
    );
    final Block textBlock = reader.document.blocks[1];
    final Block imageBlock = reader.document.blocks[2];
    final ReaderAnchor start = anchorAtBlockStart(textBlock);
    final ReaderAnchor end = anchorIn(
      imageBlock,
      imageBlock.sourceEndUtf8 - imageBlock.sourceStartUtf8,
    );
    final Extract? created = await container
        .read(readerViewModelProvider(request).notifier)
        .extractSelection(
          SelectionRange.of(
            startAnchor: start,
            endAnchor: end,
            markdown: reader.document.markdownBetween(start, end),
          ),
        );
    extractId = created!.id;
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  testWidgets('an extract shows the figure it carries', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ExtractScreen(
            request: ExtractRequest(
              extractId: extractId,
              mode: ExtractMode.scheduled,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Image && widget.image is FileImage,
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });
}
