// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:l10n/l10n.dart';
import 'package:protocol/protocol.dart';
import 'package:security/security.dart';

import 'cli_messages.dart';
import 'command_line.dart';
import 'password_reader.dart';
import 'snapshot.dart';
import 'terminal_password_reader.dart';

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
Future<CliResult> runCommand(
  ParsedCliCommand parsed, {
  SecretStore? secretStore,
  PasswordReader? passwordReader,
  AppMessages? messages,
}) async {
  if (parsed.command case ConnectCommand(:final emailAddress)) {
    return _connectAccount(
      parsed,
      emailAddress,
      secretStore: secretStore,
      passwordReader: passwordReader,
      messages: messages,
    );
  }
  final List<LmlpRequest> requests;
  try {
    requests = await _requestsOf(parsed);
  } on SnapshotException catch (error) {
    return CliResult(exitCode: 1, error: '$error');
  }
  final client = await EngineClient.start();
  try {
    if (parsed.databasePath != null) {
      final opened = await client.sendRequest(
        OpenProfileRequest(
          'open',
          parsed.databasePath!,
          blobsDirectory: parsed.blobsDirectory,
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

Future<CliResult> _connectAccount(
  ParsedCliCommand parsed,
  String emailAddress, {
  SecretStore? secretStore,
  PasswordReader? passwordReader,
  AppMessages? messages,
}) async {
  final text = messages ?? CliMessages.read();
  final reader = passwordReader ?? TerminalPasswordReader();
  late final CredentialVault vault;
  try {
    vault = CredentialVault(
      store: secretStore ?? LibsecretStore(),
      providers: const [],
    );
  } on SecretStoreException catch (error) {
    return CliResult(exitCode: 1, error: 'keychain_unavailable: $error');
  }

  final client = await EngineClient.start();
  try {
    final opened = await client.sendRequest(
      OpenProfileRequest(
        'open',
        parsed.databasePath!,
        blobsDirectory: parsed.blobsDirectory,
      ),
    );
    if (opened case ErrorResponse(:final code, :final message)) {
      return CliResult(exitCode: 1, error: '$code: $message');
    }
    final discovered = await client.sendRequest(
      DiscoverAccountRequest('discover', emailAddress),
    );
    if (discovered case ErrorResponse(:final code, :final message)) {
      return CliResult(exitCode: 1, error: '$code: $message');
    }
    if (discovered is! DiscoverAccountResponse) {
      return const CliResult(exitCode: 1, error: 'unexpected_response');
    }
    final account = discovered.account;
    if (account.imap.authentication != AccountAuthentication.password ||
        account.smtp.authentication != AccountAuthentication.password) {
      return CliResult(exitCode: 1, error: text.accountUnsupportedAuth);
    }

    final password = await reader.read(text.passwordPrompt(emailAddress));
    if (password.isEmpty) {
      return CliResult(exitCode: 1, error: text.passwordRequired);
    }
    final server = Uri(
      scheme: account.imap.security == AccountSecurity.implicitTls
          ? 'imaps'
          : 'imap',
      host: account.imap.host,
      port: account.imap.port,
    );
    try {
      await vault.storePassword(
        server: server,
        username: emailAddress,
        password: password,
      );
    } on CredentialException catch (error) {
      return CliResult(exitCode: 1, error: '$error');
    }

    try {
      final connected = await client.sendRequest(
        ConnectAccountRequest(
          'connect',
          emailAddress: emailAddress,
          credential: AccountCredential.password(password),
          imap: account.imap,
          smtp: account.smtp,
        ),
      );
      if (connected case ErrorResponse()) {
        await vault.forgetPassword(server: server, username: emailAddress);
      }
      return _format(connected);
    } on Object {
      await vault.forgetPassword(server: server, username: emailAddress);
      rethrow;
    }
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
    ConnectCommand() => throw StateError(
      'a connection needs an interactive flow',
    ),
    DiscoverCommand(:final emailAddress) => [
      DiscoverAccountRequest(id, emailAddress),
    ],
    AccountsCommand() => [ListAccountsRequest(id)],
    ChannelsCommand() => [ListChannelsRequest(id)],
    ListCommand(:final channelId) => [ListThreadsRequest(id, channelId)],
    ShowCommand(:final rootId) => [ShowThreadRequest(id, rootId)],
    SearchCommand(:final terms) => [SearchRequest(id, terms)],
    ThreadCommand(:final rootId) => [ThreadRequest(id, rootId)],
    ReplyCommand(:final messageId, :final body) => [
      CreateDraftRequest(id, messageId, body),
    ],
    ImportCommand(:final path, :final format) => [
      ImportRequest(id, path, format),
    ],
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
  ChannelListResponse(:final channels) => CliResult(
    exitCode: 0,
    output: jsonEncode({
      'channels': channels
          .map(
            (ChannelView channel) => {
              'id': channel.id,
              'listId': channel.listId,
              'label': channel.label,
              'protocol': channel.protocol,
              'endpoint': channel.endpoint,
            },
          )
          .toList(),
    }),
  ),
  ThreadListResponse(:final threads) => CliResult(
    exitCode: 0,
    output: jsonEncode({
      'threads': threads
          .map(
            (ThreadSummary thread) => {
              'rootId': thread.rootId,
              'listId': thread.listId,
              'subject': thread.subject,
              'messageCount': thread.messageCount,
              'lastActivityEpoch': thread.lastActivityEpoch,
            },
          )
          .toList(),
    }),
  ),
  ThreadResponse(:final messages) => CliResult(
    exitCode: 0,
    output: jsonEncode({
      'messages': messages
          .map(
            (message) => {
              'id': message.id,
              'rootId': message.threadRootId,
              'parentId': message.parentId,
              'subject': message.subject,
              'from': message.fromAddress,
              'date': message.dateEpoch,
              'body': message.body,
            },
          )
          .toList(),
    }),
  ),
  DraftResponse(
    :final draftId,
    :final messageId,
    :final subject,
    :final body,
  ) =>
    CliResult(
      exitCode: 0,
      output: jsonEncode({
        'draftId': draftId,
        'messageId': messageId,
        'subject': subject,
        'body': body,
      }),
    ),
  ImportResponse(:final count) => CliResult(
    exitCode: 0,
    output: jsonEncode({'count': count}),
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
  ImapSyncResponse(
    :final count,
    :final action,
    :final actedUids,
    :final quarantined,
  ) =>
    CliResult(
      exitCode: 0,
      output: jsonEncode({
        'count': count,
        'action': action,
        'actedUids': actedUids,
        'quarantined': quarantined,
      }),
    ),
  DiscoverAccountResponse(:final account) => CliResult(
    exitCode: 0,
    output: jsonEncode({
      'email': account.emailAddress,
      'verified': account.verified,
      'imap': {
        'host': account.imap.host,
        'port': account.imap.port,
        'security': account.imap.security.name,
        'authentication': account.imap.authentication.name,
        'source': account.imap.source.name,
      },
      'smtp': {
        'host': account.smtp.host,
        'port': account.smtp.port,
        'security': account.smtp.security.name,
        'authentication': account.smtp.authentication.name,
        'source': account.smtp.source.name,
      },
    }),
  ),
  ConnectAccountResponse(
    :final accountId,
    :final emailAddress,
    :final authentication,
  ) =>
    CliResult(
      exitCode: 0,
      output: jsonEncode({
        'accountId': accountId,
        'email': emailAddress,
        'authentication': authentication.name,
      }),
    ),
  AccountListResponse(:final accounts) => CliResult(
    exitCode: 0,
    output: jsonEncode({
      'accounts': accounts
          .map(
            (account) => {
              'id': account.id,
              'email': account.email,
              'imapHost': account.imapHost,
              'imapPort': account.imapPort,
              'smtpHost': account.smtpHost,
              'smtpPort': account.smtpPort,
              'authentication': account.authentication,
              'listId': account.listId,
              'createdAt': account.createdAt,
            },
          )
          .toList(),
    }),
  ),
  ErrorResponse(:final code, :final message) => CliResult(
    exitCode: 1,
    error: '$code: $message',
  ),
};
