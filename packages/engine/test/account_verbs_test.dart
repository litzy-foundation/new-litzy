// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:engine/src/access/access_policy.dart';
import 'package:engine/src/access/account_login_verifier.dart';
import 'package:engine/src/access/discovery_http_client.dart';
import 'package:engine/src/access/discovery_exception.dart';
import 'package:engine/src/access/dns_srv_resolver.dart';
import 'package:engine/src/request_handler.dart';
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
default_list_id: git
loopback_fixture_http_port: 0
''';

const config = '''
<clientConfig version="1.1">
  <emailProvider id="example.com">
    <incomingServer type="imap">
      <hostname>imap.example.com</hostname><port>993</port>
      <socketType>ssl</socketType><authentication>password</authentication>
    </incomingServer>
    <outgoingServer type="smtp">
      <hostname>smtp.example.com</hostname><port>465</port>
      <socketType>ssl</socketType><authentication>password</authentication>
    </outgoingServer>
  </emailProvider>
</clientConfig>
''';

final class StubHttp implements DiscoveryHttpClient {
  @override
  Future<DiscoveryDocument> get(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
    required int redirectBudget,
  }) async => (finalUri: uri, body: config);
}

final class EmptyDns implements DnsSrvResolver {
  @override
  Future<List<SrvRecord>> resolve(String name, {Duration? timeout}) async => [];
}

final class StubVerifier implements AccountLoginVerifier {
  @override
  Future<void> verify({
    required AccountEndpoint endpoint,
    required String username,
    required AccountCredential credential,
  }) async {}
}

void main() {
  test(
    'discovery and connect verbs answer through the typed handler',
    () async {
      final directory = await Directory.systemTemp.createTemp('litzy-account-');
      final handler = EngineRequestHandler(
        accessPolicy: AccessPolicy.fromYaml(policyYaml),
        discoveryHttp: StubHttp(),
        dns: EmptyDns(),
        loginVerifier: StubVerifier(),
      );
      try {
        final opened = await handler.handle(
          OpenProfileRequest('open', '${directory.path}/profile.db'),
        );
        expect(opened, isA<AckResponse>());

        final discovered = await handler.handle(
          const DiscoverAccountRequest('discover', 'user@example.com'),
        );
        expect(discovered, isA<DiscoverAccountResponse>());
        final account = (discovered as DiscoverAccountResponse).account;
        expect(account.verified, isTrue);

        final connected = await handler.handle(
          ConnectAccountRequest(
            'connect',
            emailAddress: 'user@example.com',
            credential: AccountCredential.password('secret-value'),
            imap: account.imap,
            smtp: account.smtp,
            listId: 'git',
          ),
        );
        expect(connected, isA<ConnectAccountResponse>());
        final response = connected as ConnectAccountResponse;
        expect(response.accountId, 'user@example.com');
        expect(response.authentication, AccountAuthentication.password);
        expect('$connected', isNot(contains('secret-value')));

        final listed = await handler.handle(const ListAccountsRequest('list'));
        expect(listed, isA<AccountListResponse>());
        final accounts = (listed as AccountListResponse).accounts;
        expect(accounts, hasLength(1));
        expect(accounts.single.email, 'user@example.com');
        expect(accounts.single.imapHost, 'imap.example.com');
      } finally {
        await handler.handle(const ShutdownRequest('shutdown'));
        directory.deleteSync(recursive: true);
      }
    },
  );

  test('an invalid address produces a typed error', () async {
    final handler = EngineRequestHandler(
      accessPolicy: AccessPolicy.fromYaml(policyYaml),
      discoveryHttp: StubHttp(),
      dns: EmptyDns(),
      loginVerifier: StubVerifier(),
    );
    final response = await handler.handle(
      const DiscoverAccountRequest('bad', 'not-an-address'),
    );
    expect(
      response,
      isA<ErrorResponse>().having(
        (error) => error.code,
        'code',
        'invalid_email',
      ),
    );
    expect(response, isNot(isA<DiscoveryException>()));
  });
}
