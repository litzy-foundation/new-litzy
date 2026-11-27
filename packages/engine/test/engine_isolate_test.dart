// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:test/test.dart';
import 'package:protocol/protocol.dart';
import 'package:engine/engine.dart';

void main() {
  test('the real engine isolate answers a typed ping', () async {
    final client = await EngineClient.start();
    addTearDown(client.close);

    final response = await client.sendRequest(const PingRequest('e1'));
    expect(response, isA<PongResponse>());
    expect(response.id, 'e1');
  });

  test('shutdown completes through the typed bus', () async {
    final client = await EngineClient.start();
    final response = await client.sendRequest(const ShutdownRequest('s1'));
    expect(response, isA<AckResponse>());
    expect(response.id, 's1');
    await client.close();
  });
}
