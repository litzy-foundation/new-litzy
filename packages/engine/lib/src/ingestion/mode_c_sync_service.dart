// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:protocol/protocol.dart';

import '../storage/channel_record.dart';
import '../storage/blob_store.dart';
import '../storage/local_database.dart';
import '../storage/sync_cursor.dart';
import 'catalog.dart';
import 'channel_mapper.dart';
import 'mode_c_ingestor.dart';
import 'nntp_client.dart';
import 'public_inbox_client.dart';

/// Refreshes one catalogue channel through its declared Mode C protocol.
///
/// Every front-end reaches this service through a typed sync verb, so the
/// choice of client, the trust check and persistence stay in the engine as
/// required by R13 and ADR-0010.
final class ModeCSyncService {
  static const int _maximumRememberedThreads = 256;

  /// Creates a sync service over the local store and blob folder.
  const ModeCSyncService({required this.database, required this.blobs});

  /// Local store that receives the fetched messages.
  final LocalDatabase database;

  /// Folder that receives the raw message content.
  final BlobStore blobs;

  /// Fetches new messages for [sourceId] from [cataloguePath] and persists them.
  ///
  /// The stored cursor decides what is new. It advances only after the batch
  /// commits, so a rejected message can be fetched again on the next sync.
  Future<SyncResponse> sync(
    String id,
    String cataloguePath,
    String sourceId,
  ) async {
    final sources = CatalogLoader.load(cataloguePath);
    ListSource? source;
    for (final candidate in sources) {
      if (candidate.id == sourceId) {
        source = candidate;
        break;
      }
    }
    if (source == null) {
      throw ModeCIngestException(
        'unknown_source',
        'source $sourceId is not in the catalogue',
      );
    }
    final channel = ChannelMapper.fromSource(source);
    final cursor = database.cursorOf(channel.id) ?? const SyncCursor();
    final fetched = channel.protocol == 'nntp'
        ? await _fetchFromNntp(channel, cursor)
        : await _fetchFromInbox(channel, cursor);
    final count = fetched.messages.isEmpty
        ? 0
        : ModeCIngestor(
            database: database,
            blobs: blobs,
          ).ingest(channel, fetched.messages);
    database.setCursor(channel.id, fetched.cursor);
    return SyncResponse(id, channel.id, count);
  }

  Future<({List<RawMessage> messages, SyncCursor cursor})> _fetchFromNntp(
    ChannelRecord channel,
    SyncCursor cursor,
  ) async {
    final pieces = channel.endpoint.split('/');
    final authority = pieces.first.split(':');
    final host = authority.first;
    final port = authority.length > 1
        ? int.tryParse(authority.last) ?? 119
        : 119;
    final newsgroup = pieces.sublist(1).join('/');
    final client = NntpClient(host, port);
    try {
      await client.connect();
      await client.group(newsgroup);
      final range = '${cursor.articleNumber + 1}-';
      final overview = await client.overview(range);
      final fresh = overview
          .where((row) => row.number > cursor.articleNumber)
          .toList(growable: false);
      final messages = <RawMessage>[];
      var highest = cursor.articleNumber;
      for (final row in fresh) {
        messages.add((await client.article(row.messageId)).toRawMessage());
        if (row.number > highest) highest = row.number;
      }
      return (
        messages: messages,
        cursor: SyncCursor(articleNumber: highest, threadIds: cursor.threadIds),
      );
    } finally {
      client.close();
    }
  }

  Future<({List<RawMessage> messages, SyncCursor cursor})> _fetchFromInbox(
    ChannelRecord channel,
    SyncCursor cursor,
  ) async {
    final base = Uri.parse(channel.endpoint);
    final client = const PublicInboxClient();
    final ids = await client.recentThreadIds(base);
    final seen = cursor.threadIds.toSet();
    final fresh = ids.where((id) => !seen.contains(id)).toList();
    final messages = <RawMessage>[];
    for (final id in fresh) {
      messages.addAll(await client.threadMessages(base, id));
    }
    final remembered = <String>[];
    for (final id in [...ids, ...cursor.threadIds]) {
      if (!remembered.contains(id)) remembered.add(id);
    }
    return (
      messages: messages,
      cursor: SyncCursor(
        articleNumber: cursor.articleNumber,
        threadIds: remembered.take(_maximumRememberedThreads).toList(),
      ),
    );
  }
}
