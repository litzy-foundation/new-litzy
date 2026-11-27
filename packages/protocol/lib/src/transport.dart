// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:async';
import 'dart:isolate';

import 'message.dart';

/// Reports that a request was not answered before its deadline.
final class LmlpTimeoutException implements Exception {
  /// Creates a timeout for the given request identifier.
  const LmlpTimeoutException(this.id);

  /// Identifier of the request that was not answered.
  final String id;

  @override
  String toString() => 'LMLP request $id timed out';
}

/// Carries typed LMLP values between two isolates through ports.
///
/// The transport owns the receive side when no port is supplied. Requests,
/// responses and events arrive on separate broadcast streams so a caller
/// never has to inspect a raw value to learn what it received.
final class InProcessLmlpTransport {
  /// Creates a transport that sends to [sendPort] and listens on [receivePort].
  InProcessLmlpTransport({required this._sendPort, ReceivePort? receivePort})
    : _receivePort = receivePort ?? ReceivePort() {
    _receivePort.listen(_onMessage);
  }

  SendPort _sendPort;
  final ReceivePort _receivePort;
  final StreamController<LmlpRequest> _requests =
      StreamController<LmlpRequest>.broadcast();
  final StreamController<LmlpResponse> _responses =
      StreamController<LmlpResponse>.broadcast();
  final StreamController<LmlpEvent> _events =
      StreamController<LmlpEvent>.broadcast();
  final Map<String, Completer<LmlpResponse>> _pending =
      <String, Completer<LmlpResponse>>{};

  /// Requests arriving from the peer isolate.
  Stream<LmlpRequest> get requests => _requests.stream;

  /// Responses arriving from the peer isolate.
  Stream<LmlpResponse> get responses => _responses.stream;

  /// Events arriving from the peer isolate.
  Stream<LmlpEvent> get events => _events.stream;

  /// Replaces the port used to send messages to the peer.
  ///
  /// The engine announces its receive port after startup, so a client
  /// created before that handshake binds the real port once it is known.
  void bindSendPort(SendPort port) => _sendPort = port;

  /// Sends a typed message to the peer without waiting for an answer.
  void send(LmlpMessage message) => _sendPort.send(message);

  /// Sends a request and completes with its matching typed response.
  Future<LmlpResponse> sendRequest(
    LmlpRequest request, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    final completer = Completer<LmlpResponse>();
    _pending[request.id] = completer;
    _sendPort.send(request);
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(request.id);
        throw LmlpTimeoutException(request.id);
      },
    );
  }

  void _onMessage(dynamic message) {
    switch (message) {
      case LmlpRequest request:
        _requests.add(request);
      case LmlpResponse response:
        _responses.add(response);
        final completer = _pending.remove(response.id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(response);
        }
      case LmlpEvent event:
        _events.add(event);
    }
  }

  /// Closes the receive port and fails any request still waiting.
  void close() {
    for (final entry in _pending.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(
          StateError('transport closed before request ${entry.key} answered'),
        );
      }
    }
    _pending.clear();
    _receivePort.close();
    _requests.close();
    _responses.close();
    _events.close();
  }
}
