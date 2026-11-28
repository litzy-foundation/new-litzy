# ADR-0017: Filesystem content-addressed blobs

## Status

Accepted on 2026-11-28. This decision implements R42 and supersedes the
compressed SQLite blob option in ADR-0006.

## Context

The earlier design allowed raw `.eml` content to live in a compressed SQLite
blob table because a single file was convenient for backup. The maintainer
stated: "Non salvare i blob .eml dentro il file SQLite". A busy list such as
`git@vger.kernel.org` can reach tens of thousands of messages. Large bodies in
SQLite inflate WAL checkpoints, slow vacuum work and disturb the FTS5 cache.
A local client already has a filesystem, so the database should hold only the
index and the digest that points to a file.

## Decision

SQLite stores metadata, triage state, cursors, thread relations, search
indexes and the SHA-256 digest of each raw message. Compressed raw messages
live on disk in a content-addressed folder shaped like
`blobs/ab/cd/<sha256>.eml.gz`. The existing `BlobStore` port remains the only
way ingestion and verification reach the bytes. The compressed SQLite backend
is not selected for any new profile and will be removed from the active path
in a migration slice. Existing content is moved to the folder rather than
deleted.

## Consequences

WAL checkpoints and vacuum operate on small rows, and FTS5 keeps a cache that
is proportional to indexed text rather than message bodies. A backup becomes
the SQLite file plus the local blob folder, which the application can package
together. Verification still uses the stored digest, so a corrupt file is
quarantined with the same code path as before. The migration must prove byte
identity before removing an old SQLite row, and it is tracked in the roadmap.
