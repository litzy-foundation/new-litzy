// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';

final class _Article {
  const _Article(this.number, this.id, this.listId, this.body);

  final int number;
  final String id;
  final String listId;
  final String body;
}

Future<ServerSocket> _startNntp(List<_Article> articles) async {
  final server = await ServerSocket.bind('127.0.0.1', 0);
  server.listen((socket) {
    void send(String line) => socket.write('$line\r\n');
    send('200 fake news server ready');
    var buffer = '';
    socket.listen((bytes) {
      buffer += utf8.decode(bytes);
      while (buffer.contains('\n')) {
        final index = buffer.indexOf('\n');
        final line = buffer.substring(0, index).trim();
        buffer = buffer.substring(index + 1);
        if (line.startsWith('GROUP')) {
          send('211 ${articles.length} 1 ${articles.length} lore.git');
        } else if (line.startsWith('XOVER')) {
          final parts = line.split(RegExp(r'\s+'));
          final lower = int.tryParse(parts[1].split('-').first) ?? 1;
          send('224 overview information follows');
          for (final article in articles.where(
            (item) => item.number >= lower,
          )) {
            send(
              '${article.number}\tsubject\tauthor\tdate\t'
              '<${article.id}>\t\t',
            );
          }
          send('.');
        } else if (line.startsWith('ARTICLE')) {
          final id = line.substring(8).replaceAll(RegExp(r'[<>]'), '');
          _Article? found;
          for (final article in articles) {
            if (article.id == id) found = article;
          }
          if (found == null) {
            send('430 no such article');
            continue;
          }
          send('220 article follows');
          send('Message-ID: <${found.id}>');
          send('List-Id: <${found.listId}>');
          send('Subject: subject ${found.id}');
          send('From: Author <author@example.invalid>');
          send('');
          send(found.body);
          send('.');
        } else {
          send('500 unknown command');
        }
      }
    });
  });
  return server;
}

String _mbox(String id, String body) =>
    '''
From <author@example.invalid> Mon Nov 28 00:00:00 2026 +0000
Message-ID: <$id>
List-Id: <git@vger.kernel.org>
Subject: subject $id
From: Author <author@example.invalid>

$body''';

Future<HttpServer> _startInbox(
  List<String> ids,
  Map<String, String> bodies,
) async {
  final server = await HttpServer.bind('127.0.0.1', 0);
  server.listen((request) async {
    if (request.uri.path == '/new.atom') {
      final entries = ids
          .map((id) => '<entry><id>$id</id><title>thread</title></entry>')
          .join();
      request.response.write(
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<feed xmlns="http://www.w3.org/2005/Atom">$entries</feed>',
      );
    } else {
      final id = request.uri.path.split('/')[1];
      final body = bodies[id];
      if (body == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.add(gzip.encode(utf8.encode(_mbox(id, body))));
      }
    }
    await request.response.close();
  });
  return server;
}

final class _Harness {
  _Harness(this.directory) {
    databaseFile = File('${directory.path}${Platform.pathSeparator}litzy.db');
    blobs = Directory('${directory.path}${Platform.pathSeparator}blobs');
  }

  final Directory directory;
  late final File databaseFile;
  late final Directory blobs;
  EngineClient? client;

  String writeCatalogue(String protocolDefinition) {
    final file = File('${directory.path}${Platform.pathSeparator}lists.yaml');
    file.writeAsStringSync('''
version: 1
sources:
  - id: git
    label: Git
    list_id: git@vger.kernel.org
    protocols:
$protocolDefinition
''');
    return file.path;
  }

  Future<EngineClient> start() async {
    client = await EngineClient.start();
    final opened = await client!.sendRequest(
      OpenProfileRequest('open', databaseFile.path, blobsDirectory: blobs.path),
    );
    expect(opened, isA<AckResponse>());
    return client!;
  }

  Future<void> close() async {
    await client?.close();
    directory.deleteSync(recursive: true);
  }
}

void main() {
  test('an NNTP cursor skips articles already fetched', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-nntp-cursor');
    final harness = _Harness(directory);
    addTearDown(harness.close);
    final articles = [
      const _Article(1, 'm1@example.invalid', 'git@vger.kernel.org', 'one'),
      const _Article(2, 'm2@example.invalid', 'git@vger.kernel.org', 'two'),
    ];
    final server = await _startNntp(articles);
    addTearDown(() => server.close());
    final catalogue = harness.writeCatalogue('''      nntp:
        host: 127.0.0.1
        port: ${server.port}
        newsgroup: lore.git''');
    final client = await harness.start();

    final first = await client.sendRequest(SyncRequest('s1', catalogue, 'git'));
    final second = await client.sendRequest(
      SyncRequest('s2', catalogue, 'git'),
    );
    articles.add(
      const _Article(3, 'm3@example.invalid', 'git@vger.kernel.org', 'three'),
    );
    final third = await client.sendRequest(SyncRequest('s3', catalogue, 'git'));
    final found = await client.sendRequest(
      const SearchRequest('f1', 'subject'),
    );

    expect((first as SyncResponse).count, 2);
    expect((second as SyncResponse).count, 0);
    expect((third as SyncResponse).count, 1);
    expect((found as SearchResponse).messageIds, hasLength(3));
  });

  test('a public-inbox cursor skips threads already fetched', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-inbox-cursor');
    final harness = _Harness(directory);
    addTearDown(harness.close);
    final ids = ['t1@example.invalid'];
    final bodies = <String, String>{'t1@example.invalid': 'one'};
    final server = await _startInbox(ids, bodies);
    addTearDown(() => server.close());
    final catalogue = harness.writeCatalogue(
      '      public_inbox:\n'
      '        base_url: http://127.0.0.1:${server.port}/',
    );
    final client = await harness.start();

    final first = await client.sendRequest(SyncRequest('s1', catalogue, 'git'));
    final second = await client.sendRequest(
      SyncRequest('s2', catalogue, 'git'),
    );
    ids.add('t2@example.invalid');
    bodies['t2@example.invalid'] = 'two';
    final third = await client.sendRequest(SyncRequest('s3', catalogue, 'git'));

    expect((first as SyncResponse).count, 1);
    expect((second as SyncResponse).count, 0);
    expect((third as SyncResponse).count, 1);
  });

  test('a cursor survives a new engine isolate on the same profile', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-cursor-open');
    final harness = _Harness(directory);
    addTearDown(harness.close);
    final server = await _startNntp([
      const _Article(1, 'm1@example.invalid', 'git@vger.kernel.org', 'one'),
    ]);
    addTearDown(() => server.close());
    final catalogue = harness.writeCatalogue('''      nntp:
        host: 127.0.0.1
        port: ${server.port}
        newsgroup: lore.git''');

    final first = await harness.start();
    expect(
      (await first.sendRequest(SyncRequest('s1', catalogue, 'git'))),
      isA<SyncResponse>(),
    );
    await first.close();
    harness.client = null;
    final second = await harness.start();
    final response = await second.sendRequest(
      SyncRequest('s2', catalogue, 'git'),
    );

    expect((response as SyncResponse).count, 0);
  });

  test('cursors are keyed by channel', () {
    final database = LocalDatabase.inMemory();
    addTearDown(database.close);

    database.setCursor('git', const SyncCursor(articleNumber: 5));
    database.setCursor('other', const SyncCursor(articleNumber: 9));

    expect(database.cursorOf('git')!.articleNumber, 5);
    expect(database.cursorOf('other')!.articleNumber, 9);
    expect(database.cursorOf('absent'), isNull);
  });

  test('a corrupt stored cursor is reported explicitly', () {
    final path =
        '${Directory.systemTemp.createTempSync('litzy-cursor-bad').path}'
        '${Platform.pathSeparator}profile.db';
    final file = File(path);
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
      file.parent.deleteSync();
    });
    final database = LocalDatabase.open(path);
    database.setCursor('git', const SyncCursor(articleNumber: 1));
    database.close();

    final raw = sqlite3.open(path);
    raw.execute(SqlResources.statement(SqlKeys.writeInvalidCursor));
    raw.dispose();
    final reopened = LocalDatabase.open(path);
    addTearDown(reopened.close);

    expect(() => reopened.cursorOf('git'), throwsA(isA<CursorException>()));
  });

  test('a rejected batch does not advance the cursor', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-cursor-fail');
    final harness = _Harness(directory);
    addTearDown(harness.close);
    final server = await _startNntp([
      const _Article(1, 'm1@example.invalid', 'other@example.invalid', 'one'),
    ]);
    addTearDown(() => server.close());
    final catalogue = harness.writeCatalogue('''      nntp:
        host: 127.0.0.1
        port: ${server.port}
        newsgroup: lore.git''');
    final client = await harness.start();

    await client.sendRequest(SyncRequest('s1', catalogue, 'git'));
    await client.close();
    harness.client = null;
    final database = LocalDatabase.open(harness.databaseFile.path);
    addTearDown(database.close);

    expect(database.cursorOf('git'), isNull);
    expect(database.messageIds, isEmpty);
  });
}
