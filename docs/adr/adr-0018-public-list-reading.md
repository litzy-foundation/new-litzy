# ADR-0018: Public list reading before private mailbox work

## Status

Accepted on 2026-11-28. This decision implements R41 and closes the plugin
question in Q6.

## Context

Mode A was an inbound SMTP listener that required a domain, MX records and an
always-on server. The maintainer stated: "Sostituisci Mode A con un ingestor
NNTP / Public-Inbox" and "in pratica elimina tutta la parte infra/server
nostra, solo client". Public technical lists are already mirrored by NNTP and
public-inbox, and `lore.kernel.org` exposes the Git list without an email
account. The fastest way to validate the reader is to follow that public data
from the terminal before building a graphical interface or asking for a
password.

## Decision

Mode A is permanently removed and does not return as a plugin without a new
maintainer decision. The first reading path is NNTP or public-inbox from the
versioned catalogue, with `git@vger.kernel.org` as the dogfooding target.
IMAP stays as optional Mode B for users who want to read their own mailbox,
and its purge remains opt-in as recorded in R15 and R43. The CLI and the GUI
consume the same engine verbs over the pure local contract of R40.

## Consequences

The project can be used daily with no infrastructure and no credentials, so
parser and threading edge cases surface from real Git threads while the GUI
is still small. Tests use local NNTP, HTTP and mbox fixtures and never need an
account. Users who only follow public lists never configure IMAP or SMTP.
Sending remains a separate slice and is not a precondition for reading.
