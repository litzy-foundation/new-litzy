# ADR-0009: Mode C, direct public-inbox and NNTP ingestion

## Status

Accepted on 2026-11-28. This decision implements R24.

## Context

Mode B alone forces a user to subscribe to a mailing list with their own
address and to configure IMAP and SMTP even when they only want to read.
Public technical lists are available without an account: NNTP servers such
as `nntp.lore.kernel.org` expose them as newsgroups with zero authentication
and incremental fetching by article range, while public-inbox mirrors such
as lore expose Atom feeds and whole threads as a single `.mbox.gz` request.
The maintainer asked to add Mode C for this direct path.

## Decision

A local YAML catalogue under `data/catalog` lists known sources with their
address, protocol, list identifier and mirror endpoints. Selecting an entry
such as `git@vger.kernel.org` creates a channel and starts ingestion without
any email credential. The NNTP adapter speaks the text protocol, maps
newsgroups to channels and uses article ranges for incremental fetches. The
public-inbox adapter reads Atom feeds for discovery and downloads a thread
as a compressed mbox for complete content. Both sources deliver into the
same pipeline as Mode B and follow the same trust chain, so a message with
no verifiable list evidence is either rejected or tagged `list-id:unverified`
rather than silently trusted. IMAP and SMTP remain optional and are needed
only for replying or for private lists.

## Consequences

Reading a public list becomes a three-second operation after installation,
with no account and no mailbox pollution. The catalogue is data, so new
lists arrive as reviewable YAML changes. The engine gains two network
clients that must be bounded and tested against local fixture servers, and
compressed mbox parsing must be hardened because it consumes untrusted
input.

The first implementation ships both clients with bounded requests and typed
failures. The public-inbox adapter validates atom entries and thread
identifiers before reading a gzipped mbox, and computes a digest for every
extracted message. A catalogue entry maps to a persisted channel, and an
end-to-end proof reads a thread from a local HTTP fixture through the real
SQLite database. The first ingestor rejects a message whose List-Id does not
match the channel, which implements the trust chain more strictly than
tagging. NNTP articles now convert onto the same path, and sync is a typed verb that
lets either front-end refresh a channel.

Incremental state is a cursor row keyed by channel in the local database, as
required by ADR-0004. The NNTP cursor is the highest overview article number
already fetched, so the next sync requests only later articles. The
public-inbox cursor keeps the most recently seen thread identifiers, so the
next sync still reads the small atom feed but skips the compressed mbox of a
thread it already fetched. A cursor advances only after the batch commits,
and a rejected batch leaves it unchanged.
