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

Still to do in later slices: the storage and ingestion verbs that will use
this bus, and the CLI and GUI clients.

## S2 — SQLite storage, threading and search

Implement the single local SQLite database with migrations, recursive thread
queries, FTS5 indexing and the local blob backend. Tests cover deep threads,
bounded recursion, atomic batches, checksum verification and corrupted
content.

Partially landed: `LocalDatabase` creates the schema, persists batches in a
single transaction, reads threads with a bounded `WITH RECURSIVE` query,
searches with FTS5 and exposes a `VACUUM INTO` backup. `LocalBlobStore`
implements the content-addressed folder and rejects a file whose bytes no
longer match its digest. Tests are green. Still to do: the SQLite blob table
with the Zstd binding and the Drift mapping that replaces the direct
`sqlite3` statements while keeping the same SQL.

## S3 — Mode C ingestion

Implement NNTP and public-inbox clients, the local YAML catalogue under
`data/catalog`, and the mapping from a selected list to a channel. Tests
use a local NNTP fixture server and a local public-inbox fixture, with an
end-to-end proof that reads a real thread through the real engine.

## S4 — Mode B with opt-in purge

Implement IMAP vacuum with the safe default of moving to `Litzy/Ingested`
or marking as read and archiving. Real `EXPUNGE` is a per-list opt-in behind
the two-phase commit and SHA-256 check. Tests prove that the default never
deletes and that the opt-in path deletes only after verification.

## S5 — Terminal client

Build the CLI as a thin front-end over the typed bus, exposing sync, triage,
read, reply and audit. Acceptance tests use the real binary and the real
database.

## S6 — Flutter GUI

Build the adaptive master-detail GUI on desktop and mobile, using the same
protocol. Include channel selection from the local catalogue and thread
reading. Package for Linux first, then the other targets.

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
