// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

const String _mbox = '''
From author@example.invalid Mon Nov 28 00:00:00 2026 +0000
Message-ID: <m1@example.invalid>
List-Id: <git@vger.kernel.org>
Subject: imported thread
From: Author <author@example.invalid>

first imported body

From author@example.invalid Mon Nov 28 00:01:00 2026 +0000
Message-ID: <m2@example.invalid>
List-Id: <git@vger.kernel.org>
In-Reply-To: <m1@example.invalid>
Subject: Re: imported thread
From: Author <author@example.invalid>

second imported body
''';

String _maildirMessage(String id) =>
    '''
Message-ID: <$id>
Subject: maildir subject $id
From: Author <author@example.invalid>

maildir body $id
''';

Future<EngineClient> _openProfile(String path) async {
  final client = await EngineClient.start();
  final opened = await client.sendRequest(OpenProfileRequest('open', path));
  expect(opened, isA<AckResponse>());
  return client;
}

void main() {
  test('an mbox file is parsed into messages and threads', () {
    final messages = LocalMailParser.parseMbox(_mbox);

    expect(messages.map((message) => message.headers['message-id']), [
      '<m1@example.invalid>',
      '<m2@example.invalid>',
    ]);
    expect(messages.first.body, 'first imported body');
    expect(messages.last.headers['in-reply-to'], '<m1@example.invalid>');
  });

  test('folded headers and quoted envelope lines are understood', () {
    const text = '''
From author@example.invalid Mon Nov 28 00:00:00 2026 +0000
Message-ID: <m1@example.invalid>
Subject: a subject
  continued here
From: Author <author@example.invalid>

>From a quoted line
''';

    final message = LocalMailParser.parseMbox(text).single;

    expect(message.headers['subject'], 'a subject continued here');
    expect(message.body, 'From a quoted line');
  });

  test('an mbox message without a header block is rejected', () {
    expect(
      () => LocalMailParser.parseMbox('From author@example.invalid\nbody\n'),
      throwsA(
        isA<ImportException>().having(
          (error) => error.code,
          'code',
          'invalid_mail',
        ),
      ),
    );
  });

  test('maildir messages come from cur and new', () {
    final directory = Directory.systemTemp.createTempSync('litzy-maildir');
    addTearDown(() => directory.deleteSync(recursive: true));
    for (final folder in ['cur', 'new']) {
      Directory('${directory.path}${Platform.pathSeparator}$folder')
          .createSync();
    }
    File(
      '${directory.path}${Platform.pathSeparator}cur${Platform.pathSeparator}a',
    ).writeAsStringSync(_maildirMessage('a@example.invalid'));
    File(
      '${directory.path}${Platform.pathSeparator}new${Platform.pathSeparator}b',
    ).writeAsStringSync(_maildirMessage('b@example.invalid'));

    final messages = LocalMailParser.parseMaildir(directory);

    expect(messages, hasLength(2));
    expect(messages.map((message) => message.headers['message-id']), [
      '<a@example.invalid>',
      '<b@example.invalid>',
    ]);
  });

  test('an mbox import reaches the profile through the real isolate', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-import-mbox');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}${Platform.pathSeparator}inbox.mbox')
      ..writeAsStringSync(_mbox);
    final client = await _openProfile(
      '${directory.path}${Platform.pathSeparator}profile.db',
    );
    addTearDown(client.close);

    final imported = await client.sendRequest(
      ImportRequest('i1', source.path, MailImportFormat.mbox),
    );
    final found = await client.sendRequest(
      const SearchRequest('s1', 'imported body'),
    );
    final thread = await client.sendRequest(
      const ThreadRequest('t1', 'm1@example.invalid'),
    );

    expect((imported as ImportResponse).count, 2);
    expect((found as SearchResponse).messageIds, hasLength(2));
    expect((thread as ThreadResponse).messages.map((message) => message.id), [
      'm1@example.invalid',
      'm2@example.invalid',
    ]);
  });

  test('a maildir import persists one message per file', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-import-dir');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = Directory(
      '${directory.path}${Platform.pathSeparator}Maildir',
    );
    Directory('${source.path}${Platform.pathSeparator}new')
        .createSync(recursive: true);
    File('${source.path}${Platform.pathSeparator}new${Platform.pathSeparator}a')
        .writeAsStringSync(_maildirMessage('a@example.invalid'));
    final client = await _openProfile(
      '${directory.path}${Platform.pathSeparator}profile.db',
    );
    addTearDown(client.close);

    final imported = await client.sendRequest(
      ImportRequest('i1', source.path, MailImportFormat.maildir),
    );
    final found = await client.sendRequest(
      const SearchRequest('s1', 'maildir body'),
    );

    expect((imported as ImportResponse).count, 1);
    expect((found as SearchResponse).messageIds, ['a@example.invalid']);
  });

  test('a repeated import does not duplicate messages', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-import-twice');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}${Platform.pathSeparator}inbox.mbox')
      ..writeAsStringSync(_mbox);
    final client = await _openProfile(
      '${directory.path}${Platform.pathSeparator}profile.db',
    );
    addTearDown(client.close);

    await client.sendRequest(
      ImportRequest('i1', source.path, MailImportFormat.mbox),
    );
    final second = await client.sendRequest(
      ImportRequest('i2', source.path, MailImportFormat.mbox),
    );

    expect((second as ImportResponse).count, 0);
  });

  test('a missing import source is rejected explicitly', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-import-miss');
    addTearDown(() => directory.deleteSync(recursive: true));
    final client = await _openProfile(
      '${directory.path}${Platform.pathSeparator}profile.db',
    );
    addTearDown(client.close);

    final response = await client.sendRequest(
      ImportRequest(
        'i1',
        '${directory.path}${Platform.pathSeparator}absent.mbox',
        MailImportFormat.mbox,
      ),
    );

    expect(
      response,
      isA<ErrorResponse>().having(
        (error) => error.code,
        'code',
        'import_source_missing',
      ),
    );
  });

  test('malformed mail is rejected before anything is persisted', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-import-bad');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File(
      '${directory.path}${Platform.pathSeparator}bad.mbox',
    )..writeAsStringSync('From author@example.invalid\nbody without headers\n');
    final client = await _openProfile(
      '${directory.path}${Platform.pathSeparator}profile.db',
    );
    addTearDown(client.close);

    final response = await client.sendRequest(
      ImportRequest('i1', source.path, MailImportFormat.mbox),
    );
    final found = await client.sendRequest(const SearchRequest('s1', 'body'));

    expect(
      response,
      isA<ErrorResponse>().having(
        (error) => error.code,
        'code',
        'invalid_mail',
      ),
    );
    expect((found as SearchResponse).messageIds, isEmpty);
  });
}
