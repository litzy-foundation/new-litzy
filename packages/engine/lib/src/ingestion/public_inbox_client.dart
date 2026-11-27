// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../storage/local_database.dart';

/// Reports a failed public-inbox request with its HTTP status, or zero for a
/// local failure such as a malformed document.
final class PublicInboxException implements Exception {
  /// Creates an exception with a status [code] and a readable [message].
  const PublicInboxException(this.code, this.message);

  /// HTTP status returned by the server, or zero for a local failure.
  final int code;

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => 'public-inbox error $code: $message';
}

/// One message extracted from a public-inbox mbox archive.
final class RawMessage {
  /// Creates a message with its header map, body and content digest.
  const RawMessage({
    required this.headers,
    required this.body,
    required this.checksum,
  });

  /// Lowercase header names mapped to their values.
  final Map<String, String> headers;

  /// Message body without the envelope line or header block.
  final String body;

  /// SHA-256 digest of the full RFC 5322 message.
  final String checksum;
}

/// Reads public threads without an email account, as required by R24.
///
/// The catalogue supplies the base URL and the atom and thread paths. Only
/// plain HTTP reads are performed, and every response is validated before a
/// message enters the local pipeline.
final class PublicInboxClient {
  /// Creates a client with a request [timeout].
  const PublicInboxClient({this.timeout = const Duration(seconds: 10)});

  /// Deadline applied to each HTTP request.
  final Duration timeout;

  /// Returns the thread identifiers listed in the recent atom feed.
  Future<List<String>> recentThreadIds(
    Uri base, {
    String atomPath = 'new.atom',
  }) async {
    final response = await _get(base.resolve(atomPath));
    if (response.statusCode != 200) {
      throw PublicInboxException(
        response.statusCode,
        'atom feed request failed',
      );
    }
    try {
      final document = XmlDocument.parse(response.body);
      return document
          .findAllElements('id')
          .map((element) => element.innerText.trim())
          .where((identifier) => identifier.isNotEmpty)
          .toList();
    } on XmlException catch (error) {
      throw PublicInboxException(0, 'malformed atom feed: ${error.message}');
    }
  }

  /// Returns the messages of one thread from its compressed mbox archive.
  Future<List<RawMessage>> threadMessages(
    Uri base,
    String threadId, {
    String suffix = '/t.mbox.gz',
  }) async {
    if (threadId.contains('/') ||
        threadId.contains('..') ||
        threadId.trim() != threadId ||
        threadId.isEmpty) {
      throw const PublicInboxException(0, 'unsafe thread identifier');
    }
    final response = await _get(base.resolve('$threadId$suffix'));
    if (response.statusCode != 200) {
      throw PublicInboxException(
        response.statusCode,
        'thread archive request failed',
      );
    }
    List<int> bytes;
    try {
      bytes = GZipDecoder().decodeBytes(response.bodyBytes);
    } on ArchiveException catch (error) {
      throw PublicInboxException(0, 'invalid mbox archive: ${error.message}');
    }
    return _parseMbox(utf8.decode(bytes, allowMalformed: true));
  }

  Future<http.Response> _get(Uri url) => http
      .get(url)
      .timeout(
        timeout,
        onTimeout: () =>
            throw const PublicInboxException(0, 'request timed out'),
      );

  static List<RawMessage> _parseMbox(String text) {
    final blocks = <List<String>>[];
    List<String>? current;
    for (final line in text.split('\n')) {
      if (line.startsWith('From ')) {
        if (current != null) {
          while (current.isNotEmpty && current.last.isEmpty) {
            current.removeLast();
          }
          blocks.add(current);
        }
        current = <String>[line];
      } else if (current != null) {
        current.add(line);
      }
    }
    if (current != null) {
      while (current.isNotEmpty && current.last.isEmpty) {
        current.removeLast();
      }
      blocks.add(current);
    }
    return blocks.map(_parseBlock).toList();
  }

  static RawMessage _parseBlock(List<String> block) {
    final separator = block.indexOf('');
    if (separator < 1) {
      throw const PublicInboxException(0, 'mbox message has no header block');
    }
    final headerLines = block.getRange(1, separator).toList();
    final bodyLines = block.skip(separator + 1).toList();
    final headers = <String, String>{};
    for (final line in headerLines) {
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      headers[line.substring(0, colon).toLowerCase()] = line
          .substring(colon + 1)
          .trim();
    }
    final raw = <String>[...headerLines, '', ...bodyLines].join('\n');
    return RawMessage(
      headers: headers,
      body: bodyLines.join('\n'),
      checksum: checksumOfBytes(utf8.encode(raw)),
    );
  }
}
