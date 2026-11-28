// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:security/security.dart';

import 'app_test_helpers.dart';
import 'fake_account_source.dart';

final class _MemoryStore implements SecretStore {
  final Map<String, String> entries = <String, String>{};

  @override
  Future<void> put(String key, String secret) async => entries[key] = secret;

  @override
  Future<String?> get(String key) async => entries[key];

  @override
  Future<void> remove(String key) async => entries.remove(key);
}

void main() {
  initializeAppTests();

  testWidgets('the password field obscures entry and skip defers setup', (
    tester,
  ) async {
    final messages = AppMessages(
      FluentCatalog.parse(resourceText('data/l10n/en.ftl')),
    );
    final controller = SetupController(
      source: FakeAccountSource(discovered: fixtureAccount()),
      vault: CredentialVault(store: _MemoryStore(), providers: const []),
      messages: messages,
    );
    var skipped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: SetupScreen(
          controller: controller,
          theme: testBundle().theme,
          onSkip: () => skipped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final password = tester.widget<TextField>(
      find.byKey(const Key('setup.password')),
    );
    expect(password.obscureText, isTrue);
    expect(find.text(messages.setupTitle), findsOneWidget);
    expect(find.text(messages.setupConnectAction), findsOneWidget);

    await tester.tap(find.byKey(const Key('setup.skip')));
    await tester.pumpAndSettle();

    expect(skipped, isTrue);
    controller.dispose();
  });
}
