// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Secret material passed through the in-process bus for one login check.
///
/// The value overrides string conversion so a logger, an error report or a
/// debug view cannot print the secret. The front-end remains responsible for
/// storing it in the operating system keychain through `CredentialVault`.
final class AccountCredential {
  AccountCredential._(this._secret, this.kind);

  /// Creates a password credential from a secure form.
  factory AccountCredential.password(String value) =>
      AccountCredential._(value, AccountAuthentication.password);

  /// Creates an OAuth bearer credential obtained by the application.
  factory AccountCredential.oauthBearer(String value) =>
      AccountCredential._(value, AccountAuthentication.oauthBearer);

  final String _secret;

  /// Authentication method that the secret belongs to.
  final AccountAuthentication kind;

  /// Secret bytes for the transport that verifies the login.
  ///
  /// Callers must not include this value in a message, a file or a log.
  String get reveal => _secret;

  @override
  String toString() => 'AccountCredential(<redacted>)';
}
