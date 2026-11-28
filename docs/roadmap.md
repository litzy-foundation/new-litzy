# Roadmap

This is a living document updated at the end of every slice, as required by
R8. The permanent directives are in `requirements.md`, decisions are in the
ADRs, and problems are in `milestone-issues.md`.

## Where we are

The repository was rebuilt from zero on 2026-11-28. The previous tree and
history remain as a local backup, and no content was removed from the
machine. The rebuild starts from the documentation alone, because the new
rules about pull requests and agent authorship are part of the foundation
rather than an afterthought. The first slice records the complete local-first
architecture before any code is written.

## S0 — Foundation documentation, current slice

The goal of this slice is to make every directive durable before
implementation starts. It lands the requirements file with R1 through R35,
the contribution rules, the agent instructions, the ADRs that settle the
architectural choices, the style skills, the development guide and the
versioned data catalogue.

Evidence for this slice is the documentation commit itself, merged into
`main` from a topic branch, with no agent co-author trailer. The problem
register records the issues that motivated the rebuild and the evidence
that closes them.

## S0a — GitHub-native enforcement, landed

The maintainer decided that a pre-receive hook will never be used and asked
for a GitHub-based alternative. This slice records R38 and ADR-0014, removes
the versioned hook, and adds the `pr-guard` workflow. Branch protection on
`main` requires that check before merging. Evidence is the configuration in
`docs/repository-security.md` and the check run on every pull request after
this slice lands.

## S1 — Engine isolate and typed LMLP transport

Create `packages/protocol` with the typed message union and the in-process
transport built on `SendPort` and `ReceivePort`. Create `packages/engine`
with the isolate entry point. The GUI and CLI depend only on the protocol.

Landed: the workspace has `core`, `protocol` and `engine` packages, a sealed
LMLP message union with typed requests, responses and events, and
`InProcessLmlpTransport` with separate request, response and event streams.
`EngineClient.start` spawns a real isolate and binds the announced receive
port; a ping and a shutdown both complete through the typed bus. Tests cover
typed delivery, event typing, timeout on an unanswered request and the real
isolate round trip. Analysis is clean and all three package suites are green.

Landed in a later slice: typed verbs open a local profile, ingest a batch,
search with FTS5 and read a thread through the real isolate.
`EngineRequestHandler` answers the sealed request union with typed responses
and deterministic error codes for an invalid path, a closed profile, an empty
batch and a failed write. Tests drive the isolate and the SQLite database
together, and check that a duplicate message leaves no partial persistence.
Still to do: the purge and ingestion verbs on the bus, and the CLI and GUI
clients.

## S2 — SQLite storage, threading and search

Implement the single local SQLite database with migrations, recursive thread
queries, FTS5 indexing and the local blob backend. Tests cover deep threads,
bounded recursion, atomic batches, checksum verification and corrupted
content.

Partially landed: `LocalDatabase` creates the schema, persists batches in a
single transaction, reads threads with a bounded `WITH RECURSIVE` query,
searches with FTS5 and exposes a `VACUUM INTO` backup. Both blob backends now
implement the `BlobStore` port. `LocalBlobStore` keeps the content-addressed
folder and rejects a file whose bytes no longer match its digest.
`SqliteBlobStore` keeps a Zstd frame and its uncompressed size in the same
database, so one file is a complete backup. Both backends are selected by a
typed field on the open request, and tests cover them through identical
calls. Deferred: the Drift mapping that replaces the direct `sqlite3`
statements. Drift 2.35 exposes only an async query API, while
`LocalDatabase`, `BlobStore` and `ListMessageIngestor.ingest` are synchronous, so a
faithful mapping would change the engine API and the tests that call storage
directly. The mismatch is recorded as P10 in the problem register. The
migration belongs in a dedicated slice that converts the storage and blob
ports to async together; the current SQL stays unchanged until then.

## S3 — Mode C ingestion

Implement NNTP and public-inbox clients, the local YAML catalogue under
`data/catalog`, and the mapping from a selected list to a channel. Tests
use a local NNTP fixture server and a local public-inbox fixture, with an
end-to-end proof that reads a real thread through the real engine.

Partially landed: `CatalogLoader` validates the versioned YAML catalogue and
produces typed `ListSource` values; `NntpClient` performs `GROUP`, `XOVER`
and `ARTICLE` against a real socket; `PublicInboxClient` reads recent thread
identifiers from an atom feed and decompresses a thread mbox into typed
messages with digests. Failures are explicit types for bad status codes,
malformed documents, unsafe identifiers and timeouts. Tests drive a local
fake NNTP server and a local HTTP fixture, and check catalogue validation.
Landed: `ChannelMapper` turns a catalogue entry into a runtime channel that
`LocalDatabase` persists, and `ListMessageIngestor` verifies the list identifier,
the raw digest and thread references before writing messages and raw blobs.
An end-to-end test loads the versioned catalogue, serves an atom feed and a
gzipped mbox from a local HTTP fixture, and reads the persisted thread and
search result from the real SQLite database. A typed `SyncRequest` now refreshes
a named catalogue channel through either NNTP or public-inbox inside the
engine isolate, and an NNTP article converts to the same raw message shape.
Tests drive the real isolate path with local fake servers and check that an
untrusted list identifier leaves no persisted message. Incremental cursors now
live in SQLite per channel: NNTP advances by article number and public-inbox
remembers seen thread identifiers, so a repeated sync fetches no duplicate
messages. A cursor advances only after its batch commits. The `audit` verb
for residual list mail is tracked in S4.

## S4 — Mode B with opt-in purge

Implement IMAP vacuum with the safe default of moving to `Litzy/Ingested`
or marking as read and archiving. Real `EXPUNGE` is a per-list opt-in behind
the two-phase commit and SHA-256 check. Tests prove that the default never
deletes and that the opt-in path deletes only after verification.

Partially landed: `PurgeCoordinator` prepares a decision by verifying each
candidate against the SQLite checksum and the local blob store, quarantines
doubtful messages in a durable ledger, and records a SHA-256 digest. The
second phase rechecks that digest and the bytes, then applies the per-list
policy through a small `MailboxPort`. The default moves to
`Litzy/Ingested`; the other safe choice marks messages as seen, and real
expunging requires an explicit per-list opt-in. A consumed preparation cannot
be replayed and a mailbox failure leaves it retryable. Tests cover all of
these paths with a fake mailbox. A read-only typed `audit` verb now reports
residual list mail, unmanaged lists and quarantined messages from a snapshot
supplied by the front-end; the engine applies the stored policy and never
changes a mailbox. A real RFC-compliant IMAP client now implements
`MailboxPort`, reads a message batch and supplies a typed inbox snapshot. A
typed Mode B verb persists only messages whose list identifier matches the
selected list, then applies the stored mailbox policy through the purge
coordinator. TLS and credential choices are recorded in ADR-0015. Still to do:
the CLI command, which waits for a platform keychain adapter so no password
needs to be typed into a terminal.

## S4a — Secure configuration and OAuth

The maintainer decided that a `.env` file is not used for management and
that the app manages credentials through OAuth and other secure mechanisms.
This slice removes `.env.example` from the versioned tree and introduces the
in-app credential flow with token storage in the operating system keychain.
Tests use a fake keychain port and a fake OAuth provider; no real credential
is stored in the repository or in a test fixture.

Partially landed: `packages/security` defines the `SecretStore` and
`OAuthProvider` ports and a `CredentialVault` that exchanges an OAuth code,
accepts a password from a secure form, reads credentials and forgets them.
Failures are deterministic codes for an unknown provider, a rejected code, a
corrupt stored token and an unavailable keychain. Tests drive fakes and prove
that no secret is written to a versioned file or a fixture. Still to do: the
platform adapters for `flutter_secure_storage` and libsecret, the browser
redirect handling in the GUI, and the use of stored credentials by the IMAP
and SMTP transports.

## S5 — Terminal client

Build the CLI as a thin front-end over the typed bus, exposing sync, triage,
read, reply and audit. Acceptance tests use the real binary and the real
database.

Partially landed: the `litzy` binary parses arguments, opens a profile and
sends typed ping, sync, import, search, thread, triage and audit requests through
a real engine isolate. Each invocation prints structured JSON and closes its isolate, so no
engine state survives between processes. Acceptance tests drive the binary
with a local NNTP fixture and check that a channel synced in one process can
be searched and read in the next. The audit command reads a typed snapshot
from a local file and prints the engine's verdict. Read and starred flags live
in SQLite behind typed verbs, and the CLI changes them with explicit flags.
Local Maildir and mbox import shares the mbox parser with public-inbox and
skips identifiers that are already persisted, so a repeated import adds no
duplicates. The reply command builds a quoted draft in the engine and stores it
in SQLite under one identifier per source message. Sending stays in the
outbound slice.

## S9 — Local-only contract and storage cleanup

The maintainer reset the order after S5, so this section takes precedence over
the older labels S6 through S8, which remain as historical scope. The slice
records R40 through R49, ADR-0016 through ADR-0020 and the updated architecture
before code changes. It then turns `protocol` into a pure Dart engine contract,
removes the compressed SQLite blob backend from the active path, moves raw
messages to a content-addressed compressed folder, extracts the schema into
`.sql` files and sets WAL with a five second busy timeout on every open. Tests
prove that an existing SQLite blob migrates byte for byte and that two real
processes can share one profile.

## S14 — Presentation algorithms in core

Restore `JwzThreadBuilder` and `QuoteAndDiffAnalyzer` from the preserved
backup into `packages/core`, keeping their coverage for missing parents,
reference cycles, duplicate identifiers, nested quotes and unified diffs.
Adapt their inputs to the current protocol values and remove any dependency
on algorithms that were not carried into the rebuild. This closes Q13 and
supplies the S10 thread display and the S11 folding and diff rendering without
reimplementing tested behaviour.

## S10 — Credential-free Git reading in the CLI

Give the terminal client a default catalogue path and a direct way to follow
`git@vger.kernel.org` through public-inbox or NNTP without credentials. Add
commands to list channels and threads and to show one reconstructed thread.
The path reads public data only and does not touch IMAP, SMTP or a keychain.
Acceptance tests use the real binary, the real engine and local fixtures that
serve an Atom feed, a gzipped mbox and an NNTP conversation.

## S11 — Chat-like read-only GUI

Create `packages/l10n` and `packages/app`, then build the read-only interface
of ADR-0020 on desktop and mobile. The left pane holds catalogue channels and
cross-channel triage views, the centre pane holds topics ordered by last
activity, and the right pane holds a branch-aware conversation. Citation
folding and monospace diff blocks are part of the first version. The composer
is not active until S8, but its To and Cc preview shape is defined now. Tests
check adaptive layout, thread navigation and that no user-visible string is
hardcoded.

## S12 — Import, export and automatic transfer

Add explicit import and export of profile data plus declarative automatic
rules under `data/`. Formats and triggers are chosen from Q10 before code is
written. Automatic transfer never bypasses the verification gate of R15. Tests
cover round trips, malformed input and a rule that refuses a destructive
mailbox action.

## S13 — Discoverability metadata

Choose the public description and tags from Q11, then add them to the
repository and package metadata. The wording describes a local-first mailing
list reader for technical lists and makes no claim about unimplemented
features.

## S6 — Flutter GUI

Build the adaptive master-detail GUI on desktop and mobile, using the same
protocol. Include channel selection from the local catalogue and thread
reading. Package for Linux first, then the other targets. This heading is
superseded by S11.

## S7 — Plugins and local agent

Restore the typed plugin surface for sources and filters, then the local
summarizer behind the same boundary.

## S8 — Outbound and export

Authenticated SMTP, sendmail or msmtp transport, opt-in DKIM and patch or
mbox export from the thread view.

## Later work

Maildir and mbox import, full-text search polish, remaining platform
packages and the parked cloud option are tracked here when a slice opens.
The open questions in `requirements.md` stay open until a decision closes
them.
