# Architecture

Litzy is one process with two isolated execution contexts. The user
interface runs in the UI isolate, and the engine runs in a separate Dart
isolate started by the same binary. They exchange typed LMLP values through
`SendPort` and `ReceivePort`, as decided in ADR-0003. There is no socket, no
serialisation step and no token between them.

## The engine

The engine owns every operation that changes state. It reads the local YAML
catalogue and rulesets, receives messages from ingestion sources, verifies
their list evidence, stores them in SQLite, builds threads with recursive
queries, maintains the FTS5 index and writes raw content to the local blob
backend. It also performs outbound operations through authenticated SMTP or
a local sendmail and msmtp pipe. The engine is a package named `engine`, not
a server, because it never runs as an independent service.

## Storage

One SQLite file holds messages, threads, triage state, cursors, the FTS5
index and optionally the compressed raw blobs. When the content-addressed
folder backend is selected, the database still holds the digest that points
at the file. Encryption at rest protects the database, and credentials are
held by the operating system keychain. A backup is therefore a copy of one
encrypted file, or of that file plus the local folder.

## Ingestion

Mode C reads public lists directly through NNTP or public-inbox without an
email account. Mode B vacuums the user's own mailbox but never deletes by
default: it moves ingested messages to `Litzy/Ingested` or marks them as
seen and archives them. Real `EXPUNGE` is a per-list opt-in behind a
two-phase commit and a SHA-256 check. Local Maildir and mbox import follow
the same trust chain. Every source feeds the same pipeline and the same
`list-id` verification, and uncertain messages are quarantined.

## Front-ends

The Flutter GUI and the CLI depend only on the protocol package. Each starts
the engine isolate and sends requests through the in-process transport. The
GUI presents an adaptive master-detail workspace on desktop and a stack on
mobile. The CLI offers the same operations in a scriptable form. No business
rule lives in either front-end.

## Boundaries

Data is classified as in ADR-0004: YAML under `data/` for declarative
configuration, SQLite for runtime state and environment or keychain for
secrets. Plugins extend the engine through typed interfaces for sources,
filters and agents, and cannot bypass the trust chain or the storage
policy. The remote repository is local, and `main` accepts only pull request
merges as described in `repository-security.md`.
