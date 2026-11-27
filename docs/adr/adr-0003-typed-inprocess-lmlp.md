# ADR-0003: LMLP as a typed in-process bus

## Status

Accepted on 2026-11-28. This decision implements R32 and closes Q5.

## Context

The old plan serialised LMLP messages as JSON over a WebSocket between the
GUI and the engine, or considered a local IPC channel. Both introduce a
boundary that does not need to exist: the client and the engine run in the
same process. Serialisation costs work, weakens type safety and creates a
network surface with no user benefit. The maintainer chose to keep the
protocol package and use it as a typed in-process bus.

## Decision

`packages/protocol` owns a sealed, typed message union for requests,
responses and events. `InProcessLmlpTransport` carries those values between
the UI isolate and the engine isolate through `SendPort` and `ReceivePort`.
No JSON encoding, socket or token is involved in that hop. Both the GUI and
the CLI depend only on the protocol, so neither knows how the engine is
implemented.

## Consequences

A single engine and a single protocol serve both front-ends without
duplicated logic. Messages keep their types across the boundary and are
checked exhaustively. The isolatemust be started by each front-end in the
same way, and every message type remains part of a versioned protocol so
that a client and an engine built from different revisions fail clearly
rather than silently misbehaving.
