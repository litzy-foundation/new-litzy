// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:protocol/protocol.dart';

void main() {
  test('a typed request receives its matching typed response', () async {
    final uiPort = ReceivePort();
    final enginePort = ReceivePort();
    final ui = InProcessLmlpTransport(
      sendPort: enginePort.sendPort,
      receivePort: uiPort,
    );
    final engine = InProcessLmlpTransport(
      sendPort: uiPort.sendPort,
      receivePort: enginePort,
    );
    addTearDown(ui.close);
    addTearDown(engine.close);

    final pending = ui.sendRequest(const PingRequest('p1'));
    final received = await engine.requests.first.timeout(
      const Duration(seconds: 2),
    );
    expect(received, isA<PingRequest>());
    expect((received as PingRequest).id, 'p1');

    engine.send(const PongResponse('p1'));
    final response = await pending;
    expect(response, isA<PongResponse>());
    expect(response.id, 'p1');
  });

  test('events arrive on the event stream with their type intact', () async {
    final uiPort = ReceivePort();
    final enginePort = ReceivePort();
    final ui = InProcessLmlpTransport(
      sendPort: enginePort.sendPort,
      receivePort: uiPort,
    );
    final engine = InProcessLmlpTransport(
      sendPort: uiPort.sendPort,
      receivePort: enginePort,
    );
    addTearDown(ui.close);
    addTearDown(engine.close);

    final eventFuture = ui.events.first.timeout(const Duration(seconds: 2));
    final readyPort = ReceivePort();
    engine.send(EngineReadyEvent(port: readyPort.sendPort));
    final event = await eventFuture;
    expect(event, isA<EngineReadyEvent>());
    expect((event as EngineReadyEvent).port, isA<SendPort>());
    readyPort.close();
  });

  test('an unanswered request fails with a timeout', () async {
    final uiPort = ReceivePort();
    final enginePort = ReceivePort();
    final ui = InProcessLmlpTransport(
      sendPort: enginePort.sendPort,
      receivePort: uiPort,
    );
    final engine = InProcessLmlpTransport(
      sendPort: uiPort.sendPort,
      receivePort: enginePort,
    );
    addTearDown(ui.close);
    addTearDown(engine.close);

    await expectLater(
      ui.sendRequest(
        const PingRequest('lost'),
        timeout: const Duration(milliseconds: 30),
      ),
      throwsA(isA<LmlpTimeoutException>()),
    );
  });
}
