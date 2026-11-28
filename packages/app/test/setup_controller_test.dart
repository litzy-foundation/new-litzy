// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:protocol/protocol.dart';
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

_Harness _harness({Object? failure, DiscoveredAccount? discovered}) {
  final store = _MemoryStore();
  final source = FakeAccountSource(discovered: discovered, failure: failure);
  final messages = AppMessages(
    FluentCatalog.parse(resourceText('data/l10n/en.ftl')),
  );
  final controller = SetupController(
    source: source,
    vault: CredentialVault(store: store, providers: const []),
    messages: messages,
  );
  return _Harness(
    store: store,
    source: source,
    controller: controller,
    messages: messages,
  );
}

final class _Harness {
  _Harness({
    required this.store,
    required this.source,
    required this.controller,
    required this.messages,
  });

  final _MemoryStore store;
  final FakeAccountSource source;
  final SetupController controller;
  final AppMessages messages;
}

void main() {
  initializeAppTests();

  test('a verified login stores the password only in the keychain', () async {
    final harness = _harness(discovered: fixtureAccount());

    await harness.controller.submit('USER@example.com', 'probe-password');

    expect(harness.controller.state.value.stage, SetupStage.connected);
    expect(harness.source.connectCalls, 1);
    expect(harness.source.revealedCredential, 'probe-password');
    expect(harness.store.entries.values, contains('probe-password'));
    expect(
      '${harness.controller.state.value}',
      isNot(contains('probe-password')),
    );
    harness.controller.dispose();
  });

  test('a rejected login removes the stored password', () async {
    final harness = _harness(
      discovered: fixtureAccount(),
      failure: const AccountSourceException('authentication_failed', 'no'),
    );

    await harness.controller.submit('user@example.com', 'probe-password');

    expect(harness.controller.state.value.stage, SetupStage.failed);
    expect(harness.controller.state.value.message, harness.messages.setupError);
    expect(harness.store.entries, isEmpty);
    harness.controller.dispose();
  });

  test('an account without password authentication stores nothing', () async {
    final discovered = fixtureAccount();
    final oauth = DiscoveredAccount(
      emailAddress: discovered.emailAddress,
      imap: AccountEndpoint(
        host: discovered.imap.host,
        port: discovered.imap.port,
        transport: discovered.imap.transport,
        security: discovered.imap.security,
        authentication: AccountAuthentication.oauthBearer,
        source: discovered.imap.source,
        verified: discovered.imap.verified,
      ),
      smtp: discovered.smtp,
    );
    final harness = _harness(discovered: oauth);

    await harness.controller.submit('user@example.com', 'probe-password');

    expect(harness.controller.state.value.stage, SetupStage.failed);
    expect(harness.source.connectCalls, 0);
    expect(
      harness.controller.state.value.message,
      harness.messages.accountUnsupportedAuth,
    );
    expect(harness.store.entries, isEmpty);
    harness.controller.dispose();
  });

  test('an empty password does not start discovery', () async {
    final harness = _harness(discovered: fixtureAccount());

    await harness.controller.submit('user@example.com', '');

    expect(harness.controller.state.value.stage, SetupStage.failed);
    expect(harness.source.connectCalls, 0);
    expect(
      harness.controller.state.value.message,
      harness.messages.passwordRequired,
    );
    expect(harness.store.entries, isEmpty);
    harness.controller.dispose();
  });

  test('an invalid address does not start discovery', () async {
    final harness = _harness(discovered: fixtureAccount());

    await harness.controller.submit('not-an-address', 'probe-password');

    expect(harness.controller.state.value.stage, SetupStage.failed);
    expect(harness.source.connectCalls, 0);
    expect(
      harness.controller.state.value.message,
      harness.messages.setupInvalidAddress,
    );
    expect(harness.store.entries, isEmpty);
    harness.controller.dispose();
  });
}
