// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:test/test.dart';
import 'package:protocol/protocol.dart';
import 'package:engine/engine.dart';

Future<ServerSocket> _startNntpServer() async {
  final server = await ServerSocket.bind('127.0.0.1', 0);
  server.listen((socket) {
    void send(String line) =>
        socket.write('$line${TextTokens.protocolLineEnding}');
    send('200 fake news server ready');
    var buffer = '';
    socket.listen((bytes) {
      buffer += utf8.decode(bytes);
      while (buffer.contains(TextTokens.lineFeed)) {
        final index = buffer.indexOf(TextTokens.lineFeed);
        final line = buffer.substring(0, index).trim();
        buffer = buffer.substring(index + 1);
        if (line.isEmpty) continue;
        if (line.startsWith('GROUP')) {
          send('211 1 1 1 lore.git');
        } else if (line.startsWith('XOVER')) {
          send('224 overview information follows');
          send(
            '1${TextTokens.horizontalTab}subject${TextTokens.horizontalTab}author${TextTokens.horizontalTab}date${TextTokens.horizontalTab}<m1@example.invalid>${TextTokens.horizontalTab}${TextTokens.horizontalTab}',
          );
          send('.');
        } else if (line.startsWith('ARTICLE')) {
          send('220 article follows');
          send('Message-ID: <m1@example.invalid>');
          send('List-Id: <git@vger.kernel.org>');
          send('Subject: cover letter');
          send('From: Author <author@example.invalid>');
          send('');
          send('first body line');
          send('.');
        } else {
          send('500 unknown command');
        }
      }
    });
  });
  return server;
}

const String _atom = '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>git</title>
  <entry><id>m1@example.invalid</id><title>cover letter</title></entry>
</feed>''';

const String _mbox =
    '''From <author@example.invalid> Mon Nov 28 00:00:00 2026 +0000
Message-ID: <m1@example.invalid>
List-Id: <git@vger.kernel.org>
Subject: cover letter
From: Author <author@example.invalid>

first body line''';

Future<HttpServer> _startInboxServer() async {
  final server = await HttpServer.bind('127.0.0.1', 0);
  server.listen((request) async {
    if (request.uri.path == '/new.atom') {
      request.response.write(_atom);
    } else if (request.uri.path == '/m1@example.invalid/t.mbox.gz') {
      request.response.add(gzip.encode(utf8.encode(_mbox)));
    } else {
      request.response.statusCode = HttpStatus.notFound;
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

  Future<EngineClient> start() async {
    client = await EngineClient.start();
    final response = await client!.sendRequest(
      OpenProfileRequest('open', databaseFile.path, blobsDirectory: blobs.path),
    );
    expect(response, isA<AckResponse>());
    return client!;
  }

  String writeCatalogue(String name, String source) {
    final file = File('${directory.path}${Platform.pathSeparator}$name.yaml');
    file.writeAsStringSync('''
version: 1
sources:
  - id: git
    label: Git
    list_id: git@vger.kernel.org
    protocols:
$source
''');
    return file.path;
  }

  Future<void> close() async {
    await client?.close();
    directory.deleteSync(recursive: true);
  }
}

Future<void> _expectSyncedThread(EngineClient client, String requestId) async {
  final found = await client.sendRequest(
    SearchRequest(requestId, 'first body line'),
  );
  expect((found as SearchResponse).messageIds, ['m1@example.invalid']);
  final thread = await client.sendRequest(
    const ThreadRequest('thread', 'm1@example.invalid'),
  );
  expect((thread as ThreadResponse).messages.single.body, 'first body line');
}

void main() {
  test('NNTP sync ingests a channel through the real isolate', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-sync-nntp');
    final harness = _Harness(directory);
    addTearDown(harness.close);
    final server = await _startNntpServer();
    addTearDown(() => server.close());
    final catalogue = harness.writeCatalogue('nntp', '''      nntp:
        host: 127.0.0.1
        port: ${server.port}
        newsgroup: lore.git''');
    final client = await harness.start();

    final response = await client.sendRequest(
      SyncRequest('sync', catalogue, 'git'),
    );

    expect(response, isA<SyncResponse>());
    expect((response as SyncResponse).count, 1);
    expect(response.channelId, 'git');
    await _expectSyncedThread(client, 'search');
  });

  test(
    'public-inbox sync ingests a channel through the real isolate',
    () async {
      final directory = Directory.systemTemp.createTempSync('litzy-sync-inbox');
      final harness = _Harness(directory);
      addTearDown(harness.close);
      final server = await _startInboxServer();
      addTearDown(() => server.close());
      final catalogue = harness.writeCatalogue('inbox', '''      public_inbox:
        base_url: http://127.0.0.1:${server.port}/''');
      final client = await harness.start();

      final response = await client.sendRequest(
        SyncRequest('sync', catalogue, 'git'),
      );

      expect((response as SyncResponse).count, 1);
      await _expectSyncedThread(client, 'search');
    },
  );

  test('an unknown source returns a typed error', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-sync-source');
    final harness = _Harness(directory);
    addTearDown(harness.close);
    final catalogue = harness.writeCatalogue('empty', '''      public_inbox:
        base_url: https://example.invalid/''');
    final client = await harness.start();

    final response = await client.sendRequest(
      const SyncRequest('sync', 'unused', 'git'),
    );
    final missingFile = await client.sendRequest(
      SyncRequest('sync2', catalogue, 'absent'),
    );

    expect(response, isA<ErrorResponse>());
    expect((response as ErrorResponse).code, 'sync_failed');
    expect(missingFile, isA<ErrorResponse>());
    expect((missingFile as ErrorResponse).code, 'sync_failed');
  });

  test('a message from another list is rejected without persistence', () async {
    final directory = Directory.systemTemp.createTempSync('litzy-sync-trust');
    final harness = _Harness(directory);
    addTearDown(harness.close);
    final server = await _startNntpServer();
    addTearDown(() => server.close());
    final catalogue = harness.writeCatalogue('nntp', '''      nntp:
        host: 127.0.0.1
        port: ${server.port}
        newsgroup: lore.git''');
    final client = await harness.start();
    final source = File(catalogue)
        .readAsStringSync()
        .replaceFirst('git@vger.kernel.org', 'other@example.invalid');
    File(catalogue).writeAsStringSync(source);

    final response = await client.sendRequest(
      SyncRequest('sync', catalogue, 'git'),
    );
    final found = await client.sendRequest(
      const SearchRequest('search', 'first body line'),
    );

    expect(response, isA<ErrorResponse>());
    expect((response as ErrorResponse).code, 'sync_failed');
    expect((found as SearchResponse).messageIds, isEmpty);
  });
}
