// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';

import 'command_line.dart';
import 'snapshot.dart';

/// The process-level result of one CLI invocation.
final class CliResult {
  /// Creates a result with an exit code and optional output streams.
  const CliResult({required this.exitCode, this.output = '', this.error = ''});

  /// Exit code returned to the operating system.
  final int exitCode;

  /// JSON written to standard output.
  final String output;

  /// Diagnostic written to standard error.
  final String error;
}

/// Executes a parsed command through the typed engine bus.
///
/// Every invocation opens the local profile and closes the isolate, so the
/// CLI holds no engine state between processes.
Future<CliResult> runCommand(ParsedCliCommand parsed) async {
  final List<LmlpRequest> requests;
  try {
    requests = await _requestsOf(parsed);
  } on SnapshotException catch (error) {
    return CliResult(exitCode: 1, error: '$error');
  }
  final client = await EngineClient.start();
  try {
    if (parsed.command is! PingCommand) {
      final opened = await client.sendRequest(
        OpenProfileRequest(
          'open',
          parsed.databasePath!,
          blobsDirectory: parsed.blobsDirectory,
          blobBackend: parsed.blobBackend,
        ),
      );
      if (opened case ErrorResponse(:final code, :final message)) {
        return CliResult(exitCode: 1, error: '$code: $message');
      }
    }
    LmlpResponse? last;
    for (final request in requests) {
      final response = await client.sendRequest(request);
      if (response is ErrorResponse) return _format(response);
      last = response;
    }
    return _format(last!);
  } finally {
    await client.close();
  }
}

Future<List<LmlpRequest>> _requestsOf(ParsedCliCommand parsed) async {
  final id = 'command';
  return switch (parsed.command) {
    PingCommand() => [PingRequest(id)],
    SyncCommand(:final cataloguePath, :final sourceId) => [
      SyncRequest(id, cataloguePath, sourceId),
    ],
    SearchCommand(:final terms) => [SearchRequest(id, terms)],
    ThreadCommand(:final rootId) => [ThreadRequest(id, rootId)],
    TriageCommand(:final messageId, :final read, :final starred) => [
      if (read != null) SetTriageRequest(id, messageId, TriageState.read, read),
      if (starred != null)
        SetTriageRequest(id, messageId, TriageState.starred, starred),
      GetTriageRequest(id, messageId),
    ],
    AuditCommand(:final snapshotPath) => [
      AuditRequest(id, readInboxSnapshot(snapshotPath)),
    ],
  };
}

CliResult _format(LmlpResponse response) => switch (response) {
  PongResponse() ||
  AckResponse() => CliResult(exitCode: 0, output: jsonEncode({'ok': true})),
  SyncResponse(:final channelId, :final count) => CliResult(
    exitCode: 0,
    output: jsonEncode({'channelId': channelId, 'count': count}),
  ),
  IngestResponse(:final count) => CliResult(
    exitCode: 0,
    output: jsonEncode({'count': count}),
  ),
  SearchResponse(:final messageIds) => CliResult(
    exitCode: 0,
    output: jsonEncode({'ids': messageIds}),
  ),
  ThreadResponse(:final messages) => CliResult(
    exitCode: 0,
    output: jsonEncode({
      'messages': messages
          .map(
            (message) => {
              'id': message.id,
              'subject': message.subject,
              'body': message.body,
            },
          )
          .toList(),
    }),
  ),
  TriageResponse(:final messageId, :final read, :final starred) => CliResult(
    exitCode: 0,
    output: jsonEncode({'id': messageId, 'read': read, 'starred': starred}),
  ),
  AuditResponse(:final residual, :final unmanaged, :final quarantined) =>
    CliResult(
      exitCode: 0,
      output: jsonEncode({
        'residual': residual,
        'unmanaged': unmanaged,
        'quarantined': quarantined,
      }),
    ),
  ErrorResponse(:final code, :final message) => CliResult(
    exitCode: 1,
    error: '$code: $message',
  ),
};
