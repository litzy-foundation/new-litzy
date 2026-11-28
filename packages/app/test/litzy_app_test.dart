// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';
import 'fake_reading_source.dart';
import 'inert_engine.dart';

void main() {
  initializeAppTests();

  testWidgets('the root app loads the fake source and closes its engine', (
    tester,
  ) async {
    final bundle = testBundle();
    final engine = InertEngine();
    final source = FakeReadingSource(
      channelViews: [defaultGitChannel()],
      threadSummaries: fixtureSummaries(),
    );

    await tester.pumpWidget(
      LitzyApp(engine: engine, source: source, bundle: bundle),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReadingShell), findsOneWidget);
    expect(find.text(bundle.messages.channelsTitle), findsOneWidget);
    expect(find.text(bundle.messages.ownThreads), findsOneWidget);
    expect(find.text(bundle.messages.unreadMail), findsOneWidget);
    expect(find.text(bundle.messages.awaitingReply), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(engine.closeCount, 1);
  });
}
