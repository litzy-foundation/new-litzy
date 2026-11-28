// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:protocol/protocol.dart';

import '../storage/channel_record.dart';
import '../storage/blob_store.dart';
import '../storage/local_database.dart';
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
  /// Creates a sync service over the local store and blob folder.
  const ModeCSyncService({required this.database, required this.blobs});

  /// Local store that receives the fetched messages.
  final LocalDatabase database;

  /// Folder that receives the raw message content.
  final BlobStore blobs;

  /// Fetches [sourceId] from [cataloguePath] and persists its messages.
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
    final messages = channel.protocol == 'nntp'
        ? await _fetchFromNntp(channel)
        : await _fetchFromInbox(channel);
    final count = ModeCIngestor(
      database: database,
      blobs: blobs,
    ).ingest(channel, messages);
    return SyncResponse(id, channel.id, count);
  }

  Future<List<RawMessage>> _fetchFromNntp(ChannelRecord channel) async {
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
      final overview = await client.overview('1-');
      final messages = <RawMessage>[];
      for (final row in overview) {
        messages.add((await client.article(row.messageId)).toRawMessage());
      }
      return messages;
    } finally {
      client.close();
    }
  }

  Future<List<RawMessage>> _fetchFromInbox(ChannelRecord channel) async {
    final base = Uri.parse(channel.endpoint);
    final client = const PublicInboxClient();
    final ids = await client.recentThreadIds(base);
    final messages = <RawMessage>[];
    for (final id in ids) {
      messages.addAll(await client.threadMessages(base, id));
    }
    return messages;
  }
}
