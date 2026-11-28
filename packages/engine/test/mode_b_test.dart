// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'imap_fixture.dart';

const String _listMessage = '''
Message-ID: <m1@example.invalid>
List-Id: <git@vger.kernel.org>
Subject: first patch
From: Author <author@example.invalid>

a patch body
''';

const String _personalMessage = '''
Message-ID: <private@example.invalid>
Subject: private note
From: Friend <friend@example.invalid>

a private body
''';

final class _Harness {
  _Harness(this.directory, this.fixture) {
    databasePath = '${directory.path}${Platform.pathSeparator}profile.db';
  }

  final Directory directory;
  final ImapFixture fixture;
  late final String databasePath;

  Future<EngineClient> start() async {
    final client = await EngineClient.start();
    final opened = await client.sendRequest(
      OpenProfileRequest('open', databasePath),
    );
    expect(opened, isA<AckResponse>());
    return client;
  }

  ImapSyncRequest request({
    bool acceptLogin = true,
    String listId = 'git@vger.kernel.org',
    String host = '127.0.0.1',
    ImapTransportSecurity security = ImapTransportSecurity.loopbackPlain,
  }) => ImapSyncRequest(
    'b1',
    host: host,
    port: fixture.port,
    username: 'user@example.invalid',
    password: acceptLogin ? 'correct password' : 'wrong password',
    listId: listId,
    security: security,
  );
}

Future<_Harness> _harness({
  required List<FixtureMessage> messages,
  bool rejectLogin = false,
  List<String>? capabilities,
}) async {
  final directory = Directory.systemTemp.createTempSync('litzy-mode-b');
  addTearDown(() => directory.deleteSync(recursive: true));
  final fixture = ImapFixture(
    messages: messages,
    rejectLogin: rejectLogin,
    capabilities: capabilities ?? const ['IMAP4REV1', 'UIDPLUS', 'MOVE'],
  );
  await fixture.start();
  addTearDown(fixture.close);
  return _Harness(directory, fixture);
}

void main() {
  test(
    'a sync ingests list mail, snapshots the inbox and moves the original',
    () async {
      final harness = await _harness(
        messages: [
          const FixtureMessage('1', _listMessage),
          const FixtureMessage('2', _personalMessage),
        ],
      );
      final client = await harness.start();
      addTearDown(client.close);

      final response = await client.sendRequest(harness.request());
      final found = await client.sendRequest(
        const SearchRequest('s1', 'patch'),
      );

      expect(
        response,
        isA<ImapSyncResponse>()
            .having((result) => result.count, 'count', 1)
            .having((result) => result.action, 'action', 'move')
            .having((result) => result.actedUids, 'acted uids', ['1'])
            .having((result) => result.snapshot, 'snapshot', hasLength(2)),
      );
      expect((found as SearchResponse).messageIds, ['m1@example.invalid']);
      expect(harness.fixture.actions, contains('UID MOVE 1 "LITZY/INGESTED"'));
      expect(harness.fixture.actions, isNot(contains('UID MOVE 2')));
      expect(harness.fixture.actions, isNot(contains('UID EXPUNGE 1')));
    },
  );

  test('a repeated sync does not persist or act twice', () async {
    final harness = await _harness(
      messages: const [FixtureMessage('1', _listMessage)],
    );
    final client = await harness.start();
    addTearDown(client.close);

    await client.sendRequest(harness.request());
    final second = await client.sendRequest(harness.request());

    expect(second, isA<ImapSyncResponse>());
    final result = second as ImapSyncResponse;
    expect(result.count, 0);
    expect(result.actedUids, isEmpty);
    expect(
      harness.fixture.actions
          .where((action) => action.startsWith('UID MOVE'))
          .length,
      1,
    );
  });

  test('an explicit policy can expunge after verification', () async {
    final harness = await _harness(
      messages: const [FixtureMessage('1', _listMessage)],
    );
    final database = LocalDatabase.open(harness.databasePath);
    database.setListPolicy('git@vger.kernel.org', 'expunge');
    database.close();
    final client = await harness.start();
    addTearDown(client.close);

    final response = await client.sendRequest(harness.request());

    expect(
      response,
      isA<ImapSyncResponse>()
          .having((result) => result.action, 'action', 'expunge')
          .having((result) => result.actedUids, 'acted uids', ['1']),
    );
    expect(harness.fixture.actions, contains('UID EXPUNGE 1'));
    expect(harness.fixture.actions, isNot(contains('UID MOVE 1')));
  });

  test('an unverified message is quarantined instead of acted upon', () async {
    final harness = await _harness(
      messages: const [FixtureMessage('1', _listMessage)],
    );
    final database = LocalDatabase.open(harness.databasePath);
    database.insertMessages([
      const MessageRecord(
        id: 'm1@example.invalid',
        listId: 'git@vger.kernel.org',
        subject: 'first patch',
        fromAddress: 'author@example.invalid',
        dateEpoch: 0,
        parentId: null,
        threadRootId: 'm1@example.invalid',
        body: 'a patch body',
        checksum: 'stale digest',
      ),
    ]);
    database.close();
    final client = await harness.start();
    addTearDown(client.close);

    final response = await client.sendRequest(harness.request());

    expect(
      response,
      isA<ImapSyncResponse>()
          .having((result) => result.count, 'count', 0)
          .having((result) => result.quarantined, 'quarantined', ['1'])
          .having((result) => result.actedUids, 'acted uids', isEmpty),
    );
    expect(harness.fixture.actions, isNot(contains('UID MOVE 1')));
    expect(harness.fixture.actions, isNot(contains('UID EXPUNGE 1')));
  });

  test('a rejected login returns a typed error and persists nothing', () async {
    final harness = await _harness(
      messages: const [FixtureMessage('1', _listMessage)],
      rejectLogin: true,
    );
    final client = await harness.start();
    addTearDown(client.close);

    final response = await client.sendRequest(harness.request());

    expect(
      response,
      isA<ErrorResponse>().having(
        (error) => error.code,
        'code',
        'authentication_failed',
      ),
    );
    final database = LocalDatabase.open(harness.databasePath);
    addTearDown(database.close);
    expect(database.messageIds, isEmpty);
  });

  test('plain transport is rejected for a remote host', () async {
    final harness = await _harness(
      messages: const [FixtureMessage('1', _listMessage)],
    );
    final client = await harness.start();
    addTearDown(client.close);

    final response = await client.sendRequest(
      harness.request(host: 'mail.example.invalid'),
    );

    expect(
      response,
      isA<ErrorResponse>().having(
        (error) => error.code,
        'code',
        'insecure_transport',
      ),
    );
  });

  test('a missing mailbox capability fails deterministically', () async {
    final harness = await _harness(
      messages: const [FixtureMessage('1', _listMessage)],
      capabilities: const ['IMAP4REV1'],
    );
    final client = await harness.start();
    addTearDown(client.close);

    final response = await client.sendRequest(harness.request());

    expect(
      response,
      isA<ErrorResponse>().having(
        (error) => error.code,
        'code',
        'missing_capability',
      ),
    );
    expect(harness.fixture.actions, isNot(contains('UID EXPUNGE 1')));
  });
}
