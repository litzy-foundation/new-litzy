# ADR-0013: End-to-end acceptance with the real application

## Status

Accepted on 2026-11-28. This decision implements R27. ADR-0023 extends the
binary rule to every binary the agent builds or changes, including the GUI
client.

## Context

Green unit tests with in-process fakes can hide integration failures in the
engine, the database and the front-end. The maintainer requires acceptance
tests that open the real binary, the real embedded engine and the real
database and actually perform the flows.

## Decision

Every feature slice lands with at least one acceptance test that starts a
real client, uses a real SQLite database and drives a complete flow. Local
fixture servers stand in for external protocols, but the client, engine and
database under test are the shipped ones. Unit tests remain mandatory for
algorithmic cores such as threading, parsing and purge decisions, and are
run with the targeted test commands during iteration. The full suite runs
before a pull request is merged.

## Consequences

Acceptance tests are slower than unit tests, so they are grouped and run at
slice boundaries and in continuous integration. Fakes are still useful for
algorithms, but they no longer count as proof that a feature works. The
test harness must create databases in temporary directories so no local
user data is touched.
