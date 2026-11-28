// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Returns the non-secret endpoints derived from an email address.
final class DiscoverAccountResponse extends LmlpResponse {
  /// Creates a response carrying [account].
  const DiscoverAccountResponse(super.id, this.account);

  /// Endpoints derived from the address.
  final DiscoveredAccount account;
}
