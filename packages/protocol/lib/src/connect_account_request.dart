// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Asks the engine to verify a login and store non-secret account settings.
///
/// The credential travels only on the in-process bus in memory. It is redacted
/// by its own string conversion, and the engine never writes it to SQLite.
final class ConnectAccountRequest extends LmlpRequest {
  /// Creates a connection request for one discovered account.
  const ConnectAccountRequest(
    super.id, {
    required this.emailAddress,
    required this.credential,
    required this.imap,
    required this.smtp,
    this.listId,
  });

  /// Address typed by the user.
  final String emailAddress;

  /// Secret supplied by the secure form or by the OAuth flow.
  final AccountCredential credential;

  /// Endpoint approved for reading mail.
  final AccountEndpoint imap;

  /// Endpoint approved for submission.
  final AccountEndpoint smtp;

  /// Optional list identifier; the engine uses its declarative default.
  final String? listId;
}
