# LMLP protocol

LMLP is the typed language shared by the front-ends and the engine. It is
not a wire protocol in this architecture: the messages cross an isolate
boundary inside one process, so they remain Dart values with their types
intact.

## Shape of a message

A request carries an identifier, a verb and typed arguments. A response
carries the same identifier and either a typed result or a deterministic
error. Events carry a topic and a typed payload, and are used for progress
and for changes pushed from the engine to the interface. The message set is
a sealed union so the analyzer can check that every case is handled.

## In-process transport

`InProcessLmlpTransport` owns a `SendPort` to the peer isolate and a
`ReceivePort` on which it listens. Sending a request registers the identifier
so the matching response can be routed back to its caller. Events are
delivered to a separate stream. Because messages are not serialised, objects
must be immutable before they are sent; the protocol types are final and
deeply immutable for that reason.

## Failure behaviour

If the engine isolate exits unexpectedly, pending requests finish with an
explicit engine-unavailable error instead of hanging. A protocol version is
exchanged when the isolate starts, so a front-end and an engine built from
different revisions report a clear mismatch. There is no authentication
step because there is no network boundary, as decided in ADR-0007.
