// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

Directory _litzyRoot() {
  var directory = Directory.current;
  while (true) {
    final manifest = File(
      '${directory.path}${Platform.pathSeparator}pubspec.yaml',
    );
    if (manifest.existsSync() &&
        manifest.readAsStringSync().contains('- packages/cli')) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError('the Litzy root was not found');
}

String _fixture(String name) => File(
  '${_litzyRoot().path}${Platform.pathSeparator}data'
  '${Platform.pathSeparator}fixtures${Platform.pathSeparator}$name',
).readAsStringSync();

File _catalogue(Directory directory, String name, int port) {
  final target = File('${directory.path}${Platform.pathSeparator}$name');
  target.writeAsStringSync(
    _fixture(name).replaceAll('__PORT__', port.toString()),
  );
  return target;
}

Future<ProcessResult> _run(Directory root, List<String> arguments) =>
    Process.run(Platform.resolvedExecutable, [
      'run',
      'cli:litzy',
      ...arguments,
    ], workingDirectory: root.path);

Map<String, Object?> _jsonObject(Object? text) =>
    jsonDecode(text! as String) as Map<String, Object?>;

List<Object?> _jsonList(Object? text, String key) =>
    _jsonObject(text)[key] as List<Object?>;

Future<ServerSocket> _startNntpFixture() async {
  final lines = const LineSplitter().convert(_fixture('git_nntp_article.eml'));
  final messageId = lines
      .firstWhere((line) => line.startsWith('Message-ID:'))
      .split(':')
      .last
      .trim();
  final subject = lines
      .firstWhere((line) => line.startsWith('Subject:'))
      .split(':')
      .last
      .trim();
  final from = lines
      .firstWhere((line) => line.startsWith('From:'))
      .split(':')
      .last
      .trim();
  final fieldSeparator = String.fromCharCode(9);
  final carriageReturn = String.fromCharCode(13);
  final lineFeed = String.fromCharCode(10);
  final crlf = '$carriageReturn$lineFeed';
  final server = await ServerSocket.bind('127.0.0.1', 0);
  server.listen((socket) {
    void send(String line) => socket.write('$line$crlf');
    send('200 local fixture ready');
    final buffer = StringBuffer();
    socket.listen((bytes) {
      buffer.write(utf8.decode(bytes));
      while (true) {
        final text = buffer.toString();
        final index = text.indexOf(lineFeed);
        if (index < 0) return;
        buffer.clear();
        buffer.write(text.substring(index + lineFeed.length));
        final rawLine = text.substring(0, index);
        final line = rawLine.endsWith(carriageReturn)
            ? rawLine.substring(0, rawLine.length - 1)
            : rawLine;
        if (line.isEmpty) continue;
        if (line.startsWith('GROUP')) {
          send('211 1 1 1 lore.git');
        } else if (line.startsWith('XOVER')) {
          send('224 overview information follows');
          send(
            [
              '1',
              subject,
              from,
              'Mon Nov 28 00:00:00 2026 +0000',
              messageId,
              '',
              '',
            ].join(fieldSeparator),
          );
          send('.');
        } else if (line.startsWith('ARTICLE')) {
          send('220 article follows');
          for (final articleLine in lines) {
            send(articleLine);
          }
          send('.');
        } else {
          send('500 unknown command');
        }
      }
    });
  });
  return server;
}

Future<HttpServer> _startPublicInboxFixture() async {
  final atom = _fixture('git_public_inbox_atom.xml');
  final mbox = _fixture('git_public_inbox_thread.mbox');
  final server = await HttpServer.bind('127.0.0.1', 0);
  server.listen((request) async {
    if (request.uri.path == '/git/new.atom') {
      request.response.headers.contentType = ContentType(
        'application',
        'atom+xml',
      );
      request.response.write(atom);
    } else if (request.uri.path == '/git/m1@example.invalid/t.mbox.gz') {
      request.response.headers.contentType = ContentType('application', 'gzip');
      request.response.add(gzip.encode(utf8.encode(mbox)));
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  });
  return server;
}

final class _Harness {
  _Harness(this.root) {
    directory = Directory.systemTemp.createTempSync('litzy-git-reading');
    database = '${directory.path}${Platform.pathSeparator}litzy.db';
  }

  final Directory root;
  late final Directory directory;
  late final String database;

  Future<ProcessResult> run(List<String> arguments) =>
      _run(root, ['--database', database, ...arguments]);

  void close() => directory.deleteSync(recursive: true);
}

void main() {
  final root = _litzyRoot();

  test('the binary lists channels, topics and a thread from NNTP', () async {
    final harness = _Harness(root);
    addTearDown(harness.close);
    final server = await _startNntpFixture();
    addTearDown(() => server.close());
    final catalogue = _catalogue(
      harness.directory,
      'git_nntp_catalogue.yaml',
      server.port,
    );

    final synced = await harness.run([
      'sync',
      '--catalogue',
      catalogue.path,
      '--source',
      'git',
    ]);
    final channels = await harness.run(['channels']);
    final listed = await harness.run(['list', 'git']);
    final shown = await harness.run(['show', 'm1@example.invalid']);

    expect(synced.exitCode, 0, reason: synced.stderr as String);
    expect(_jsonObject(synced.stdout), {'channelId': 'git', 'count': 1});
    final channelList =
        _jsonList(channels.stdout, 'channels').single as Map<String, Object?>;
    expect(channelList['id'], 'git');
    expect(channelList['listId'], 'git@vger.kernel.org');
    expect(channelList['protocol'], 'nntp');
    final summary =
        _jsonList(listed.stdout, 'threads').single as Map<String, Object?>;
    expect(summary['rootId'], 'm1@example.invalid');
    expect(summary['subject'], '[PATCH] cover letter');
    expect(summary['messageCount'], 1);
    final messages = _jsonList(shown.stdout, 'messages');
    expect(messages, hasLength(1));
    expect((messages.single as Map<String, Object?>)['parentId'], isNull);
  });

  test('the binary reads a reconstructed thread from public-inbox', () async {
    final harness = _Harness(root);
    addTearDown(harness.close);
    final server = await _startPublicInboxFixture();
    addTearDown(() => server.close());
    final catalogue = _catalogue(
      harness.directory,
      'git_public_inbox_catalogue.yaml',
      server.port,
    );

    final synced = await harness.run(['sync', '--catalogue', catalogue.path]);
    final listed = await harness.run(['list']);
    final shown = await harness.run(['show', 'm1@example.invalid']);

    expect(synced.exitCode, 0, reason: synced.stderr as String);
    expect(_jsonObject(synced.stdout), {'channelId': 'git', 'count': 2});
    final summary =
        _jsonList(listed.stdout, 'threads').single as Map<String, Object?>;
    expect(summary['messageCount'], 2);
    expect(summary['listId'], 'git@vger.kernel.org');
    final messages = _jsonList(shown.stdout, 'messages');
    expect(messages, hasLength(2));
    final reply = messages.last as Map<String, Object?>;
    expect(reply['id'], 'm2@example.invalid');
    expect(reply['parentId'], 'm1@example.invalid');
    expect(reply['body'], contains('reply body'));
  });
}
