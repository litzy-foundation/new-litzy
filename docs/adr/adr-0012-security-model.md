# ADR-0012: Security model for a local-first client

## Status

Accepted on 2026-11-28. This decision implements R18.

## Context

The application handles personal mail credentials and potentially hostile
message content. With no client-to-engine network boundary, the meaningful
protections are the local database, the keychain and the parsing boundary.
The maintainer requires maximum security with no leaks of data or memory.

## Decision

The SQLite database is encrypted at rest with a key derived by Argon2id and
used with AES-256-GCM. The key is never logged or stored in clear. IMAP and
SMTP credentials live in the operating system keychain as decided in
ADR-0007. There is no telemetry and no third-party analytics. Outbound
traffic occurs only to sources and destinations the user configured.
Untrusted input such as MIME bodies, Atom feeds and mbox archives is parsed
behind strict size and depth limits, with sanitised rendering. Secrets are
zeroed after use where the language and platform allow it.

## Consequences

The single-file backup is encrypted, so moving it to another machine
requires the user secret. Some platform work is needed for keychain and
secure memory. Every parser needs fuzz-style tests, and failures degrade
explicitly instead of leaking content. The lack of a network hop removes a
whole category of interception risk.
