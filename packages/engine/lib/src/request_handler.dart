// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:protocol/protocol.dart';

import 'access/access_policy.dart';
import 'access/access_policy_file.dart';
import 'access/account_discovery_service.dart';
import 'access/account_login_verifier.dart';
import 'access/account_setup_service.dart';
import 'access/discovery_exception.dart';
import 'access/discovery_http_client.dart';
import 'access/dns_srv_resolver.dart';
import 'access/http_discovery_client.dart';
import 'access/imap_login_verifier.dart';
import 'access/setup_exception.dart';
import 'access/udp_dns_srv_resolver.dart';
import 'ingestion/audit_service.dart';
import 'ingestion/draft_service.dart';
import 'ingestion/local_import_service.dart';
import 'ingestion/local_mail_parser.dart';
import 'ingestion/mode_b_sync_service.dart';
import 'ingestion/mode_c_sync_service.dart';
import 'storage/blob_store.dart';
import 'storage/legacy_blob_migrator.dart';
import 'storage/local_blob_store.dart';
import 'storage/local_database.dart';
import 'storage/message_record.dart';

/// Executes typed LMLP requests against the local profile.
///
/// The handler is exhaustive over the sealed request union, so a new verb
/// must be answered here before it can cross the isolate boundary.
final class EngineRequestHandler {
  /// Creates a handler over the default access ports, or injected fakes.
  EngineRequestHandler({
    AccessPolicy? accessPolicy,
    DiscoveryHttpClient? discoveryHttp,
    DnsSrvResolver? dns,
    AccountLoginVerifier? loginVerifier,
  }) : _policy = accessPolicy,
       _httpClient = discoveryHttp,
       _dnsResolver = dns,
       _loginCheck = loginVerifier;

  final AccessPolicy? _policy;
  final DiscoveryHttpClient? _httpClient;
  final DnsSrvResolver? _dnsResolver;
  final AccountLoginVerifier? _loginCheck;
  LocalDatabase? _database;
  BlobStore? _blobs;

  /// Answers [request] with a typed response or a deterministic error.
  Future<LmlpResponse> handle(LmlpRequest request) async {
    switch (request) {
      case PingRequest():
        return PongResponse(request.id);
      case ShutdownRequest():
        _close();
        return AckResponse(request.id);
      case OpenProfileRequest():
        return _open(request);
      case SyncRequest():
        return _sync(request);
      case ImapSyncRequest():
        return _syncImap(request);
      case DiscoverAccountRequest():
        return _discover(request);
      case ConnectAccountRequest():
        return _connect(request);
      case ListAccountsRequest():
        return _accounts(request);
      case IngestRequest():
        return _ingest(request);
      case SearchRequest():
        return _search(request);
      case ThreadRequest():
        return _thread(request.id, request.rootId);
      case ShowThreadRequest():
        return _thread(request.id, request.rootId);
      case ListChannelsRequest():
        return _channels(request);
      case ListThreadsRequest():
        return _threads(request);
      case AuditRequest():
        return _audit(request);
      case CreateDraftRequest():
        return _createDraft(request);
      case ImportRequest():
        return _import(request);
      case SetTriageRequest():
        return _setTriage(request);
      case GetTriageRequest():
        return _getTriage(request);
    }
  }

  LmlpResponse _open(OpenProfileRequest request) {
    if (request.databasePath.trim().isEmpty) {
      return ErrorResponse(
        request.id,
        'invalid_profile_path',
        'database path must not be empty',
      );
    }
    _close();
    try {
      final blobsDirectory =
          request.blobsDirectory ??
          '${File(request.databasePath).parent.path}'
              '${Platform.pathSeparator}blobs';
      final database = LocalDatabase.open(request.databasePath);
      final blobs = LocalBlobStore(Directory(blobsDirectory));
      LegacyBlobMigrator(database, blobs).migrate();
      _database = database;
      _blobs = blobs;
    } catch (_) {
      _close();
      return ErrorResponse(
        request.id,
        'profile_open_failed',
        'the local database could not be opened',
      );
    }
    return AckResponse(request.id);
  }

  Future<LmlpResponse> _sync(SyncRequest request) async {
    final database = _database;
    final blobs = _blobs;
    if (database == null || blobs == null) return _notOpen(request.id);
    try {
      return await ModeCSyncService(
        database: database,
        blobs: blobs,
      ).sync(request.id, request.cataloguePath, request.sourceId);
    } catch (error) {
      return ErrorResponse(
        request.id,
        'sync_failed',
        'the channel could not be refreshed: $error',
      );
    }
  }

  Future<LmlpResponse> _syncImap(ImapSyncRequest request) async {
    final database = _database;
    final blobs = _blobs;
    if (database == null || blobs == null) return _notOpen(request.id);
    try {
      final result = await ModeBSyncService(
        database: database,
        blobs: blobs,
      ).sync(request);
      return ImapSyncResponse(
        request.id,
        result.count,
        result.snapshot,
        result.action,
        result.actedUids,
        result.quarantined,
      );
    } on ModeBSyncException catch (error) {
      return ErrorResponse(request.id, error.code, error.message);
    } catch (_) {
      return ErrorResponse(
        request.id,
        'imap_sync_failed',
        'the mailbox could not be synchronised',
      );
    }
  }

  Future<LmlpResponse> _discover(DiscoverAccountRequest request) async {
    try {
      final service = AccountDiscoveryService(
        policy: _policy ?? AccessPolicyFile.read(),
        http:
            _httpClient ??
            const HttpDiscoveryClient(allowLoopbackPlaintextFixtures: true),
        dns: _dnsResolver ?? const UdpDnsSrvResolver(),
      );
      final account = await service.discover(request.emailAddress);
      return DiscoverAccountResponse(request.id, account);
    } on DiscoveryException catch (error) {
      return ErrorResponse(request.id, error.code, error.message);
    } catch (_) {
      return ErrorResponse(
        request.id,
        'discovery_failed',
        'the mail endpoints could not be derived',
      );
    }
  }

  Future<LmlpResponse> _connect(ConnectAccountRequest request) async {
    final database = _database;
    if (database == null) return _notOpen(request.id);
    try {
      final policy = _policy ?? AccessPolicyFile.read();
      final service = AccountSetupService(
        database: database,
        verifier:
            _loginCheck ??
            ImapLoginVerifier(
              allowLoopbackPlaintextFixtures:
                  policy.allowLoopbackPlaintextFixtures,
            ),
        policy: policy,
      );
      final record = await service.connect(request);
      return ConnectAccountResponse(
        request.id,
        record.id,
        record.email,
        request.credential.kind,
      );
    } on SetupException catch (error) {
      return ErrorResponse(request.id, error.code, error.message);
    } catch (_) {
      return ErrorResponse(
        request.id,
        'connect_failed',
        'the account could not be connected',
      );
    }
  }

  LmlpResponse _accounts(ListAccountsRequest request) {
    final database = _database;
    if (database == null) return _notOpen(request.id);
    try {
      return AccountListResponse(
        request.id,
        database
            .accounts()
            .map(
              (account) => (
                id: account.id,
                email: account.email,
                imapHost: account.imapHost,
                imapPort: account.imapPort,
                smtpHost: account.smtpHost,
                smtpPort: account.smtpPort,
                authentication: account.authentication,
                listId: account.listId,
                createdAt: account.createdAt,
              ),
            )
            .toList(growable: false),
      );
    } catch (_) {
      return ErrorResponse(
        request.id,
        'account_list_failed',
        'the accounts could not be listed',
      );
    }
  }

  LmlpResponse _ingest(IngestRequest request) {
    final database = _database;
    if (database == null) return _notOpen(request.id);
    if (request.messages.isEmpty) {
      return ErrorResponse(
        request.id,
        'empty_ingest',
        'an ingest batch must contain at least one message',
      );
    }
    try {
      database.insertMessages(
        request.messages
            .map(
              (message) => MessageRecord(
                id: message.id,
                listId: request.listId,
                subject: message.subject,
                fromAddress: message.fromAddress,
                dateEpoch: message.dateEpoch,
                parentId: message.parentId,
                threadRootId: message.threadRootId,
                body: message.body,
                checksum: message.checksum,
              ),
            )
            .toList(),
      );
    } catch (_) {
      return ErrorResponse(
        request.id,
        'ingest_failed',
        'the messages were not persisted',
      );
    }
    return IngestResponse(request.id, request.messages.length);
  }

  LmlpResponse _search(SearchRequest request) {
    final database = _database;
    if (database == null) return _notOpen(request.id);
    try {
      return SearchResponse(request.id, database.search(request.terms));
    } catch (_) {
      return ErrorResponse(
        request.id,
        'search_failed',
        'the full-text query could not be completed',
      );
    }
  }

  LmlpResponse _thread(String id, String rootId) {
    final database = _database;
    if (database == null) return _notOpen(id);
    try {
      final messages = database
          .subtree(rootId)
          .map(
            (record) => MessageData(
              id: record.id,
              listId: record.listId,
              subject: record.subject,
              fromAddress: record.fromAddress,
              dateEpoch: record.dateEpoch,
              parentId: record.parentId,
              threadRootId: record.threadRootId,
              body: record.body,
              checksum: record.checksum,
            ),
          );
      return ThreadResponse(id, messages.toList());
    } catch (_) {
      return ErrorResponse(id, 'thread_failed', 'the thread could not be read');
    }
  }

  LmlpResponse _channels(ListChannelsRequest request) {
    final database = _database;
    if (database == null) return _notOpen(request.id);
    try {
      return ChannelListResponse(
        request.id,
        database.channels
            .map(
              (channel) => (
                id: channel.id,
                listId: channel.listId,
                label: channel.label,
                protocol: channel.protocol,
                endpoint: channel.endpoint,
              ),
            )
            .toList(growable: false),
      );
    } catch (_) {
      return ErrorResponse(
        request.id,
        'channel_list_failed',
        'the channels could not be listed',
      );
    }
  }

  LmlpResponse _threads(ListThreadsRequest request) {
    final database = _database;
    if (database == null) return _notOpen(request.id);
    try {
      return ThreadListResponse(
        request.id,
        database.threadSummaries(channelId: request.channelId).toList(),
      );
    } catch (_) {
      return ErrorResponse(
        request.id,
        'thread_list_failed',
        'the topics could not be listed',
      );
    }
  }

  LmlpResponse _audit(AuditRequest request) {
    final database = _database;
    if (database == null) return _notOpen(request.id);
    try {
      final report = AuditService(database: database).inspect(request.messages);
      return AuditResponse(
        request.id,
        report.residual.map((message) => message.uid).toList(),
        report.unmanaged.map((message) => message.uid).toList(),
        report.quarantined.map((message) => message.uid).toList(),
      );
    } catch (_) {
      return ErrorResponse(
        request.id,
        'audit_failed',
        'the inbox snapshot could not be audited',
      );
    }
  }

  LmlpResponse _createDraft(CreateDraftRequest request) {
    final database = _database;
    if (database == null) return _notOpen(request.id);
    try {
      final draft = DraftService(database: database)
          .create(request.messageId, request.body);
      return DraftResponse(
        request.id,
        draft.draftId,
        draft.messageId,
        draft.subject,
        draft.body,
      );
    } on DraftException catch (error) {
      return ErrorResponse(request.id, error.code, error.message);
    } catch (_) {
      return ErrorResponse(
        request.id,
        'draft_failed',
        'the reply draft was not stored',
      );
    }
  }

  LmlpResponse _import(ImportRequest request) {
    final database = _database;
    final blobs = _blobs;
    if (database == null || blobs == null) return _notOpen(request.id);
    try {
      final count = ImportService(
        database: database,
        blobs: blobs,
      ).importMessages(request.path, request.format);
      return ImportResponse(request.id, count);
    } on ImportException catch (error) {
      return ErrorResponse(request.id, error.code, error.message);
    } catch (_) {
      return ErrorResponse(
        request.id,
        'import_failed',
        'the local mail could not be imported',
      );
    }
  }

  LmlpResponse _setTriage(SetTriageRequest request) {
    final database = _database;
    if (database == null) return _notOpen(request.id);
    if (database.triageOf(request.messageId) == null) {
      return ErrorResponse(
        request.id,
        'message_not_found',
        'the message is not in the open profile',
      );
    }
    try {
      database.setTriage(
        request.messageId,
        read: request.state == TriageState.read ? request.enabled : null,
        starred: request.state == TriageState.starred ? request.enabled : null,
      );
      final flags = database.triageOf(request.messageId)!;
      return TriageResponse(
        request.id,
        request.messageId,
        flags.read,
        flags.starred,
      );
    } catch (_) {
      return ErrorResponse(
        request.id,
        'triage_failed',
        'the triage flag was not changed',
      );
    }
  }

  LmlpResponse _getTriage(GetTriageRequest request) {
    final database = _database;
    if (database == null) return _notOpen(request.id);
    try {
      final flags = database.triageOf(request.messageId);
      if (flags == null) {
        return ErrorResponse(
          request.id,
          'message_not_found',
          'the message is not in the open profile',
        );
      }
      return TriageResponse(
        request.id,
        request.messageId,
        flags.read,
        flags.starred,
      );
    } catch (_) {
      return ErrorResponse(
        request.id,
        'triage_failed',
        'the triage flags could not be read',
      );
    }
  }

  ErrorResponse _notOpen(String id) => ErrorResponse(
    id,
    'profile_not_open',
    'open a local profile before using this verb',
  );

  void _close() {
    final database = _database;
    _database = null;
    _blobs = null;
    database?.close();
  }
}
