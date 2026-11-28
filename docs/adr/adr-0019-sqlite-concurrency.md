# ADR-0019: SQLite concurrency between front-ends

## Status

Accepted on 2026-11-28. This decision implements R44.

## Context

The CLI and the Flutter GUI can run at the same time against one profile. The
maintainer stated: "Gestisci subito la concorrenza SQLite tra CLI (litzy) e
GUI (litzy-gui)". Without an explicit setting, a sync in the terminal while
the desktop application is open can end in `SQLITE_BUSY`. The project must not
introduce a daemon only to solve a local database contention problem.

## Decision

Every database open sets `journal_mode=WAL` and `busy_timeout=5000` before any
schema access. Writers keep transactions short and commit through the existing
atomic batch path. A busy database produces a deterministic typed failure that
the front-end can report or retry. A shared write lock is added only if an
acceptance test with two real processes shows that the pragmas are not enough.
No server process owns the database.

## Consequences

Readers and one writer can proceed at the same time, and a short lock wait is
handled inside SQLite rather than in business logic. The concurrency settings
are verified in tests that open two real connections to one profile. If a
lock becomes necessary, it belongs in the storage layer and does not change
the engine contract. The choice keeps the project local-first and leaves the
database file as the single source of runtime state.
