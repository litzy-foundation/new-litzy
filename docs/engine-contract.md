# Engine contract

The engine contract is the typed language shared by the front-ends and the
engine. It is not a wire protocol: calls cross an isolate boundary inside one
process, so Dart values keep their types. The package that holds the contract
keeps the historical name `protocol`, but its role is now only the local
interface described in ADR-0016.

## Interface

`LmlpEngine` exposes asynchronous methods for profile, ingestion, search,
thread, triage and audit operations. Progress and state changes are delivered
through streams for channels, thread trees and messages. Values are immutable
and final so a caller cannot mutate an object after it crosses the isolate
boundary. The message vocabulary remains a sealed union inside the engine so
the analyzer can check every case, but a front-end calls methods rather than
constructing framed requests.

## Local delivery

`InProcessLmlpTransport` owns a `SendPort` to the peer isolate and a
`ReceivePort` on which it listens. It correlates each call with its result and
delivers events on a separate stream. The startup port handshake is hidden by
the engine client and is not part of the public contract. There is no
serialisation, no authentication step and no protocol version negotiation
because there is no network boundary.

## Failure behaviour

If the engine isolate exits unexpectedly, pending calls finish with an
explicit engine-unavailable error instead of hanging. A failed operation
returns a deterministic error code and a readable message that never contains
credential material. The front-ends present those codes through shared
Fluent resources so the CLI and the GUI use the same vocabulary.
