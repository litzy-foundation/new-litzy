// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Local engine interface implemented inside the client process.
library;

import 'message.dart';

/// The contract every front-end uses to reach the embedded engine.
///
/// Calls and events are immutable Dart values. There is no serialisation,
/// remote address or wire format in this interface, as required by R40.
abstract interface class LmlpEngine {
  /// Sends [request] and completes with its typed response.
  Future<LmlpResponse> send(LmlpRequest request);

  /// Engine events such as progress and state changes.
  Stream<LmlpEvent> get events;

  /// Closes the local engine and releases its resources.
  Future<void> close();
}
