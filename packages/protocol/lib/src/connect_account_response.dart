// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Confirms that a login was verified and the settings were stored.
final class ConnectAccountResponse extends LmlpResponse {
  /// Creates a response for the stored account.
  const ConnectAccountResponse(
    super.id,
    this.accountId,
    this.emailAddress,
    this.authentication,
  );

  /// Stable identifier of the stored account.
  final String accountId;

  /// Address of the connected account.
  final String emailAddress;

  /// Authentication method used for the verified login.
  final AccountAuthentication authentication;
}
