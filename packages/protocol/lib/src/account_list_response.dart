// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Returns the non-secret account settings persisted in the open profile.
final class AccountListResponse extends LmlpResponse {
  /// Creates a response with the listed [accounts].
  const AccountListResponse(super.id, this.accounts);

  /// Accounts ordered by their stable identifier.
  final List<AccountView> accounts;
}
