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

## P10 — Drift's async API versus synchronous storage ports

R25 and ADR-0005 require Drift for SQLite threading. Drift 2.35 resolves in
this workspace with `drift` 2.35.4, `drift_dev` 2.35.3 and `sqlite3` 3.9.2,
but its custom selects, writes and transactions all return futures. The
current `LocalDatabase`, `BlobStore` and `ListMessageIngestor.ingest` are
synchronous, so Drift cannot replace the statements as a drop-in change. A
faithful mapping would convert the storage and blob ports to async and
update the engine and the tests that read the database directly. Status:
tracked for a dedicated S2 follow-up. Evidence: the dependency experiment
resolved successfully and analysis reported only deprecation notices in the
existing `sqlite3` calls before the experiment was reverted, so no Drift
dependency remains in the tree. The SQL statements and the storage tests
stay stable until the async slice lands.

## P11 — Wire protocol language after the local-first pivot

Documents still described LMLP as if it had a wire framing and version
negotiation, although the current transport already passes typed Dart values
through isolate ports. The maintainer stated: "Taglia il wire protocol LMLP".
Status: addressed. Evidence: R40 and ADR-0016 record the pure Dart engine
contract, `docs/lmlp-protocol.md` is replaced by `docs/engine-contract.md`,
and ADR-0003 marks its wire language as superseded. `protocol` now exposes
`LmlpEngine` as Dart interfaces, immutable values and streams, and
`EngineClient` implements it without serialisation, handshake or remote
framing.

## P12 — Raw messages in SQLite

The active storage path still offers a compressed SQLite blob backend, and the
schema includes a `blobs` table. The maintainer stated: "Non salvare i blob
.eml dentro il file SQLite". Status: addressed. Evidence: R42 and ADR-0017
settle the filesystem-only layout, `SqliteBlobStore` and the `BlobBackend`
selection are removed, and every new raw message is written as a verified gzip
file under the content-addressed folder. `LegacyBlobMigrator` moves old rows
byte for byte before dropping the retired table, and a corrupt row leaves that
table in place for recovery.

## P13 — Concurrent CLI and GUI access

Two front-ends can open one SQLite profile at the same time, so a terminal sync
can meet an open desktop application. The maintainer asked to handle this
immediately. Status: addressed. Evidence: R44 and ADR-0019 choose WAL with a
five second busy timeout and leave a shared write lock as a tested fallback.
Every open applies both pragmas before schema access, and a test starts two
separate processes that write to one profile without a daemon or lock service.

## P14 — No credential-free GUI reading of the Git list

The engine and CLI already read public lists from local fixtures, but there is
no GUI package and no direct daily path for `git@vger.kernel.org`. The
maintainer asked to read that list from both CLI and GUI without credentials.
Status: tracked in S10 and S11. Evidence: R45 records the goal, the catalogue
already names the list, and the existing binary test proves the engine and CLI
path with local fixtures.

## P15 — Hardcoded literals and inline schema

User-visible strings are scattered in Dart, the schema is inline in Dart, and
protocol delimiters appear as raw literals. The maintainer stated: "tutto
pulitissimo, tutto in yml" and "db in file .sql a parte". Status: tracked in
S9 and S11. Evidence: R47 records the conventions and the clean-code, l10n and
data-separation skills are updated. The SQLite schema now lives in
`packages/engine/schema.sql`, SQLite settings and text tokens are named values,
and declarative fixtures live under `data/`. User-visible text still needs
Fluent resources in S11, and Q8 remains open for other literals.

## P16 — Missing import, export and automatic transfer

There is no export command and no automatic import or export rule, although
the maintainer asked for both. Status: tracked in S12. Evidence: R48 records
the requirement and Q10 records the open format and trigger decision.

## P17 — Missing presentation algorithms and packages

`JwzThreadBuilder`, `QuoteAndDiffAnalyzer`, `packages/app` and `packages/l10n`
do not exist in the rebuilt tree. Earlier versions survive only in the local
backup. Status: tracked in S11. Evidence: Q13 is closed in favour of restoring
and adapting the tested algorithms. `JwzThreadBuilder` and
`QuoteAndDiffAnalyzer` now live in `packages/core` with adapted tests, so the
remaining scope of this problem is the `app` and `l10n` packages assigned to
S11.

## P18 — Project discoverability

The repository has no agreed public description or discovery tags for the
local-first mailing list reader. Status: tracked in S13. Evidence: R49 records
the maintainer's goal and Q11 records the publication place as open.
