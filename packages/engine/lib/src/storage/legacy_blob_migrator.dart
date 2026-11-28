// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Moves raw messages from the retired SQLite blob table to the blob folder.
///
/// A row is removed only after decompression, size and SHA-256 all agree with
/// the file written through `BlobStore`. If any row fails, the legacy table is
/// kept so no content is lost, as required by ADR-0017.
library;

import 'package:zstd_dart/zstd_dart.dart';

import 'blob_store.dart';
import 'local_database.dart';

/// One-shot migration from the compressed SQLite backend to local files.
final class LegacyBlobMigrator {
  /// Creates a migrator over [database] writing through [blobs].
  const LegacyBlobMigrator(this._database, this._blobs);

  final LocalDatabase _database;
  final BlobStore _blobs;

  /// Codec written by the retired backend.
  static const String legacyCodec = 'zstd';

  /// Largest uncompressed payload accepted from a legacy row.
  static const int maximumBytes = 64 * 1024 * 1024;

  /// Migrates every verified row and returns the number written.
  int migrate() {
    if (!_database.hasLegacyBlobs()) return 0;
    var migrated = 0;
    var failed = 0;

    for (final row in _database.legacyBlobs()) {
      if (row.codec != legacyCodec || row.size < 0 || row.size > maximumBytes) {
        failed++;
        continue;
      }
      try {
        final bytes = ZstdCodec.decompress(
          row.payload,
          maxOutputBytes: row.size == 0 ? 1 : row.size,
        );
        if (bytes.length != row.size || checksumOfBytes(bytes) != row.digest) {
          failed++;
          continue;
        }
        if (_blobs.get(row.digest) == null) {
          _blobs.put(bytes);
        }
        migrated++;
      } on ZstdException {
        failed++;
      } on ArgumentError {
        failed++;
      }
    }

    if (failed == 0) {
      _database.dropLegacyBlobs();
    }
    return migrated;
  }
}
