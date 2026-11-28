// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// HTTPS implementation of the autoconfiguration document port.
///
/// Every redirect is checked before it is followed and the body is bounded
/// while it is read, as required by ADR-0025. A loopback plaintext address is
/// accepted only for local fixtures.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'discovery_exception.dart';
import 'discovery_http_client.dart';

/// Reads autoconfiguration documents with a real HTTP client.
final class HttpDiscoveryClient implements DiscoveryHttpClient {
  /// Creates a client, optionally over an injected transport for tests.
  const HttpDiscoveryClient({
    this.client,
    this.allowLoopbackPlaintextFixtures = false,
  });

  /// Injected HTTP transport, or a fresh client when null.
  final http.Client? client;

  /// Whether plaintext loopback fixtures are allowed.
  final bool allowLoopbackPlaintextFixtures;

  @override
  Future<DiscoveryDocument> get(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
    required int redirectBudget,
  }) async {
    final transport = client ?? http.Client();
    var current = uri;
    try {
      for (var hop = 0; hop <= redirectBudget; hop++) {
        _checkUri(current);
        final request = http.Request('GET', current)
          ..followRedirects = false
          ..maxRedirects = 0;
        final response = await transport.send(request).timeout(timeout);
        if (_isRedirect(response.statusCode)) {
          final location = response.headers['location'];
          if (location == null || location.isEmpty) {
            throw const DiscoveryException(
              'unsafe_redirect',
              'the redirect did not carry a destination',
            );
          }
          final next = current.resolve(location);
          if (next.origin != current.origin) {
            throw const DiscoveryException(
              'unsafe_redirect',
              'the redirect left the original HTTPS origin',
            );
          }
          await response.stream.drain<void>();
          current = next;
          continue;
        }
        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          throw DiscoveryException(
            'discovery_failed',
            'the server answered with status ${response.statusCode}',
          );
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          builder.add(chunk);
          if (builder.length > maxBytes) {
            throw const DiscoveryException(
              'oversized_document',
              'the autoconfiguration document exceeded the policy limit',
            );
          }
        }
        try {
          return (
            finalUri: current,
            body: utf8.decode(builder.takeBytes(), allowMalformed: false),
          );
        } on FormatException {
          throw const DiscoveryException(
            'invalid_document',
            'the autoconfiguration document is not valid UTF-8',
          );
        }
      }
      throw const DiscoveryException(
        'unsafe_redirect',
        'the redirect budget was exhausted',
      );
    } on TimeoutException {
      throw const DiscoveryException(
        'discovery_timeout',
        'the autoconfiguration document did not arrive in time',
      );
    } on http.ClientException {
      throw const DiscoveryException(
        'discovery_failed',
        'the autoconfiguration document could not be fetched',
      );
    } finally {
      if (client == null) transport.close();
    }
  }

  void _checkUri(Uri uri) {
    if (uri.scheme == 'https') return;
    final host = uri.host.toLowerCase();
    final loopback =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    if (loopback && allowLoopbackPlaintextFixtures) return;
    throw const DiscoveryException(
      'insecure_transport',
      'autoconfiguration documents require HTTPS',
    );
  }

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;
}
