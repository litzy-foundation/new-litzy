// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'blob_store.dart';
import 'local_database.dart';

/// A local content-addressed folder for compressed raw messages.
///
/// A digest is split into two directory levels before the `.eml.gz` file name,
/// so a large public list does not fill one directory. The bytes are verified
/// on every read. An older flat uncompressed file is copied into the new
/// layout without deleting the original.
final class LocalBlobStore implements BlobStore {
  /// Creates a store rooted at [directory], creating it when absent.
  LocalBlobStore(Directory directory) : _directory = directory {
    if (!_directory.existsSync()) {
      _directory.createSync(recursive: true);
    }
  }

  final Directory _directory;

  /// Extension of each compressed raw message file.
  static const String fileExtension = '.eml.gz';

  /// Number of digest characters in each directory level.
  static const int directoryLevelLength = 2;

  /// Number of directory levels derived from the digest.
  static const int directoryLevelCount = 2;

  /// Stores [bytes] and returns their SHA-256 digest.
  @override
  String put(List<int> bytes) {
    final digest = checksumOfBytes(bytes);
    final file = _fileFor(digest);
    if (!file.existsSync()) {
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(gzip.encode(bytes), flush: true);
    }
    return digest;
  }

  /// Reads the content for [digest], or null when it is absent or corrupt.
  @override
  List<int>? get(String digest) {
    if (!_isValidDigest(digest)) return null;
    final file = _fileFor(digest);
    if (!file.existsSync()) {
      return _readLegacyFile(digest);
    }
    try {
      final bytes = gzip.decode(file.readAsBytesSync());
      return checksumOfBytes(bytes) == digest ? bytes : null;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// Whether the stored content still matches its digest.
  @override
  bool verify(String digest) => get(digest) != null;

  static bool _isValidDigest(String digest) =>
      digest.length >= directoryLevelLength * directoryLevelCount;

  File _fileFor(String digest) {
    final path = _directory.path;
    final first = digest.substring(0, directoryLevelLength);
    final second = digest.substring(
      directoryLevelLength,
      directoryLevelLength * directoryLevelCount,
    );
    return File(
      '$path${Platform.pathSeparator}$first${Platform.pathSeparator}$second'
      '${Platform.pathSeparator}$digest$fileExtension',
    );
  }

  File _legacyFileFor(String digest) =>
      File('${_directory.path}${Platform.pathSeparator}$digest');

  List<int>? _readLegacyFile(String digest) {
    final file = _legacyFileFor(digest);
    if (!file.existsSync()) return null;
    final bytes = file.readAsBytesSync();
    if (checksumOfBytes(bytes) != digest) return null;
    put(bytes);
    return bytes;
  }
}
