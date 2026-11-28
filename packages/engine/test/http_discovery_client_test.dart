// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';

import 'package:engine/src/access/discovery_exception.dart';
import 'package:engine/src/access/http_discovery_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

final class ScriptedTransport extends http.BaseClient {
  ScriptedTransport(this.responses);

  final List<http.StreamedResponse> responses;
  final List<Uri> requested = [];
  int _index = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requested.add(request.url);
    return responses[_index++];
  }
}

http.StreamedResponse response(
  int status, {
  String location = '',
  List<int> body = const [],
}) => http.StreamedResponse(
  Stream.value(body),
  status,
  headers: location.isEmpty ? {} : {'location': location},
);

void main() {
  const timeout = Duration(seconds: 1);
  final uri = Uri.parse('https://example.com/config.xml');

  test('a same-origin HTTPS redirect is followed', () async {
    final transport = ScriptedTransport([
      response(302, location: 'https://example.com/other.xml'),
      response(200, body: utf8.encode('<ok/>')),
    ]);
    final client = HttpDiscoveryClient(client: transport);
    final document = await client.get(
      uri,
      timeout: timeout,
      maxBytes: 1024,
      redirectBudget: 2,
    );
    expect(document.finalUri.path, '/other.xml');
    expect(document.body, '<ok/>');
    expect(transport.requested.length, 2);
  });

  test('a cross-origin redirect is rejected', () async {
    final transport = ScriptedTransport([
      response(302, location: 'https://attacker.invalid/config.xml'),
    ]);
    final client = HttpDiscoveryClient(client: transport);
    await expectLater(
      client.get(uri, timeout: timeout, maxBytes: 1024, redirectBudget: 2),
      throwsA(
        isA<DiscoveryException>().having(
          (error) => error.code,
          'code',
          'unsafe_redirect',
        ),
      ),
    );
    expect(transport.requested.length, 1);
  });

  test('a plaintext remote document is rejected', () async {
    final transport = ScriptedTransport([response(200)]);
    final client = HttpDiscoveryClient(client: transport);
    await expectLater(
      client.get(
        Uri.parse('http://example.com/config.xml'),
        timeout: timeout,
        maxBytes: 1024,
        redirectBudget: 2,
      ),
      throwsA(
        isA<DiscoveryException>().having(
          (error) => error.code,
          'code',
          'insecure_transport',
        ),
      ),
    );
    expect(transport.requested, isEmpty);
  });

  test('a body larger than the limit is rejected', () async {
    final transport = ScriptedTransport([
      response(200, body: List<int>.filled(1025, 120)),
    ]);
    final client = HttpDiscoveryClient(client: transport);
    await expectLater(
      client.get(uri, timeout: timeout, maxBytes: 1024, redirectBudget: 2),
      throwsA(
        isA<DiscoveryException>().having(
          (error) => error.code,
          'code',
          'oversized_document',
        ),
      ),
    );
  });
}
