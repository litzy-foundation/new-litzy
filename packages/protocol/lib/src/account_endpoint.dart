// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Mail protocol represented by one discovered endpoint.
enum AccountTransport {
  /// Internet Message Access Protocol.
  imap,

  /// Simple Mail Transfer Protocol submission.
  smtp,
}

/// Transport protection offered by one discovered endpoint.
enum AccountSecurity {
  /// TLS from the first byte on a dedicated port.
  implicitTls,

  /// A plaintext connection that must issue STARTTLS before authentication.
  startTls,
}

/// Authentication method advertised by a discovered endpoint.
enum AccountAuthentication {
  /// A password collected in the secure credential form.
  password,

  /// An OAuth bearer token obtained by the application.
  oauthBearer,

  /// A method that the configuration did not declare.
  unspecified,
}

/// Evidence that produced one discovered endpoint.
enum AccountEndpointSource {
  /// The well-known autoconfiguration document at the provider domain.
  autoconfigWellKnown,

  /// The autoconfiguration document at the `autoconfig` subdomain.
  autoconfigSubdomain,

  /// DNS service records for the provider domain.
  serviceRecord,

  /// The Microsoft Autodiscover document at the provider domain.
  autodiscover,

  /// A conventional host derived from the email domain without evidence.
  derived,
}

/// One non-secret mail endpoint derived from an email address.
///
/// An endpoint is immutable so it can cross the in-process bus and be stored
/// in SQLite without a caller changing it afterwards. Trust is carried as a
/// value because the interface distinguishes a verified document from a guess.
final class AccountEndpoint {
  /// Creates an endpoint with its transport and trust details.
  const AccountEndpoint({
    required this.host,
    required this.port,
    required this.transport,
    required this.security,
    required this.authentication,
    required this.source,
    required this.verified,
  });

  /// Host name of the mail server.
  final String host;

  /// Port on which the mail server listens.
  final int port;

  /// Protocol spoken by the endpoint.
  final AccountTransport transport;

  /// Transport protection required by the endpoint.
  final AccountSecurity security;

  /// Authentication method advertised for the endpoint.
  final AccountAuthentication authentication;

  /// Evidence that produced the endpoint.
  final AccountEndpointSource source;

  /// Whether an authenticated document confirmed this endpoint.
  final bool verified;
}
