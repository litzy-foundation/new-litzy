// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:isolate';

/// A value that may cross the in-process boundary between UI and engine.
sealed class LmlpMessage {
  /// Creates a message.
  const LmlpMessage();
}

/// A typed instruction sent by a front-end to the engine.
sealed class LmlpRequest extends LmlpMessage {
  /// Creates a request with the identifier used to match its response.
  const LmlpRequest(this.id);

  /// Identifier echoed by the response that answers this request.
  final String id;
}

/// Requests a response that proves the engine isolate is alive.
final class PingRequest extends LmlpRequest {
  /// Creates a ping with the given identifier.
  const PingRequest(super.id);
}

/// Asks the engine to finish its work and close its isolate port.
final class ShutdownRequest extends LmlpRequest {
  /// Creates a shutdown request with the given identifier.
  const ShutdownRequest(super.id);
}

/// A typed answer sent by the engine for one request identifier.
sealed class LmlpResponse extends LmlpMessage {
  /// Creates a response for the given request identifier.
  const LmlpResponse(this.id);

  /// Identifier of the request this response answers.
  final String id;
}

/// Confirms that the engine answered a ping.
final class PongResponse extends LmlpResponse {
  /// Creates a pong for the given request identifier.
  const PongResponse(super.id);
}

/// Confirms that an instruction was carried out.
final class AckResponse extends LmlpResponse {
  /// Creates an acknowledgement for the given request identifier.
  const AckResponse(super.id);
}

/// Reports a deterministic failure for one request.
final class ErrorResponse extends LmlpResponse {
  /// Creates an error response with a stable code and a readable message.
  const ErrorResponse(super.id, this.code, this.message);

  /// Stable machine-readable code.
  final String code;

  /// Human-readable explanation of the failure.
  final String message;
}

/// A typed notification pushed by the engine without a request.
sealed class LmlpEvent extends LmlpMessage {
  /// Creates an event.
  const LmlpEvent();
}

/// Announces the port on which a newly started engine receives requests.
final class EngineReadyEvent extends LmlpEvent {
  /// Creates a ready event carrying the engine receive port.
  const EngineReadyEvent({required this.port});

  /// Port on which the engine listens for typed messages.
  final SendPort port;
}
