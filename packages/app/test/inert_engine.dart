// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:async';

import 'package:protocol/protocol.dart';

/// Engine stub that satisfies the application lifecycle without an isolate.
final class InertEngine implements LmlpEngine {
  /// Creates an engine that has not been closed.
  InertEngine();

  /// Number of times the application closed the engine.
  int closeCount = 0;

  @override
  Future<LmlpResponse> send(LmlpRequest request) async =>
      const AckResponse('test');

  @override
  Stream<LmlpEvent> get events => const Stream.empty();

  @override
  Future<void> close() async {
    closeCount++;
  }
}
