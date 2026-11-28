// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';

import 'oauth_provider.dart';
import 'secret_store.dart';

/// Reports a credential that cannot be obtained, stored or read.
final class CredentialException implements Exception {
  /// Creates an exception with a stable [code] and a readable [message].
  const CredentialException(this.code, this.message);

  /// Stable failure code such as `oauth_failed` or `storage_failed`.
  final String code;

  /// Explanation that never contains secret material.
  final String message;

  @override
  String toString() => 'credential error ($code): $message';
}

/// Manages credentials acquired inside the application.
///
/// OAuth tokens and provider passwords pass through this vault on their way
/// to the keychain. R37 forbids a `.env` file, and R35 requires the operating
/// system to hold the secret, so the vault never writes one to a local file
/// or to a log.
final class CredentialVault {
  /// Creates a vault over a keychain port and the supported providers.
  const CredentialVault({required this.store, required this.providers});

  /// Keychain port that holds all secret material.
  final SecretStore store;

  /// Providers whose OAuth flow the application supports.
  final List<OAuthProvider> providers;

  /// Identifiers of the supported providers.
  Iterable<String> get providerIds => providers.map((provider) => provider.id);

  /// Builds the browser URL for [providerId] without storing anything.
  Uri authorizationUri(
    String providerId, {
    required String redirectUri,
    required String state,
  }) =>
      _provider(providerId)
          .authorizationUri(redirectUri: redirectUri, state: state);

  /// Exchanges an OAuth code and stores the resulting token.
  Future<OAuthToken> signInWithOAuth(
    String providerId, {
    required String code,
    required String redirectUri,
  }) async {
    final provider = _provider(providerId);
    final OAuthToken token;
    try {
      token = await provider.redeemCode(code: code, redirectUri: redirectUri);
    } on OAuthException catch (error) {
      throw CredentialException('oauth_failed', error.message);
    }
    try {
      await store.put('oauth.$providerId', _encode(token));
    } on SecretStoreException catch (error) {
      throw CredentialException('storage_failed', error.message);
    }
    return token;
  }

  /// Reads the stored token for [providerId], or null when absent.
  Future<OAuthToken?> oauthToken(String providerId) async {
    final String? value;
    try {
      value = await store.get('oauth.$providerId');
    } on SecretStoreException catch (error) {
      throw CredentialException('storage_failed', error.message);
    }
    if (value == null) return null;
    try {
      return _decode(value);
    } catch (_) {
      throw const CredentialException(
        'corrupt_credential',
        'the stored token is not valid',
      );
    }
  }

  /// Stores a password entered in the secure credential form.
  Future<void> storePassword({
    required Uri server,
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || password.isEmpty || server.host.isEmpty) {
      throw const CredentialException(
        'invalid_account',
        'server, username and password must not be empty',
      );
    }
    try {
      await store.put(_passwordKey(server, username), password);
    } on SecretStoreException catch (error) {
      throw CredentialException('storage_failed', error.message);
    }
  }

  /// Reads the stored password for one account, or null when absent.
  Future<String?> password({
    required Uri server,
    required String username,
  }) async {
    try {
      return await store.get(_passwordKey(server, username));
    } on SecretStoreException catch (error) {
      throw CredentialException('storage_failed', error.message);
    }
  }

  /// Removes the stored token for [providerId].
  Future<void> forgetOAuth(String providerId) => _remove('oauth.$providerId');

  /// Removes the stored password for one account.
  Future<void> forgetPassword({
    required Uri server,
    required String username,
  }) => _remove(_passwordKey(server, username));

  Future<void> _remove(String key) async {
    try {
      await store.remove(key);
    } on SecretStoreException catch (error) {
      throw CredentialException('storage_failed', error.message);
    }
  }

  OAuthProvider _provider(String providerId) {
    for (final provider in providers) {
      if (provider.id == providerId) return provider;
    }
    throw CredentialException(
      'unknown_provider',
      'provider $providerId is not supported',
    );
  }

  static String _passwordKey(Uri server, String username) =>
      'password.${server.host}.$username';

  static String _encode(OAuthToken token) => jsonEncode({
    'access_token': token.accessToken,
    'refresh_token': token.refreshToken,
    'expires_at': token.expiresAt?.millisecondsSinceEpoch,
  });

  static OAuthToken _decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('token is not an object');
    }
    final access = decoded['access_token'];
    if (access is! String || access.isEmpty) {
      throw const FormatException('token has no access token');
    }
    final refresh = decoded['refresh_token'];
    final Object? rawExpiry = decoded['expires_at'];
    if (refresh != null && refresh is! String) {
      throw const FormatException('token has an invalid refresh token');
    }
    if (rawExpiry != null && rawExpiry is! int) {
      throw const FormatException('token has an invalid expiry');
    }
    final expiry = rawExpiry is int ? rawExpiry : null;
    return OAuthToken(
      accessToken: access,
      refreshToken: refresh as String?,
      expiresAt: expiry == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiry, isUtc: true),
    );
  }
}
