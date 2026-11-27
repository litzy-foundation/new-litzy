// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../storage/local_database.dart';
import 'public_inbox_client.dart';

/// Reports a failed NNTP command with its status code, or zero for a local
/// failure such as a timeout.
final class NntpException implements Exception {
  /// Creates an exception for [code] with a readable [message].
  const NntpException(this.code, this.message);

  /// Status code returned by the server, or zero for a local failure.
  final int code;

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => 'NNTP error $code: $message';
}

/// One overview row returned by the NNTP `XOVER` command.
final class NntpOverview {
  /// Creates an overview row.
  const NntpOverview({
    required this.number,
    required this.subject,
    required this.from,
    required this.messageId,
  });

  /// Article number inside the newsgroup.
  final int number;

  /// Subject line.
  final String subject;

  /// Author line.
  final String from;

  /// Message identifier including angle brackets.
  final String messageId;
}

/// One complete article returned by the NNTP `ARTICLE` command.
final class NntpArticle {
  /// Creates an article with separated headers and body.
  const NntpArticle({required this.headers, required this.body});

  /// Header lines without the blank separator.
  final List<String> headers;

  /// Body lines without the terminating dot line.
  final List<String> body;

  /// Converts the article to the shared raw message shape.
  RawMessage toRawMessage() {
    final headerMap = <String, String>{};
    for (final line in headers) {
      final colon = line.indexOf(':');
      if (colon > 0) {
        headerMap[line.substring(0, colon).toLowerCase()] = line
            .substring(colon + 1)
            .trim();
      }
    }
    final raw = '${headers.join('\n')}\n\n${body.join('\n')}';
    return RawMessage(
      headers: headerMap,
      body: body.join('\n'),
      raw: raw,
      checksum: checksumOfBytes(utf8.encode(raw)),
    );
  }
}

/// A minimal RFC 3977 text client for public newsgroups.
///
/// Mode C uses this client to read lists without authentication or an email
/// account, as required by R24 and ADR-0009. Only one command is in flight
/// at a time, which matches the conversational nature of the protocol.
final class NntpClient {
  /// Creates a client for [host] and [port].
  NntpClient(this.host, this.port);

  /// Server host name.
  final String host;

  /// Server port.
  final int port;

  Socket? _socket;
  String _buffer = '';
  Completer<_Response>? _active;
  bool _multiline = false;
  final List<String> _earlyLines = <String>[];

  /// Opens the connection and consumes the greeting line.
  Future<void> connect() async {
    _socket = await Socket.connect(host, port);
    _socket!.listen(
      _onBytes,
      onError: (Object error) {
        final active = _active;
        if (active != null && !active.isCompleted) {
          active.completeError(NntpException(0, 'connection failed: $error'));
        }
      },
    );
    await _send('');
  }

  /// Selects a newsgroup and returns the reported article count.
  Future<int> group(String name) async {
    final response = await _send('GROUP $name');
    _expect(response, 211);
    final fields = response.lines.last.split(RegExp(r'\s+'));
    if (fields.length < 2) {
      throw NntpException(response.code, 'malformed group response');
    }
    final count = int.tryParse(fields[1]);
    if (count == null) {
      throw NntpException(response.code, 'malformed group count');
    }
    return count;
  }

  /// Fetches overview rows in the inclusive range `from-to`.
  Future<List<NntpOverview>> overview(String range) async {
    final response = await _send('XOVER $range');
    _expect(response, 224);
    return response.lines.skip(1).map(_parseOverview).toList();
  }

  /// Fetches a complete article by message identifier.
  Future<NntpArticle> article(String messageId) async {
    final response = await _send('ARTICLE $messageId');
    _expect(response, 220);
    final separator = response.lines.indexOf('');
    if (separator < 0) {
      throw NntpException(response.code, 'article $messageId has no separator');
    }
    return NntpArticle(
      headers: response.lines.sublist(0, separator),
      body: response.lines.sublist(separator + 1),
    );
  }

  /// Closes the connection.
  void close() => _socket?.destroy();

  void _expect(_Response response, int code) {
    if (response.code != code) {
      throw NntpException(response.code, 'unexpected response');
    }
  }

  NntpOverview _parseOverview(String line) {
    final fields = line.split('\t');
    if (fields.length < 5) {
      throw const NntpException(224, 'malformed overview row');
    }
    final number = int.tryParse(fields[0]);
    if (number == null) {
      throw const NntpException(224, 'malformed overview number');
    }
    return NntpOverview(
      number: number,
      subject: fields[1],
      from: fields[2],
      messageId: fields[4],
    );
  }

  Future<_Response> _send(String command) {
    final active = _active;
    if (active != null && !active.isCompleted) {
      throw const NntpException(0, 'a command is already in flight');
    }
    final completer = Completer<_Response>();
    _active = completer;
    if (_earlyLines.isNotEmpty) {
      final early = List<String>.of(_earlyLines);
      _earlyLines.clear();
      for (final line in early) {
        _consumeLine(line);
      }
    }
    if (command.isNotEmpty && !completer.isCompleted) {
      _socket!.writeln(command);
    }
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _active = null;
        throw NntpException(0, 'command timed out: $command');
      },
    );
  }

  void _onBytes(List<int> bytes) {
    _buffer += utf8.decode(bytes, allowMalformed: true);
    while (true) {
      final index = _buffer.indexOf('\r\n');
      if (index < 0) return;
      final line = _buffer.substring(0, index);
      _buffer = _buffer.substring(index + 2);
      _handleLine(line);
    }
  }

  void _handleLine(String line) {
    final active = _active;
    if (active == null || active.isCompleted) {
      _earlyLines.add(line);
      return;
    }
    _consumeLine(line);
  }

  void _consumeLine(String line) {
    final active = _active!;
    if (!_multiline) {
      final code = int.tryParse(line.substring(0, 3));
      if (code == null) {
        active.completeError(const NntpException(0, 'malformed status line'));
        return;
      }
      _multiline = _isMultiline(code);
      if (_multiline) {
        _responseLines = <String>[line];
        return;
      }
      _active = null;
      active.complete(_Response(code, <String>[line]));
      return;
    }
    if (line == '.') {
      _multiline = false;
      _active = null;
      final code = int.parse(_responseLines.first.substring(0, 3));
      active.complete(_Response(code, _responseLines));
      return;
    }
    _responseLines.add(line.startsWith('..') ? line.substring(1) : line);
  }

  List<String> _responseLines = <String>[];

  static bool _isMultiline(int code) =>
      code == 224 || code == 220 || code == 215;
}

final class _Response {
  const _Response(this.code, this.lines);

  final int code;
  final List<String> lines;
}
