// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:test/test.dart';
import 'package:protocol/protocol.dart';
import 'package:engine/engine.dart';

MessageData _message(String id, String? parent, String body) {
  return MessageData(
    id: id,
    listId: 'git@vger.kernel.org',
    subject: 'subject $id',
    fromAddress: 'dev@example.invalid',
    dateEpoch: 1000,
    parentId: parent,
    threadRootId: 'root',
    body: body,
    checksum: checksumOfBytes(body.codeUnits),
  );
}

void main() {
  test(
    'typed verbs ingest, search and read a thread through the isolate',
    () async {
      final directory = Directory.systemTemp.createTempSync('litzy-verbs');
      addTearDown(() => directory.deleteSync(recursive: true));
      final client = await EngineClient.start();
      addTearDown(client.close);
      final path = '${directory.path}${Platform.pathSeparator}litzy.db';

      final opened = await client.sendRequest(OpenProfileRequest('o1', path));
      expect(opened, isA<AckResponse>());
      final ingested = await client.sendRequest(
        IngestRequest('i1', 'git@vger.kernel.org', [
          _message('root', null, 'a body with zstd notes'),
          _message('reply', 'root', 'an unrelated reply body'),
        ]),
      );
      expect((ingested as IngestResponse).count, 2);
      final found = await client.sendRequest(const SearchRequest('s1', 'zstd'));
      expect((found as SearchResponse).messageIds, ['root']);
      final thread = await client.sendRequest(
        const ThreadRequest('t1', 'root'),
      );
      expect((thread as ThreadResponse).messages.map((message) => message.id), [
        'root',
        'reply',
      ]);
    },
  );

  test('a verb before opening a profile returns a typed error', () async {
    final client = await EngineClient.start();
    addTearDown(client.close);

    final response = await client.sendRequest(const SearchRequest('s2', 'x'));

    expect(response, isA<ErrorResponse>());
    expect((response as ErrorResponse).code, 'profile_not_open');
  });

  test('an empty profile path is rejected explicitly', () async {
    final client = await EngineClient.start();
    addTearDown(client.close);

    final response = await client.sendRequest(
      const OpenProfileRequest('o2', ''),
    );

    expect(response, isA<ErrorResponse>());
    expect((response as ErrorResponse).code, 'invalid_profile_path');
  });

  test('an empty ingest batch is rejected explicitly', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-verbs');
    addTearDown(() => directory.deleteSync(recursive: true));
    final client = await EngineClient.start();
    addTearDown(client.close);
    final path = '${directory.path}${Platform.pathSeparator}litzy.db';
    await client.sendRequest(OpenProfileRequest('o3', path));

    final response = await client.sendRequest(
      const IngestRequest('i2', 'git@vger.kernel.org', []),
    );

    expect(response, isA<ErrorResponse>());
    expect((response as ErrorResponse).code, 'empty_ingest');
  });

  test(
    'a duplicate message in a batch fails without partial persistence',
    () async {
      final directory = Directory.systemTemp.createTempSync('litzy-verbs');
      addTearDown(() => directory.deleteSync(recursive: true));
      final client = await EngineClient.start();
      addTearDown(client.close);
      final path = '${directory.path}${Platform.pathSeparator}litzy.db';
      await client.sendRequest(OpenProfileRequest('o4', path));

      final response = await client.sendRequest(
        IngestRequest('i3', 'git@vger.kernel.org', [
          _message('same', null, 'first'),
          _message('same', null, 'second'),
        ]),
      );
      final search = await client.sendRequest(
        const SearchRequest('s3', 'first'),
      );

      expect(response, isA<ErrorResponse>());
      expect((response as ErrorResponse).code, 'ingest_failed');
      expect((search as SearchResponse).messageIds, isEmpty);
    },
  );
}
