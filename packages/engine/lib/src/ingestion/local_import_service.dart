// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

import 'package:protocol/protocol.dart';

import '../storage/blob_store.dart';
import '../storage/local_database.dart';
import '../storage/message_record.dart';
import 'local_mail_parser.dart';
import 'message_headers.dart';

/// Persists local Maildir and mbox messages into the open profile.
///
/// R24 requires local import for existing mail archives. The service validates
/// every message, stores its raw bytes by digest and skips identifiers already
/// present, so an interrupted import can be repeated safely.
final class ImportService {
  /// Creates an import service over the local store and blob backend.
  const ImportService({required this.database, required this.blobs});

  /// Local database receiving the imported messages.
  final LocalDatabase database;

  /// Content-addressed store receiving the raw message bytes.
  final BlobStore blobs;

  /// Imports [path] in [format] and returns the number of new messages.
  int importMessages(String path, MailImportFormat format) {
    final exists = switch (format) {
      MailImportFormat.maildir => Directory(path).existsSync(),
      MailImportFormat.mbox => File(path).existsSync(),
    };
    if (!exists) {
      throw const ImportException(
        'import_source_missing',
        'the local import source does not exist',
      );
    }
    final messages = switch (format) {
      MailImportFormat.maildir => LocalMailParser.parseMaildir(Directory(path)),
      MailImportFormat.mbox => LocalMailParser.parseMbox(
        File(path).readAsStringSync(),
      ),
    };
    final existing = database.messageIds.toSet();
    final records = <MessageRecord>[];
    final rawById = <String, List<int>>{};
    final roots = <String, String>{};
    for (final message in messages) {
      final messageId = headerIdentifier(message.headers['message-id']);
      if (messageId.isEmpty) {
        throw const ImportException(
          'invalid_mail',
          'a message has no usable Message-ID',
        );
      }
      if (existing.contains(messageId)) continue;
      final rawBytes = utf8.encode(message.raw);
      if (checksumOfBytes(rawBytes) != message.checksum) {
        throw const ImportException(
          'checksum_mismatch',
          'a message does not match its digest',
        );
      }
      final parentId = headerIdentifier(message.headers['in-reply-to']);
      final rootId = headerThreadRoot(
        messageId: messageId,
        inReplyTo: message.headers['in-reply-to'] ?? '',
        references: message.headers['references'] ?? '',
        roots: roots,
      );
      roots[messageId] = rootId;
      rawById[messageId] = rawBytes;
      existing.add(messageId);
      final declaredList = headerIdentifier(message.headers['list-id']);
      records.add(
        MessageRecord(
          id: messageId,
          listId: declaredList.isEmpty ? 'local-import' : declaredList,
          subject: message.headers['subject'] ?? '',
          fromAddress: message.headers['from'] ?? '',
          dateEpoch: headerEpoch(message.headers['date']),
          parentId: parentId.isEmpty ? null : parentId,
          threadRootId: rootId,
          body: message.body,
          checksum: message.checksum,
        ),
      );
    }
    if (records.isEmpty) return 0;
    for (final raw in rawById.values) {
      blobs.put(raw);
    }
    try {
      database.insertMessages(records);
    } catch (_) {
      throw const ImportException(
        'persistence_failed',
        'the imported messages were not persisted',
      );
    }
    return records.length;
  }
}
