# ADR-0016: Pure in-process engine contract

## Status

Accepted on 2026-11-28. This decision implements R40 and supersedes the wire
framing language retained in ADR-0003.

## Context

Litzy is a local client with an engine on a background isolate. Earlier
documents still used the name LMLP as if it were a wire protocol and kept
ideas such as protocol version handshakes that belong to a network boundary.
The maintainer stated: "Taglia il wire protocol LMLP" and asked for "un
contratto puramente in-process (interfacce Dart + Stream reattivi tra un
background Isolate e la UI/CLI)". There is no remote peer, so serialisation,
authentication and compatibility negotiation only add cost and places for
bugs.

## Decision

The `protocol` package exposes an asynchronous `LmlpEngine` interface,
immutable request and result values, and streams for channels, thread trees
and messages. The engine implements that interface on a dedicated Dart
isolate. `SendPort` and `ReceivePort` carry Dart values between isolates and
are an implementation detail of the local hop, not a transport a front-end
can address over a network. No JSON, WebSocket, remote procedure call layer,
protocol version handshake or wire vocabulary remains in the contract.

## Consequences

The dependency from both front-ends stays small and points only to Dart
types. Tests call the engine interface directly or through the real isolate
without building a second serialisation path. Documentation will rename the
old protocol note to describe an engine contract, and later code changes will
remove lingering wire terminology. There is no compatibility boundary between
front-end and engine, so both ship from one build. A future remote service is
out of scope and would require a new architectural decision.
