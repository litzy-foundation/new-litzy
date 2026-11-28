// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Storage port for raw message content.
///
/// ADR-0006 requires the folder and SQLite backends to be equivalent. The
/// engine depends only on this port, so neither ingestion nor purge knows
/// where the bytes are kept. A digest is the identity of the content and is
/// verified whenever bytes are read back.
abstract interface class BlobStore {
  /// Stores [bytes] and returns their SHA-256 digest.
  String put(List<int> bytes);

  /// Reads the content for [digest], or null when it is absent or corrupt.
  List<int>? get(String digest);

  /// Whether the stored content still matches its digest.
  bool verify(String digest);
}
