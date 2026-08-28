/// Conformance vectors read from real SuperMemo 20 collections.
///
/// These are not synthetic fixtures. `plans/sm20_binary/systems` holds two
/// collections the executable itself created, and this suite decodes their
/// binary files with the port's own primitives. A change that breaks any
/// expectation here has diverged from the program, not from a guess about it.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:incremental_reader/scheduling/mercy/mercy.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:test/test.dart';

/// Root of the two collections shipped with the scheduler evidence.
const String _systems = 'plans/sm20_binary/systems';
const String _abc = '$_systems/ABC of SuperMemo 20';
const String _second = '$_systems/second collection';

/// One SM20 scheduling record. Offsets are section 4.1 of the specification.
final class _ElementRecord {
  _ElementRecord(this.bytes) : _view = ByteData.sublistView(bytes);

  static const int size = 118;

  final Uint8List bytes;
  final ByteData _view;

  int get type => bytes[0x00];
  int get status => bytes[0x01];
  int get repetitions => _view.getUint16(0x0C, Endian.little);
  int get lapses => _view.getUint16(0x0E, Endian.little);
  int get interval => _view.getUint16(0x10, Endian.little);
  int get lastReviewDay => _view.getInt16(0x12, Endian.little);
  Uint8List get aFactorRaw => Uint8List.sublistView(bytes, 0x1C, 0x22);
  Uint8List get ratioRaw => Uint8List.sublistView(bytes, 0x22, 0x28);
  int get historyBlockId => _view.getUint32(0x28, Endian.little);
  int get recentPostponements => _view.getUint32(0x31, Endian.little);
  int get totalPostponements => _view.getUint32(0x35, Endian.little);
  int get learningControl => bytes[0x6D];
}

List<_ElementRecord> _readElements(String collection) {
  final Uint8List bytes = File(
    '$collection/info/ElementInfo.dat',
  ).readAsBytesSync();
  expect(
    bytes.length % _ElementRecord.size,
    0,
    reason: 'ElementInfo.dat must be a whole number of 118-byte records',
  );
  return <_ElementRecord>[
    for (var i = 0; i < bytes.length ~/ _ElementRecord.size; i += 1)
      _ElementRecord(
        Uint8List.sublistView(
          bytes,
          i * _ElementRecord.size,
          (i + 1) * _ElementRecord.size,
        ),
      ),
  ];
}

List<int> _readUint32List(String path) {
  final Uint8List bytes = File(path).readAsBytesSync();
  final ByteData view = ByteData.sublistView(bytes);
  return <int>[
    for (var i = 0; i + 4 <= bytes.length; i += 4)
      view.getUint32(i, Endian.little),
  ];
}

void main() {
  // Running from a different working directory would silently skip every
  // expectation below, which is worse than failing.
  setUpAll(() {
    if (!Directory(_abc).existsSync()) {
      throw StateError(
        'run this suite from the repository root; $_abc was not found',
      );
    }
  });

  group('the interval-factor matrix SM20 ships', () {
    test('is identical in two independently created collections', () {
      final List<int> abc = File(
        '$_abc/info/sm8opt.dat',
      ).readAsBytesSync().sublist(0, 800);
      final List<int> second = File(
        '$_second/info/sm8opt.dat',
      ).readAsBytesSync().sublist(0, 800);
      // This is what makes the table a property of the program rather than of
      // one collection, and therefore safe to use as a built-in default.
      expect(second, abc);
    });

    test('is reproduced exactly by the generated default', () {
      final Uint8List raw = File('$_abc/info/sm8opt.dat').readAsBytesSync();
      final ByteData view = ByteData.sublistView(raw);
      final List<int> stored = <int>[
        for (var i = 0; i < kSm20MercyMatrixLength; i += 1)
          view.getUint16(i * 2, Endian.little),
      ];
      expect(Sm20MercyMatrix.sm20Default.values, stored);
    });

    test('rounds half to even, on the float64 value', () {
      // Genuine ties settle on the even value.
      expect(Sm20MercyMatrix.sm20Default.valueAt(1, 8), 1238);
      expect(Sm20MercyMatrix.sm20Default.valueAt(3, 8), 1312);
      expect(Sm20MercyMatrix.sm20Default.valueAt(5, 8), 1388);
      expect(Sm20MercyMatrix.sm20Default.valueAt(7, 8), 1462);
      // These two only look like ties. On the exact rational they are 1537.5
      // and 1612.5, but the float64 the executable computes lands just below,
      // so they round down and not to the even neighbour.
      expect(Sm20MercyMatrix.sm20Default.valueAt(9, 8), 1537);
      expect(Sm20MercyMatrix.sm20Default.valueAt(11, 8), 1612);
      expect(Sm20MercyMatrix.sm20Default.valueAt(18, 16), 1537);
    });

    test('supplies the cells Mercy actually reads', () {
      // Section 12.1 consumes M[0][0] and row 6 only.
      expect(Sm20MercyMatrix.sm20Default.factorAt(0, 0), closeTo(2.484, 1e-9));
      expect(Sm20MercyMatrix.sm20Default.valueAt(6, 1), 3000);
      expect(Sm20MercyMatrix.sm20Default.valueAt(6, 19), 1295);
    });
  });

  group('element records', () {
    test('decode with the port Real48 reader', () {
      final List<_ElementRecord> records = _readElements(_second);
      expect(records, hasLength(4));

      // Record 0 is the collection root: a concept, dismissed, never studied.
      final _ElementRecord root = records.first;
      expect(root.type, 4);
      expect(root.status, 2);
      expect(root.repetitions, 0);
      expect(root.interval, 0);

      // The blank-topic A vector from section 16, straight out of the file.
      expect(root.aFactorRaw, <int>[0x81, 0x9a, 0x99, 0x99, 0x99, 0x19]);
      expect(DelphiReal48.fromBytes(root.aFactorRaw).value, closeTo(1.2, 1e-9));

      for (final _ElementRecord topic in records.skip(1)) {
        expect(topic.type, 0, reason: 'the three studied elements are topics');
        expect(topic.status, 1, reason: 'memorized after one repetition');
        expect(topic.repetitions, 1);
        expect(topic.lapses, 0);
        expect(topic.interval, 1);
        expect(topic.lastReviewDay, 1);
        expect(topic.recentPostponements, 0);
        expect(topic.totalPostponements, 0);
        expect(topic.learningControl, 8);
        // A is untouched by a first repetition; the ratio becomes exactly 1.
        expect(
          DelphiReal48.fromBytes(topic.aFactorRaw).value,
          closeTo(1.2, 1e-9),
        );
        expect(topic.ratioRaw, <int>[0x81, 0, 0, 0, 0, 0]);
        expect(DelphiReal48.fromBytes(topic.ratioRaw).value, 1.0);
      }

      // Each studied element owns a distinct history block.
      expect(
        <int>[for (final _ElementRecord r in records.skip(1)) r.historyBlockId],
        <int>[2, 3, 4],
      );
    });

    test('a fresh collection holds only the dismissed root', () {
      final List<_ElementRecord> records = _readElements(_abc);
      expect(records, hasLength(1));
      expect(records.single.status, 2);
    });
  });

  group('the priority population', () {
    test('contains every intact element, dismissed ones included', () {
      // Section 4.2 requires dismissed elements to keep their rank, because
      // dropping them would change N and therefore every derived percentage.
      // Element 1 is the dismissed root and is present here.
      final List<int> order = _readUint32List('$_second/info/priority.sub');
      expect(order, <int>[4, 3, 2, 1]);

      final List<_ElementRecord> records = _readElements(_second);
      expect(
        order.length,
        records.length,
        reason: 'every record, whatever its status, carries a rank',
      );
      expect(records.first.status, 2, reason: 'element 1 is dismissed');
    });
  });
}
