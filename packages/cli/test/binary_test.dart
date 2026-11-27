// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

Directory _litzyRoot() {
  var directory = Directory.current;
  while (true) {
    if (File('${directory.path}${Platform.pathSeparator}pubspec.yaml')
        .existsSync()) {
      final workspace = File(
        '${directory.path}${Platform.pathSeparator}pubspec.yaml',
      ).readAsStringSync();
      if (workspace.contains('- packages/cli')) return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError('Litzy root not found from ${Directory.current.path}');
}

Future<ProcessResult> _run(Directory root, List<String> arguments) =>
    Process.run(Platform.resolvedExecutable, [
      'run',
      'cli:litzy',
      ...arguments,
    ], workingDirectory: root.path);

Map<String, Object?> _jsonObject(Object? text) =>
    jsonDecode(text! as String) as Map<String, Object?>;

Future<ServerSocket> _startNntpServer() async {
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
        if (line.isEmpty) continue;
        if (line.startsWith('GROUP')) {
          send('211 1 1 1 lore.git');
        } else if (line.startsWith('XOVER')) {
          send('224 overview information follows');
          send('1\tsubject\tauthor\tdate\t<m1@example.invalid>\t\t');
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

final class _Harness {
  _Harness(this.root) {
    directory = Directory.systemTemp.createTempSync('litzy-cli');
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

  test('the binary answers a ping with structured output', () async {
    final result = await _run(root, ['ping']);

    expect(result.exitCode, 0);
    expect(_jsonObject(result.stdout), {'ok': true});
  });

  test(
    'sync, search and thread work across separate binary invocations',
    () async {
      final harness = _Harness(root);
      addTearDown(harness.close);
      final server = await _startNntpServer();
      addTearDown(() => server.close());
      final catalogue = File(
        '${harness.directory.path}${Platform.pathSeparator}lists.yaml',
      );
      catalogue.writeAsStringSync('''
version: 1
sources:
  - id: git
    label: Git
    list_id: git@vger.kernel.org
    protocols:
      nntp:
        host: 127.0.0.1
        port: ${server.port}
        newsgroup: lore.git
''');

      final empty = await harness.run(['search', 'first body line']);
      final synced = await harness.run([
        'sync',
        '--catalogue',
        catalogue.path,
        '--source',
        'git',
      ]);
      final found = await harness.run(['search', 'first body line']);
      final thread = await harness.run(['thread', 'm1@example.invalid']);

      expect(_jsonObject(empty.stdout), {'ids': <Object?>[]});
      expect(_jsonObject(synced.stdout), {'channelId': 'git', 'count': 1});
      expect(_jsonObject(found.stdout), {
        'ids': ['m1@example.invalid'],
      });
      final messages = _jsonObject(thread.stdout)['messages'] as List<Object?>;
      final message = messages.single as Map<String, Object?>;
      expect(message['body'], 'first body line');
    },
  );

  test('a failed sync exits nonzero with a stable code', () async {
    final harness = _Harness(root);
    addTearDown(harness.close);
    final catalogue = File(
      '${harness.directory.path}${Platform.pathSeparator}lists.yaml',
    );
    catalogue.writeAsStringSync('version: 1\nsources: []\n');

    final result = await harness.run([
      'sync',
      '--catalogue',
      catalogue.path,
      '--source',
      'absent',
    ]);

    expect(result.exitCode, 1);
    expect(result.stderr as String, contains('sync_failed'));
  });

  test('an invalid command exits with a usage code', () async {
    final result = await _run(root, ['--database', 'p.db', 'unknown']);

    expect(result.exitCode, 64);
    expect(result.stderr as String, contains('usage error'));
  });
}
