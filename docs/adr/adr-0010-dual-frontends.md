# ADR-0010: GUI and CLI as thin front-ends

## Status

Accepted on 2026-11-28. This decision implements R13.

## Context

The maintainer requires Litzy to be usable both as a GUI and as a CLI on the
same data. Duplicating engine logic in two front-ends would double the work
and let the two implementations drift. The in-process bus of ADR-0003 makes
a clean separation possible.

## Decision

The Flutter GUI and the terminal CLI depend only on `packages/protocol`.
Each starts the engine isolate and exchanges typed LMLP messages with it.
No feature is implemented in a front-end when it belongs to the engine.
The CLI is scriptable and keyboard-first, and the GUI is adaptive across
desktop and mobile. Both expose the same operations, with input and output
shapes appropriate to their medium. The first verb set makes the boundary
concrete: the protocol owns the message payload and the request and response
types, while the engine handler maps them to SQLite records inside the
isolate. A sync verb selects a catalogue channel and runs the Mode C client
inside the engine, so neither front-end decides how a list is fetched. The
terminal binary opens a profile for one invocation, sends one typed request
and prints structured JSON; it holds no domain state between processes. A new
operation cannot cross the bus until it has a typed request and response.

## Consequences

A feature implemented once is reachable from both clients, and tests can
drive the same engine through either front-end. The protocol becomes a
stable contract that needs versioning. Front-ends must avoid embedding
business rules, which is enforced by review and by the package dependency
direction.
