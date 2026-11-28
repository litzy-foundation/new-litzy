// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// A deterministic failure reported by a mailbox implementation.
abstract interface class MailboxException implements Exception {
  /// Stable machine-readable failure code.
  String get code;

  /// Explanation that never contains credential material.
  String get message;
}

/// The mailbox operations used by the purge coordinator.
///
/// Keeping this surface small lets a fake mailbox prove the safety rules in
/// tests without a live account, as required by R16. A typed failure crosses
/// the boundary unchanged so a caller can map it to a stable error code.
abstract interface class MailboxPort {
  /// Moves the given unique identifiers to [folder].
  Future<void> moveToFolder(List<String> uids, String folder);

  /// Marks the given unique identifiers as seen.
  Future<void> markSeen(List<String> uids);

  /// Permanently removes the given unique identifiers.
  Future<void> expunge(List<String> uids);
}
