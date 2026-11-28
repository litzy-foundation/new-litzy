// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:isolate';

part 'account_credential.dart';
part 'account_endpoint.dart';
part 'account_list_response.dart';
part 'account_view.dart';
part 'channel_list_response.dart';
part 'channel_view.dart';
part 'connect_account_request.dart';
part 'connect_account_response.dart';
part 'discover_account_request.dart';
part 'discover_account_response.dart';
part 'discovered_account.dart';
part 'list_accounts_request.dart';
part 'list_channels_request.dart';
part 'list_threads_request.dart';
part 'show_thread_request.dart';
part 'thread_list_response.dart';
part 'thread_summary.dart';

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

/// Local mailbox format accepted by the import verb.
enum MailImportFormat {
  /// A folder with `cur` and `new` message files.
  maildir,

  /// A single file with `From ` envelope lines.
  mbox,
}

/// Transport used to reach an IMAP server.
enum ImapTransportSecurity {
  /// An implicit TLS connection, which is the only remote transport.
  tls,

  /// A plain socket accepted only for loopback fixtures.
  loopbackPlain,
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
  /// The optional [blobsDirectory] overrides the sibling content-addressed
  /// folder. Front-ends never handle message bytes themselves.
  const OpenProfileRequest(super.id, this.databasePath, {this.blobsDirectory});

  /// Path of the SQLite database to open.
  final String databasePath;

  /// Optional folder for raw message content.
  final String? blobsDirectory;
}

/// Refreshes one catalogue channel using its declared Mode C protocol.
final class SyncRequest extends LmlpRequest {
  /// Creates a sync request with optional catalogue and source overrides.
  ///
  /// A null path or source tells the engine to read the declarative defaults.
  const SyncRequest(super.id, this.cataloguePath, this.sourceId);

  /// Path of the declarative source catalogue, or null for the default.
  final String? cataloguePath;

  /// Stable identifier of the source, or null for the default.
  final String? sourceId;
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

/// Reads one list from a personal IMAP mailbox into the open profile.
///
/// The password is supplied by the front-end after it reads the operating
/// system keychain. It crosses the in-process bus in memory only.
final class ImapSyncRequest extends LmlpRequest {
  /// Creates a Mode B sync request for [listId] at [host].
  const ImapSyncRequest(
    super.id, {
    required this.host,
    this.port = 993,
    required this.username,
    required this.password,
    required this.listId,
    this.mailbox = 'INBOX',
    this.security = ImapTransportSecurity.tls,
  });

  /// Host name of the RFC-compliant IMAP server.
  final String host;

  /// Port on which the IMAP server listens.
  final int port;

  /// Login name supplied to the server.
  final String username;

  /// Password read from the operating system keychain by the front-end.
  final String password;

  /// List identifier that every ingested message must declare.
  final String listId;

  /// Mailbox from which list mail is read.
  final String mailbox;

  /// Transport used for the connection.
  final ImapTransportSecurity security;
}

/// Builds and stores a quoted reply draft for one message.
final class CreateDraftRequest extends LmlpRequest {
  /// Creates a reply draft for [messageId] with the user's [body].
  const CreateDraftRequest(super.id, this.messageId, this.body);

  /// Identifier of the message being answered.
  final String messageId;

  /// Text written by the user above the quoted original.
  final String body;
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

/// Reports what one Mode B sync persisted and changed in the mailbox.
final class ImapSyncResponse extends LmlpResponse {
  /// Creates a Mode B response with its counts and classified identifiers.
  const ImapSyncResponse(
    super.id,
    this.count,
    this.snapshot,
    this.action,
    this.actedUids,
    this.quarantined,
  );

  /// Number of new messages persisted by the sync.
  final int count;

  /// Read-only snapshot of the mailbox before any action.
  final List<InboxMessage> snapshot;

  /// Stable name of the applied policy action, or `none` when no action ran.
  final String action;

  /// Mailbox unique identifiers changed by the applied policy.
  final List<String> actedUids;

  /// Mailbox unique identifiers held in quarantine.
  final List<String> quarantined;
}

/// Reports the quoted reply draft stored by the engine.
final class DraftResponse extends LmlpResponse {
  /// Creates a response describing the stored draft.
  const DraftResponse(
    super.id,
    this.draftId,
    this.messageId,
    this.subject,
    this.body,
  );

  /// Stable identifier of the draft.
  final String draftId;

  /// Identifier of the message being answered.
  final String messageId;

  /// Subject prepared for the reply.
  final String subject;

  /// Full quoted body stored in the draft.
  final String body;
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
