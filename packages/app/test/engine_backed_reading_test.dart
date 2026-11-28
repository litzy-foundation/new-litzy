// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:app/app.dart';
import 'package:engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';

import 'app_test_helpers.dart';

void main() {
  initializeAppTests();

  testWidgets('the GUI reads the recorded Git thread through the real engine', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('litzy-gui-reading');
    addTearDown(() => directory.deleteSync(recursive: true));
    final databasePath = '${directory.path}${Platform.pathSeparator}litzy.db';
    final blobsPath = '${directory.path}${Platform.pathSeparator}blobs';
    final defaults = DefaultCatalogue.resolve();
    final source = CatalogLoader.load(defaults.cataloguePath)
        .singleWhere((candidate) => candidate.id == defaults.sourceId);
    final channel = ChannelMapper.fromSource(source);
    final database = LocalDatabase.open(databasePath);
    final count =
        ListMessageIngestor(
          database: database,
          blobs: LocalBlobStore(Directory(blobsPath)),
        ).ingest(
          channel,
          LocalMailParser.parseMbox(
            resourceText('data/fixtures/git_public_inbox_thread.mbox'),
          ),
        );
    database.close();
    expect(count, 2);

    final bundle = testBundle();
    late EngineClient engine;
    late ReadingController controller;
    await tester.runAsync(() async {
      engine = await EngineClient.start();
      final opened = await engine.send(
        OpenProfileRequest('gui-test-open', databasePath),
      );
      expect(opened, isA<AckResponse>());

      controller = ReadingController(
        EngineReadingSource(engine),
        bundle.messages,
      );
      await controller.load();
      await controller.selectChannel(channel.id);
      await controller.selectThread(fixtureSummaries().single.rootId);
    });
    addTearDown(engine.close);

    await tester.binding.setSurfaceSize(
      Size(bundle.layout.desktopMinWidth.toDouble(), 800),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: ReadingShell(controller: controller, bundle: bundle),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(ChannelPane),
        matching: find.text(channel.label),
      ),
      findsOneWidget,
    );
    expect(find.text(fixtureSummaries().single.subject), findsWidgets);
    expect(find.text(fixtureMessages().last.body.trim()), findsOneWidget);
  });
}
