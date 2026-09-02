/// Content-addressed image files owned by the application.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// The result of placing one immutable image in the asset directory.
final class StoredSourceAsset {
  const StoredSourceAsset({
    required this.sha256,
    required this.file,
    required this.byteLength,
    required this.wasCreated,
  });

  /// Lowercase SHA-256 of the encoded image bytes.
  final String sha256;

  /// Final content-addressed file.
  final File file;

  /// Number of encoded bytes.
  final int byteLength;

  /// Whether this call created the blob rather than reusing it.
  final bool wasCreated;
}

/// Stores immutable image blobs under lowercase SHA-256 file names.
final class SourceAssetFileStore {
  SourceAssetFileStore({required Directory assetDirectory})
    : _assetDirectory = assetDirectory;

  static final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

  final Directory _assetDirectory;

  /// Directory containing final blobs and short-lived `.partial` files.
  Directory get directory => _assetDirectory;

  /// Returns the final file only after rejecting path-like identifiers.
  File fileForSha256(String sha256Value) {
    _requireSha256(sha256Value);
    return File(p.join(_assetDirectory.path, sha256Value));
  }

  /// Saves [bytes] durably before exposing their final content-addressed name.
  ///
  /// The partial name also contains only the computed hash, so neither Windows
  /// nor Android ever has to interpret a source filename or content URI.
  Future<StoredSourceAsset> saveBytes(Uint8List bytes) async {
    final sha256Value = sha256.convert(bytes).toString();
    final target = fileForSha256(sha256Value);
    await _assetDirectory.create(recursive: true);

    if (target.existsSync()) {
      await _requireMatchingFile(target, sha256Value, bytes.length);
      return StoredSourceAsset(
        sha256: sha256Value,
        file: target,
        byteLength: bytes.length,
        wasCreated: false,
      );
    }

    final partial = File('${target.path}.partial');
    await _deleteFileIfPresent(partial);
    try {
      final openFile = await partial.open(mode: FileMode.writeOnly);
      try {
        await openFile.writeFrom(bytes);
        await openFile.flush();
      } finally {
        await openFile.close();
      }
      await _requireMatchingFile(partial, sha256Value, bytes.length);

      if (target.existsSync()) {
        await _requireMatchingFile(target, sha256Value, bytes.length);
        await _deleteFileIfPresent(partial);
        return StoredSourceAsset(
          sha256: sha256Value,
          file: target,
          byteLength: bytes.length,
          wasCreated: false,
        );
      }
      await partial.rename(target.path);
      return StoredSourceAsset(
        sha256: sha256Value,
        file: target,
        byteLength: bytes.length,
        wasCreated: true,
      );
    } on Object {
      await _deleteFileIfPresent(partial);
      rethrow;
    }
  }

  /// Whether the named blob exists and still has the promised content.
  Future<bool> hasVerifiedBlob(String sha256Value) async {
    final file = fileForSha256(sha256Value);
    if (!file.existsSync()) return false;
    return await _hashFile(file) == sha256Value;
  }

  /// Removes a blob whose database reference count has already reached zero.
  Future<void> deleteBlob(String sha256Value) async {
    await _deleteFileIfPresent(fileForSha256(sha256Value));
  }

  /// Removes writes abandoned by a crash without touching completed blobs.
  Future<int> deletePartialFiles() async {
    if (!_assetDirectory.existsSync()) return 0;
    var deletedCount = 0;
    await for (final entity in _assetDirectory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.partial')) continue;
      try {
        await entity.delete();
        deletedCount++;
      } on FileSystemException {
        // A concurrent importer may still own the file; the next pass retries.
      }
    }
    return deletedCount;
  }

  /// Removes completed blobs no database row still references.
  ///
  /// Only exact lowercase SHA-256 file names are candidates. This keeps
  /// partial writes and any future metadata files outside garbage collection.
  Future<int> deleteUnreferencedBlobs(
    Set<String> referencedSha256Values,
  ) async {
    for (final sha256Value in referencedSha256Values) {
      _requireSha256(sha256Value);
    }
    if (!_assetDirectory.existsSync()) return 0;

    var deletedCount = 0;
    await for (final entity in _assetDirectory.list(followLinks: false)) {
      if (entity is! File) continue;
      final filename = p.basename(entity.path);
      if (!_sha256Pattern.hasMatch(filename) ||
          referencedSha256Values.contains(filename)) {
        continue;
      }
      try {
        await entity.delete();
        deletedCount++;
      } on FileSystemException {
        // A locked file is harmless; the next startup pass retries it.
      }
    }
    return deletedCount;
  }

  Future<void> _requireMatchingFile(
    File file,
    String expectedSha256,
    int expectedLength,
  ) async {
    if (await file.length() != expectedLength ||
        await _hashFile(file) != expectedSha256) {
      throw StateError('asset blob does not match its SHA-256 file name');
    }
  }

  static Future<String> _hashFile(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static void _requireSha256(String sha256Value) {
    if (!_sha256Pattern.hasMatch(sha256Value)) {
      throw FormatException('asset identifier is not a lowercase SHA-256');
    }
  }

  static Future<void> _deleteFileIfPresent(File file) async {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Cleanup is best-effort; a later startup pass will retry leftovers.
    }
  }
}
