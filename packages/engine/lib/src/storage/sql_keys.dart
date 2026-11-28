// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Names of the standalone SQL resources used by the local database.
///
/// R51 requires SQL to live in `.sql` files, so the Dart layer refers only to
/// these keys. Each key is the file name of one statement resource.
library;

/// File names of SQL statements loaded by `SqlResources`.
final class SqlKeys {
  const SqlKeys._();

  /// Sets the write-ahead journal mode.
  static const String setJournalMode = 'set_journal_mode.sql';

  /// Reads the current journal mode.
  static const String readJournalMode = 'read_journal_mode.sql';

  /// Sets the busy timeout in milliseconds.
  static const String setBusyTimeout = 'set_busy_timeout.sql';

  /// Reads the current busy timeout.
  static const String readBusyTimeout = 'read_busy_timeout.sql';

  /// Lists the columns of the messages table.
  static const String messagesTableInfo = 'messages_table_info.sql';

  /// Adds the quarantined column to an older profile.
  static const String addQuarantinedColumn = 'add_quarantined_column.sql';

  /// Adds the read column to an older profile.
  static const String addIsReadColumn = 'add_is_read_column.sql';

  /// Adds the starred column to an older profile.
  static const String addStarredColumn = 'add_starred_column.sql';

  /// Starts an exclusive write transaction.
  static const String beginImmediate = 'begin_immediate.sql';

  /// Commits the current write transaction.
  static const String commit = 'commit.sql';

  /// Rolls back the current write transaction.
  static const String rollback = 'rollback.sql';

  /// Inserts one message row.
  static const String insertMessage = 'insert_message.sql';

  /// Inserts one full-text index row.
  static const String insertMessageFts = 'insert_message_fts.sql';

  /// Lists every message identifier in stable order.
  static const String selectMessageIds = 'select_message_ids.sql';

  /// Stores or replaces one channel row.
  static const String upsertChannel = 'upsert_channel.sql';

  /// Reads one channel by identifier.
  static const String selectChannelById = 'select_channel_by_id.sql';

  /// Reads every channel in stable order.
  static const String selectChannels = 'select_channels.sql';

  /// Reads topic summaries for one channel or for every channel.
  static const String selectThreadSummaries = 'select_thread_summaries.sql';

  /// Reads one message by identifier.
  static const String selectMessageById = 'select_message_by_id.sql';

  /// Stores or replaces one reply draft.
  static const String upsertDraft = 'upsert_draft.sql';

  /// Reads one reply draft.
  static const String selectDraft = 'select_draft.sql';

  /// Reads the checksum of one message.
  static const String selectChecksum = 'select_checksum.sql';

  /// Changes only the read flag of one message.
  static const String updateTriageRead = 'update_triage_read.sql';

  /// Changes only the starred flag of one message.
  static const String updateTriageStarred = 'update_triage_starred.sql';

  /// Changes both triage flags of one message.
  static const String updateTriageBoth = 'update_triage_both.sql';

  /// Reads both triage flags of one message.
  static const String selectTriage = 'select_triage.sql';

  /// Creates the retired compressed blob table in a legacy profile fixture.
  static const String createLegacyBlobs = 'create_legacy_blobs.sql';

  /// Inserts one row into the retired compressed blob table.
  static const String insertLegacyBlob = 'insert_legacy_blob.sql';

  /// Reads rows from the retired compressed blob table.
  static const String selectLegacyBlobs = 'select_legacy_blobs.sql';

  /// Drops the retired compressed blob table.
  static const String dropLegacyBlobs = 'drop_legacy_blobs.sql';

  /// Lists the tables in the open database.
  static const String selectTableNames = 'select_table_names.sql';

  /// Stores or replaces one incremental cursor.
  static const String upsertSyncCursor = 'upsert_sync_cursor.sql';

  /// Reads one incremental cursor.
  static const String selectSyncCursor = 'select_sync_cursor.sql';

  /// Writes an invalid cursor used by the corruption test.
  static const String writeInvalidCursor = 'write_invalid_cursor.sql';

  /// Stores or replaces one mailbox policy.
  static const String upsertListPolicy = 'upsert_list_policy.sql';

  /// Reads the action of one mailbox policy.
  static const String selectPolicyAction = 'select_policy_action.sql';

  /// Reads the destination folder of one mailbox policy.
  static const String selectPolicyFolder = 'select_policy_folder.sql';

  /// Records one single-use purge preparation.
  static const String insertPurgePreparation = 'insert_purge_preparation.sql';

  /// Reads the digest of one purge preparation.
  static const String selectPreparationDigest = 'select_preparation_digest.sql';

  /// Reads whether one purge preparation was consumed.
  static const String selectPreparationConsumed =
      'select_preparation_consumed.sql';

  /// Marks one purge preparation consumed.
  static const String consumePreparation = 'consume_preparation.sql';

  /// Quarantines one message row.
  static const String quarantineMessage = 'quarantine_message.sql';

  /// Records one quarantined message in the ledger.
  static const String insertQuarantineEntry = 'insert_quarantine_entry.sql';

  /// Lists every quarantined message identifier.
  static const String selectQuarantinedIds = 'select_quarantined_ids.sql';

  /// Reads a whole thread in pre-order with a bounded recursive query.
  static const String selectSubtree = 'select_subtree.sql';

  /// Searches subjects and bodies through FTS5.
  static const String searchMessages = 'search_messages.sql';

  /// Counts every persisted message.
  static const String countMessages = 'count_messages.sql';

  /// Writes a vacuumed copy to a path supplied by the caller.
  static const String vacuumInto = 'vacuum_into.sql';

  /// Stores or replaces one connected account.
  static const String upsertAccount = 'upsert_account.sql';

  /// Reads one connected account by identifier.
  static const String selectAccount = 'select_account.sql';

  /// Reads every connected account in stable order.
  static const String selectAccounts = 'select_accounts.sql';
}
