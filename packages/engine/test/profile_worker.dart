// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

import 'package:engine/engine.dart';

const Duration _pollDelay = Duration(milliseconds: 10);
const int _maximumPolls = 500;

Future<void> _waitForMarker(File marker) async {
  for (var attempt = 0; attempt < _maximumPolls; attempt++) {
    if (marker.existsSync()) return;
    await Future<void>.delayed(_pollDelay);
  }
  throw StateError('the worker barrier was not released');
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 4) {
    throw ArgumentError(
      'expected a database path, a message id, a ready file and a marker',
    );
  }
  final databasePath = arguments[0];
  final messageId = arguments[1];
  final ready = File(arguments[2]);
  final marker = File(arguments[3]);
  final body = 'message from $messageId';
  final database = LocalDatabase.open(databasePath);
  ready.writeAsStringSync('opened');
  await _waitForMarker(marker);
  database.insertMessages([
    MessageRecord(
      id: messageId,
      listId: 'git@vger.kernel.org',
      subject: 'concurrent write',
      fromAddress: 'worker@example.invalid',
      dateEpoch: 1000,
      parentId: null,
      threadRootId: messageId,
      body: body,
      checksum: checksumOfBytes(utf8.encode(body)),
    ),
  ]);
  database.close();
}
