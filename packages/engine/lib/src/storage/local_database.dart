// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'channel_record.dart';
import 'message_record.dart';
import 'sync_cursor.dart';

/// A compressed content row with the codec used and the uncompressed size.
typedef StoredBlob = ({String codec, int size, Uint8List payload});

/// The local SQLite store for messages, threads and full-text search.
///
/// ADR-0005 chooses recursive queries and FTS5, and ADR-0002 makes this the
/// only active backend. Every write is a transaction so a purge decision is
/// never based on a half-persisted message.
final class LocalDatabase {
  LocalDatabase._(this._database) {
    _migrate();
  }

  final Database _database;

  /// Opens a database at [path], creating it when absent.
  factory LocalDatabase.open(String path) =>
      LocalDatabase._(sqlite3.open(path));

  /// Opens a transient database for tests and isolated algorithms.
  factory LocalDatabase.inMemory() => LocalDatabase._(sqlite3.openInMemory());

  void _migrate() {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        list_id TEXT NOT NULL,
        subject TEXT NOT NULL,
        from_address TEXT NOT NULL,
        date_epoch INTEGER NOT NULL,
        parent_id TEXT,
        thread_root_id TEXT NOT NULL,
        body TEXT NOT NULL,
        checksum TEXT NOT NULL,
        quarantined INTEGER NOT NULL DEFAULT 0
      )
    ''');
    _database.execute('''
      CREATE INDEX IF NOT EXISTS messages_thread
      ON messages (thread_root_id, parent_id)
    ''');
    _database.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts
      USING fts5(id UNINDEXED, subject, body)
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS list_policies (
        list_id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        folder TEXT NOT NULL
      )
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS purge_preparations (
        id TEXT PRIMARY KEY,
        list_id TEXT NOT NULL,
        digest TEXT NOT NULL,
        consumed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS quarantine_entries (
        message_id TEXT PRIMARY KEY,
        quarantined_at INTEGER NOT NULL
      )
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS blobs (
        digest TEXT PRIMARY KEY,
        codec TEXT NOT NULL,
        size INTEGER NOT NULL,
        payload BLOB NOT NULL
      )
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS sync_cursors (
        channel_id TEXT PRIMARY KEY,
        cursor TEXT NOT NULL
      )
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS channels (
        id TEXT PRIMARY KEY,
        list_id TEXT NOT NULL,
        label TEXT NOT NULL,
        protocol TEXT NOT NULL,
        endpoint TEXT NOT NULL
      )
    ''');
    final columns = _database.select('PRAGMA table_info(messages)');
    if (!columns.any((column) => column['name'] == 'quarantined')) {
      _database.execute(
        'ALTER TABLE messages ADD COLUMN quarantined INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  /// Persists a batch of messages atomically.
  void insertMessages(List<MessageRecord> records) {
    _database.execute('BEGIN IMMEDIATE');
    try {
      final insert = _database.prepare('''
        INSERT INTO messages
          (id, list_id, subject, from_address, date_epoch, parent_id,
           thread_root_id, body, checksum)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      final search = _database.prepare('''
        INSERT INTO messages_fts (id, subject, body) VALUES (?, ?, ?)
      ''');
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
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Identifiers of all persisted messages, ordered for stable assertions.
  List<String> get messageIds {
    final rows = _database.select('SELECT id FROM messages ORDER BY id');
    return rows.map((row) => row['id'] as String).toList();
  }

  /// Stores a selected channel, replacing its previous endpoint.
  void upsertChannel(ChannelRecord channel) {
    _database.execute(
      '''
      INSERT INTO channels (id, list_id, label, protocol, endpoint)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        list_id = excluded.list_id,
        label = excluded.label,
        protocol = excluded.protocol,
        endpoint = excluded.endpoint
      ''',
      [
        channel.id,
        channel.listId,
        channel.label,
        channel.protocol,
        channel.endpoint,
      ],
    );
  }

  /// Returns the stored channel with [id], or null when absent.
  ChannelRecord? channelOf(String id) {
    final rows = _database.select(
      'SELECT id, list_id, label, protocol, endpoint FROM channels WHERE id = ?',
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

  /// Returns the verified checksum for [id], or null when absent.
  String? checksumOf(String id) {
    final rows = _database.select(
      'SELECT checksum FROM messages WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return rows.first['checksum'] as String;
  }

  /// Stores a compressed blob once, keyed by its uncompressed digest.
  void putBlob(String digest, String codec, int size, List<int> payload) {
    _database.execute(
      '''
      INSERT OR IGNORE INTO blobs (digest, codec, size, payload)
      VALUES (?, ?, ?, ?)
      ''',
      [digest, codec, size, Uint8List.fromList(payload)],
    );
  }

  /// Returns the stored blob for [digest], or null when absent.
  StoredBlob? blobOf(String digest) {
    final rows = _database.select(
      'SELECT codec, size, payload FROM blobs WHERE digest = ?',
      [digest],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      codec: row['codec'] as String,
      size: row['size'] as int,
      payload: row['payload'] as Uint8List,
    );
  }

  /// Stores the incremental cursor for [channelId].
  void setCursor(String channelId, SyncCursor cursor) {
    _database.execute(
      '''
      INSERT INTO sync_cursors (channel_id, cursor) VALUES (?, ?)
      ON CONFLICT(channel_id) DO UPDATE SET cursor = excluded.cursor
      ''',
      [channelId, cursor.encode()],
    );
  }

  /// Returns the cursor for [channelId], or null when none was stored.
  SyncCursor? cursorOf(String channelId) {
    final rows = _database.select(
      'SELECT cursor FROM sync_cursors WHERE channel_id = ?',
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
    _database.execute(
      '''
      INSERT INTO list_policies (list_id, action, folder) VALUES (?, ?, ?)
      ON CONFLICT(list_id) DO UPDATE SET
        action = excluded.action, folder = excluded.folder
      ''',
      [listId, action, folder],
    );
  }

  /// Returns the stored policy action for [listId], or null when unset.
  String? rawPolicyOf(String listId) {
    final rows = _database.select(
      'SELECT action FROM list_policies WHERE list_id = ?',
      [listId],
    );
    if (rows.isEmpty) return null;
    return rows.first['action'] as String;
  }

  /// Returns the destination folder for [listId], or null when unset.
  String? policyFolderOf(String listId) {
    final rows = _database.select(
      'SELECT folder FROM list_policies WHERE list_id = ?',
      [listId],
    );
    if (rows.isEmpty) return null;
    return rows.first['folder'] as String;
  }

  /// Records the digest prepared for [id] before any mailbox action.
  ///
  /// A decision identifier is single use, so an existing record is kept.
  void recordPreparation(String id, String listId, String digest) {
    _database.execute(
      '''INSERT OR IGNORE INTO purge_preparations
         (id, list_id, digest) VALUES (?, ?, ?)''',
      [id, listId, digest],
    );
  }

  /// Returns the recorded digest for [id], or null when absent.
  String? preparationDigestOf(String id) {
    final rows = _database.select(
      'SELECT digest FROM purge_preparations WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return rows.first['digest'] as String;
  }

  /// Whether the preparation for [id] has already been consumed.
  bool isPreparationConsumed(String id) {
    final rows = _database.select(
      'SELECT consumed FROM purge_preparations WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return false;
    return (rows.first['consumed'] as int) == 1;
  }

  /// Marks the preparation for [id] consumed after a successful action.
  void consumePreparation(String id) {
    _database.execute(
      'UPDATE purge_preparations SET consumed = 1 WHERE id = ?',
      [id],
    );
  }

  /// Records doubtful messages in the quarantine ledger.
  ///
  /// A candidate that has no persisted row is still recorded, so it can never
  /// be mistaken for one that passed verification.
  void quarantine(List<String> ids) {
    if (ids.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _database.execute('BEGIN IMMEDIATE');
    try {
      final update = _database.prepare(
        'UPDATE messages SET quarantined = 1 WHERE id = ?',
      );
      final insert = _database.prepare(
        '''INSERT OR IGNORE INTO quarantine_entries
           (message_id, quarantined_at) VALUES (?, ?)''',
      );
      for (final id in ids) {
        update.execute([id]);
        insert.execute([id, now]);
      }
      update.dispose();
      insert.dispose();
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Identifiers recorded in the quarantine ledger.
  List<String> get quarantinedIds {
    final rows = _database.select(
      'SELECT message_id FROM quarantine_entries ORDER BY message_id',
    );
    return rows.map((row) => row['message_id'] as String).toList();
  }

  /// Reads a whole thread in pre-order with a bounded recursive query.
  List<MessageRecord> subtree(String rootId, {int maxDepth = 64}) {
    final rows = _database.select(
      '''
      WITH RECURSIVE subtree (id, depth) AS (
        SELECT id, 0 FROM messages WHERE id = ?
        UNION ALL
        SELECT m.id, s.depth + 1
        FROM messages m
        JOIN subtree s ON m.parent_id = s.id
        WHERE s.depth < ?
      )
      SELECT m.* FROM messages m
      JOIN subtree s ON m.id = s.id
      ORDER BY s.depth, m.date_epoch
    ''',
      [rootId, maxDepth],
    );
    return rows.map(_toRecord).toList();
  }

  /// Searches subjects and bodies through FTS5.
  List<String> search(String terms) {
    final rows = _database.select(
      'SELECT id FROM messages_fts WHERE messages_fts MATCH ?',
      [terms],
    );
    return rows.map((row) => row['id'] as String).toList();
  }

  /// Number of persisted messages.
  int get count {
    final rows = _database.select('SELECT COUNT(*) AS total FROM messages');
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Writes a copy of the database to [destination] for a durable backup.
  void backupTo(File destination) {
    _database.execute(
      "VACUUM INTO '${destination.path.replaceAll("'", "''")}'",
    );
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
