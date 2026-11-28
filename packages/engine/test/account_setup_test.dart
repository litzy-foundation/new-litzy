// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:core/core.dart';
import 'package:engine/src/access/access_policy.dart';
import 'package:engine/src/access/account_login_verifier.dart';
import 'package:engine/src/access/account_setup_service.dart';
import 'package:engine/src/access/setup_exception.dart';
import 'package:engine/src/storage/local_database.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

const policyYaml = '''
version: 1
http_timeout_ms: 5000
max_document_bytes: 262144
redirect_budget: 2
dns_timeout_ms: 3000
allowed_imap_ports: [143, 993]
allowed_smtp_ports: [465, 587]
allow_loopback_plaintext_fixtures: true
''';

final class FakeLoginVerifier implements AccountLoginVerifier {
  String? failureCode;
  String? username;
  AccountCredential? credential;

  @override
  Future<void> verify({
    required AccountEndpoint endpoint,
    required String username,
    required AccountCredential credential,
  }) async {
    if (failureCode != null) {
      throw SetupException(failureCode!, 'the login was rejected');
    }
    this.username = username;
    this.credential = credential;
  }
}

void main() {
  late LocalDatabase database;
  late FakeLoginVerifier verifier;
  late AccountSetupService service;
  late AccountEndpoint imap;
  late AccountEndpoint smtp;

  setUp(() {
    database = LocalDatabase.inMemory();
    verifier = FakeLoginVerifier();
    service = AccountSetupService(
      database: database,
      verifier: verifier,
      policy: AccessPolicy.fromYaml(policyYaml),
    );
    imap = const AccountEndpoint(
      host: 'imap.example.com',
      port: 993,
      transport: AccountTransport.imap,
      security: AccountSecurity.implicitTls,
      authentication: AccountAuthentication.password,
      source: AccountEndpointSource.autoconfigWellKnown,
      verified: true,
    );
    smtp = const AccountEndpoint(
      host: 'smtp.example.com',
      port: 465,
      transport: AccountTransport.smtp,
      security: AccountSecurity.implicitTls,
      authentication: AccountAuthentication.password,
      source: AccountEndpointSource.autoconfigWellKnown,
      verified: true,
    );
  });

  test('a verified login stores only non-secret settings', () async {
    final request = ConnectAccountRequest(
      'connect-1',
      emailAddress: 'user@example.com',
      credential: AccountCredential.password('secret-value'),
      imap: imap,
      smtp: smtp,
      listId: 'git',
    );
    final record = await service.connect(request);
    expect(record.id, 'user@example.com');
    expect(record.imapHost, 'imap.example.com');
    expect(record.smtpPort, 465);
    expect(record.listId, 'git');
    expect(verifier.username, 'user@example.com');
    expect(verifier.credential?.reveal, 'secret-value');
    final stored = database.accountOf('user@example.com');
    expect(stored, isNotNull);
    expect(stored?.email, 'user@example.com');
  });

  test('a rejected login stores nothing', () async {
    verifier.failureCode = 'authentication_failed';
    final request = ConnectAccountRequest(
      'connect-2',
      emailAddress: 'user@example.com',
      credential: AccountCredential.password('wrong-value'),
      imap: imap,
      smtp: smtp,
      listId: 'git',
    );
    await expectLater(
      service.connect(request),
      throwsA(
        isA<SetupException>().having(
          (error) => error.code,
          'code',
          'authentication_failed',
        ),
      ),
    );
    expect(database.accountOf('user@example.com'), isNull);
  });

  test('an unspecified method accepts an OAuth credential', () async {
    const unverifiedImap = AccountEndpoint(
      host: 'imap.example.com',
      port: 993,
      transport: AccountTransport.imap,
      security: AccountSecurity.implicitTls,
      authentication: AccountAuthentication.unspecified,
      source: AccountEndpointSource.serviceRecord,
      verified: false,
    );
    const unverifiedSmtp = AccountEndpoint(
      host: 'smtp.example.com',
      port: 465,
      transport: AccountTransport.smtp,
      security: AccountSecurity.implicitTls,
      authentication: AccountAuthentication.unspecified,
      source: AccountEndpointSource.serviceRecord,
      verified: false,
    );
    final request = ConnectAccountRequest(
      'connect-oauth',
      emailAddress: 'user@example.com',
      credential: AccountCredential.oauthBearer('a-token-value'),
      imap: unverifiedImap,
      smtp: unverifiedSmtp,
      listId: 'git',
    );
    final record = await service.connect(request);
    expect(record.authentication, 'oauthBearer');
    expect(verifier.credential?.kind, AccountAuthentication.oauthBearer);
  });

  test('a control character in the endpoint host fails closed', () async {
    final hostile = AccountEndpoint(
      host: 'imap${TextTokens.lineFeed}.example.com',
      port: 993,
      transport: AccountTransport.imap,
      security: AccountSecurity.implicitTls,
      authentication: AccountAuthentication.password,
      source: AccountEndpointSource.derived,
      verified: false,
    );
    final request = ConnectAccountRequest(
      'connect-3',
      emailAddress: 'user@example.com',
      credential: AccountCredential.password('secret-value'),
      imap: hostile,
      smtp: smtp,
      listId: 'git',
    );
    await expectLater(
      service.connect(request),
      throwsA(
        isA<SetupException>().having(
          (error) => error.code,
          'code',
          'untrusted_endpoint',
        ),
      ),
    );
  });

  test(
    'a credential that does not match the advertised method fails closed',
    () async {
      const bearerSmtp = AccountEndpoint(
        host: 'smtp.example.com',
        port: 465,
        transport: AccountTransport.smtp,
        security: AccountSecurity.implicitTls,
        authentication: AccountAuthentication.oauthBearer,
        source: AccountEndpointSource.autoconfigWellKnown,
        verified: true,
      );
      final request = ConnectAccountRequest(
        'connect-4',
        emailAddress: 'user@example.com',
        credential: AccountCredential.password('secret-value'),
        imap: imap,
        smtp: bearerSmtp,
        listId: 'git',
      );
      await expectLater(
        service.connect(request),
        throwsA(
          isA<SetupException>().having(
            (error) => error.code,
            'code',
            'authentication_mismatch',
          ),
        ),
      );
    },
  );
}
