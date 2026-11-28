// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:protocol/protocol.dart';

import '../storage/blob_store.dart';
import '../storage/channel_record.dart';
import '../storage/local_database.dart';
import 'imap_client.dart';
import 'list_message_ingestor.dart';
import 'message_headers.dart';
import 'purge_coordinator.dart';

/// Reports a Mode B sync that could not be completed safely.
final class ModeBSyncException implements Exception {
  /// Creates an exception with a stable [code] and a readable [message].
  const ModeBSyncException(this.code, this.message);

  /// Stable failure code such as `insecure_transport`.
  final String code;

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => 'Mode B sync failed ($code): $message';
}

/// The durable outcome of one Mode B sync.
final class ModeBSyncResult {
  /// Creates a result with its persistence and mailbox effects.
  const ModeBSyncResult({
    required this.count,
    required this.snapshot,
    required this.action,
    required this.actedUids,
    required this.quarantined,
  });

  /// Number of new messages persisted by the sync.
  final int count;

  /// Read-only snapshot taken before any mailbox action.
  final List<InboxMessage> snapshot;

  /// Stable name of the applied policy action, or `none` when nothing ran.
  final String action;

  /// Mailbox identifiers changed by the applied policy.
  final List<String> actedUids;

  /// Mailbox identifiers held in quarantine.
  final List<String> quarantined;
}

/// Reads one list from IMAP and applies the stored mailbox policy.
///
/// Only messages whose List-Id matches the selected list enter the local
/// profile, so personal mail never reaches storage or a mailbox action. The
/// persistence and the action both go through the same verified pipeline used
/// by the other ingestion modes, as required by R15 and R16.
final class ModeBSyncService {
  /// Creates a sync service over the local store and blob backend.
  const ModeBSyncService({required this.database, required this.blobs});

  /// Local database receiving messages and purge decisions.
  final LocalDatabase database;

  /// Local content store receiving verified raw messages.
  final BlobStore blobs;

  /// Fetches [request] through one IMAP client and applies the stored policy.
  Future<ModeBSyncResult> sync(ImapSyncRequest request) async {
    final listId = headerIdentifier(request.listId);
    if (listId.isEmpty) {
      throw const ModeBSyncException(
        'invalid_list',
        'the selected list identifier is empty',
      );
    }
    final channel = ChannelRecord(
      id: 'imap:$listId',
      listId: listId,
      label: request.listId,
      protocol: 'imap',
      endpoint: '${request.host}:${request.port}',
    );
    final client = ImapClient(
      host: request.host,
      port: request.port,
      username: request.username,
      password: request.password,
      mailbox: request.mailbox,
      security: request.security,
    );
    try {
      await client.connect();
      final fetched = await client.fetchMessages();
      final matching = fetched
          .where(
            (message) =>
                headerIdentifier(message.rawMessage.headers['list-id']) ==
                listId,
          )
          .toList(growable: false);
      final existing = database.messageIds.toSet();
      final fresh = matching
          .where(
            (message) => !existing.contains(
              headerIdentifier(message.rawMessage.headers['message-id']),
            ),
          )
          .map((message) => message.rawMessage)
          .toList(growable: false);
      final count = fresh.isEmpty
          ? 0
          : ListMessageIngestor(
              database: database,
              blobs: blobs,
            ).ingest(channel, fresh);
      final result = await _applyPolicies(client, channel, matching);
      return ModeBSyncResult(
        count: count,
        snapshot: List<InboxMessage>.unmodifiable(
          fetched.map((message) => message.inboxMessage),
        ),
        action: result.action,
        actedUids: result.actedUids,
        quarantined: result.quarantined,
      );
    } on ImapException catch (error) {
      throw ModeBSyncException(error.code, error.message);
    } on ListMessageIngestException catch (error) {
      throw ModeBSyncException(error.code, error.message);
    } finally {
      await client.close();
    }
  }

  Future<({String action, List<String> actedUids, List<String> quarantined})>
  _applyPolicies(
    ImapClient client,
    ChannelRecord channel,
    List<ImapMessage> messages,
  ) async {
    final coordinator = PurgeCoordinator(
      database: database,
      blobs: blobs,
      mailbox: client,
    );
    final actedUids = <String>[];
    final quarantined = <String>[];
    var appliedAction = 'none';
    for (final message in messages) {
      final messageId = headerIdentifier(
        message.rawMessage.headers['message-id'],
      );
      final decisionId = 'modeb:${channel.id}:$messageId:${message.uid}';
      if (database.isPreparationConsumed(decisionId)) continue;
      final candidate = PurgeCandidate(
        uid: message.uid,
        messageId: messageId,
        checksum: message.rawMessage.checksum,
      );
      final plan = await coordinator.prepare(decisionId, channel.listId, [
        candidate,
      ]);
      quarantined.addAll(plan.quarantined.map((candidate) => candidate.uid));
      if (plan.accepted.isEmpty) continue;
      final outcome = await coordinator.commit(plan);
      switch (outcome) {
        case PurgeApplied(:final action, :final uids):
          appliedAction = action;
          actedUids.addAll(uids);
        case PurgeRejected(:final reason):
          throw ModeBSyncException('purge_failed', reason);
      }
    }
    return (
      action: appliedAction,
      actedUids: List<String>.unmodifiable(actedUids),
      quarantined: List<String>.unmodifiable(quarantined),
    );
  }
}
