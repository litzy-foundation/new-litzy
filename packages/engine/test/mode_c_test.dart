// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
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

Future<ServerSocket> _startFakeServer() async {
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
          send('211 2 1 2 lore.git');
        } else if (line.startsWith('XOVER bad-range')) {
          send('501 range syntax error');
        } else if (line.startsWith('XOVER')) {
          send('224 overview information follows');
          send(
            '1${TextTokens.horizontalTab}subject${TextTokens.horizontalTab}author${TextTokens.horizontalTab}date${TextTokens.horizontalTab}<m1@example.invalid>${TextTokens.horizontalTab}${TextTokens.horizontalTab}',
          );
          send(
            '2${TextTokens.horizontalTab}subject${TextTokens.horizontalTab}author${TextTokens.horizontalTab}date${TextTokens.horizontalTab}<m2@example.invalid>${TextTokens.horizontalTab}${TextTokens.horizontalTab}',
          );
          send('.');
        } else if (line.startsWith('ARTICLE')) {
          send('220 article follows');
          send('Message-ID: <m1@example.invalid>');
          send('List-Id: git@vger.kernel.org');
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

void main() {
  test('the NNTP client reads a group, an overview and an article', () async {
    final server = await _startFakeServer();
    addTearDown(() => server.close());
    final client = NntpClient('127.0.0.1', server.port);
    await client.connect();
    addTearDown(client.close);

    expect(await client.group('lore.git'), 2);
    final overview = await client.overview('1-');
    expect(overview.map((row) => row.messageId), [
      '<m1@example.invalid>',
      '<m2@example.invalid>',
    ]);
    final article = await client.article('<m1@example.invalid>');
    expect(article.headers, contains('List-Id: git@vger.kernel.org'));
    expect(article.body, ['first body line']);
  });

  test('an unexpected NNTP status is reported explicitly', () async {
    final server = await _startFakeServer();
    addTearDown(() => server.close());
    final client = NntpClient('127.0.0.1', server.port);
    await client.connect();
    addTearDown(client.close);

    await expectLater(
      client.overview('bad-range'),
      throwsA(isA<NntpException>().having((error) => error.code, 'code', 501)),
    );
  });

  test('the versioned YAML catalogue lists Mode C sources', () {
    final root = _litzyRoot();
    final sources = CatalogLoader.load('${root.path}/data/catalog/lists.yaml');
    final git = sources.firstWhere((source) => source.id == 'git');
    expect(git.listId, 'git@vger.kernel.org');
    expect(git.nntpHost, 'nntp.lore.kernel.org');
    expect(git.newsgroup, 'lore.git');
    expect(git.inboxBaseUrl, contains('lore.kernel.org'));
    expect(sources.map((source) => source.id), contains('linux-kernel'));
  });

  test('a missing catalogue fails with an explicit error', () {
    final root = _litzyRoot();
    expect(
      () => CatalogLoader.load('${root.path}/data/catalog/missing.yaml'),
      throwsA(isA<CatalogException>()),
    );
  });
}
