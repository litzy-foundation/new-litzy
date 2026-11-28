// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:core/core.dart';
import 'package:engine/src/access/access_policy.dart';
import 'package:engine/src/access/account_discovery_service.dart';
import 'package:engine/src/access/discovery_exception.dart';
import 'package:engine/src/access/discovery_http_client.dart';
import 'package:engine/src/access/dns_srv_resolver.dart';
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

String autoconfig({
  String imapHost = 'imap.example.com',
  int imapPort = 993,
  String socketType = 'ssl',
  String smtpHost = 'smtp.example.com',
  int smtpPort = 465,
}) =>
    '''
<?xml version="1.0"?>
<clientConfig version="1.1">
  <emailProvider id="example.com">
    <incomingServer type="imap">
      <hostname>$imapHost</hostname>
      <port>$imapPort</port>
      <socketType>$socketType</socketType>
      <authentication>password-cleartext</authentication>
    </incomingServer>
    <outgoingServer type="smtp">
      <hostname>$smtpHost</hostname>
      <port>$smtpPort</port>
      <socketType>ssl</socketType>
      <authentication>oauth2</authentication>
    </outgoingServer>
  </emailProvider>
</clientConfig>
''';

final class FakeDiscoveryHttpClient implements DiscoveryHttpClient {
  final Map<String, DiscoveryDocument> documents = {};
  final Map<String, Uri> finalUris = {};

  @override
  Future<DiscoveryDocument> get(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
    required int redirectBudget,
  }) async {
    final document = documents[uri.host];
    if (document == null) {
      throw const DiscoveryException(
        'discovery_failed',
        'no document for this host',
      );
    }
    final override = finalUris[uri.host];
    return override == null
        ? document
        : (finalUri: override, body: document.body);
  }
}

final class FakeDnsSrvResolver implements DnsSrvResolver {
  final Map<String, List<SrvRecord>> records = {};

  @override
  Future<List<SrvRecord>> resolve(String name, {Duration? timeout}) async =>
      records[name] ?? [];
}

void main() {
  late AccessPolicy policy;
  late FakeDiscoveryHttpClient http;
  late FakeDnsSrvResolver dns;
  late AccountDiscoveryService service;

  setUp(() {
    policy = AccessPolicy.fromYaml(policyYaml);
    http = FakeDiscoveryHttpClient();
    dns = FakeDnsSrvResolver();
    service = AccountDiscoveryService(policy: policy, http: http, dns: dns);
  });

  test('a well-known autoconfig document yields verified endpoints', () async {
    http.documents['example.com'] = (
      finalUri: Uri.parse('https://example.com/config.xml'),
      body: autoconfig(),
    );
    final account = await service.discover('user@example.com');
    expect(account.emailAddress, 'user@example.com');
    expect(account.verified, isTrue);
    expect(account.imap.host, 'imap.example.com');
    expect(account.imap.port, 993);
    expect(account.imap.security, AccountSecurity.implicitTls);
    expect(account.imap.authentication, AccountAuthentication.password);
    expect(account.smtp.authentication, AccountAuthentication.oauthBearer);
    expect(account.imap.source, AccountEndpointSource.autoconfigWellKnown);
  });

  test(
    'the autoconfig subdomain is read when the first document is incomplete',
    () async {
      http.documents['example.com'] = (
        finalUri: Uri.https('example.com', '/config.xml'),
        body: '<clientConfig><emailProvider id="x"/></clientConfig>',
      );
      http.documents['autoconfig.example.com'] = (
        finalUri: Uri.https('autoconfig.example.com', '/config.xml'),
        body: autoconfig(),
      );
      final account = await service.discover('user@example.com');
      expect(account.imap.source, AccountEndpointSource.autoconfigSubdomain);
      expect(account.verified, isTrue);
    },
  );

  test('DNS service records provide unverified endpoints', () async {
    dns.records['_imaps._tcp.example.com'] = [
      (priority: 10, weight: 1, port: 993, target: 'mail.example.com.'),
    ];
    dns.records['_submission._tcp.example.com'] = [
      (priority: 10, weight: 1, port: 587, target: 'mail.example.com.'),
    ];
    final account = await service.discover('user@example.com');
    expect(account.verified, isFalse);
    expect(account.imap.host, 'mail.example.com');
    expect(account.imap.source, AccountEndpointSource.serviceRecord);
    expect(account.smtp.port, 587);
    expect(account.imap.authentication, AccountAuthentication.unspecified);
  });

  test('a conventional fallback is reported as unverified', () async {
    final account = await service.discover('user@example.com');
    expect(account.verified, isFalse);
    expect(account.imap.source, AccountEndpointSource.derived);
    expect(account.imap.host, 'imap.example.com');
    expect(account.smtp.host, 'smtp.example.com');
    expect(account.smtp.authentication, AccountAuthentication.unspecified);
  });

  test('a plaintext socket type fails closed', () async {
    http.documents['example.com'] = (
      finalUri: Uri.https('example.com', '/config.xml'),
      body: autoconfig(socketType: 'plain'),
    );
    await expectLater(
      service.discover('user@example.com'),
      throwsA(
        isA<DiscoveryException>().having(
          (error) => error.code,
          'code',
          'insecure_transport',
        ),
      ),
    );
  });

  test('a plaintext redirect fails closed', () async {
    http.documents['example.com'] = (
      finalUri: Uri.https('example.com', '/config.xml'),
      body: autoconfig(),
    );
    http.finalUris['example.com'] = Uri.parse('http://example.com/config.xml');
    await expectLater(
      service.discover('user@example.com'),
      throwsA(
        isA<DiscoveryException>().having(
          (error) => error.code,
          'code',
          'insecure_transport',
        ),
      ),
    );
  });

  test('a cross-origin redirect fails closed', () async {
    http.documents['example.com'] = (
      finalUri: Uri.https('example.com', '/config.xml'),
      body: autoconfig(),
    );
    http.finalUris['example.com'] = Uri.https(
      'attacker.invalid',
      '/config.xml',
    );
    await expectLater(
      service.discover('user@example.com'),
      throwsA(
        isA<DiscoveryException>().having(
          (error) => error.code,
          'code',
          'unsafe_redirect',
        ),
      ),
    );
  });

  test('an oversized document fails closed', () async {
    http.documents['example.com'] = (
      finalUri: Uri.https('example.com', '/config.xml'),
      body: autoconfig() + 'x' * policy.maxDocumentBytes,
    );
    await expectLater(
      service.discover('user@example.com'),
      throwsA(
        isA<DiscoveryException>().having(
          (error) => error.code,
          'code',
          'oversized_document',
        ),
      ),
    );
  });

  test('a document type declaration fails closed', () async {
    http.documents['example.com'] = (
      finalUri: Uri.https('example.com', '/config.xml'),
      body:
          '<!DOCTYPE clientConfig [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>'
          '${autoconfig()}',
    );
    await expectLater(
      service.discover('user@example.com'),
      throwsA(
        isA<DiscoveryException>().having(
          (error) => error.code,
          'code',
          'unsafe_xml',
        ),
      ),
    );
  });

  test('a control character in the address fails closed', () async {
    await expectLater(
      service.discover('user${TextTokens.lineFeed}@example.com'),
      throwsA(
        isA<DiscoveryException>().having(
          (error) => error.code,
          'code',
          'invalid_email',
        ),
      ),
    );
  });

  test('a port outside the policy fails closed', () async {
    http.documents['example.com'] = (
      finalUri: Uri.https('example.com', '/config.xml'),
      body: autoconfig(imapPort: 25),
    );
    await expectLater(
      service.discover('user@example.com'),
      throwsA(
        isA<DiscoveryException>().having(
          (error) => error.code,
          'code',
          'untrusted_endpoint',
        ),
      ),
    );
  });
}
