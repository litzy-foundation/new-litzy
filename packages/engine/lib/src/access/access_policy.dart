// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Declarative limits for provider-agnostic mail discovery.
///
/// ADR-0025 puts timeouts, byte limits and allowed ports in versioned data so
/// discovery code never carries a provider name or an ad hoc threshold.
library;

import 'package:yaml/yaml.dart';

/// Immutable discovery limits loaded from `data/access/policy.yaml`.
final class AccessPolicy {
  /// Creates a policy from already parsed values.
  const AccessPolicy({
    required this.httpTimeout,
    required this.maxDocumentBytes,
    required this.redirectBudget,
    required this.dnsTimeout,
    required this.allowedImapPorts,
    required this.allowedSmtpPorts,
    required this.allowLoopbackPlaintextFixtures,
  });

  /// Parses a versioned policy document.
  factory AccessPolicy.fromYaml(String source) {
    final document = loadYaml(source);
    if (document is! YamlMap || document['version'] != 1) {
      throw StateError('unsupported access policy version');
    }
    final httpTimeout = _integer(document, 'http_timeout_ms');
    final dnsTimeout = _integer(document, 'dns_timeout_ms');
    final maxBytes = _integer(document, 'max_document_bytes');
    final redirects = _integer(document, 'redirect_budget');
    final loopback = document['allow_loopback_plaintext_fixtures'];
    if (httpTimeout <= 0 ||
        dnsTimeout <= 0 ||
        maxBytes <= 0 ||
        redirects < 0 ||
        loopback is! bool) {
      throw StateError('the access policy contains an invalid limit');
    }
    return AccessPolicy(
      httpTimeout: Duration(milliseconds: httpTimeout),
      maxDocumentBytes: maxBytes,
      redirectBudget: redirects,
      dnsTimeout: Duration(milliseconds: dnsTimeout),
      allowedImapPorts: _ports(document, 'allowed_imap_ports'),
      allowedSmtpPorts: _ports(document, 'allowed_smtp_ports'),
      allowLoopbackPlaintextFixtures: loopback,
    );
  }

  static int _integer(YamlMap document, String key) {
    final value = document[key];
    if (value is! int) throw StateError('the access policy needs $key');
    return value;
  }

  static List<int> _ports(YamlMap document, String key) {
    final value = document[key];
    if (value is! YamlList || value.isEmpty) {
      throw StateError('the access policy needs $key');
    }
    final ports = <int>[];
    for (final entry in value) {
      if (entry is! int || entry <= 0 || entry > 65535) {
        throw StateError('the access policy has an invalid $key entry');
      }
      ports.add(entry);
    }
    return List<int>.unmodifiable(ports);
  }

  /// Deadline applied to autoconfiguration HTTP requests.
  final Duration httpTimeout;

  /// Largest autoconfiguration document accepted from a server.
  final int maxDocumentBytes;

  /// Number of HTTPS redirects followed before failing.
  final int redirectBudget;

  /// Deadline applied to DNS service record queries.
  final Duration dnsTimeout;

  /// Ports accepted for an IMAP endpoint.
  final List<int> allowedImapPorts;

  /// Ports accepted for an SMTP submission endpoint.
  final List<int> allowedSmtpPorts;

  /// Whether plaintext sockets are limited to loopback fixtures.
  final bool allowLoopbackPlaintextFixtures;

  /// Reports whether [port] may be used for IMAP.
  bool allowsImapPort(int port) => allowedImapPorts.contains(port);

  /// Reports whether [port] may be used for SMTP submission.
  bool allowsSmtpPort(int port) => allowedSmtpPorts.contains(port);
}
