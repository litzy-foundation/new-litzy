// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// The action applied to ingested mail for one list.
///
/// Moving to a dedicated folder is the safe default required by R15. Real
/// expunging is an explicit per-list opt-in and is never inferred.
enum MailboxAction {
  /// Move the message to the dedicated ingestion folder.
  moveToIngested,

  /// Mark the message as seen and archive it.
  markSeen,

  /// Delete the message after verification, only when explicitly opted in.
  expunge,
}

/// Converts mailbox actions to and from their stable storage names.
extension MailboxActionStorage on MailboxAction {
  /// Stable name written to the local database.
  String get storageName => switch (this) {
    MailboxAction.moveToIngested => 'move',
    MailboxAction.markSeen => 'mark_seen',
    MailboxAction.expunge => 'expunge',
  };
}

/// Resolves a stored action name, falling back to the safe default.
MailboxAction mailboxActionFromStorage(String? value) => switch (value) {
  'move' => MailboxAction.moveToIngested,
  'mark_seen' => MailboxAction.markSeen,
  'expunge' => MailboxAction.expunge,
  _ => MailboxAction.moveToIngested,
};
