// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Reports a rejected OAuth exchange.
final class OAuthException implements Exception {
  /// Creates an exception with a readable [message].
  const OAuthException(this.message);

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => 'OAuth exchange failed: $message';
}

/// Secret material returned by an OAuth provider.
///
/// The value stays in memory only until the credential vault writes it to
/// the operating system keychain. It is never logged or versioned.
final class OAuthToken {
  /// Creates a token with optional refresh material and expiry.
  const OAuthToken({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  /// Token used for authenticated requests.
  final String accessToken;

  /// Token used to renew access, when the provider issues one.
  final String? refreshToken;

  /// Expiry reported by the provider, or null when unknown.
  final DateTime? expiresAt;

  @override
  bool operator ==(Object other) =>
      other is OAuthToken &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, expiresAt);
}

/// Platform port for the authorization code flow of one provider.
///
/// A provider implementation opens the system browser for [authorizationUri]
/// and exchanges the returned code in [redeemCode]. Both methods stay inside
/// the application so no credential reaches a versioned file or a log.
abstract interface class OAuthProvider {
  /// Stable identifier of the provider.
  String get id;

  /// Builds the browser URL that starts the flow.
  Uri authorizationUri({required String redirectUri, required String state});

  /// Exchanges an authorization [code] for a token.
  Future<OAuthToken> redeemCode({
    required String code,
    required String redirectUri,
  });
}
