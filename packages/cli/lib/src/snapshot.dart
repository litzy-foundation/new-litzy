// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

import 'package:protocol/protocol.dart';

/// Reports an inbox snapshot that cannot be read or understood.
final class SnapshotException implements Exception {
  /// Creates a snapshot error with a stable [code] and a readable [message].
  const SnapshotException(this.code, this.message);

  /// Stable failure code such as `invalid_snapshot`.
  final String code;

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => '$code: $message';
}

/// Reads a JSON inbox snapshot gathered by a mailbox reader.
///
/// The CLI supplies the snapshot to the audit verb but makes no policy
/// decision, as required by R13 and ADR-0008.
List<InboxMessage> readInboxSnapshot(String path) {
  final String content;
  try {
    content = File(path).readAsStringSync();
  } on Object {
    throw const SnapshotException(
      'snapshot_unreadable',
      'the inbox snapshot could not be read',
    );
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(content);
  } on FormatException {
    throw const SnapshotException(
      'invalid_snapshot',
      'the inbox snapshot is not JSON',
    );
  }
  if (decoded is! List) {
    throw const SnapshotException(
      'invalid_snapshot',
      'the inbox snapshot must be a list',
    );
  }
  final messages = <InboxMessage>[];
  for (var index = 0; index < decoded.length; index++) {
    final Object? entry = decoded[index];
    if (entry is! Map<String, Object?>) {
      throw SnapshotException(
        'invalid_snapshot',
        'snapshot entry $index is not an object',
      );
    }
    final Object? uid = entry['uid'];
    final Object? messageId = entry['messageId'];
    final Object? listId = entry['listId'];
    if (uid is! String ||
        uid.isEmpty ||
        messageId is! String ||
        messageId.isEmpty) {
      throw SnapshotException(
        'invalid_snapshot',
        'snapshot entry $index needs a uid and a messageId',
      );
    }
    if (listId != null && listId is! String) {
      throw SnapshotException(
        'invalid_snapshot',
        'snapshot entry $index has an invalid listId',
      );
    }
    messages.add(
      InboxMessage(uid: uid, messageId: messageId, listId: listId as String?),
    );
  }
  return messages;
}
