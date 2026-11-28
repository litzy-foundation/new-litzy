// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:test/test.dart';
import 'package:security/security.dart';

final class FakeKeychain implements SecretStore {
  final Map<String, String> entries = <String, String>{};

  bool failWrites = false;
  bool failReads = false;

  @override
  Future<void> put(String key, String secret) async {
    if (failWrites) throw const SecretStoreException('keychain is locked');
    entries[key] = secret;
  }

  @override
  Future<String?> get(String key) async {
    if (failReads) throw const SecretStoreException('keychain is locked');
    return entries[key];
  }

  @override
  Future<void> remove(String key) async {
    entries.remove(key);
  }
}

final class FakeOAuthProvider implements OAuthProvider {
  @override
  String get id => 'example';

  int redemptions = 0;

  @override
  Uri authorizationUri({required String redirectUri, required String state}) =>
      Uri.https('auth.example.invalid', '/authorize', {
        'redirect_uri': redirectUri,
        'state': state,
      });

  @override
  Future<OAuthToken> redeemCode({
    required String code,
    required String redirectUri,
  }) async {
    redemptions++;
    if (code != 'good-code') throw const OAuthException('code rejected');
    return OAuthToken(
      accessToken: 'fake-access',
      refreshToken: 'fake-refresh',
      expiresAt: DateTime.utc(2026, 11, 28),
    );
  }
}

final class _Harness {
  _Harness() {
    keychain = FakeKeychain();
    provider = FakeOAuthProvider();
    vault = CredentialVault(store: keychain, providers: [provider]);
  }

  late final FakeKeychain keychain;
  late final FakeOAuthProvider provider;
  late final CredentialVault vault;
}

void main() {
  test('the authorization URI carries the redirect and the state', () {
    final harness = _Harness();

    final uri = harness.vault.authorizationUri(
      'example',
      redirectUri: 'litzy://oauth',
      state: 'state-1',
    );

    expect(uri.host, 'auth.example.invalid');
    expect(uri.queryParameters['redirect_uri'], 'litzy://oauth');
    expect(uri.queryParameters['state'], 'state-1');
  });

  test('an OAuth sign-in stores the token in the keychain', () async {
    final harness = _Harness();

    final token = await harness.vault.signInWithOAuth(
      'example',
      code: 'good-code',
      redirectUri: 'litzy://oauth',
    );
    final stored = await harness.vault.oauthToken('example');

    expect(harness.provider.redemptions, 1);
    expect(token.accessToken, 'fake-access');
    expect(stored, token);
    expect(harness.keychain.entries.keys, ['oauth.example']);
  });

  test('a rejected code produces a typed error and no stored secret', () async {
    final harness = _Harness();

    await expectLater(
      harness.vault.signInWithOAuth(
        'example',
        code: 'bad-code',
        redirectUri: 'litzy://oauth',
      ),
      throwsA(
        isA<CredentialException>().having(
          (error) => error.code,
          'code',
          'oauth_failed',
        ),
      ),
    );
    expect(harness.keychain.entries, isEmpty);
  });

  test(
    'a secure credential form stores a password per server and account',
    () async {
      final harness = _Harness();
      final server = Uri.parse('imap://imap.example.invalid');

      await harness.vault.storePassword(
        server: server,
        username: 'alice',
        password: 'fake-password',
      );
      final stored = await harness.vault.password(
        server: server,
        username: 'alice',
      );
      final other = await harness.vault.password(
        server: server,
        username: 'bob',
      );

      expect(stored, 'fake-password');
      expect(other, isNull);
      expect(harness.keychain.entries.keys, [
        'password.imap.example.invalid.alice',
      ]);
    },
  );

  test('forgetting a credential removes it from the keychain', () async {
    final harness = _Harness();
    final server = Uri.parse('smtp://smtp.example.invalid');
    await harness.vault.signInWithOAuth(
      'example',
      code: 'good-code',
      redirectUri: 'litzy://oauth',
    );
    await harness.vault.storePassword(
      server: server,
      username: 'alice',
      password: 'fake-password',
    );

    await harness.vault.forgetOAuth('example');
    await harness.vault.forgetPassword(server: server, username: 'alice');

    expect(await harness.vault.oauthToken('example'), isNull);
    expect(
      await harness.vault.password(server: server, username: 'alice'),
      isNull,
    );
    expect(harness.keychain.entries, isEmpty);
  });

  test('an unknown provider is rejected before any request', () async {
    final harness = _Harness();

    await expectLater(
      harness.vault.signInWithOAuth(
        'missing',
        code: 'good-code',
        redirectUri: 'litzy://oauth',
      ),
      throwsA(
        isA<CredentialException>().having(
          (error) => error.code,
          'code',
          'unknown_provider',
        ),
      ),
    );
    expect(harness.provider.redemptions, 0);
  });

  test('a corrupt stored token is reported explicitly', () async {
    final harness = _Harness();
    await harness.keychain.put('oauth.example', 'not a token');

    await expectLater(
      harness.vault.oauthToken('example'),
      throwsA(
        isA<CredentialException>().having(
          (error) => error.code,
          'code',
          'corrupt_credential',
        ),
      ),
    );
  });

  test('a keychain write failure becomes a deterministic error', () async {
    final harness = _Harness();
    harness.keychain.failWrites = true;

    await expectLater(
      harness.vault.storePassword(
        server: Uri.parse('imap://imap.example.invalid'),
        username: 'alice',
        password: 'fake-password',
      ),
      throwsA(
        isA<CredentialException>().having(
          (error) => error.code,
          'code',
          'storage_failed',
        ),
      ),
    );
    expect(harness.keychain.entries, isEmpty);
  });

  test('a keychain read failure becomes a deterministic error', () async {
    final harness = _Harness();
    harness.keychain.failReads = true;

    await expectLater(
      harness.vault.password(
        server: Uri.parse('imap://imap.example.invalid'),
        username: 'alice',
      ),
      throwsA(
        isA<CredentialException>().having(
          (error) => error.code,
          'code',
          'storage_failed',
        ),
      ),
    );
  });
}
