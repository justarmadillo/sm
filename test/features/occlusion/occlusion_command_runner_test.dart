/// Scheduled fan-out tests for image-occlusion creation.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/features/occlusion/occlusion_command_runner.dart';
import 'package:incremental_reader/features/occlusion/occlusion_commands.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/drift/drift_occlusion_repository.dart';
import 'package:incremental_reader/storage/files/source_asset_file_store.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

void main() {
  late Directory workspace;
  late AppHarness harness;
  late OcclusionCommandRunner runner;
  late SourceImageImport image;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir-occlusion-');
    harness = AppHarness();
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    image = SourceImageImport(
      bytes: bytes,
      altText: 'Diagram',
      sha256: sha256.convert(bytes).toString(),
      mime: 'image/png',
      widthPx: 640,
      heightPx: 480,
    );
    runner = OcclusionCommandRunner(
      content: harness.content,
      learning: harness.learning,
      occlusions: DriftOcclusionRepository(harness.database),
      search: harness.search,
      transfer: harness.transfer,
      transactions: harness.transactions,
      context: harness.context,
      files: SourceAssetFileStore(
        assetDirectory: Directory('${workspace.path}/assets'),
      ),
      clock: harness.clock,
      ids: FakeIdGenerator(prefix: 'occlusion'),
      diagnostics: harness.diagnostics,
    );
  });

  tearDown(() async {
    await harness.close();
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  const regions = <OcclusionRegion>[
    OcclusionRegion(id: 'a', left: 0.1, top: 0.1, width: 0.1, height: 0.1),
    OcclusionRegion(id: 'b', left: 0.2, top: 0.2, width: 0.1, height: 0.1),
    OcclusionRegion(id: 'c', left: 0.3, top: 0.3, width: 0.1, height: 0.1),
    OcclusionRegion(id: 'd', left: 0.4, top: 0.4, width: 0.1, height: 0.1),
  ];

  test('guess-one fans out while guess-all creates one due card', () async {
    final guessOne = await runner.create(
      CreateOcclusionCards(
        harness.operation(),
        parent: null,
        image: image,
        regions: regions,
        mode: OcclusionMode.hideAllGuessOne,
        header: '',
        extra: '',
      ),
    );
    final guessAll = await runner.create(
      CreateOcclusionCards(
        harness.operation(),
        parent: null,
        image: image,
        regions: regions,
        mode: OcclusionMode.hideAllGuessAll,
        header: '',
        extra: '',
      ),
    );

    expect(guessOne.unwrap(), hasLength(4));
    expect(guessAll.unwrap(), hasLength(1));
    expect(guessOne.unwrap().first.extra, '');
    final runtime = await harness.context.runtimeState();
    expect(runtime.pending, hasLength(5));
    for (final Card card in <Card>[
      ...guessOne.unwrap(),
      ...guessAll.unwrap(),
    ]) {
      final state = await harness.learning.findCardState(card.id);
      expect(state?.schedule.dueDay, await harness.context.today());
    }
  });

  test('editing replaces masks and wording without changing memory', () async {
    final created = await runner.create(
      CreateOcclusionCards(
        harness.operation(),
        parent: null,
        image: image,
        regions: regions,
        mode: OcclusionMode.hideAllGuessOne,
        header: 'Old header',
        extra: 'Old remarks',
      ),
    );
    final card = created.unwrap().first;
    final before = await harness.learning.findCardState(card.id);
    const replacement = <OcclusionRegion>[
      OcclusionRegion(
        id: 'replacement',
        left: 0.15,
        top: 0.2,
        width: 0.3,
        height: 0.4,
      ),
    ];

    final edited = await runner.edit(
      EditOcclusionCard(
        harness.operation(),
        cardId: card.id,
        regions: replacement,
        mode: OcclusionMode.hideOneGuessOne,
        header: 'New header',
        extra: 'New remarks',
      ),
    );

    expect(edited.unwrap().front, 'New header');
    expect(edited.unwrap().extra, 'New remarks');
    expect(await harness.learning.findCardState(card.id), before);
    final stored = await DriftOcclusionRepository(
      harness.database,
    ).findCardOcclusion(card.id);
    expect(stored?.regions, replacement);
    expect(stored?.activeRegionId, 'replacement');
    expect(stored?.mode, OcclusionMode.hideOneGuessOne);
  });
}
