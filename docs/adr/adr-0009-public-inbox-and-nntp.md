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
no verifiable list evidence is tagged `list-id:unverified` rather than
silently trusted. IMAP and SMTP remain optional and are needed only for
replying or for private lists.

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
extracted message. Mapping a catalogue entry to a channel and the end-to-end
proof through the engine remain in the roadmap.
