// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:isolate';

/// A value that may cross the in-process boundary between UI and engine.
sealed class LmlpMessage {
  /// Creates a message.
  const LmlpMessage();
}

/// An immutable message payload shared by every front-end and the engine.
final class MessageData {
  /// Creates a message payload with its indexing and content fields.
  const MessageData({
    required this.id,
    required this.listId,
    required this.subject,
    required this.fromAddress,
    required this.dateEpoch,
    required this.parentId,
    required this.threadRootId,
    required this.body,
    required this.checksum,
  });

  /// Stable message identifier.
  final String id;

  /// Identifier of the list or channel that delivered the message.
  final String listId;

  /// Subject line.
  final String subject;

  /// Address of the author.
  final String fromAddress;

  /// Message date in epoch seconds.
  final int dateEpoch;

  /// Identifier of the parent message, or null for a root.
  final String? parentId;

  /// Identifier of the thread root.
  final String threadRootId;

  /// Raw message body.
  final String body;

  /// SHA-256 digest of the raw source.
  final String checksum;
}

/// A typed instruction sent by a front-end to the engine.
sealed class LmlpRequest extends LmlpMessage {
  /// Creates a request with the identifier used to match its response.
  const LmlpRequest(this.id);

  /// Identifier echoed by the response that answers this request.
  final String id;
}

/// Requests a response that proves the engine isolate is alive.
final class PingRequest extends LmlpRequest {
  /// Creates a ping with the given identifier.
  const PingRequest(super.id);
}

/// Asks the engine to finish its work and close its isolate port.
final class ShutdownRequest extends LmlpRequest {
  /// Creates a shutdown request with the given identifier.
  const ShutdownRequest(super.id);
}

/// Local backend that holds raw message content.
///
/// ADR-0006 allows an equivalent folder and SQLite implementation. The
/// folder is the default so an existing profile keeps its current layout.
enum BlobBackend {
  /// Content-addressed files named by SHA-256 digest.
  folder,

  /// Zstd-compressed rows in the profile database.
  sqlite,
}

/// Opens the local profile before any data operation.
final class OpenProfileRequest extends LmlpRequest {
  /// Creates a request for the database at [databasePath].
  ///
  /// The optional [blobsDirectory] overrides the sibling folder used by the
  /// folder backend. Front-ends never handle message bytes themselves.
  const OpenProfileRequest(
    super.id,
    this.databasePath, {
    this.blobsDirectory,
    this.blobBackend = BlobBackend.folder,
  });

  /// Path of the SQLite database to open.
  final String databasePath;

  /// Optional folder for raw message content.
  final String? blobsDirectory;

  /// Backend selected for raw message content.
  final BlobBackend blobBackend;
}

/// Refreshes one catalogue channel using its declared Mode C protocol.
final class SyncRequest extends LmlpRequest {
  /// Creates a sync request for [sourceId] in the catalogue at [cataloguePath].
  const SyncRequest(super.id, this.cataloguePath, this.sourceId);

  /// Path of the declarative source catalogue.
  final String cataloguePath;

  /// Stable identifier of the source to refresh.
  final String sourceId;
}

/// Persists one batch of messages in the open profile.
final class IngestRequest extends LmlpRequest {
  /// Creates an ingest request for [listId] with immutable [messages].
  const IngestRequest(super.id, this.listId, this.messages);

  /// Identifier of the source list.
  final String listId;

  /// Messages to persist atomically.
  final List<MessageData> messages;
}

/// Searches subjects and bodies through the local full-text index.
final class SearchRequest extends LmlpRequest {
  /// Creates a search request for [terms].
  const SearchRequest(super.id, this.terms);

  /// Full-text query terms.
  final String terms;
}

/// Reads one thread in pre-order from the open profile.
final class ThreadRequest extends LmlpRequest {
  /// Creates a request for the thread rooted at [rootId].
  const ThreadRequest(super.id, this.rootId);

  /// Identifier of the thread root.
  final String rootId;
}

/// A typed answer sent by the engine for one request identifier.
sealed class LmlpResponse extends LmlpMessage {
  /// Creates a response for the given request identifier.
  const LmlpResponse(this.id);

  /// Identifier of the request this response answers.
  final String id;
}

/// Confirms that the engine answered a ping.
final class PongResponse extends LmlpResponse {
  /// Creates a pong for the given request identifier.
  const PongResponse(super.id);
}

/// Confirms that an instruction was carried out.
final class AckResponse extends LmlpResponse {
  /// Creates an acknowledgement for the given request identifier.
  const AckResponse(super.id);
}

/// Reports a deterministic failure for one request.
final class ErrorResponse extends LmlpResponse {
  /// Creates an error response with a stable code and a readable message.
  const ErrorResponse(super.id, this.code, this.message);

  /// Stable machine-readable code.
  final String code;

  /// Human-readable explanation of the failure.
  final String message;
}

/// Reports how many messages were persisted by an ingest request.
final class IngestResponse extends LmlpResponse {
  /// Creates an ingest response with the persisted [count].
  const IngestResponse(super.id, this.count);

  /// Number of persisted messages.
  final int count;
}

/// Returns the message identifiers matching a full-text query.
final class SearchResponse extends LmlpResponse {
  /// Creates a search response with the matching [messageIds].
  const SearchResponse(super.id, this.messageIds);

  /// Identifiers of the matching messages.
  final List<String> messageIds;
}

/// Reports the channel and message count produced by a sync request.
final class SyncResponse extends LmlpResponse {
  /// Creates a sync response for [channelId] with [count] messages.
  const SyncResponse(super.id, this.channelId, this.count);

  /// Identifier of the refreshed channel.
  final String channelId;

  /// Number of messages persisted by the refresh.
  final int count;
}

/// Returns the messages of one thread in pre-order.
final class ThreadResponse extends LmlpResponse {
  /// Creates a thread response with its ordered [messages].
  const ThreadResponse(super.id, this.messages);

  /// Messages in pre-order.
  final List<MessageData> messages;
}

/// A typed notification pushed by the engine without a request.
sealed class LmlpEvent extends LmlpMessage {
  /// Creates an event.
  const LmlpEvent();
}

/// Announces the port on which a newly started engine receives requests.
final class EngineReadyEvent extends LmlpEvent {
  /// Creates a ready event carrying the engine receive port.
  const EngineReadyEvent({required this.port});

  /// Port on which the engine listens for typed messages.
  final SendPort port;
}
