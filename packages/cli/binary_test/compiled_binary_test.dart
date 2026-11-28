// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';
import 'dart:io';

import 'package:engine/engine.dart';
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
    if (parent.path == directory.path) {
      throw StateError('the Litzy root was not found');
    }
    directory = parent;
  }
}

String _fixture(Directory root, String name) => File(
  '${root.path}${Platform.pathSeparator}data${Platform.pathSeparator}'
  'fixtures${Platform.pathSeparator}$name',
).readAsStringSync();

Future<File> _compile(Directory root, Directory directory) async {
  final output = Directory('${directory.path}${Platform.pathSeparator}build');
  final result = await Process.run(Platform.resolvedExecutable, [
    'build',
    'cli',
    '-o',
    output.path,
    '-t',
    'packages/cli/bin/litzy.dart',
    '--root-package',
    'cli',
  ], workingDirectory: root.path);
  expect(result.exitCode, 0, reason: result.stderr as String);
  return File(
    '${output.path}${Platform.pathSeparator}bundle${Platform.pathSeparator}'
    'bin${Platform.pathSeparator}litzy',
  );
}

void _seedProfile(Directory directory, Directory root) {
  final defaults = DefaultCatalogue.resolve();
  final source = CatalogLoader.load(defaults.cataloguePath)
      .singleWhere((candidate) => candidate.id == defaults.sourceId);
  final channel = ChannelMapper.fromSource(source);
  final database = LocalDatabase.open(
    '${directory.path}${Platform.pathSeparator}litzy.db',
  );
  ListMessageIngestor(
    database: database,
    blobs: LocalBlobStore(
      Directory('${directory.path}${Platform.pathSeparator}blobs'),
    ),
  ).ingest(
    channel,
    LocalMailParser.parseMbox(_fixture(root, 'git_public_inbox_thread.mbox')),
  );
  database.close();
}

Map<String, Object?> _jsonObject(Object? text) =>
    jsonDecode(text! as String) as Map<String, Object?>;

List<Object?> _jsonList(Object? text, String key) =>
    _jsonObject(text)[key] as List<Object?>;

void main() {
  test('the compiled CLI binary reads a real Git profile', () async {
    final root = _litzyRoot();
    final directory = Directory.systemTemp.createTempSync('litzy-cli-binary');
    addTearDown(() => directory.deleteSync(recursive: true));
    final executable = await _compile(root, directory);
    _seedProfile(directory, root);
    final database = '${directory.path}${Platform.pathSeparator}litzy.db';

    Future<ProcessResult> run(List<String> arguments) => Process.run(
      executable.path,
      ['--database', database, ...arguments],
      workingDirectory: root.path,
    );

    final channels = await run(['channels']);
    final listed = await run(['list']);
    final shown = await run(['show', 'm1@example.invalid']);

    expect(channels.exitCode, 0, reason: channels.stderr as String);
    expect(listed.exitCode, 0, reason: listed.stderr as String);
    expect(shown.exitCode, 0, reason: shown.stderr as String);
    final channel =
        _jsonList(channels.stdout, 'channels').single as Map<String, Object?>;
    expect(channel['listId'], 'git@vger.kernel.org');
    final summary =
        _jsonList(listed.stdout, 'threads').single as Map<String, Object?>;
    expect(summary['messageCount'], 2);
    final messages = _jsonList(shown.stdout, 'messages');
    expect(messages, hasLength(2));
  });
}
