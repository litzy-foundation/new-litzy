// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';

/// Reports a cursor row that cannot be decoded.
final class CursorException implements Exception {
  /// Creates an exception with a stable [code] and a readable [message].
  const CursorException(this.code, this.message);

  /// Stable failure code such as `corrupt_cursor`.
  final String code;

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => 'cursor error ($code): $message';
}

/// Incremental state for one channel, persisted in SQLite as required by
/// ADR-0004.
///
/// NNTP compares [articleNumber] with overview numbers. Public-inbox skips
/// [threadIds] that were fetched in an earlier sync. Both shapes live in the
/// same row because a channel uses exactly one protocol.
final class SyncCursor {
  /// Creates a cursor with an article high-water mark and seen thread IDs.
  const SyncCursor({this.articleNumber = 0, this.threadIds = const <String>[]});

  /// Highest overview article number fetched so far.
  final int articleNumber;

  /// Thread identifiers already fetched from a public-inbox mirror.
  final List<String> threadIds;

  /// Encodes the cursor for storage.
  String encode() =>
      jsonEncode({'article': articleNumber, 'threads': threadIds});

  /// Decodes a cursor from storage.
  static SyncCursor decode(String value) {
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      throw const CursorException('corrupt_cursor', 'the cursor is not JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const CursorException(
        'corrupt_cursor',
        'the cursor is not an object',
      );
    }
    final Object? article = decoded['article'];
    final Object? threads = decoded['threads'];
    if (article is! int || article < 0 || threads is! List) {
      throw const CursorException(
        'corrupt_cursor',
        'the cursor has invalid fields',
      );
    }
    final ids = <String>[];
    for (final Object? id in threads) {
      if (id is! String) {
        throw const CursorException(
          'corrupt_cursor',
          'the cursor has an invalid thread identifier',
        );
      }
      ids.add(id);
    }
    return SyncCursor(articleNumber: article, threadIds: ids);
  }
}
