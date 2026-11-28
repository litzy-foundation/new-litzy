// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:protocol/protocol.dart';

/// Deterministic account port used by setup tests.
final class FakeAccountSource implements AccountSource {
  /// Creates a source with a fixed discovery result or failure.
  FakeAccountSource({
    this.discovered,
    this.failure,
    this.stored = const <AccountView>[],
  });

  /// Result returned by discovery.
  final DiscoveredAccount? discovered;

  /// Exception thrown by discovery and connection when set.
  final Object? failure;

  /// Accounts returned by the list operation.
  final List<AccountView> stored;

  /// Number of connection calls received.
  int connectCalls = 0;

  /// Password supplied to the last connection call.
  String? revealedCredential;

  @override
  Future<List<AccountView>> accounts() async => stored;

  @override
  Future<DiscoveredAccount> discover(String emailAddress) async {
    final raised = failure;
    if (raised != null) throw raised;
    final account = discovered;
    if (account == null) {
      throw const AccountSourceException('discovery', 'none');
    }
    return account;
  }

  @override
  Future<void> connect({
    required String emailAddress,
    required AccountCredential credential,
    required AccountEndpoint imap,
    required AccountEndpoint smtp,
  }) async {
    connectCalls++;
    revealedCredential = credential.reveal;
    final raised = failure;
    if (raised != null) throw raised;
  }
}

/// Creates a verified password account for a loopback fixture.
DiscoveredAccount fixtureAccount() => const DiscoveredAccount(
  emailAddress: 'user@example.com',
  imap: AccountEndpoint(
    host: '127.0.0.1',
    port: 993,
    transport: AccountTransport.imap,
    security: AccountSecurity.implicitTls,
    authentication: AccountAuthentication.password,
    source: AccountEndpointSource.autoconfigWellKnown,
    verified: true,
  ),
  smtp: AccountEndpoint(
    host: '127.0.0.1',
    port: 465,
    transport: AccountTransport.smtp,
    security: AccountSecurity.implicitTls,
    authentication: AccountAuthentication.password,
    source: AccountEndpointSource.autoconfigWellKnown,
    verified: true,
  ),
);
