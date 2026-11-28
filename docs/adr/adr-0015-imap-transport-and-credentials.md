# ADR-0015: IMAP transport and credentials

## Status

Accepted on 2026-11-28. This decision implements R10, R24, R35, R37 and R39.

## Context

Mode B reads the user's own mailbox with IMAP and then applies the mailbox
separation rules of ADR-0008. The earlier implementation provided only a small
`MailboxPort` and a fake mailbox for tests; no component spoke IMAP. The
maintainer chose password authentication through the keychain, required TLS,
asked for a typed verb that reaches the real client, and postponed the CLI
command until a platform keychain adapter exists.

An RFC-compliant client must not assume provider-specific folders, header
quirks or capability names. It also must not accept a password from a flag,
a versioned file or an environment variable, because R35 and R37 require the
operating system keychain to hold credentials.

## Decision

The engine owns an IMAP client that implements the small operations needed by
the purge coordinator: select a mailbox, fetch messages, mark them seen, move
them to another folder and expunge explicit unique identifiers. It implements
`MailboxPort`, so the two-phase purge and audit code does not change.

Connections use `SecureSocket` to port 993 by default. A plain socket is
allowed only when the host is a loopback address, so a local fixture can test
the wire protocol without weakening remote security. OAuth XOAUTH2 is deferred
until provider adapters exist; authentication uses RFC LOGIN with a password
the front-end reads through `CredentialVault`. The password crosses the
in-process typed bus only in memory and is never persisted or logged.

A typed Mode B verb connects the client, fetches messages, verifies the list
identifier and checksum before persistence, applies the stored per-list
mailbox policy through `PurgeCoordinator`, and returns a read-only inbox
snapshot for the audit verb. The CLI command waits for a platform
`SecretStore` adapter, so this slice has no way for a user to type a password
into the terminal.

## Consequences

Both front-ends can eventually use one engine path without duplicating IMAP
logic. Purge and audit run against a real mailbox through the same port used
by the fake in tests, and personal mail is never ingested because only
messages whose `List-Id` matches the selected list are accepted. TLS is a
transport default rather than an option, and the loopback exception is
validated in the engine so a remote host cannot downgrade.

Deferring the CLI command means the typed verb is exercised through the real
engine isolate with a test value rather than through the shipped binary. The
CLI stays free of insecure password entry, but a platform keychain adapter is
required before a user can run Mode B from the terminal. Providers that lack
the MOVE or UIDPLUS capabilities receive a deterministic error for the
affected mailbox action instead of a silent fallback that could delete mail.
