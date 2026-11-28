# Architecture

Litzy is one local client process with two isolated execution contexts. The
interface runs in the UI isolate and the engine runs in a Dart isolate started
by the same binary. They exchange immutable Dart values through an
asynchronous engine contract, as decided in ADR-0016. There is no socket, no
serialisation step, no wire protocol and no token between them.

## Engine contract

The `protocol` package is a pure Dart contract. It defines the `LmlpEngine`
interface, immutable values and streams for channels, thread trees and
messages. The engine implements the interface on its own isolate. Isolate
ports are hidden behind the client implementation, so a front-end never sees
a transport it could direct at a remote address. Both the terminal client and
the graphical client depend only on this contract and on shared value types.

## The engine

The engine owns every operation that changes state. It reads the local YAML
catalogue and rulesets, receives messages from ingestion sources, verifies
their list evidence, stores metadata in SQLite, builds threads with recursive
queries, maintains the FTS5 index and writes compressed raw messages to the
local blob folder. It also owns outbound operations, which remain separate
from reading. The engine is a package named `engine`, not a server, because it
never runs as an independent service.

## Storage

SQLite holds messages, thread relations, triage state, cursors, quarantine
ledger entries and the FTS5 index. The schema is versioned in separate `.sql`
files, and every open sets `journal_mode=WAL` and `busy_timeout=5000` before
accessing the schema, as decided in ADR-0019. Raw `.eml` content is compressed
and written to a content-addressed folder through `BlobStore`, as decided in
ADR-0017. The database stores the digest that points to the file. A backup is
the SQLite file together with the blob folder. Credentials are held by the
operating system keychain and never by either store.

## Ingestion

Mode C reads public lists directly through NNTP or public-inbox without an
email account and is the first path used for daily reading, as decided in
ADR-0018. The catalogue already names `git@vger.kernel.org` through
`lore.kernel.org`. Mode B vacuums the user's own mailbox but never deletes by
default: it moves ingested messages to an archive folder or marks them as
seen. Real `EXPUNGE` is a per-list opt-in behind a two-phase commit and a
SHA-256 check. Local Maildir and mbox import follow the same trust chain.
Every source feeds the same pipeline and the same `list-id` verification, and
uncertain messages are quarantined.

## Front-ends

The CLI is the first thin front-end and is the fastest way to dogfood real Git
list data. The Flutter GUI is a presentation layer over the same engine
streams, with catalogue channels and triage views on the left, a topic feed in
the centre and a branch-aware conversation on the right, as decided in
ADR-0020. User-visible text comes from Fluent resources rather than source
literals. No business rule lives in either front-end.

## Boundaries

Data is classified as in ADR-0004: YAML under `data/` for declarative
configuration, `.sql` files for schema, Fluent resources for interface text,
SQLite for runtime state and environment or keychain for secrets. Source
files define one public class each and refer to keys rather than literal
values. Plugins extend the engine through typed interfaces for sources,
filters and agents, and cannot bypass the trust chain or the storage policy.
The remote repository is local, and `main` accepts only pull request merges as
described in `repository-security.md`.
