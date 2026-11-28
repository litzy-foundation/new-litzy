// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:protocol/protocol.dart';

import 'local_mail_parser.dart';
import 'mailbox_port.dart';
import 'message_headers.dart';
import 'public_inbox_client.dart';

/// Reports a failed IMAP command or a local violation of the transport rules.
final class ImapException implements MailboxException {
  /// Creates an exception with a stable [code] and a readable [message].
  const ImapException(this.code, this.message);

  /// Stable failure code such as `authentication_failed`.
  @override
  final String code;

  /// Explanation that never contains credential material.
  @override
  final String message;

  @override
  String toString() => 'IMAP error $code: $message';
}

/// One message fetched from an IMAP mailbox with its envelope identifier.
final class ImapMessage {
  /// Creates a fetched message with its mailbox and message identifiers.
  const ImapMessage({
    required this.uid,
    required this.rawMessage,
    required this.inboxMessage,
  });

  /// Mailbox unique identifier used by subsequent mailbox actions.
  final String uid;

  /// Parsed RFC 5322 message with its content digest.
  final RawMessage rawMessage;

  /// Read-only snapshot entry for the audit verb.
  final InboxMessage inboxMessage;
}

final class _ImapResponse {
  const _ImapResponse(this.line, this.literal);

  final String line;
  final List<int>? literal;
}

final class _CommandResult {
  const _CommandResult(this.ok, this.responses);

  final bool ok;
  final List<_ImapResponse> responses;
}

final class _PendingCommand {
  _PendingCommand(this.tag, this.failureCode, this.allowFailure);

  final String tag;
  final String failureCode;
  final bool allowFailure;
  final Completer<_CommandResult> completer = Completer<_CommandResult>();
  final List<_ImapResponse> responses = <_ImapResponse>[];
}

/// A small RFC-compliant IMAP client for Mode B mailbox ingestion.
///
/// The client owns one command at a time, authenticates with RFC LOGIN and
/// uses an implicit TLS connection unless it is explicitly pointed at a
/// loopback fixture. It implements `MailboxPort` so the purge coordinator can
/// act on a real mailbox through the same boundary used by its tests.
final class ImapClient implements MailboxPort {
  /// Creates a client for [host] and [port].
  ImapClient({
    required this.host,
    this.port = 993,
    required this.username,
    required this.password,
    this.mailbox = 'INBOX',
    this.security = ImapTransportSecurity.tls,
    this.timeout = const Duration(seconds: 10),
  });

  /// Host name of the IMAP server.
  final String host;

  /// Port on which the IMAP server listens.
  final int port;

  /// Login name supplied to the server.
  final String username;

  /// Password supplied by the front-end from the operating system keychain.
  final String password;

  /// Mailbox read by fetches and changed by mailbox actions.
  final String mailbox;

  /// Transport used for the connection.
  final ImapTransportSecurity security;

  /// Deadline applied to connection and command completion.
  final Duration timeout;

  Socket? _socket;
  final List<int> _buffer = <int>[];
  String? _pendingLiteralLine;
  int _pendingLiteralLength = 0;
  final Completer<_ImapResponse> _greeting = Completer<_ImapResponse>();
  _PendingCommand? _active;
  Set<String> _capabilities = <String>{};
  int _tag = 0;

  /// Opens the connection, negotiates capabilities and authenticates.
  Future<void> connect() async {
    if (_socket != null) {
      throw const ImapException('already_connected', 'the client is connected');
    }
    if (host.trim().isEmpty || port < 1 || port > 65535) {
      throw const ImapException('invalid_argument', 'invalid server address');
    }
    if (security == ImapTransportSecurity.loopbackPlain && !_isLoopback(host)) {
      throw const ImapException(
        'insecure_transport',
        'plain IMAP is only allowed for a loopback host',
      );
    }
    try {
      _socket = security == ImapTransportSecurity.tls
          ? await SecureSocket.connect(host, port).timeout(timeout)
          : await Socket.connect(host, port).timeout(timeout);
    } on TimeoutException {
      throw const ImapException('connection_failed', 'connection timed out');
    } on SocketException catch (error) {
      throw ImapException(
        'connection_failed',
        'the IMAP server could not be reached: ${error.message}',
      );
    }
    _socket!.listen(
      _onBytes,
      onError: (Object error) =>
          _fail('connection_failed', 'the IMAP connection failed'),
      onDone: () => _fail('connection_failed', 'the IMAP connection closed'),
    );
    final greeting = await _greeting.future.timeout(
      timeout,
      onTimeout: () =>
          throw const ImapException('timeout', 'the server sent no greeting'),
    );
    final upper = greeting.line.toUpperCase();
    if (!upper.startsWith('* OK') && !upper.startsWith('* PREAUTH')) {
      throw const ImapException(
        'connection_failed',
        'the greeting was rejected',
      );
    }
    _capabilities = _capabilitiesFrom(greeting.line);
    final capability = await _send('CAPABILITY');
    for (final response in capability.responses) {
      _capabilities.addAll(_capabilitiesFrom(response.line));
    }
    if (!upper.startsWith('* PREAUTH')) {
      await _send(
        'LOGIN ${_quote(username, 'invalid_credential')} '
        '${_quote(password, 'invalid_credential')}',
        failureCode: 'authentication_failed',
      );
    }
  }

  /// Fetches every message in the selected mailbox with a content digest.
  Future<List<ImapMessage>> fetchMessages() async {
    await _select();
    final search = await _send('UID SEARCH ALL');
    final searchLine = _find(search, '* SEARCH', 'malformed_response');
    final uids = searchLine.line.split(RegExp(r'\s+')).skip(2).toList();
    if (uids.isEmpty) return <ImapMessage>[];
    final fetch = await _send('UID FETCH ${uids.join(',')} (UID RFC822)');
    final rawByUid = <String, RawMessage>{};
    for (final response in fetch.responses) {
      final bytes = response.literal;
      if (bytes == null) continue;
      final uid = RegExp(r'\bUID\s+(\d+)').firstMatch(response.line)?.group(1);
      if (uid == null || !uids.contains(uid)) continue;
      try {
        rawByUid[uid] = LocalMailParser.parseMessage(
          utf8.decode(bytes, allowMalformed: true),
        );
      } on ImportException catch (error) {
        throw ImapException('malformed_message', error.message);
      }
    }
    if (rawByUid.length != uids.length) {
      throw const ImapException(
        'malformed_response',
        'the server did not return every requested message',
      );
    }
    return uids
        .map(
          (uid) => ImapMessage(
            uid: uid,
            rawMessage: rawByUid[uid]!,
            inboxMessage: _snapshotOf(uid, rawByUid[uid]!),
          ),
        )
        .toList(growable: false);
  }

  /// Returns a read-only snapshot of the selected mailbox for the audit verb.
  Future<List<InboxMessage>> inboxSnapshot() async {
    final messages = await fetchMessages();
    return messages
        .map((message) => message.inboxMessage)
        .toList(growable: false);
  }

  @override
  Future<void> moveToFolder(List<String> uids, String folder) async {
    final list = _uidList(uids);
    final quoted = _quote(folder, 'invalid_mailbox');
    final canMove = _capabilities.contains('MOVE');
    if (!canMove && !_capabilities.contains('UIDPLUS')) {
      throw const ImapException(
        'missing_capability',
        'the server supports neither MOVE nor UIDPLUS',
      );
    }
    await _select();
    await _send('CREATE $quoted', allowFailure: true);
    if (canMove) {
      await _send('UID MOVE $list $quoted');
      return;
    }
    await _send('UID COPY $list $quoted');
    await _send('UID STORE $list +FLAGS (\\Deleted)');
    await _send('UID EXPUNGE $list');
  }

  @override
  Future<void> markSeen(List<String> uids) async {
    final list = _uidList(uids);
    await _select();
    await _send('UID STORE $list +FLAGS (\\Seen)');
  }

  @override
  Future<void> expunge(List<String> uids) async {
    final list = _uidList(uids);
    if (!_capabilities.contains('UIDPLUS')) {
      throw const ImapException(
        'missing_capability',
        'the server does not support UID EXPUNGE',
      );
    }
    await _select();
    await _send('UID EXPUNGE $list');
  }

  /// Sends LOGOUT and closes the socket.
  Future<void> close() async {
    final socket = _socket;
    if (socket == null) return;
    try {
      await _send('LOGOUT', allowFailure: true).timeout(timeout);
    } catch (_) {
      _active = null;
    }
    socket.destroy();
    _socket = null;
  }

  Future<_CommandResult> _send(
    String command, {
    String failureCode = 'command_failed',
    bool allowFailure = false,
  }) {
    final active = _active;
    if (active != null && !active.completer.isCompleted) {
      throw const ImapException('busy', 'an IMAP command is already in flight');
    }
    final tag = 'L${++_tag}';
    final pending = _PendingCommand(tag, failureCode, allowFailure);
    _active = pending;
    final socket = _socket;
    if (socket == null) {
      _active = null;
      throw const ImapException('not_connected', 'connect before sending');
    }
    socket.write('$tag $command\r\n');
    return pending.completer.future.timeout(
      timeout,
      onTimeout: () {
        if (_active == pending) _active = null;
        throw const ImapException('timeout', 'the IMAP command timed out');
      },
    );
  }

  Future<void> _select() async {
    final result = await _send('SELECT ${_quote(mailbox, 'invalid_mailbox')}');
    _find(result, '* ', 'select_failed');
  }

  InboxMessage _snapshotOf(String uid, RawMessage message) => InboxMessage(
    uid: uid,
    messageId: headerIdentifier(message.headers['message-id']),
    listId: message.headers.containsKey('list-id')
        ? headerIdentifier(message.headers['list-id'])
        : null,
  );

  _ImapResponse _find(_CommandResult result, String prefix, String code) {
    for (final response in result.responses) {
      if (response.line.toUpperCase().startsWith(prefix.toUpperCase())) {
        return response;
      }
    }
    throw ImapException(code, 'the server omitted an expected response');
  }

  void _onBytes(List<int> bytes) {
    _buffer.addAll(bytes);
    while (true) {
      final length = _pendingLiteralLength;
      if (_pendingLiteralLine != null) {
        if (_buffer.length < length + 3) return;
        final literal = List<int>.unmodifiable(_buffer.sublist(0, length));
        final suffix = _buffer.sublist(length, length + 3);
        if (suffix[0] != 0x29 || suffix[1] != 0x0d || suffix[2] != 0x0a) {
          _fail('malformed_response', 'a message literal was not terminated');
          return;
        }
        _buffer.removeRange(0, length + 3);
        final line = _pendingLiteralLine!;
        _pendingLiteralLine = null;
        _pendingLiteralLength = 0;
        _handleResponse(_ImapResponse(line, literal));
        continue;
      }
      final end = _crlfIndex();
      if (end < 0) return;
      final line = utf8.decode(_buffer.sublist(0, end), allowMalformed: true);
      _buffer.removeRange(0, end + 2);
      final match = RegExp(r'\{(\d+)\+?\}$').firstMatch(line);
      if (match == null) {
        _handleResponse(_ImapResponse(line, null));
        continue;
      }
      _pendingLiteralLine = line;
      _pendingLiteralLength = int.parse(match.group(1)!);
    }
  }

  int _crlfIndex() {
    for (var index = 0; index < _buffer.length - 1; index++) {
      if (_buffer[index] == 0x0d && _buffer[index + 1] == 0x0a) return index;
    }
    return -1;
  }

  void _handleResponse(_ImapResponse response) {
    if (!_greeting.isCompleted) {
      _greeting.complete(response);
      return;
    }
    final active = _active;
    if (active == null) return;
    final prefix = '${active.tag} ';
    if (!response.line.startsWith(prefix)) {
      active.responses.add(response);
      return;
    }
    _active = null;
    final status = response.line.substring(prefix.length).toUpperCase();
    if (status.startsWith('OK') || active.allowFailure) {
      active.completer.complete(
        _CommandResult(status.startsWith('OK'), active.responses),
      );
      return;
    }
    active.completer.completeError(
      ImapException(active.failureCode, 'the IMAP command was rejected'),
    );
  }

  void _fail(String code, String message) {
    final active = _active;
    if (active == null || active.completer.isCompleted) return;
    _active = null;
    active.completer.completeError(ImapException(code, message));
  }

  static Set<String> _capabilitiesFrom(String line) {
    final match = RegExp(
      r'CAPABILITY\s+([^\]]+)',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return <String>{};
    return match
        .group(1)!
        .split(RegExp(r'\s+'))
        .map((value) => value.replaceAll(RegExp(r'[\[\]]'), '').toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static String _uidList(List<String> uids) {
    if (uids.isEmpty) {
      throw const ImapException('invalid_argument', 'no mailbox identifiers');
    }
    for (final uid in uids) {
      if (!RegExp(r'^\d+$').hasMatch(uid)) {
        throw const ImapException(
          'invalid_argument',
          'a mailbox identifier is not numeric',
        );
      }
    }
    return uids.join(',');
  }

  static String _quote(String value, [String code = 'invalid_argument']) {
    if (value.isEmpty || value.contains(RegExp(r'[\r\n\x00]'))) {
      throw ImapException(code, 'an IMAP argument contains control characters');
    }
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }

  static bool _isLoopback(String value) {
    final host = value.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }
}
