// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';
import 'fake_reading_source.dart';

void main() {
  initializeAppTests();

  late AppBundle bundle;
  late ReadingController controller;

  setUp(() async {
    bundle = testBundle();
    controller = ReadingController(
      FakeReadingSource(
        channelViews: [defaultGitChannel()],
        threadSummaries: fixtureSummaries(),
        messageList: fixtureMessages(),
      ),
      bundle.messages,
    );
    await controller.load();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: ReadingShell(controller: controller, bundle: bundle),
      ),
    );
  }

  testWidgets('a wide window shows three panes', (tester) async {
    await tester.binding.setSurfaceSize(
      Size(bundle.layout.desktopMinWidth.toDouble(), 800),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpShell(tester);

    expect(find.byType(ChannelPane), findsOneWidget);
    expect(find.byType(TopicPane), findsOneWidget);
    expect(find.byType(ThreadPane), findsOneWidget);
  });

  testWidgets('a narrow window navigates from channels to a conversation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(
      Size(bundle.layout.desktopMinWidth.toDouble() - 1, 800),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpShell(tester);

    expect(find.byType(ChannelPane), findsOneWidget);
    expect(find.byType(TopicPane), findsNothing);
    expect(find.byType(ThreadPane), findsNothing);

    await tester.tap(find.text(defaultGitChannel().label));
    await tester.pumpAndSettle();

    expect(find.byType(TopicPane), findsOneWidget);
    expect(find.text(bundle.messages.patchBadge), findsOneWidget);
    final subject = fixtureSummaries().single.subject;
    await tester.tap(find.text(subject).first);
    await tester.pumpAndSettle();

    expect(find.byType(ThreadPane), findsOneWidget);
    expect(
      find.textContaining(fixtureMessages().last.body.trim()),
      findsWidgets,
    );

    await tester.tap(find.text(bundle.messages.backAction));
    await tester.pumpAndSettle();

    expect(find.byType(TopicPane), findsOneWidget);
    expect(find.byType(ThreadPane), findsNothing);
  });
}
