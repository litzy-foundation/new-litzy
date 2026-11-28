---
name: litzy-data-separation
description: REQUIRED when adding data or deciding where a kind of data belongs. Implements ADR-0004 and R2.
---

# Litzy data separation

Classify a piece of data before creating a file. Declarative data such as
rules, policies, the source catalogue and fixtures is versioned YAML under
`data/`. Runtime data such as messages, threads, triage state, cursors and
search indexes lives in the local SQLite database. Sensitive data such as
OAuth tokens and IMAP or SMTP passwords is acquired inside the app through
OAuth or a secure credential form and lives in the operating system keychain,
as required by R37. No `.env` file is used for management and no secret is
versioned.

Files under `data/` are pure data with no logic, no imports and no secrets.
A missing required field is an explicit startup error. The catalogue lives
under `data/catalog`, rulesets under `data/rulesets`, style tokens under
`data/ui`, discovery limits under `data/access` and fixtures under
`data/fixtures` with descriptive names. A local ignored directory under
`data/local` may hold development-only data that never enters the
repository. Tests load fixtures through a helper rather than inline strings.
An autoconfiguration policy holds limits and ports, never provider names or
secrets, as required by ADR-0025.
