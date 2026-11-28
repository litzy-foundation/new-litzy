// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:cli/cli.dart';
import 'package:test/test.dart';

String _write(String body) {
  final directory = Directory.systemTemp.createTempSync('litzy-snapshot');
  final file = File('${directory.path}${Platform.pathSeparator}inbox.json');
  file.writeAsStringSync(body);
  addTearDown(() => directory.deleteSync(recursive: true));
  return file.path;
}

void main() {
  test('a snapshot is read into typed messages', () {
    final path = _write('''
[
  {"uid": "1", "messageId": "r@example.invalid", "listId": "git@vger.kernel.org"},
  {"uid": "2", "messageId": "p@example.invalid"}
]
''');

    final messages = readInboxSnapshot(path);

    expect(messages.map((message) => message.uid), ['1', '2']);
    expect(messages.map((message) => message.messageId), [
      'r@example.invalid',
      'p@example.invalid',
    ]);
    expect(messages.first.listId, 'git@vger.kernel.org');
    expect(messages.last.listId, isNull);
  });

  test('a missing snapshot fails with a stable code', () {
    final directory = Directory.systemTemp.createTempSync('litzy-no-snapshot');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}absent.json';

    expect(
      () => readInboxSnapshot(path),
      throwsA(
        isA<SnapshotException>().having(
          (error) => error.code,
          'code',
          'snapshot_unreadable',
        ),
      ),
    );
  });

  test('a malformed snapshot fails with a stable code', () {
    final path = _write('not json');

    expect(
      () => readInboxSnapshot(path),
      throwsA(
        isA<SnapshotException>().having(
          (error) => error.code,
          'code',
          'invalid_snapshot',
        ),
      ),
    );
  });

  test('a snapshot entry without identifiers is rejected', () {
    final path = _write('[{"uid": "1"}]');

    expect(
      () => readInboxSnapshot(path),
      throwsA(
        isA<SnapshotException>().having(
          (error) => error.code,
          'code',
          'invalid_snapshot',
        ),
      ),
    );
  });
}
