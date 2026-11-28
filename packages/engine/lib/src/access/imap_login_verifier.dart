// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// IMAP implementation of the account login verifier.
///
/// ADR-0015 owns the transport itself. This adapter only connects, authenticates
/// and closes, so no mailbox is selected or changed during setup.
library;

import 'package:core/core.dart';
import 'package:protocol/protocol.dart';

import '../ingestion/imap_client.dart';
import 'account_login_verifier.dart';
import 'setup_exception.dart';

/// Verifies a login with the shared IMAP client.
final class ImapLoginVerifier implements AccountLoginVerifier {
  /// Creates a verifier with an optional command deadline.
  const ImapLoginVerifier({
    this.timeout = const Duration(seconds: 10),
    this.allowLoopbackPlaintextFixtures = false,
  });

  /// Deadline applied to the verification connection.
  final Duration timeout;

  /// Whether a loopback fixture may answer without TLS.
  final bool allowLoopbackPlaintextFixtures;

  @override
  Future<void> verify({
    required AccountEndpoint endpoint,
    required String username,
    required AccountCredential credential,
  }) async {
    final loopbackFixture =
        allowLoopbackPlaintextFixtures && _isLoopback(endpoint.host);
    if (endpoint.security != AccountSecurity.implicitTls && !loopbackFixture) {
      throw const SetupException(
        'unsupported_transport',
        'STARTTLS verification is not available in this slice',
      );
    }
    if (TextTokens.containsControlCharacter(endpoint.host) ||
        TextTokens.containsControlCharacter(username)) {
      throw const SetupException(
        'invalid_account',
        'the account contains an unsafe character',
      );
    }
    final client = ImapClient(
      host: endpoint.host,
      port: endpoint.port,
      username: username,
      password: credential.reveal,
      timeout: timeout,
      security: loopbackFixture
          ? ImapTransportSecurity.loopbackPlain
          : ImapTransportSecurity.tls,
    );
    try {
      await client.connect();
    } on ImapException catch (error) {
      throw SetupException(error.code, error.message);
    } finally {
      await client.close();
    }
  }

  bool _isLoopback(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }
}
