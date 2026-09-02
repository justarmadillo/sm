/// Verifies durable, path-safe storage of content-addressed image blobs.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:incremental_reader/storage/files/source_asset_file_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;
  late SourceAssetFileStore store;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir_asset_store_test_');
    store = SourceAssetFileStore(
      assetDirectory: Directory('${workspace.path}/assets'),
    );
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  test('saves under a lowercase SHA-256 and reuses identical bytes', () async {
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final expectedSha256 = sha256.convert(bytes).toString();

    final first = await store.saveBytes(bytes);
    final second = await store.saveBytes(bytes);

    expect(first.sha256, expectedSha256);
    expect(first.file.path, endsWith(expectedSha256));
    expect(first.wasCreated, isTrue);
    expect(second.wasCreated, isFalse);
    expect(second.file.readAsBytesSync(), bytes);
    expect(store.directory.listSync(), hasLength(1));
  });

  test('rejects identifiers that could escape the asset directory', () {
    for (final unsafeIdentifier in <String>[
      '../image',
      r'C:\image',
      'A' * 64,
      'a' * 63,
    ]) {
      expect(
        () => store.fileForSha256(unsafeIdentifier),
        throwsFormatException,
      );
    }
  });

  test('does not reuse a corrupt blob with a valid-looking name', () async {
    final bytes = Uint8List.fromList(<int>[9, 8, 7]);
    final expectedSha256 = sha256.convert(bytes).toString();
    store.directory.createSync(recursive: true);
    store.fileForSha256(expectedSha256).writeAsBytesSync(<int>[0, 0, 0]);

    expect(() => store.saveBytes(bytes), throwsStateError);
  });

  test('startup cleanup removes only partial files', () async {
    store.directory.createSync(recursive: true);
    File(
      '${store.directory.path}/${'a' * 64}.partial',
    ).writeAsBytesSync(<int>[1]);
    final complete = File('${store.directory.path}/${'b' * 64}')
      ..writeAsBytesSync(<int>[2]);

    expect(await store.deletePartialFiles(), 1);
    expect(complete.existsSync(), isTrue);
    expect(store.directory.listSync(), hasLength(1));
  });

  test('garbage collection removes only unreferenced hash files', () async {
    store.directory.createSync(recursive: true);
    final referencedSha256 = 'a' * 64;
    final unreferencedSha256 = 'b' * 64;
    final referenced = File('${store.directory.path}/$referencedSha256')
      ..writeAsBytesSync(<int>[1]);
    final unreferenced = File('${store.directory.path}/$unreferencedSha256')
      ..writeAsBytesSync(<int>[2]);
    final partial = File('${store.directory.path}/${'c' * 64}.partial')
      ..writeAsBytesSync(<int>[3]);
    final unrelated = File('${store.directory.path}/notes.json')
      ..writeAsBytesSync(<int>[4]);

    final deletedCount = await store.deleteUnreferencedBlobs(<String>{
      referencedSha256,
    });

    expect(deletedCount, 1);
    expect(referenced.existsSync(), isTrue);
    expect(unreferenced.existsSync(), isFalse);
    expect(partial.existsSync(), isTrue);
    expect(unrelated.existsSync(), isTrue);
  });
}
