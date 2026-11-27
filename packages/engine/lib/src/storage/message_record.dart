// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// The immutable row stored for one ingested message.
///
/// The checksum gates every destructive decision, as required by R15 and
/// ADR-0008. Parent and root identifiers drive the recursive thread queries
/// of ADR-0005.
final class MessageRecord {
  /// Creates a message row.
  const MessageRecord({
    required this.id,
    required this.listId,
    required this.subject,
    required this.fromAddress,
    required this.dateEpoch,
    required this.parentId,
    required this.threadRootId,
    required this.body,
    required this.checksum,
  });

  /// Stable message identifier.
  final String id;

  /// Identifier of the list or channel that delivered the message.
  final String listId;

  /// Subject line used by threading and search.
  final String subject;

  /// Address of the author.
  final String fromAddress;

  /// Message date in epoch seconds.
  final int dateEpoch;

  /// Identifier of the parent message, or null for a root.
  final String? parentId;

  /// Identifier of the thread root.
  final String threadRootId;

  /// Raw message body.
  final String body;

  /// SHA-256 digest of the raw source, used by the two-phase commit.
  final String checksum;
}
