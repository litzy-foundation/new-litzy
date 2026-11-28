// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

/// One message served by [ImapFixture].
final class FixtureMessage {
  /// Creates a message with its unique identifier and raw RFC 5322 text.
  const FixtureMessage(this.uid, this.raw);

  /// Mailbox unique identifier.
  final String uid;

  /// Raw message text including headers and body.
  final String raw;
}

/// A minimal in-process IMAP server for client tests.
///
/// It implements only the commands Litzy uses and records them so tests can
/// prove which mailbox operations were issued.
final class ImapFixture {
  /// Creates a fixture over [messages].
  ImapFixture({
    required this.messages,
    this.rejectLogin = false,
    this.omitFetchUid = false,
    this.capabilities = const ['IMAP4REV1', 'UIDPLUS', 'MOVE'],
  });

  /// Messages returned by SEARCH and FETCH.
  final List<FixtureMessage> messages;

  /// Whether LOGIN must fail.
  final bool rejectLogin;

  /// Whether FETCH responses omit the unique identifier.
  final bool omitFetchUid;

  /// Capabilities advertised in the greeting.
  final List<String> capabilities;

  ServerSocket? _server;

  /// Commands received from the client, in order.
  final List<String> actions = <String>[];

  /// Starts listening on a loopback port.
  Future<void> start() async {
    _server = await ServerSocket.bind('127.0.0.1', 0);
    _server!.listen(_accept);
  }

  /// Port on which the fixture listens.
  int get port => _server!.port;

  /// Stops the fixture.
  Future<void> close() async {
    await _server?.close();
    _server = null;
  }

  void _accept(Socket socket) {
    socket.write('* OK [CAPABILITY ${capabilities.join(' ')}] ready\r\n');
    var buffer = '';
    socket.listen((bytes) {
      buffer += utf8.decode(bytes, allowMalformed: true);
      while (buffer.contains('\r\n')) {
        final end = buffer.indexOf('\r\n');
        final line = buffer.substring(0, end);
        buffer = buffer.substring(end + 2);
        if (line.isEmpty) continue;
        final parts = line.split(' ');
        final tag = parts.first;
        final command = parts.skip(1).join(' ').toUpperCase();
        actions.add(command);
        if (command.startsWith('CAPABILITY')) {
          socket.write('* CAPABILITY ${capabilities.join(' ')}\r\n');
          socket.write('$tag OK done\r\n');
        } else if (command.startsWith('LOGIN')) {
          if (rejectLogin) {
            socket.write('$tag NO authentication failed\r\n');
          } else {
            socket.write('$tag OK logged in\r\n');
          }
        } else if (command.startsWith('SELECT')) {
          socket.write('* ${messages.length} EXISTS\r\n');
          socket.write('$tag OK [READ-WRITE] selected\r\n');
        } else if (command.startsWith('UID SEARCH')) {
          final uids = messages.map((message) => message.uid).join(' ');
          socket.write('* SEARCH $uids\r\n');
          socket.write('$tag OK search complete\r\n');
        } else if (command.startsWith('UID FETCH')) {
          for (final message in messages) {
            final bytes = utf8.encode(message.raw);
            final prefix = omitFetchUid
                ? '* ${message.uid} FETCH (RFC822 {${bytes.length}}'
                : '* ${message.uid} FETCH (UID ${message.uid} RFC822 '
                      '{${bytes.length}}';
            socket.write('$prefix\r\n');
            socket.add(bytes);
            socket.write(')\r\n');
          }
          socket.write('$tag OK fetch complete\r\n');
        } else if (command.startsWith('UID STORE')) {
          for (final message in messages) {
            socket.write(
              '* ${message.uid} FETCH (UID ${message.uid} '
              'FLAGS (\\Seen))\r\n',
            );
          }
          socket.write('$tag OK store complete\r\n');
        } else if (command.startsWith('UID MOVE') ||
            command.startsWith('UID COPY') ||
            command.startsWith('UID EXPUNGE') ||
            command.startsWith('CREATE')) {
          socket.write('$tag OK action complete\r\n');
        } else if (command.startsWith('LOGOUT')) {
          socket.write('* BYE closing\r\n');
          socket.write('$tag OK logout complete\r\n');
        } else {
          socket.write('$tag BAD unknown command\r\n');
        }
      }
    });
  }
}
