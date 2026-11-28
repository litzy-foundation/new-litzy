// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';

import '../storage/channel_record.dart';
import '../storage/blob_store.dart';
import '../storage/local_database.dart';
import '../storage/message_record.dart';
import 'public_inbox_client.dart';

/// Reports a Mode C message that cannot be trusted or persisted.
final class ModeCIngestException implements Exception {
  /// Creates an exception with a stable [code] and a readable [message].
  const ModeCIngestException(this.code, this.message);

  /// Stable failure code such as `list_id_mismatch`.
  final String code;

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => 'mode C ingestion failed ($code): $message';
}

/// Persists fetched public messages into the selected channel.
///
/// Every message must carry the list identifier declared by the catalogue,
/// which keeps list mail out of a personal mailbox as required by R15. The
/// raw source is stored by digest before the SQLite batch commits, so the
/// purge coordinator can later verify it as required by R16.
final class ModeCIngestor {
  /// Creates an ingestor over the local store and blob folder.
  const ModeCIngestor({required this.database, required this.blobs});

  /// Local database holding channels, messages and the search index.
  final LocalDatabase database;

  /// Content-addressed folder holding the raw message sources.
  final BlobStore blobs;

  /// Verifies and persists [messages] for [channel], returning their count.
  int ingest(ChannelRecord channel, Iterable<RawMessage> messages) {
    final incoming = messages.toList(growable: false);
    if (incoming.isEmpty) {
      throw const ModeCIngestException('empty_batch', 'no messages to ingest');
    }
    final roots = <String, String>{};
    final rawById = <String, List<int>>{};
    final records = <MessageRecord>[];
    for (final message in incoming) {
      final rawBytes = utf8.encode(message.raw);
      if (checksumOfBytes(rawBytes) != message.checksum) {
        throw const ModeCIngestException(
          'checksum_mismatch',
          'the raw message does not match its digest',
        );
      }
      final listId = _identifier(message.headers['list-id']);
      if (listId.isEmpty) {
        throw const ModeCIngestException(
          'missing_list_id',
          'the message has no List-Id header',
        );
      }
      if (listId != channel.listId) {
        throw ModeCIngestException(
          'list_id_mismatch',
          'expected ${channel.listId} but found $listId',
        );
      }
      final messageId = _identifier(message.headers['message-id']);
      if (messageId.isEmpty) {
        throw const ModeCIngestException(
          'invalid_message_id',
          'the message has no usable Message-ID',
        );
      }
      final parentId = _identifier(message.headers['in-reply-to']);
      final firstReference = _identifier(
        RegExp(r'<[^>]+>')
            .firstMatch(message.headers['references'] ?? '')
            ?.group(0),
      );
      final rootId = firstReference.isNotEmpty
          ? firstReference
          : parentId.isNotEmpty && roots.containsKey(parentId)
          ? roots[parentId]!
          : messageId;
      roots[messageId] = rootId;
      rawById[messageId] = rawBytes;
      records.add(
        MessageRecord(
          id: messageId,
          listId: channel.listId,
          subject: message.headers['subject'] ?? '',
          fromAddress: message.headers['from'] ?? '',
          dateEpoch: _epoch(message.headers['date']),
          parentId: parentId.isEmpty ? null : parentId,
          threadRootId: rootId,
          body: message.body,
          checksum: message.checksum,
        ),
      );
    }

    database.upsertChannel(channel);
    for (final raw in rawById.values) {
      blobs.put(raw);
    }
    try {
      database.insertMessages(records);
    } catch (_) {
      throw const ModeCIngestException(
        'persistence_failed',
        'the message batch was not persisted',
      );
    }
    return records.length;
  }

  static String _identifier(String? value) =>
      value?.replaceAll(RegExp(r'[<>\s]'), '') ?? '';

  static int _epoch(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value);
    return parsed == null ? 0 : parsed.millisecondsSinceEpoch ~/ 1000;
  }
}
