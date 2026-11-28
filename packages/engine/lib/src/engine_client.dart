// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:async';
import 'dart:isolate';

import 'package:protocol/protocol.dart';

import 'engine_isolate.dart';

/// Starts the engine isolate and exposes the typed bus to a front-end.
final class EngineClient implements LmlpEngine {
  EngineClient._(this._transport, this._isolate);

  final InProcessLmlpTransport _transport;
  final Isolate _isolate;

  /// Spawns a real engine isolate and waits for its ready event.
  static Future<EngineClient> start() async {
    final readyPort = ReceivePort();
    final isolate = await Isolate.spawn(engineIsolateEntry, readyPort.sendPort);
    final transport = InProcessLmlpTransport(
      sendPort: readyPort.sendPort,
      receivePort: readyPort,
    );
    final first = await transport.events
        .firstWhere((event) => event is EngineReadyEvent)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw StateError('engine isolate did not become ready'),
        );
    if (first case EngineReadyEvent(:final SendPort port)) {
      transport.bindSendPort(port);
      return EngineClient._(transport, isolate);
    }
    transport.close();
    isolate.kill();
    throw StateError('engine isolate sent an unexpected first message');
  }

  /// Sends a typed request and completes with its typed response.
  Future<LmlpResponse> sendRequest(LmlpRequest request) =>
      _transport.sendRequest(request);

  /// Sends a typed request through the local engine interface.
  @override
  Future<LmlpResponse> send(LmlpRequest request) => sendRequest(request);

  /// Events emitted by the engine isolate.
  @override
  Stream<LmlpEvent> get events => _transport.events;

  /// Closes the transport and stops the isolate.
  @override
  Future<void> close() async {
    _transport.close();
    _isolate.kill();
  }
}
