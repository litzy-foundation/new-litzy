# ADR-0006: Local blob storage instead of an object store

## Status

Accepted on 2026-11-28. This decision implements R34.

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

## Consequences

A user can back up the application by copying one file when the blob table
is selected, and deduplication comes for free with content addressing in
the folder variant. Large attachments may favour the folder variant because
they do not inflate the database. Tests must cover both backends through
the same port so neither becomes an untested alternative.
