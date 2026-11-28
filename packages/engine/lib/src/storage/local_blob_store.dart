// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'blob_store.dart';

/// A content-addressed folder for raw message content.
///
/// ADR-0006 allows this backend as an alternative to SQLite blobs. The
/// digest is the file name, so identical content is stored once and a
/// checksum gate can verify a file before any destructive action.
final class LocalBlobStore implements BlobStore {
  /// Creates a store rooted at [directory], creating it when absent.
  LocalBlobStore(Directory directory) : _directory = directory {
    if (!_directory.existsSync()) {
      _directory.createSync(recursive: true);
    }
  }

  final Directory _directory;

  /// Stores [bytes] and returns their SHA-256 digest.
  @override
  String put(List<int> bytes) {
    final digest = sha256.convert(bytes).toString();
    final file = File('${_directory.path}${Platform.pathSeparator}$digest');
    if (!file.existsSync()) {
      file.writeAsBytesSync(bytes, flush: true);
    }
    return digest;
  }

  /// Reads the content for [digest], or null when it is absent.
  @override
  List<int>? get(String digest) {
    final file = File('${_directory.path}${Platform.pathSeparator}$digest');
    if (!file.existsSync()) return null;
    final bytes = file.readAsBytesSync();
    return sha256.convert(bytes).toString() == digest ? bytes : null;
  }

  /// Whether the stored content still matches its digest.
  @override
  bool verify(String digest) => get(digest) != null;
}
