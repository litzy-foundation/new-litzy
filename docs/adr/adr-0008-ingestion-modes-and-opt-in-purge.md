# ADR-0008: Ingestion modes and opt-in purge

## Status

Accepted on 2026-11-28. This decision implements R15 and supersedes the
earlier automatic purge rule.

## Context

The old server-side model deleted list mail with `EXPUNGE` immediately after
a verified transaction. In a local-first client that behaviour is dangerous:
a user who connects a personal Gmail or ProtonMail account to try Litzy
could lose thousands of messages on the first sync, especially when several
devices are involved. The maintainer required purge to be opt-in rather
than automatic.

## Decision

Litzy supports three ingestion modes. Mode C reads public sources directly
and never touches a personal mailbox. Mode B vacuums the user's own mailbox
but, by default, only moves ingested messages to a dedicated folder such as
`Litzy/Ingested`, or marks them as seen and archives them, according to the
user's choice. Real `EXPUNGE` is an explicit opt-in enabled per list only
after the user trusts the flow. Even in that mode, deletion occurs only
after verified persistence, through the two-phase commit with SHA-256
verification. Doubtful messages are quarantined. The `audit` verb reports
residual list mail under the active policy.

## Consequences

First-run behaviour is safe and reversible, and multi-device users keep
their mail. Users who want a clean inbox still have a path to real deletion,
protected by the same transaction that already made the pipeline durable.
The implementation needs a per-list policy in configuration, a folder
creation step, and tests that prove the default never deletes while the
opt-in deletes only after verification.

The first implementation keeps policies and preparations in the local SQLite
database, uses `MailboxPort` as the boundary to a mailbox, and quarantines
doubtful messages in a durable ledger. A SHA-256 digest binds the accepted
candidates to a preparation; the second phase recomputes it and rechecks the
stored bytes before any mailbox action. The same boundary now has a real IMAP
implementation, recorded in ADR-0015.

The audit verb is now typed and read-only. It accepts a snapshot of inbox
messages gathered by the front-end's mailbox reader and lets the engine apply
the stored per-list policy and quarantine ledger, so no front-end decides
what counts as residual list mail. The verb never moves, marks or deletes a
message. The real IMAP client fills the same snapshot without changing the
verb or its response.

A real RFC-compliant IMAP client now implements `MailboxPort` and supplies the
snapshot. A typed Mode B verb connects it, verifies the selected list before
persistence and applies the stored policy through the purge coordinator. Its
transport and credential choices are recorded in ADR-0015. The client never
chooses a mailbox action on its own; the stored policy and the two-phase gate
remain authoritative.
