// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:protocol/protocol.dart';

import 'ingestion/mode_c_sync_service.dart';
import 'storage/local_blob_store.dart';
import 'storage/local_database.dart';
import 'storage/message_record.dart';

/// Executes typed LMLP requests against the local profile.
///
/// The handler is exhaustive over the sealed request union, so a new verb
/// must be answered here before it can cross the isolate boundary.
final class EngineRequestHandler {
  LocalDatabase? _database;
  LocalBlobStore? _blobs;

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
      case IngestRequest():
        return _ingest(request);
      case SearchRequest():
        return _search(request);
      case ThreadRequest():
        return _thread(request);
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
      _blobs = LocalBlobStore(Directory(blobsDirectory));
      _database = LocalDatabase.open(request.databasePath);
    } catch (_) {
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

  LmlpResponse _thread(ThreadRequest request) {
    final database = _database;
    if (database == null) return _notOpen(request.id);
    try {
      final messages = database
          .subtree(request.rootId)
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
      return ThreadResponse(request.id, messages.toList());
    } catch (_) {
      return ErrorResponse(
        request.id,
        'thread_failed',
        'the thread could not be read',
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
