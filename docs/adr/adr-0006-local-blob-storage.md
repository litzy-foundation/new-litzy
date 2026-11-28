# ADR-0006: Local blob storage instead of an object store

## Status

Accepted on 2026-11-28. This decision implements R34. The compressed SQLite
blob option is superseded by ADR-0017; the content-addressed folder remains
and becomes the only active backend.

## Context

Raw messages were previously kept in MinIO as `.eml` blobs. An object store
is a service to operate and a second place to back up. The maintainer chose
local storage, observing that for files below roughly 100 KB SQLite is
often faster than the filesystem and gives atomic backups in a single
database file.

## Decision

Raw message content is stored locally in one of two equivalent ways: a blob
table in the SQLite database with Zstd compression, or a content-addressed
folder named by SHA-256 digest under the profile data directory. The
database remains the index and the authority for which content exists. No
object store adapter is shipped. The choice between the two local backends
is a configuration decision and both implement the same port.

Both backends are now implemented behind a single `BlobStore` port with
`put`, `get` and `verify`. The folder backend writes raw bytes to a file named
by the SHA-256 digest. The SQLite backend stores a Zstd frame together with
the codec name and the uncompressed size, and accepts a row only when
decompression, size and digest all agree. A front-end selects the backend
through the typed open request, so the choice belongs to profile
configuration rather than to ingestion or mailbox logic. The folder remains
the default so existing profiles keep their current layout.

## Consequences

A user can back up the application by copying one file when the blob table
is selected, and deduplication comes for free with content addressing in
both variants, because a repeated digest inserts no new row or file. Large
attachments may favour the folder variant because they do not inflate the
database. The Zstd frame is bounded on read by the recorded uncompressed
size and by a maximum, so a hostile payload cannot request an unbounded
allocation. Tests cover both backends through the same port, including
corrupted content and a backup taken from the SQLite profile.
