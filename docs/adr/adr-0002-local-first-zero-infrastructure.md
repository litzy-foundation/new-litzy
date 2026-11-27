# ADR-0002: Local-first engine with zero infrastructure

## Status

Accepted on 2026-11-28. This decision implements R14, R23 and R33 and
supersedes the earlier server-side architecture.

## Context

The previous architecture included a PostgreSQL store with `ltree` threading,
a MinIO blob store and an inbound SMTP listener. Each of them requires
something to operate: a database server, an object store, or a domain with
MX records and an always-on process. The maintainer chose a one hundred
percent local-first replacement, stating that the important thing is to
keep everything perfectly local and to remove nothing from the local
machine.

## Decision

The engine is embedded in the client process on a Dart isolate separate
from the user interface, and its package is named `packages/engine` to make
that role explicit. The only active store is a local SQLite database.
PostgreSQL and MinIO are not shipped. Mode A, the inbound SMTP listener, is
removed because it requires infrastructure that contradicts the
requirement; it may return as a future plugin only after a new decision.
Nothing is pushed or published automatically, and the remote is local.

## Consequences

There is no service to run, no monthly cost and no server to secure. Thread
and search work can use the query engine of SQLite directly. Users keep all
data in one file that can be backed up atomically. The trade-off is that
multi-device synchronisation is not provided by the engine and would need a
future, explicit opt-in design.
