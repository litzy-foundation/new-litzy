// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('a password credential never prints its secret', () {
    final credential = AccountCredential.password('a-secret-value');
    expect(credential.reveal, 'a-secret-value');
    expect(credential.toString(), isNot(contains('a-secret-value')));
    expect(credential.kind, AccountAuthentication.password);
  });

  test('an OAuth credential records its authentication method', () {
    final credential = AccountCredential.oauthBearer('a-token-value');
    expect(credential.reveal, 'a-token-value');
    expect(credential.kind, AccountAuthentication.oauthBearer);
    expect('$credential', isNot(contains('a-token-value')));
  });
}
