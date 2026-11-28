// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:engine/engine.dart';

Directory _litzyRoot() {
  var directory = Directory.current;
  while (true) {
    final catalogue =
        '${directory.path}${Platform.pathSeparator}data'
        '${Platform.pathSeparator}catalog${Platform.pathSeparator}lists.yaml';
    if (File(catalogue).existsSync()) return directory;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError('Litzy root not found from ${Directory.current.path}');
}

const String _atom = '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>git</title>
  <entry>
    <id>m1@example.invalid</id>
    <title>cover letter</title>
  </entry>
</feed>''';

const String _mbox =
    '''From <author@example.invalid> Mon Nov 28 00:00:00 2026 +0000
Message-ID: <m1@example.invalid>
List-Id: <git@vger.kernel.org>
Subject: cover letter
From: Author <author@example.invalid>

first body line

From <reply@example.invalid> Mon Nov 28 00:01:00 2026 +0000
Message-ID: <m2@example.invalid>
In-Reply-To: <m1@example.invalid>
References: <m1@example.invalid>
List-Id: <git@vger.kernel.org>
Subject: Re: cover letter
From: Replier <reply@example.invalid>

reply body''';

Future<HttpServer> _startServer() async {
  final server = await HttpServer.bind('127.0.0.1', 0);
  server.listen((request) async {
    if (request.uri.path == '/new.atom') {
      request.response.headers.contentType = ContentType(
        'application',
        'atom+xml',
      );
      request.response.write(_atom);
    } else if (request.uri.path == '/m1@example.invalid/t.mbox.gz') {
      request.response.headers.contentType = ContentType('application', 'gzip');
      request.response.add(gzip.encode(utf8.encode(_mbox)));
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  });
  return server;
}

final class _Harness {
  _Harness() {
    directory = Directory.systemTemp.createTempSync('litzy-mode-c');
    database = LocalDatabase.inMemory();
    blobs = LocalBlobStore(directory);
    ingestor = ListMessageIngestor(database: database, blobs: blobs);
  }

  late final Directory directory;
  late final LocalDatabase database;
  late final LocalBlobStore blobs;
  late final ListMessageIngestor ingestor;

  void close() {
    database.close();
    directory.deleteSync(recursive: true);
  }
}

ListSource _source(
  String id,
  String listId, {
  String nntpHost = '',
  String newsgroup = '',
  String inboxBaseUrl = 'https://mirror.example.invalid/git/',
}) => ListSource(
  id: id,
  label: id,
  listId: listId,
  nntpHost: nntpHost,
  nntpPort: 119,
  newsgroup: newsgroup,
  inboxBaseUrl: inboxBaseUrl,
);

RawMessage _message(String id, String listId) {
  final raw = [
    'Message-ID: <$id>',
    if (listId.isNotEmpty) 'List-Id: <$listId>',
    'Subject: subject',
    'From: Author <author@example.invalid>',
    '',
    'body',
  ].join('\n');
  return RawMessage(
    headers: {
      'message-id': '<$id>',
      if (listId.isNotEmpty) 'list-id': '<$listId>',
      'subject': 'subject',
      'from': 'Author <author@example.invalid>',
    },
    body: 'body',
    raw: raw,
    checksum: checksumOfBytes(utf8.encode(raw)),
  );
}

void main() {
  test('a catalogue source maps to a persisted channel', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final sources = CatalogLoader.load(
      '${_litzyRoot().path}/data/catalog/lists.yaml',
    );
    final git = sources.firstWhere((source) => source.id == 'git');
    final debian = sources.firstWhere((source) => source.id == 'debian-devel');

    final gitChannel = ChannelMapper.fromSource(git);
    final debianChannel = ChannelMapper.fromSource(debian);
    harness.database.upsertChannel(gitChannel);

    expect(gitChannel.listId, 'git@vger.kernel.org');
    expect(gitChannel.protocol, 'nntp');
    expect(gitChannel.endpoint, 'nntp.lore.kernel.org:119/lore.git');
    expect(debianChannel.protocol, 'public_inbox');
    expect(harness.database.channelOf('git'), gitChannel);
  });

  test('a source without a usable protocol is rejected', () {
    expect(
      () => ChannelMapper.fromSource(
        _source('empty', 'empty@example.invalid', inboxBaseUrl: ''),
      ),
      throwsA(isA<CatalogException>()),
    );
  });

  test('public-inbox messages reach SQLite through a mapped channel', () async {
    final server = await _startServer();
    addTearDown(() => server.close());
    final harness = _Harness();
    addTearDown(harness.close);
    final client = const PublicInboxClient();
    final base = Uri.parse('http://127.0.0.1:${server.port}/');
    final channel = ChannelMapper.fromSource(
      _source('git', 'git@vger.kernel.org', inboxBaseUrl: base.toString()),
    );

    final ids = await client.recentThreadIds(base);
    final messages = await client.threadMessages(base, ids.first);
    final count = harness.ingestor.ingest(channel, messages);

    expect(count, 2);
    expect(harness.database.messageIds, [
      'm1@example.invalid',
      'm2@example.invalid',
    ]);
    expect(
      harness.database.subtree('m1@example.invalid').map((record) => record.id),
      ['m1@example.invalid', 'm2@example.invalid'],
    );
    expect(harness.database.search('first body line'), ['m1@example.invalid']);
    final root = harness.database.subtree('m1@example.invalid').first;
    expect(harness.blobs.verify(root.checksum), isTrue);
    expect(harness.database.channelOf('git'), channel);
  });

  test('a message from another list is rejected without persistence', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final channel = ChannelMapper.fromSource(
      _source('git', 'git@vger.kernel.org'),
    );

    expect(
      () => harness.ingestor.ingest(channel, [
        _message('m1@example.invalid', 'other@example.invalid'),
      ]),
      throwsA(
        isA<ListMessageIngestException>().having(
          (error) => error.code,
          'code',
          'list_id_mismatch',
        ),
      ),
    );
    expect(harness.database.messageIds, isEmpty);
  });

  test('a message without a List-Id header is rejected', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final channel = ChannelMapper.fromSource(
      _source('git', 'git@vger.kernel.org'),
    );

    expect(
      () => harness.ingestor.ingest(channel, [
        _message('m1@example.invalid', ''),
      ]),
      throwsA(
        isA<ListMessageIngestException>().having(
          (error) => error.code,
          'code',
          'missing_list_id',
        ),
      ),
    );
    expect(harness.database.messageIds, isEmpty);
  });

  test('re-ingesting the same batch leaves the database unchanged', () {
    final harness = _Harness();
    addTearDown(harness.close);
    final channel = ChannelMapper.fromSource(
      _source('git', 'git@vger.kernel.org'),
    );
    final messages = [_message('m1@example.invalid', 'git@vger.kernel.org')];
    harness.ingestor.ingest(channel, messages);

    expect(
      () => harness.ingestor.ingest(channel, messages),
      throwsA(
        isA<ListMessageIngestException>().having(
          (error) => error.code,
          'code',
          'persistence_failed',
        ),
      ),
    );
    expect(harness.database.messageIds, ['m1@example.invalid']);
  });
}
