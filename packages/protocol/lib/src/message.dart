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

/// One message in the front-end's snapshot of an inbox.
///
/// The front-end reads flags and headers from a mailbox; the engine decides
/// which messages count as residual list mail under the stored policy. A
/// message without a list identifier is personal mail and is not audited.
final class InboxMessage {
  /// Creates a snapshot entry with its mailbox and message identifiers.
  const InboxMessage({required this.uid, required this.messageId, this.listId});

  /// Mailbox unique identifier used by the front-end.
  final String uid;

  /// Stable identifier of the message.
  final String messageId;

  /// List identifier declared by the message headers, if any.
  final String? listId;
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

/// Local mailbox format accepted by the import verb.
enum MailImportFormat {
  /// A folder with `cur` and `new` message files.
  maildir,

  /// A single file with `From ` envelope lines.
  mbox,
}

/// One mutable flag in the local triage state.
enum TriageState {
  /// Whether the message has been read.
  read,

  /// Whether the user starred the message.
  starred,
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

/// Imports local Maildir or mbox mail into the open profile.
final class ImportRequest extends LmlpRequest {
  /// Creates an import request for [path] in [format].
  const ImportRequest(super.id, this.path, this.format);

  /// Path of the local Maildir folder or mbox file.
  final String path;

  /// Format used to parse the source.
  final MailImportFormat format;
}

/// Changes one triage flag on one persisted message.
final class SetTriageRequest extends LmlpRequest {
  /// Creates a request that sets [state] to [enabled] for [messageId].
  const SetTriageRequest(super.id, this.messageId, this.state, this.enabled);

  /// Identifier of the message to change.
  final String messageId;

  /// Flag to change.
  final TriageState state;

  /// New value of the flag.
  final bool enabled;
}

/// Reads the triage flags of one persisted message.
final class GetTriageRequest extends LmlpRequest {
  /// Creates a request for the flags of [messageId].
  const GetTriageRequest(super.id, this.messageId);

  /// Identifier of the message to inspect.
  final String messageId;
}

/// Asks the engine to audit a read-only snapshot of inbox messages.
final class AuditRequest extends LmlpRequest {
  /// Creates an audit request for [messages].
  const AuditRequest(super.id, this.messages);

  /// Snapshot gathered by the front-end's mailbox reader.
  final List<InboxMessage> messages;
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

/// Reports how many new messages an import persisted.
final class ImportResponse extends LmlpResponse {
  /// Creates an import response with [count] persisted messages.
  const ImportResponse(super.id, this.count);

  /// Number of new messages persisted by the import.
  final int count;
}

/// Reports both triage flags of one persisted message.
final class TriageResponse extends LmlpResponse {
  /// Creates a response for [messageId] with both flags.
  const TriageResponse(super.id, this.messageId, this.read, this.starred);

  /// Identifier of the inspected message.
  final String messageId;

  /// Whether the message has been read.
  final bool read;

  /// Whether the message is starred.
  final bool starred;
}

/// Reports the engine's read-only verdict on an inbox snapshot.
final class AuditResponse extends LmlpResponse {
  /// Creates an audit response with the classified mailbox identifiers.
  const AuditResponse(
    super.id,
    this.residual,
    this.unmanaged,
    this.quarantined,
  );

  /// Mailbox identifiers that remain under an active list policy.
  final List<String> residual;

  /// Mailbox identifiers from lists without a stored policy.
  final List<String> unmanaged;

  /// Mailbox identifiers held deliberately in the quarantine ledger.
  final List<String> quarantined;
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
