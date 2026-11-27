# Problem register

Every problem raised during development is recorded here until it is
addressed with documentation, tests and code, or until it is assigned to a
tracked roadmap slice. A problem is never silently dropped. The status of a
problem is open, tracked or addressed.

## P1 — Agent co-authors in commit history

The rebuilt repository inherited a history in which every commit carried a
`Co-Authored-By` trailer for an automation account. The maintainer stated
that the agent must never add itself as a co-author. Status: addressed in
the rebuilt repository. Evidence: the rebuilt history starts at an empty
root commit, all content lands from topic branches with no agent trailer,
R30 and ADR-0001 record the rule, and `CONTRIBUTING.md` states it for
humans and agents. The old history exists only as a local backup and is not
part of the shipped history.

## P2 — Automatic purge on a personal mailbox

Deleting thousands of messages from a user's personal account on first sync
would be unacceptable, especially across multiple devices. Status:
addressed by design in R15 and ADR-0008. Evidence: the default policy never
deletes, `EXPUNGE` is opt-in per list, and tests will prove both paths in
S4.

## P3 — Infrastructure cost and protocol surface

Mode A required a domain, MX records and an always-on server, while
PostgreSQL and MinIO added services to operate. Status: addressed in R23
and ADR-0002. Evidence: the rebuilt tree has no inbound SMTP listener, no
PostgreSQL adapter and no object store, and the engine package name states
its embedded role.

## P4 — Serialising protocol messages over a socket

A JSON-over-WebSocket boundary between the GUI and the engine duplicated
logic and added a network surface where none is needed. Status: addressed
by design in R32 and ADR-0003. Evidence: the transport passes typed messages
through isolate ports, and tests will verify typed delivery in S1.

## P5 — Materialized path versus recursive queries

The earlier requirement forbade recursion in thread reads. The maintainer
chose SQLite with recursive queries and FTS5 instead. Status: addressed by
the decision recorded in R25 and ADR-0005, with implementation tracked in
S2. The old requirement is preserved as history in the requirements file.

## P6 — Secrets at rest and in memory

Credentials previously had to be protected from a network boundary that no
longer exists. Status: addressed by design in R35 and ADR-0007. Evidence:
secrets come from environment variables and the operating system keychain,
and no token or mutual TLS is used between client and engine.

## P7 — Full rebuild without local loss

Recreating the repository from zero must not remove anything from the local
machine. Status: addressed. Evidence: a complete copy of the previous tree
and git history was created under `/tmp/opencode/litzy-backup` before the
rebuild, and no remote push was performed.
