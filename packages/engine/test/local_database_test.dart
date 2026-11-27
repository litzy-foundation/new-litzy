// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:test/test.dart';
import 'package:engine/engine.dart';

MessageRecord record(String id, String? parent, String subject, String body) {
  return MessageRecord(
    id: id,
    listId: 'git@vger.kernel.org',
    subject: subject,
    fromAddress: 'dev@example.invalid',
    dateEpoch: 1000,
    parentId: parent,
    threadRootId: 'root',
    body: body,
    checksum: checksumOfBytes(body.codeUnits),
  );
}

void main() {
  test('a deep thread is read in pre-order by a recursive query', () {
    final db = LocalDatabase.inMemory();
    addTearDown(db.close);
    db.insertMessages([
      record('root', null, 'series', 'cover letter'),
      record('a', 'root', 'patch one', 'first patch'),
      record('b', 'a', 'patch two', 'second patch'),
      record('c', 'b', 'patch three', 'third patch'),
    ]);

    final thread = db.subtree('root');
    expect(thread.map((message) => message.id), ['root', 'a', 'b', 'c']);
  });

  test('recursion is bounded by the caller', () {
    final db = LocalDatabase.inMemory();
    addTearDown(db.close);
    db.insertMessages([
      record('root', null, 'series', 'cover letter'),
      record('a', 'root', 'one', 'first'),
      record('b', 'a', 'two', 'second'),
    ]);

    expect(db.subtree('root', maxDepth: 1).map((message) => message.id), [
      'root',
      'a',
    ]);
  });

  test('full-text search finds words in bodies', () {
    final db = LocalDatabase.inMemory();
    addTearDown(db.close);
    db.insertMessages([
      record('root', null, 'subject', 'a body with zstd compression notes'),
      record('a', 'root', 'other', 'nothing relevant here'),
    ]);

    expect(db.search('compression'), ['root']);
  });

  test('a rejected batch leaves no half-persisted message', () {
    final db = LocalDatabase.inMemory();
    addTearDown(db.close);
    final first = record('root', null, 'subject', 'body');
    final duplicate = record('root', null, 'subject', 'body');

    expect(() => db.insertMessages([first, duplicate]), throwsA(anything));
    expect(db.count, 0);
  });

  test('the checksum gate reads the verified digest', () {
    final db = LocalDatabase.inMemory();
    addTearDown(db.close);
    final message = record('root', null, 'subject', 'original');
    db.insertMessages([message]);

    expect(db.checksumOf('root'), message.checksum);
    expect(db.checksumOf('missing'), isNull);
  });

  test('the content-addressed blob store rejects corrupted content', () {
    final directory = Directory.systemTemp.createTempSync('litzy-blobs');
    addTearDown(() => directory.deleteSync(recursive: true));
    final store = LocalBlobStore(directory);

    final digest = store.put('original bytes'.codeUnits);
    expect(store.verify(digest), isTrue);
    File('${directory.path}${Platform.pathSeparator}$digest')
        .writeAsStringSync('corrupted bytes');
    expect(store.verify(digest), isFalse);
  });
}
