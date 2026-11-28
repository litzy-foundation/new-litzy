// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

final class _Harness {
  _Harness(this.directory) {
    path = '${directory.path}${Platform.pathSeparator}profile.db';
  }

  final Directory directory;
  late final String path;

  void seed() {
    final database = LocalDatabase.open(path);
    database.insertMessages([
      MessageRecord(
        id: 'm1@example.invalid',
        listId: 'git@vger.kernel.org',
        subject: 'original subject',
        fromAddress: 'author@example.invalid',
        dateEpoch: 1000,
        parentId: null,
        threadRootId: 'm1@example.invalid',
        body: 'first body line\nsecond body line',
        checksum: checksumOfBytes('body'.codeUnits),
      ),
    ]);
    database.close();
  }

  Future<EngineClient> start() async {
    final client = await EngineClient.start();
    final opened = await client.sendRequest(OpenProfileRequest('open', path));
    expect(opened, isA<AckResponse>());
    return client;
  }

  void close() => directory.deleteSync(recursive: true);
}

void main() {
  test('a reply is quoted, stored and returned through the isolate', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-draft');
    final harness = _Harness(directory);
    addTearDown(harness.close);
    harness.seed();
    final client = await harness.start();
    addTearDown(client.close);

    final response = await client.sendRequest(
      const CreateDraftRequest('d1', 'm1@example.invalid', 'my reply'),
    );

    expect(response, isA<DraftResponse>());
    final draft = response as DraftResponse;
    expect(draft.messageId, 'm1@example.invalid');
    expect(draft.subject, 'Re: original subject');
    expect(draft.body, contains('my reply'));
    expect(draft.body, contains('> first body line'));
    expect(draft.body, contains('> second body line'));
    await client.close();

    final database = LocalDatabase.open(harness.path);
    addTearDown(database.close);
    expect(database.draftOf(draft.draftId), isNotNull);
    expect(database.draftOf(draft.draftId)!.body, draft.body);
  });

  test('writing a reply again updates the same draft', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-draft-update');
    final harness = _Harness(directory);
    addTearDown(harness.close);
    harness.seed();
    final client = await harness.start();
    addTearDown(client.close);

    final first = await client.sendRequest(
      const CreateDraftRequest('d1', 'm1@example.invalid', 'first reply'),
    );
    final second = await client.sendRequest(
      const CreateDraftRequest('d2', 'm1@example.invalid', 'second reply'),
    );

    expect((first as DraftResponse).draftId, (second as DraftResponse).draftId);
    expect(second.body, contains('second reply'));
    expect(second.body, isNot(contains('first reply')));
  });

  test('an unknown message is rejected', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-draft-miss');
    final harness = _Harness(directory);
    addTearDown(harness.close);
    final client = await harness.start();
    addTearDown(client.close);

    final response = await client.sendRequest(
      const CreateDraftRequest('d1', 'absent', 'reply'),
    );

    expect(
      response,
      isA<ErrorResponse>().having(
        (error) => error.code,
        'code',
        'message_not_found',
      ),
    );
  });

  test('an empty reply is rejected', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-draft-empty');
    final harness = _Harness(directory);
    addTearDown(harness.close);
    harness.seed();
    final client = await harness.start();
    addTearDown(client.close);

    final response = await client.sendRequest(
      const CreateDraftRequest('d1', 'm1@example.invalid', '   '),
    );

    expect(
      response,
      isA<ErrorResponse>().having((error) => error.code, 'code', 'empty_reply'),
    );
  });

  test('a reply before opening a profile returns a typed error', () async {
    final client = await EngineClient.start();
    addTearDown(client.close);

    final response = await client.sendRequest(
      const CreateDraftRequest('d1', 'm1@example.invalid', 'reply'),
    );

    expect(
      response,
      isA<ErrorResponse>().having(
        (error) => error.code,
        'code',
        'profile_not_open',
      ),
    );
  });
}
