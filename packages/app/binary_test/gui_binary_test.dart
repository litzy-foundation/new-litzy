// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/app.dart';
import 'package:engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

Directory _litzyRoot() {
  var directory = Directory.current;
  while (true) {
    final manifest = File(
      '${directory.path}${Platform.pathSeparator}pubspec.yaml',
    );
    if (manifest.existsSync() &&
        manifest.readAsStringSync().contains('- packages/app')) {
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

({String channelId, int topicCount}) _seedProfile(
  Directory directory,
  Directory root,
) {
  final defaults = DefaultCatalogue.resolve();
  final source = CatalogLoader.load(defaults.cataloguePath)
      .singleWhere((candidate) => candidate.id == defaults.sourceId);
  final channel = ChannelMapper.fromSource(source);
  final databasePath = '${directory.path}${Platform.pathSeparator}litzy.db';
  final database = LocalDatabase.open(databasePath);
  ListMessageIngestor(
    database: database,
    blobs: LocalBlobStore(
      Directory('${directory.path}${Platform.pathSeparator}blobs'),
    ),
  ).ingest(
    channel,
    LocalMailParser.parseMbox(_fixture(root, 'git_public_inbox_thread.mbox')),
  );
  final topicCount = database.threadSummaries().length;
  database.close();
  return (channelId: channel.id, topicCount: topicCount);
}

void main() {
  test('the compiled GUI binary loads a real Git profile', () async {
    final root = _litzyRoot();
    final binary = File(
      '${root.path}${Platform.pathSeparator}packages${Platform.pathSeparator}'
      'app${Platform.pathSeparator}build${Platform.pathSeparator}'
      'linux${Platform.pathSeparator}x64${Platform.pathSeparator}debug'
      '${Platform.pathSeparator}bundle${Platform.pathSeparator}litzy_gui',
    );
    if (!binary.existsSync()) {
      fail('build the Linux GUI binary before running binary acceptance');
    }
    final directory = Directory.systemTemp.createTempSync('litzy-gui-binary');
    addTearDown(() => directory.deleteSync(recursive: true));
    final profile = _seedProfile(directory, root);

    final environment = Map<String, String>.from(Platform.environment);
    environment[AppEnvironmentKeys.profilePath] =
        '${directory.path}${Platform.pathSeparator}litzy.db';
    environment[AppEnvironmentKeys.acceptance] = AppEnvironmentKeys.enabled;
    final process = await Process.start(
      binary.path,
      const <String>[],
      workingDirectory: root.path,
      environment: environment,
    );
    final stderr = StringBuffer();
    process.stderr.transform(utf8.decoder).listen(stderr.write);

    try {
      final output = <String>[];
      final reported = Completer<void>();
      final subscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            output.add(line);
            if (line.startsWith('${AppRequestKeys.topics}=') &&
                !reported.isCompleted) {
              reported.complete();
            }
          });
      await reported.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            fail('the GUI binary did not report a loaded profile: $stderr'),
      );
      await subscription.cancel();

      expect(output, contains(AppRequestKeys.ready));
      expect(
        output,
        contains('${AppRequestKeys.channel}=${profile.channelId}'),
      );
      expect(
        output,
        contains('${AppRequestKeys.topics}=${profile.topicCount}'),
      );
    } finally {
      process.kill();
    }
  });
}
