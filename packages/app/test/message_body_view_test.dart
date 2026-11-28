// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';

void main() {
  initializeAppTests();

  late AppBundle bundle;

  setUp(() {
    bundle = testBundle();
  });

  testWidgets('quotes fold and patches render with declarative styling', (
    tester,
  ) async {
    final fixture = guiBodyFixture();
    final quoted = [
      TextTokens.quoteMarker,
      TextTokens.space,
      fixture.quotedContext,
    ].join();
    final rawDiff = fixture.diffLines.join(TextTokens.lineFeed);
    final body = [quoted, fixture.prose, rawDiff].join(TextTokens.lineFeed);

    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: Scaffold(
          body: MessageBodyView(body: body, bundle: bundle),
        ),
      ),
    );

    expect(
      find.widgetWithText(ExpansionTile, bundle.messages.quotedContext(1)),
      findsOneWidget,
    );
    expect(find.text(fixture.prose), findsOneWidget);
    expect(find.text(rawDiff), findsOneWidget);

    final diffText = tester.widget<Text>(find.text(rawDiff));
    expect(diffText.style?.fontFamily, bundle.theme.monospaceFont);
    expect(diffText.style?.color, bundle.theme.diffColor);

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.text(fixture.quotedContext), findsOneWidget);
  });
}
