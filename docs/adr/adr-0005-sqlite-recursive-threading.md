# ADR-0005: Threading with SQLite recursive queries and FTS5

## Status

Accepted on 2026-11-28. This decision implements R25 and supersedes the
earlier materialized-path design.

## Context

The earlier requirement stored threads through a fixed-width lexicographic
path and explicitly avoided recursion. It was designed for a PostgreSQL
`ltree` column and was carried over when the project moved to SQLite. The
maintainer chose a pure SQLite replacement, noting that SQLite manages deep
thread trees in milliseconds without an external dependency, and asked for
`WITH RECURSIVE` plus FTS5.

## Decision

Thread storage uses SQLite through Drift. Parent and root identifiers stay
in the message rows, and subtree reads and pre-order traversal are expressed
with recursive common table expressions. Full-text search is provided by
FTS5 in the same database. The fixed-width path is no longer the storage
mechanism; its earlier requirement is preserved in `requirements.md` as
history and is explicitly superseded here.

## Consequences

One database file now holds messages, threads and search indexes, which
makes backup atomic and removes a whole class of migration between two
stores. Recursive queries are easier to read and change than path
arithmetic, and the analyzer remains clean. The cost is that query plans
must be checked on deep threads with tests, and recursion depth has to be
bounded explicitly so a malformed message chain cannot exhaust resources.
