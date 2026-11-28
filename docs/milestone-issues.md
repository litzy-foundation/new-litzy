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
deletes, `EXPUNGE` is opt-in per list, and `purge_test.dart` proves both
paths together with the digest gate, quarantine and replay protection.

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
secrets enter the app through OAuth or a secure credential form and live in
the operating system keychain, and no token or mutual TLS is used between
client and engine. `packages/security` now supplies the keychain and OAuth
ports with fake-based tests; the native adapters remain in S4a.

## P8 — Environment file as a credential surface

The first design loaded credentials from a root `.env` documented by
`.env.example`. The maintainer stated that management should be done by the
app through OAuth and other secure mechanisms instead. Status: addressed by
the decision in R37 and ADR-0007. Evidence: `requirements.md` records the
supersession of R9, the versioned `.env.example` is removed, and the
credential flow is tracked in S4a with keychain storage and fake OAuth
tests. `CredentialVault` now carries that flow behind ports, and its tests
use only fake secrets. The native keychain adapters are still to be added.
Any local `.env` already on a machine stays there and is git-ignored;
nothing is removed from the local machine.

## P7 — Full rebuild without local loss

Recreating the repository from zero must not remove anything from the local
machine. Status: addressed. Evidence: a complete copy of the previous tree
and git history was created under `/tmp/opencode/litzy-backup` before the
rebuild, and no remote push was performed.

## P9 — Server-side hook on a public GitHub remote

The rebuilt repository versioned a `pre-receive` hook and installed it in a
local bare mirror, but the authoritative remote is a public GitHub repository
where that hook cannot run. The maintainer stated that such a hook will never
be used and asked for a GitHub-based alternative. Status: addressed by R38
and ADR-0014. Evidence: the versioned hook is removed from the tree, the
installed mirror hook is moved to the existing local backup rather than
deleted, and the `pr-guard` workflow plus branch protection enforce the pull
request rules on GitHub. The mirror remains an offline copy without policy.
