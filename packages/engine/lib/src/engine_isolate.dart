// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:isolate';

import 'package:protocol/protocol.dart';

/// Entry point of the engine isolate.
///
/// It announces its receive port through an [EngineReadyEvent], then answers
/// typed requests until a shutdown request arrives.
void engineIsolateEntry(SendPort uiPort) {
  final receivePort = ReceivePort();
  uiPort.send(EngineReadyEvent(port: receivePort.sendPort));
  final transport = InProcessLmlpTransport(
    sendPort: uiPort,
    receivePort: receivePort,
  );
  transport.requests.listen((request) {
    switch (request) {
      case PingRequest():
        transport.send(PongResponse(request.id));
      case ShutdownRequest():
        transport.send(AckResponse(request.id));
        transport.close();
    }
  });
}
