// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Engine-backed implementation of the GUI account port.
///
/// Every operation is one typed request over the in-process bus. The adapter
/// carries no secret material between calls and leaves keychain work to the
/// `CredentialVault` held by the setup controller.
library;

import 'package:protocol/protocol.dart';

import 'account_source.dart';
import 'account_source_exception.dart';

/// Sends account setup verbs to the embedded engine.
final class EngineAccountSource implements AccountSource {
  /// Creates a source over [engine] with fixed request identifier prefixes.
  const EngineAccountSource(this.engine);

  /// Engine that answers the typed requests.
  final LmlpEngine engine;

  @override
  Future<List<AccountView>> accounts() async {
    final response = await engine.send(
      const ListAccountsRequest(_AccountRequestKeys.accounts),
    );
    return switch (response) {
      AccountListResponse(:final accounts) => accounts,
      ErrorResponse(:final code, :final message) =>
        throw AccountSourceException(code, message),
      _ => throw const AccountSourceException(
        _AccountRequestKeys.unexpectedResponse,
        _AccountFailureMessages.accountListFailed,
      ),
    };
  }

  @override
  Future<DiscoveredAccount> discover(String emailAddress) async {
    final response = await engine.send(
      DiscoverAccountRequest(_AccountRequestKeys.discover, emailAddress),
    );
    return switch (response) {
      DiscoverAccountResponse(:final account) => account,
      ErrorResponse(:final code, :final message) =>
        throw AccountSourceException(code, message),
      _ => throw const AccountSourceException(
        _AccountRequestKeys.unexpectedResponse,
        _AccountFailureMessages.discoveryFailed,
      ),
    };
  }

  @override
  Future<void> connect({
    required String emailAddress,
    required AccountCredential credential,
    required AccountEndpoint imap,
    required AccountEndpoint smtp,
  }) async {
    final response = await engine.send(
      ConnectAccountRequest(
        _AccountRequestKeys.connect,
        emailAddress: emailAddress,
        credential: credential,
        imap: imap,
        smtp: smtp,
      ),
    );
    switch (response) {
      case ConnectAccountResponse():
        return;
      case ErrorResponse(:final code, :final message):
        throw AccountSourceException(code, message);
      default:
        throw const AccountSourceException(
          _AccountRequestKeys.unexpectedResponse,
          _AccountFailureMessages.connectFailed,
        );
    }
  }
}

final class _AccountRequestKeys {
  const _AccountRequestKeys._();

  static const String accounts = 'app.list-accounts';
  static const String discover = 'app.discover-account';
  static const String connect = 'app.connect-account';
  static const String unexpectedResponse = 'unexpected_response';
}

final class _AccountFailureMessages {
  const _AccountFailureMessages._();

  static const String accountListFailed = 'the accounts could not be listed';
  static const String discoveryFailed =
      'the mail settings could not be derived';
  static const String connectFailed = 'the account could not be connected';
}
