// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'account_record.dart';
import 'channel_record.dart';
import 'message_record.dart';
import 'schema_file.dart';
import 'sql_keys.dart';
import 'sql_resources.dart';
import 'sync_cursor.dart';

/// A row from the retired compressed blob table.
typedef LegacyBlob = ({
  String digest,
  String codec,
  int size,
  Uint8List payload,
});

/// A stored reply draft with its source message and prepared content.
typedef StoredDraft = ({String messageId, String subject, String body});

/// The local SQLite store for messages, threads and full-text search.
///
/// ADR-0005 chooses recursive queries and FTS5, ADR-0002 makes this the only
/// active backend, and R51 keeps every statement in a standalone `.sql`
/// resource. Every write is a transaction so a purge decision is never based
/// on a half-persisted message.
final class LocalDatabase {
  LocalDatabase._(this._database) {
    _database.execute(SqlResources.statement(SqlKeys.setJournalMode));
    _database.execute(SqlResources.statement(SqlKeys.setBusyTimeout));
    _migrate();
  }

  /// Column additions that bring an older profile to the current schema.
  static const List<({String name, String statement})> _migrations = [
    (name: 'quarantined', statement: SqlKeys.addQuarantinedColumn),
    (name: 'is_read', statement: SqlKeys.addIsReadColumn),
    (name: 'starred', statement: SqlKeys.addStarredColumn),
  ];

  final Database _database;

  /// Opens a database at [path], creating it when absent.
  factory LocalDatabase.open(String path) =>
      LocalDatabase._(sqlite3.open(path));

  /// Opens a transient database for tests and isolated algorithms.
  factory LocalDatabase.inMemory() => LocalDatabase._(sqlite3.openInMemory());

  /// Journal mode reported by the open connection.
  String get journalMode {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.readJournalMode),
    );
    return rows.single.values.first as String;
  }

  /// Busy timeout reported by the open connection.
  int get busyTimeoutMilliseconds {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.readBusyTimeout),
    );
    return rows.single.values.first as int;
  }

  void _migrate() {
    for (final statement in SchemaFile.statements()) {
      _database.execute(statement);
    }
    final columns = _database
        .select(SqlResources.statement(SqlKeys.messagesTableInfo))
        .map((row) => row['name'] as String)
        .toSet();
    for (final migration in _migrations) {
      if (!columns.contains(migration.name)) {
        _database.execute(SqlResources.statement(migration.statement));
      }
    }
  }

  /// Persists a batch of messages atomically.
  void insertMessages(List<MessageRecord> records) {
    _database.execute(SqlResources.statement(SqlKeys.beginImmediate));
    try {
      final insert = _database.prepare(
        SqlResources.statement(SqlKeys.insertMessage),
      );
      final search = _database.prepare(
        SqlResources.statement(SqlKeys.insertMessageFts),
      );
      for (final record in records) {
        insert.execute([
          record.id,
          record.listId,
          record.subject,
          record.fromAddress,
          record.dateEpoch,
          record.parentId,
          record.threadRootId,
          record.body,
          record.checksum,
        ]);
        search.execute([record.id, record.subject, record.body]);
      }
      insert.dispose();
      search.dispose();
      _database.execute(SqlResources.statement(SqlKeys.commit));
    } catch (_) {
      _database.execute(SqlResources.statement(SqlKeys.rollback));
      rethrow;
    }
  }

  /// Identifiers of all persisted messages, ordered for stable assertions.
  List<String> get messageIds {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectMessageIds),
    );
    return rows.map((row) => row['id'] as String).toList();
  }

  /// Stores a selected channel, replacing its previous endpoint.
  void upsertChannel(ChannelRecord channel) {
    _database.execute(SqlResources.statement(SqlKeys.upsertChannel), [
      channel.id,
      channel.listId,
      channel.label,
      channel.protocol,
      channel.endpoint,
    ]);
  }

  /// Returns the stored channel with [id], or null when absent.
  ChannelRecord? channelOf(String id) {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectChannelById),
      [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return ChannelRecord(
      id: row['id'] as String,
      listId: row['list_id'] as String,
      label: row['label'] as String,
      protocol: row['protocol'] as String,
      endpoint: row['endpoint'] as String,
    );
  }

  /// Returns every persisted channel ordered by its stable identifier.
  List<ChannelRecord> get channels => _database
      .select(SqlResources.statement(SqlKeys.selectChannels))
      .map(
        (row) => ChannelRecord(
          id: row['id'] as String,
          listId: row['list_id'] as String,
          label: row['label'] as String,
          protocol: row['protocol'] as String,
          endpoint: row['endpoint'] as String,
        ),
      )
      .toList(growable: false);

  /// Returns topic summaries, optionally limited to one persisted channel.
  List<
    ({
      String rootId,
      String listId,
      String subject,
      int messageCount,
      int lastActivityEpoch,
    })
  >
  threadSummaries({String? channelId}) => _database
      .select(SqlResources.statement(SqlKeys.selectThreadSummaries), [
        channelId,
        channelId,
      ])
      .map(
        (row) => (
          rootId: row['root_id'] as String,
          listId: row['list_id'] as String,
          subject: row['subject'] as String,
          messageCount: row['message_count'] as int,
          lastActivityEpoch: row['last_activity_epoch'] as int,
        ),
      )
      .toList(growable: false);

  /// Returns one persisted message, or null when [id] is absent.
  MessageRecord? messageOf(String id) {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectMessageById),
      [id],
    );
    if (rows.isEmpty) return null;
    return _toRecord(rows.first);
  }

  /// Stores or replaces the reply draft with [id].
  void saveDraft(
    String id,
    String messageId,
    String subject,
    String body,
    int createdAt,
  ) {
    _database.execute(SqlResources.statement(SqlKeys.upsertDraft), [
      id,
      messageId,
      subject,
      body,
      createdAt,
    ]);
  }

  /// Returns the stored draft with [id], or null when absent.
  StoredDraft? draftOf(String id) {
    final rows = _database.select(SqlResources.statement(SqlKeys.selectDraft), [
      id,
    ]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      messageId: row['message_id'] as String,
      subject: row['subject'] as String,
      body: row['body'] as String,
    );
  }

  /// Returns the verified checksum for [id], or null when absent.
  String? checksumOf(String id) {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectChecksum),
      [id],
    );
    if (rows.isEmpty) return null;
    return rows.first['checksum'] as String;
  }

  /// Changes the supplied triage flags of an existing message.
  void setTriage(String id, {bool? read, bool? starred}) {
    final String key;
    final List<Object?> values;
    if (read != null && starred != null) {
      key = SqlKeys.updateTriageBoth;
      values = [read ? 1 : 0, starred ? 1 : 0, id];
    } else if (read != null) {
      key = SqlKeys.updateTriageRead;
      values = [read ? 1 : 0, id];
    } else if (starred != null) {
      key = SqlKeys.updateTriageStarred;
      values = [starred ? 1 : 0, id];
    } else {
      return;
    }
    _database.execute(SqlResources.statement(key), values);
  }

  /// Returns both triage flags of [id], or null when the message is absent.
  ({bool read, bool starred})? triageOf(String id) {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectTriage),
      [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      read: (row['is_read'] as int) == 1,
      starred: (row['starred'] as int) == 1,
    );
  }

  /// Whether an older profile still has the retired blob table.
  bool hasLegacyBlobs() => _tableNames().contains('blobs');

  /// Returns the rows that still need migration to the blob folder.
  List<LegacyBlob> legacyBlobs() {
    if (!hasLegacyBlobs()) return const [];
    return _database
        .select(SqlResources.statement(SqlKeys.selectLegacyBlobs))
        .map(
          (row) => (
            digest: row['digest'] as String,
            codec: row['codec'] as String,
            size: row['size'] as int,
            payload: row['payload'] as Uint8List,
          ),
        )
        .toList(growable: false);
  }

  /// Removes the retired blob table after a verified migration.
  void dropLegacyBlobs() {
    if (hasLegacyBlobs()) {
      _database.execute(SqlResources.statement(SqlKeys.dropLegacyBlobs));
    }
  }

  Set<String> _tableNames() => _database
      .select(SqlResources.statement(SqlKeys.selectTableNames))
      .map((row) => row['name'] as String)
      .toSet();

  /// Stores the incremental cursor for [channelId].
  void setCursor(String channelId, SyncCursor cursor) {
    _database.execute(SqlResources.statement(SqlKeys.upsertSyncCursor), [
      channelId,
      cursor.encode(),
    ]);
  }

  /// Returns the cursor for [channelId], or null when none was stored.
  SyncCursor? cursorOf(String channelId) {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectSyncCursor),
      [channelId],
    );
    if (rows.isEmpty) return null;
    return SyncCursor.decode(rows.first['cursor'] as String);
  }

  /// Records the mailbox policy chosen for [listId].
  void setListPolicy(
    String listId,
    String action, {
    String folder = 'Litzy/Ingested',
  }) {
    _database.execute(SqlResources.statement(SqlKeys.upsertListPolicy), [
      listId,
      action,
      folder,
    ]);
  }

  /// Returns the stored policy action for [listId], or null when unset.
  String? rawPolicyOf(String listId) {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectPolicyAction),
      [listId],
    );
    if (rows.isEmpty) return null;
    return rows.first['action'] as String;
  }

  /// Returns the destination folder for [listId], or null when unset.
  String? policyFolderOf(String listId) {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectPolicyFolder),
      [listId],
    );
    if (rows.isEmpty) return null;
    return rows.first['folder'] as String;
  }

  /// Records the digest prepared for [id] before any mailbox action.
  ///
  /// A decision identifier is single use, so an existing record is kept.
  void recordPreparation(String id, String listId, String digest) {
    _database.execute(SqlResources.statement(SqlKeys.insertPurgePreparation), [
      id,
      listId,
      digest,
    ]);
  }

  /// Returns the recorded digest for [id], or null when absent.
  String? preparationDigestOf(String id) {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectPreparationDigest),
      [id],
    );
    if (rows.isEmpty) return null;
    return rows.first['digest'] as String;
  }

  /// Whether the preparation for [id] has already been consumed.
  bool isPreparationConsumed(String id) {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectPreparationConsumed),
      [id],
    );
    if (rows.isEmpty) return false;
    return (rows.first['consumed'] as int) == 1;
  }

  /// Marks the preparation for [id] consumed after a successful action.
  void consumePreparation(String id) {
    _database.execute(SqlResources.statement(SqlKeys.consumePreparation), [id]);
  }

  /// Records doubtful messages in the quarantine ledger.
  ///
  /// A candidate that has no persisted row is still recorded, so it can never
  /// be mistaken for one that passed verification.
  void quarantine(List<String> ids) {
    if (ids.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _database.execute(SqlResources.statement(SqlKeys.beginImmediate));
    try {
      final update = _database.prepare(
        SqlResources.statement(SqlKeys.quarantineMessage),
      );
      final insert = _database.prepare(
        SqlResources.statement(SqlKeys.insertQuarantineEntry),
      );
      for (final id in ids) {
        update.execute([id]);
        insert.execute([id, now]);
      }
      update.dispose();
      insert.dispose();
      _database.execute(SqlResources.statement(SqlKeys.commit));
    } catch (_) {
      _database.execute(SqlResources.statement(SqlKeys.rollback));
      rethrow;
    }
  }

  /// Identifiers recorded in the quarantine ledger.
  List<String> get quarantinedIds {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectQuarantinedIds),
    );
    return rows.map((row) => row['message_id'] as String).toList();
  }

  /// Reads a whole thread in pre-order with a bounded recursive query.
  List<MessageRecord> subtree(String rootId, {int maxDepth = 64}) {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectSubtree),
      [rootId, maxDepth],
    );
    return rows.map(_toRecord).toList();
  }

  /// Searches subjects and bodies through FTS5.
  List<String> search(String terms) {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.searchMessages),
      [terms],
    );
    return rows.map((row) => row['id'] as String).toList();
  }

  /// Number of persisted messages.
  int get count {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.countMessages),
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Stores one connected account without any secret material.
  void upsertAccount(AccountRecord account) {
    _database.execute(SqlResources.statement(SqlKeys.upsertAccount), [
      account.id,
      account.email,
      account.imapHost,
      account.imapPort,
      account.smtpHost,
      account.smtpPort,
      account.authentication,
      account.listId,
      account.createdAt,
    ]);
  }

  /// Returns the stored account with [id], or null when absent.
  AccountRecord? accountOf(String id) {
    final rows = _database.select(
      SqlResources.statement(SqlKeys.selectAccount),
      [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      id: row['id'] as String,
      email: row['email'] as String,
      imapHost: row['imap_host'] as String,
      imapPort: row['imap_port'] as int,
      smtpHost: row['smtp_host'] as String,
      smtpPort: row['smtp_port'] as int,
      authentication: row['authentication'] as String,
      listId: row['list_id'] as String,
      createdAt: row['created_at'] as int,
    );
  }

  /// Writes a copy of the database to [destination] for a durable backup.
  void backupTo(File destination) {
    _database.execute(SqlResources.vacuumInto(destination.path));
  }

  /// Closes the database handle.
  void close() => _database.dispose();

  static MessageRecord _toRecord(Row row) => MessageRecord(
    id: row['id'] as String,
    listId: row['list_id'] as String,
    subject: row['subject'] as String,
    fromAddress: row['from_address'] as String,
    dateEpoch: row['date_epoch'] as int,
    parentId: row['parent_id'] as String?,
    threadRootId: row['thread_root_id'] as String,
    body: row['body'] as String,
    checksum: row['checksum'] as String,
  );
}

/// Computes the SHA-256 digest used by the two-phase commit gate.
String checksumOfBytes(List<int> bytes) => sha256.convert(bytes).toString();
