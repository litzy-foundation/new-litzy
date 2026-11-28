// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:test/test.dart';
import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';

import 'fixture_paths.dart';

void main() {
  test(
    'typed verbs list channels, topics and one reconstructed thread',
    () async {
      final directory = Directory.systemTemp.createTempSync('litzy-reading');
      addTearDown(() => directory.deleteSync(recursive: true));
      final databasePath = '${directory.path}${Platform.pathSeparator}litzy.db';
      final blobsDirectory = '${directory.path}${Platform.pathSeparator}blobs';
      final defaults = DefaultCatalogue.resolve();
      final source = CatalogLoader.load(defaults.cataloguePath)
          .singleWhere((candidate) => candidate.id == defaults.sourceId);
      final channel = ChannelMapper.fromSource(source);
      final database = LocalDatabase.open(databasePath);
      final count =
          ListMessageIngestor(
            database: database,
            blobs: LocalBlobStore(Directory(blobsDirectory)),
          ).ingest(
            channel,
            LocalMailParser.parseMbox(
              fixtureText('git_public_inbox_thread.mbox'),
            ),
          );
      database.close();
      expect(count, 2);

      final client = await EngineClient.start();
      addTearDown(client.close);
      final opened = await client.sendRequest(
        OpenProfileRequest('open', databasePath),
      );
      expect(opened, isA<AckResponse>());

      final channels = await client.sendRequest(
        const ListChannelsRequest('channels'),
      );
      expect(channels, isA<ChannelListResponse>());
      final listedChannels = (channels as ChannelListResponse).channels;
      expect(listedChannels, hasLength(1));
      expect(listedChannels.single.id, 'git');
      expect(listedChannels.single.listId, 'git@vger.kernel.org');

      final threads = await client.sendRequest(
        const ListThreadsRequest('threads'),
      );
      expect(threads, isA<ThreadListResponse>());
      final summaries = (threads as ThreadListResponse).threads;
      expect(summaries, hasLength(1));
      expect(summaries.single.rootId, 'm1@example.invalid');
      expect(summaries.single.subject, '[PATCH] cover letter');
      expect(summaries.single.messageCount, 2);
      expect(summaries.single.listId, 'git@vger.kernel.org');

      final filtered = await client.sendRequest(
        const ListThreadsRequest('filtered', 'git'),
      );
      expect((filtered as ThreadListResponse).threads, summaries);

      final shown = await client.sendRequest(
        const ShowThreadRequest('show', 'm1@example.invalid'),
      );
      expect(shown, isA<ThreadResponse>());
      final messages = (shown as ThreadResponse).messages;
      expect(messages.map((message) => message.id), [
        'm1@example.invalid',
        'm2@example.invalid',
      ]);
      expect(messages.first.parentId, isNull);
      expect(messages.last.parentId, 'm1@example.invalid');
      expect(messages.first.body, contains('first body line'));
    },
  );

  test('reading verbs before opening a profile return a typed error', () async {
    final client = await EngineClient.start();
    addTearDown(client.close);

    final response = await client.sendRequest(
      const ListChannelsRequest('channels'),
    );

    expect(response, isA<ErrorResponse>());
    expect((response as ErrorResponse).code, 'profile_not_open');
  });
}
