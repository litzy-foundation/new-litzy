// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:engine/engine.dart';

const String _atom = '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>git</title>
  <entry>
    <id>m1@example.invalid</id>
    <title>cover letter</title>
  </entry>
  <entry>
    <id>m2@example.invalid</id>
    <title>other thread</title>
  </entry>
</feed>''';

const String _mbox =
    '''From <author@example.invalid> Mon Nov 28 00:00:00 2026 +0000
Message-ID: <m1@example.invalid>
Subject: cover letter
From: Author <author@example.invalid>

first body line
second body line

From <reply@example.invalid> Mon Nov 28 00:01:00 2026 +0000
Message-ID: <m2@example.invalid>
In-Reply-To: <m1@example.invalid>
Subject: Re: cover letter
From: Replier <reply@example.invalid>

reply body''';

Future<HttpServer> _startServer({String atom = _atom}) async {
  final server = await HttpServer.bind('127.0.0.1', 0);
  server.listen((request) async {
    final path = request.uri.path;
    if (path == '/new.atom') {
      request.response.headers.contentType = ContentType(
        'application',
        'atom+xml',
      );
      request.response.write(atom);
    } else if (path == '/m1@example.invalid/t.mbox.gz') {
      request.response.headers.contentType = ContentType('application', 'gzip');
      request.response.add(gzip.encode(utf8.encode(_mbox)));
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('missing');
    }
    await request.response.close();
  });
  return server;
}

void main() {
  test('recent thread identifiers come from the local atom feed', () async {
    final server = await _startServer();
    addTearDown(() => server.close());
    final client = const PublicInboxClient();
    final base = Uri.parse('http://127.0.0.1:${server.port}/');

    expect(await client.recentThreadIds(base), [
      'm1@example.invalid',
      'm2@example.invalid',
    ]);
  });

  test('a thread mbox is decompressed into typed messages', () async {
    final server = await _startServer();
    addTearDown(() => server.close());
    final client = const PublicInboxClient();
    final base = Uri.parse('http://127.0.0.1:${server.port}/');

    final messages = await client.threadMessages(base, 'm1@example.invalid');

    expect(messages, hasLength(2));
    expect(messages.first.headers['message-id'], '<m1@example.invalid>');
    expect(messages.first.body, 'first body line\nsecond body line');
    expect(messages.last.headers['in-reply-to'], '<m1@example.invalid>');
    expect(messages.last.body, 'reply body');
    final expectedRaw = <String>[
      'Message-ID: <m1@example.invalid>',
      'Subject: cover letter',
      'From: Author <author@example.invalid>',
      '',
      'first body line',
      'second body line',
    ].join('\n');
    expect(messages.first.checksum, checksumOfBytes(utf8.encode(expectedRaw)));
  });

  test('a missing mbox reports its HTTP status', () async {
    final server = await _startServer();
    addTearDown(() => server.close());
    final client = const PublicInboxClient();
    final base = Uri.parse('http://127.0.0.1:${server.port}/');

    await expectLater(
      client.threadMessages(base, 'missing@example.invalid'),
      throwsA(
        isA<PublicInboxException>().having(
          (error) => error.code,
          'code',
          HttpStatus.notFound,
        ),
      ),
    );
  });

  test('a malformed atom feed reports a typed failure', () async {
    final server = await _startServer(atom: '<feed><entry></feed>');
    addTearDown(() => server.close());
    final client = const PublicInboxClient();
    final base = Uri.parse('http://127.0.0.1:${server.port}/');

    await expectLater(
      client.recentThreadIds(base),
      throwsA(isA<PublicInboxException>()),
    );
  });

  test('an unsafe thread identifier is rejected before a request', () async {
    final server = await _startServer();
    addTearDown(() => server.close());
    final client = const PublicInboxClient();
    final base = Uri.parse('http://127.0.0.1:${server.port}/');

    await expectLater(
      client.threadMessages(base, '../secrets'),
      throwsA(isA<PublicInboxException>()),
    );
  });
}
