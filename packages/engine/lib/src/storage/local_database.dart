// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'message_record.dart';

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
        checksum TEXT NOT NULL
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

  /// Returns the verified checksum for [id], or null when absent.
  String? checksumOf(String id) {
    final rows = _database.select(
      'SELECT checksum FROM messages WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return rows.first['checksum'] as String;
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
