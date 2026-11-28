// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';

import 'public_inbox_client.dart';

/// Reports local mail that cannot be read or parsed.
final class ImportException implements Exception {
  /// Creates an exception with a stable [code] and a readable [message].
  const ImportException(this.code, this.message);

  /// Stable failure code such as `invalid_mail`.
  final String code;

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => 'local import failed ($code): $message';
}

/// Parses local mbox files and Maildir folders into the shared raw shape.
///
/// R24 requires local import for people who already synchronise mail with
/// mbsync or offlineimap. The parser performs no persistence and makes no
/// trust decision; those stay in the engine service.
final class LocalMailParser {
  /// Creates a parser.
  const LocalMailParser();

  /// Reads the messages of an mbox file, in file order.
  static List<RawMessage> parseMbox(String text) {
    final blocks = <List<String>>[];
    List<String>? current;
    for (final line in _lines(text)) {
      if (line.startsWith('From ')) {
        if (current != null) blocks.add(_trimmed(current));
        current = <String>[line];
      } else if (current != null) {
        current.add(line);
      }
    }
    if (current != null) blocks.add(_trimmed(current));
    return blocks.map(_parseBlock).toList(growable: false);
  }

  /// Reads the messages in the `cur` and `new` folders of a Maildir.
  static List<RawMessage> parseMaildir(Directory directory) {
    final folders = [
      Directory('${directory.path}${Platform.pathSeparator}cur'),
      Directory('${directory.path}${Platform.pathSeparator}new'),
    ].where((folder) => folder.existsSync()).toList();
    if (folders.isEmpty) {
      throw const ImportException(
        'invalid_maildir',
        'the Maildir has no cur or new folder',
      );
    }
    final messages = <RawMessage>[];
    for (final folder in folders) {
      final files =
          folder
              .listSync()
              .where((entity) => entity is File && !_isHidden(entity))
              .cast<File>()
              .toList()
            ..sort((left, right) => left.path.compareTo(right.path));
      for (final file in files) {
        messages.add(parseMessage(file.readAsStringSync()));
      }
    }
    return messages;
  }

  /// Parses one RFC 5322 message without an mbox envelope line.
  static RawMessage parseMessage(String text) {
    final lines = _lines(text);
    final separator = lines.indexOf('');
    if (separator < 1) {
      throw const ImportException(
        'invalid_mail',
        'the message has no header block',
      );
    }
    final headers = <String, String>{};
    String? lastHeader;
    for (final line in lines.take(separator)) {
      if ((line.startsWith(TextTokens.space) ||
              line.startsWith(TextTokens.horizontalTab)) &&
          lastHeader != null) {
        headers[lastHeader] = '${headers[lastHeader]} ${line.trim()}';
        continue;
      }
      final colon = line.indexOf(':');
      if (colon < 1) continue;
      lastHeader = line.substring(0, colon).toLowerCase();
      headers[lastHeader] = line.substring(colon + 1).trim();
    }
    final bodyLines = lines
        .skip(separator + 1)
        .map((line) => line.startsWith('>From ') ? line.substring(1) : line)
        .toList();
    final headerLines = lines.take(separator).toList();
    final raw = <String>[
      ...headerLines,
      '',
      ...bodyLines,
    ].join(TextTokens.lineFeed);
    return RawMessage(
      headers: headers,
      body: bodyLines.join(TextTokens.lineFeed),
      raw: raw,
      checksum: sha256.convert(utf8.encode(raw)).toString(),
    );
  }

  static List<String> _lines(String text) => text
      .split(TextTokens.lineFeed)
      .map(
        (line) => line.endsWith(TextTokens.carriageReturn)
            ? line.substring(0, line.length - 1)
            : line,
      )
      .toList(growable: false);

  static List<String> _trimmed(List<String> block) {
    while (block.isNotEmpty && block.last.isEmpty) {
      block.removeLast();
    }
    return block;
  }

  static bool _isHidden(File file) =>
      file.uri.pathSegments.last.startsWith('.');

  static RawMessage _parseBlock(List<String> block) =>
      parseMessage(block.skip(1).join(TextTokens.lineFeed));
}
