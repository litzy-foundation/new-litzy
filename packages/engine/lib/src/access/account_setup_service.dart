// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Verifies a discovered account and stores its non-secret settings.
///
/// Credentials stay in the front-end keychain; this service only compares an
/// authentication method, performs one login check and writes settings that
/// contain no secret material, as required by ADR-0025.
library;

import 'package:core/core.dart';
import 'package:protocol/protocol.dart';

import '../storage/account_record.dart';
import '../storage/local_database.dart';
import 'access_policy.dart';
import 'account_login_verifier.dart';
import 'setup_exception.dart';

/// Connects one discovered account to the local profile.
final class AccountSetupService {
  /// Creates a setup service over injected storage and verification ports.
  const AccountSetupService({
    required this.database,
    required this.verifier,
    required this.policy,
  });

  /// Local profile that receives non-secret account settings.
  final LocalDatabase database;

  /// Port that performs the login check.
  final AccountLoginVerifier verifier;

  /// Declarative limits applied to the endpoint addresses.
  final AccessPolicy policy;

  /// Verifies [request] and returns the stored account record.
  Future<AccountRecord> connect(ConnectAccountRequest request) async {
    final email = request.emailAddress.trim().toLowerCase();
    if (TextTokens.containsControlCharacter(email) ||
        email.isEmpty ||
        email.split('@').length != 2) {
      throw const SetupException(
        'invalid_account',
        'enter one email address with a single at sign',
      );
    }
    _checkEndpoint(request.imap);
    _checkEndpoint(request.smtp);
    _checkAuthentication(request.imap, request.credential);
    _checkAuthentication(request.smtp, request.credential);
    if (TextTokens.containsControlCharacter(request.listId) ||
        request.listId.trim().isEmpty) {
      throw const SetupException(
        'invalid_account',
        'the list identifier is not valid',
      );
    }

    await verifier.verify(
      endpoint: request.imap,
      username: email,
      credential: request.credential,
    );

    final record = (
      id: email,
      email: email,
      imapHost: request.imap.host,
      imapPort: request.imap.port,
      smtpHost: request.smtp.host,
      smtpPort: request.smtp.port,
      authentication: request.credential.kind.name,
      listId: request.listId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    database.upsertAccount(record);
    return record;
  }

  void _checkEndpoint(AccountEndpoint endpoint) {
    final hostname = RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$');
    final allowed = switch (endpoint.transport) {
      AccountTransport.imap => policy.allowsImapPort(endpoint.port),
      AccountTransport.smtp => policy.allowsSmtpPort(endpoint.port),
    };
    if (TextTokens.containsControlCharacter(endpoint.host) ||
        !hostname.hasMatch(endpoint.host.toLowerCase()) ||
        !allowed) {
      throw const SetupException(
        'untrusted_endpoint',
        'the endpoint is outside the access policy',
      );
    }
  }

  void _checkAuthentication(
    AccountEndpoint endpoint,
    AccountCredential credential,
  ) {
    if (endpoint.authentication == AccountAuthentication.unspecified) return;
    if (endpoint.authentication != credential.kind) {
      throw const SetupException(
        'authentication_mismatch',
        'the credential does not match the endpoint authentication',
      );
    }
  }
}
