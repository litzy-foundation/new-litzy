// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Provider-agnostic derivation of mail endpoints from an email address.
///
/// ADR-0025 fixes the order of trust and treats every remote document as
/// hostile. The algorithm holds no provider name and no secret.
library;

import 'package:core/core.dart';
import 'package:protocol/protocol.dart';
import 'package:xml/xml.dart';

import 'access_policy.dart';
import 'discovery_exception.dart';
import 'discovery_http_client.dart';
import 'dns_srv_resolver.dart';

/// Derives non-secret IMAP and SMTP endpoints from an email address.
final class AccountDiscoveryService {
  /// Creates a discovery service over declarative limits and injected ports.
  const AccountDiscoveryService({
    required this.policy,
    required this.http,
    required this.dns,
  });

  /// Declarative limits applied to every remote source.
  final AccessPolicy policy;

  /// Port that reads HTTPS autoconfiguration documents.
  final DiscoveryHttpClient http;

  /// Port that reads DNS service records.
  final DnsSrvResolver dns;

  /// Derives endpoints for [emailAddress] in the fixed order of trust.
  Future<DiscoveredAccount> discover(String emailAddress) async {
    final (:localPart, :domain) = _emailParts(emailAddress);
    final address = '$localPart@$domain';

    for (final source in const [
      AccountEndpointSource.autoconfigWellKnown,
      AccountEndpointSource.autoconfigSubdomain,
    ]) {
      final host = source == AccountEndpointSource.autoconfigWellKnown
          ? domain
          : 'autoconfig.$domain';
      final path = source == AccountEndpointSource.autoconfigWellKnown
          ? '/.well-known/autoconfig/mail/config-v1.1.xml'
          : '/mail/config-v1.1.xml';
      final uri = Uri.https(host, path, {'emailaddress': address});
      try {
        final document = await _read(uri, host);
        return _parseAutoconfig(document.body, address, source);
      } on DiscoveryException catch (error) {
        if (_aborts(error)) rethrow;
      }
    }

    try {
      return await _discoverFromSrv(domain, address);
    } on DiscoveryException catch (error) {
      if (_aborts(error)) rethrow;
    }

    final autodiscoverHost = 'autodiscover.$domain';
    final autodiscoverUri = Uri.https(
      autodiscoverHost,
      '/autodiscover/autodiscover.xml',
      {'Email': address},
    );
    try {
      final document = await _read(autodiscoverUri, autodiscoverHost);
      return _parseAutodiscover(document.body, address);
    } on DiscoveryException catch (error) {
      if (_aborts(error)) rethrow;
    }

    return _derived(domain, address);
  }

  Future<DiscoveryDocument> _read(Uri uri, String expectedHost) async {
    final document = await http.get(
      uri,
      timeout: policy.httpTimeout,
      maxBytes: policy.maxDocumentBytes,
      redirectBudget: policy.redirectBudget,
    );
    if (document.body.length > policy.maxDocumentBytes) {
      throw const DiscoveryException(
        'oversized_document',
        'the autoconfiguration document exceeded the policy limit',
      );
    }
    final finalUri = document.finalUri;
    if (finalUri.scheme != 'https') {
      throw const DiscoveryException(
        'insecure_transport',
        'the document was served over a plaintext transport',
      );
    }
    if (finalUri.host.toLowerCase() != expectedHost) {
      throw const DiscoveryException(
        'unsafe_redirect',
        'the document did not come from the expected HTTPS origin',
      );
    }
    return document;
  }

  ({String localPart, String domain}) _emailParts(String input) {
    final email = input.trim();
    final at = email.indexOf('@');
    if (at <= 0 || at != email.lastIndexOf('@') || at == email.length - 1) {
      throw const DiscoveryException(
        'invalid_email',
        'enter one email address with a single at sign',
      );
    }
    if (TextTokens.containsControlCharacter(email) || email.contains(' ')) {
      throw const DiscoveryException(
        'invalid_email',
        'the email address contains an unsafe character',
      );
    }
    final domain = email.substring(at + 1).toLowerCase();
    final localPart = email.substring(0, at);
    final labels = domain.split('.');
    final hostname = RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$');
    if (labels.length < 2 || !hostname.hasMatch(domain)) {
      throw const DiscoveryException(
        'invalid_email',
        'the email address has no valid domain',
      );
    }
    return (localPart: localPart, domain: domain);
  }

  DiscoveredAccount _parseAutoconfig(
    String body,
    String address,
    AccountEndpointSource source,
  ) {
    final document = _secureXml(body);
    AccountEndpoint? imap;
    AccountEndpoint? smtp;
    for (final element in document.findAllElements('incomingServer')) {
      if (element.getAttribute('type')?.toLowerCase() != 'imap') continue;
      imap ??= _endpoint(
        host: _childText(element, 'hostname'),
        port: _childPort(element, 'port'),
        transport: AccountTransport.imap,
        socketType: _childText(element, 'socketType'),
        authentication: _childText(element, 'authentication'),
        source: source,
        verified: true,
      );
    }
    for (final element in document.findAllElements('outgoingServer')) {
      if (element.getAttribute('type')?.toLowerCase() != 'smtp') continue;
      smtp ??= _endpoint(
        host: _childText(element, 'hostname'),
        port: _childPort(element, 'port'),
        transport: AccountTransport.smtp,
        socketType: _childText(element, 'socketType'),
        authentication: _childText(element, 'authentication'),
        source: source,
        verified: true,
      );
    }
    if (imap == null || smtp == null) {
      throw const DiscoveryException(
        'discovery_incomplete',
        'the document did not declare both mail protocols',
      );
    }
    return DiscoveredAccount(emailAddress: address, imap: imap, smtp: smtp);
  }

  DiscoveredAccount _parseAutodiscover(String body, String address) {
    final document = _secureXml(body);
    AccountEndpoint? imap;
    AccountEndpoint? smtp;
    for (final element in document.findAllElements('Protocol')) {
      final type = _childText(element, 'Type').toLowerCase();
      if (type != 'imap' && type != 'smtp') continue;
      final endpoint = _endpoint(
        host: _childText(element, 'Server'),
        port: _childPort(element, 'Port'),
        transport: type == 'imap'
            ? AccountTransport.imap
            : AccountTransport.smtp,
        socketType: 'ssl',
        authentication: _childText(element, 'Authentication'),
        source: AccountEndpointSource.autodiscover,
        verified: true,
      );
      if (type == 'imap') {
        imap ??= endpoint;
      } else {
        smtp ??= endpoint;
      }
    }
    if (imap == null || smtp == null) {
      throw const DiscoveryException(
        'discovery_incomplete',
        'the document did not declare both mail protocols',
      );
    }
    return DiscoveredAccount(emailAddress: address, imap: imap, smtp: smtp);
  }

  Future<DiscoveredAccount> _discoverFromSrv(
    String domain,
    String address,
  ) async {
    final imapRecords = await dns.resolve(
      '_imaps._tcp.$domain',
      timeout: policy.dnsTimeout,
    );
    final smtpRecords = await dns.resolve(
      '_submission._tcp.$domain',
      timeout: policy.dnsTimeout,
    );
    if (imapRecords.isEmpty || smtpRecords.isEmpty) {
      throw const DiscoveryException(
        'discovery_incomplete',
        'the DNS records did not declare both mail protocols',
      );
    }
    imapRecords.sort((a, b) => a.priority.compareTo(b.priority));
    smtpRecords.sort((a, b) => a.priority.compareTo(b.priority));
    final imap = _endpoint(
      host: imapRecords.first.target,
      port: imapRecords.first.port,
      transport: AccountTransport.imap,
      socketType: 'ssl',
      authentication: 'unspecified',
      source: AccountEndpointSource.serviceRecord,
      verified: false,
    );
    final smtp = _endpoint(
      host: smtpRecords.first.target,
      port: smtpRecords.first.port,
      transport: AccountTransport.smtp,
      socketType: 'ssl',
      authentication: 'unspecified',
      source: AccountEndpointSource.serviceRecord,
      verified: false,
    );
    return DiscoveredAccount(emailAddress: address, imap: imap, smtp: smtp);
  }

  DiscoveredAccount _derived(String domain, String address) =>
      DiscoveredAccount(
        emailAddress: address,
        imap: _endpoint(
          host: 'imap.$domain',
          port: 993,
          transport: AccountTransport.imap,
          socketType: 'ssl',
          authentication: 'unspecified',
          source: AccountEndpointSource.derived,
          verified: false,
        ),
        smtp: _endpoint(
          host: 'smtp.$domain',
          port: 465,
          transport: AccountTransport.smtp,
          socketType: 'ssl',
          authentication: 'unspecified',
          source: AccountEndpointSource.derived,
          verified: false,
        ),
      );

  AccountEndpoint _endpoint({
    required String host,
    required int port,
    required AccountTransport transport,
    required String socketType,
    required String authentication,
    required AccountEndpointSource source,
    required bool verified,
  }) {
    final normalizedHost = host.trim().toLowerCase();
    if (normalizedHost.endsWith('.')) {
      return _endpoint(
        host: normalizedHost.substring(0, normalizedHost.length - 1),
        port: port,
        transport: transport,
        socketType: socketType,
        authentication: authentication,
        source: source,
        verified: verified,
      );
    }
    final hostname = RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$');
    final allowed = switch (transport) {
      AccountTransport.imap => policy.allowsImapPort(port),
      AccountTransport.smtp => policy.allowsSmtpPort(port),
    };
    if (!hostname.hasMatch(normalizedHost) || !allowed) {
      throw const DiscoveryException(
        'untrusted_endpoint',
        'the document named an endpoint outside the access policy',
      );
    }
    final security = switch (socketType.toLowerCase()) {
      'ssl' || 'tls' || 'implicit' => AccountSecurity.implicitTls,
      'starttls' => AccountSecurity.startTls,
      _ => throw const DiscoveryException(
        'insecure_transport',
        'the endpoint does not require TLS',
      ),
    };
    final auth = switch (authentication.toLowerCase()) {
      'oauth2' ||
      'oauthbearer' ||
      'bearer' => AccountAuthentication.oauthBearer,
      '' ||
      'password' ||
      'password-cleartext' ||
      'plain' => AccountAuthentication.password,
      _ => AccountAuthentication.unspecified,
    };
    return AccountEndpoint(
      host: normalizedHost,
      port: port,
      transport: transport,
      security: security,
      authentication: auth,
      source: source,
      verified: verified,
    );
  }

  XmlDocument _secureXml(String body) {
    if (body.toLowerCase().contains('<!doctype')) {
      throw const DiscoveryException(
        'unsafe_xml',
        'document type declarations are not accepted',
      );
    }
    try {
      final document = XmlDocument.parse(
        body,
        entityMapping: const XmlNullEntityMapping(),
      );
      if (document.children.any((node) => node is XmlDoctype)) {
        throw const DiscoveryException(
          'unsafe_xml',
          'document type declarations are not accepted',
        );
      }
      return document;
    } on XmlException {
      throw const DiscoveryException(
        'invalid_document',
        'the autoconfiguration document is not valid XML',
      );
    }
  }

  String _childText(XmlElement element, String name) =>
      element.findElements(name).firstOrNull?.innerText.trim() ?? '';

  int _childPort(XmlElement element, String name) =>
      int.tryParse(_childText(element, name)) ?? 0;

  bool _aborts(DiscoveryException error) => switch (error.code) {
    'insecure_transport' ||
    'untrusted_endpoint' ||
    'unsafe_redirect' ||
    'unsafe_xml' ||
    'oversized_document' => true,
    _ => false,
  };
}
