// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Non-secret endpoints derived from one email address.
///
/// The value never carries a password or a token. A front-end can show it,
/// persist it in the local profile and pass it back for connection approval.
final class DiscoveredAccount {
  /// Creates a discovery result for [emailAddress].
  const DiscoveredAccount({
    required this.emailAddress,
    required this.imap,
    required this.smtp,
  });

  /// Address supplied by the user.
  final String emailAddress;

  /// Endpoint used to read mail.
  final AccountEndpoint imap;

  /// Endpoint used to submit mail.
  final AccountEndpoint smtp;

  /// Whether both endpoints were confirmed by an authenticated document.
  bool get verified => imap.verified && smtp.verified;
}
