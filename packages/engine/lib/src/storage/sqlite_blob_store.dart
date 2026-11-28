// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:typed_data';

import 'package:zstd_dart/zstd_dart.dart';

import 'blob_store.dart';
import 'local_database.dart';

/// Compressed blob backend that keeps raw messages in the profile database.
///
/// Each row records the codec and uncompressed size next to a Zstd frame.
/// Reads accept a row only when decompression, size and SHA-256 digest all
/// agree, so a corrupt frame becomes an absence rather than an exception.
final class SqliteBlobStore implements BlobStore {
  /// Creates a store over the open local database.
  const SqliteBlobStore(this._database);

  final LocalDatabase _database;

  static const String _codec = 'zstd';
  static const int _maximumBytes = 64 * 1024 * 1024;

  @override
  String put(List<int> bytes) {
    final input = Uint8List.fromList(bytes);
    final digest = checksumOfBytes(input);
    _database.putBlob(digest, _codec, input.length, ZstdCodec.compress(input));
    return digest;
  }

  @override
  List<int>? get(String digest) {
    final row = _database.blobOf(digest);
    if (row == null || row.codec != _codec) return null;
    if (row.size < 0 || row.size > _maximumBytes) return null;
    try {
      final bytes = ZstdCodec.decompress(
        row.payload,
        maxOutputBytes: row.size == 0 ? 1 : row.size,
      );
      if (bytes.length != row.size || checksumOfBytes(bytes) != digest) {
        return null;
      }
      return bytes;
    } on ZstdException {
      return null;
    }
  }

  @override
  bool verify(String digest) => get(digest) != null;
}
