// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'imap_fixture.dart';

const String _listMessage = '''
Message-ID: <list@example.invalid>
List-Id: <git@vger.kernel.org>
Subject: patch series
From: Author <author@example.invalid>

first body line
''';

const String _personalMessage = '''
Message-ID: <personal@example.invalid>
Subject: private note
From: Friend <friend@example.invalid>

personal body
''';

Future<ImapClient> _connect(
  ImapFixture fixture, {
  String username = 'user@example.invalid',
  String password = 'correct password',
}) async {
  final client = ImapClient(
    host: '127.0.0.1',
    port: fixture.port,
    username: username,
    password: password,
    security: ImapTransportSecurity.loopbackPlain,
  );
  await client.connect();
  addTearDown(client.close);
  return client;
}

void main() {
  test('a real IMAP conversation fetches messages and a snapshot', () async {
    final fixture = ImapFixture(
      messages: [
        const FixtureMessage('1', _listMessage),
        const FixtureMessage('2', _personalMessage),
      ],
    );
    await fixture.start();
    addTearDown(fixture.close);
    final client = await _connect(fixture);

    final messages = await client.fetchMessages();
    final snapshot = await client.inboxSnapshot();

    expect(messages.map((message) => message.uid), ['1', '2']);
    expect(
      messages.first.rawMessage.headers['list-id'],
      '<git@vger.kernel.org>',
    );
    expect(
      messages.first.rawMessage.body,
      'first body line${TextTokens.lineFeed}',
    );
    expect(snapshot.map((message) => message.messageId), [
      'list@example.invalid',
      'personal@example.invalid',
    ]);
    expect(snapshot.first.listId, 'git@vger.kernel.org');
    expect(snapshot.last.listId, isNull);
    expect(
      fixture.actions,
      containsAll([
        'CAPABILITY',
        'LOGIN "USER@EXAMPLE.INVALID" "CORRECT PASSWORD"',
        'SELECT "INBOX"',
        'UID SEARCH ALL',
      ]),
    );
  });

  test('a FETCH response without a unique identifier is rejected', () async {
    final fixture = ImapFixture(
      messages: const [FixtureMessage('1', _listMessage)],
      omitFetchUid: true,
    );
    await fixture.start();
    addTearDown(fixture.close);
    final client = await _connect(fixture);

    await expectLater(
      client.fetchMessages(),
      throwsA(
        isA<ImapException>().having(
          (error) => error.code,
          'code',
          'malformed_response',
        ),
      ),
    );
  });

  test('a rejected login is a deterministic authentication failure', () async {
    final fixture = ImapFixture(
      messages: const [FixtureMessage('1', _listMessage)],
      rejectLogin: true,
    );
    await fixture.start();
    addTearDown(fixture.close);
    final client = ImapClient(
      host: '127.0.0.1',
      port: fixture.port,
      username: 'user@example.invalid',
      password: 'wrong password',
      security: ImapTransportSecurity.loopbackPlain,
    );

    await expectLater(
      client.connect(),
      throwsA(
        isA<ImapException>().having(
          (error) => error.code,
          'code',
          'authentication_failed',
        ),
      ),
    );
    expect(fixture.actions, isNot(contains('SELECT "INBOX"')));
  });

  test('mailbox actions use RFC commands and respect capabilities', () async {
    final fixture = ImapFixture(
      messages: const [FixtureMessage('7', _listMessage)],
    );
    await fixture.start();
    addTearDown(fixture.close);
    final client = await _connect(fixture);

    await client.markSeen(['7']);
    await client.moveToFolder(['7'], 'Litzy/Ingested');
    await client.expunge(['7']);

    expect(fixture.actions, contains('UID STORE 7 +FLAGS (\\SEEN)'));
    expect(fixture.actions, contains('CREATE "LITZY/INGESTED"'));
    expect(fixture.actions, contains('UID MOVE 7 "LITZY/INGESTED"'));
    expect(fixture.actions, contains('UID EXPUNGE 7'));
  });

  test('expunge is rejected without UIDPLUS', () async {
    final fixture = ImapFixture(
      messages: const [FixtureMessage('7', _listMessage)],
      capabilities: const ['IMAP4REV1', 'MOVE'],
    );
    await fixture.start();
    addTearDown(fixture.close);
    final client = await _connect(fixture);

    await expectLater(
      client.expunge(['7']),
      throwsA(
        isA<ImapException>().having(
          (error) => error.code,
          'code',
          'missing_capability',
        ),
      ),
    );
    expect(fixture.actions, isNot(contains('UID EXPUNGE 7')));
  });

  test('a move without MOVE uses copy and UID expunge', () async {
    final fixture = ImapFixture(
      messages: const [FixtureMessage('7', _listMessage)],
      capabilities: const ['IMAP4REV1', 'UIDPLUS'],
    );
    await fixture.start();
    addTearDown(fixture.close);
    final client = await _connect(fixture);

    await client.moveToFolder(['7'], 'Litzy/Ingested');

    expect(fixture.actions, contains('UID COPY 7 "LITZY/INGESTED"'));
    expect(fixture.actions, contains('UID STORE 7 +FLAGS (\\DELETED)'));
    expect(fixture.actions, contains('UID EXPUNGE 7'));
  });

  test('control characters cannot be injected through a folder name', () async {
    final fixture = ImapFixture(
      messages: const [FixtureMessage('7', _listMessage)],
    );
    await fixture.start();
    addTearDown(fixture.close);
    final client = await _connect(fixture);

    await expectLater(
      client.moveToFolder([
        '7',
      ], 'Litzy${TextTokens.protocolLineEnding}UID EXPUNGE 1'),
      throwsA(
        isA<ImapException>().having(
          (error) => error.code,
          'code',
          'invalid_mailbox',
        ),
      ),
    );
    expect(fixture.actions, isNot(contains('UID EXPUNGE 1')));
  });

  test('plain transport is refused for a remote host', () async {
    final client = ImapClient(
      host: 'mail.example.invalid',
      username: 'user@example.invalid',
      password: 'correct password',
      security: ImapTransportSecurity.loopbackPlain,
    );

    await expectLater(
      client.connect(),
      throwsA(
        isA<ImapException>().having(
          (error) => error.code,
          'code',
          'insecure_transport',
        ),
      ),
    );
  });
}
