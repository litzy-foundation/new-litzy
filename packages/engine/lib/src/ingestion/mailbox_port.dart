// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// The mailbox operations used by the purge coordinator.
///
/// Keeping this surface small lets a fake mailbox prove the safety rules in
/// tests without a live account, as required by R16.
abstract interface class MailboxPort {
  /// Moves the given unique identifiers to [folder].
  Future<void> moveToFolder(List<String> uids, String folder);

  /// Marks the given unique identifiers as seen.
  Future<void> markSeen(List<String> uids);

  /// Permanently removes the given unique identifiers.
  Future<void> expunge(List<String> uids);
}
