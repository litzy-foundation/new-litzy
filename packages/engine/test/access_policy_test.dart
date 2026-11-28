// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:engine/src/access/access_policy.dart';
import 'package:test/test.dart';

const validPolicy = '''
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

void main() {
  test('a valid policy exposes its limits', () {
    final policy = AccessPolicy.fromYaml(validPolicy);
    expect(policy.httpTimeout, const Duration(milliseconds: 5000));
    expect(policy.maxDocumentBytes, 262144);
    expect(policy.redirectBudget, 2);
    expect(policy.dnsTimeout, const Duration(milliseconds: 3000));
    expect(policy.allowsImapPort(993), isTrue);
    expect(policy.allowsSmtpPort(25), isFalse);
    expect(policy.allowLoopbackPlaintextFixtures, isTrue);
    expect(policy.defaultListId, 'git');
    expect(policy.loopbackFixtureHttpPort, 0);
  });

  test('a policy with an unsupported version is rejected', () {
    expect(
      () => AccessPolicy.fromYaml(
        validPolicy.replaceFirst('version: 1', 'version: 2'),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('a policy with an unsafe redirect budget is rejected', () {
    expect(
      () => AccessPolicy.fromYaml(
        validPolicy.replaceFirst('redirect_budget: 2', 'redirect_budget: -1'),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
