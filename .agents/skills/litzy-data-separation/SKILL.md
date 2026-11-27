---
name: litzy-data-separation
description: REQUIRED when adding data or deciding where a kind of data belongs. Implements ADR-0004 and R2.
---

# Litzy data separation

Classify a piece of data before creating a file. Declarative data such as
rules, policies, the source catalogue and fixtures is versioned YAML under
`data/`. Runtime data such as messages, threads, triage state, cursors and
search indexes lives in the local SQLite database. Sensitive data such as
IMAP and SMTP passwords lives in the environment or the operating system
keychain and never in a versioned file.

Files under `data/` are pure data with no logic, no imports and no secrets.
A missing required field is an explicit startup error. The catalogue lives
under `data/catalog`, rulesets under `data/rulesets` and fixtures under
`data/fixtures` with descriptive names. A local ignored directory under
`data/local` may hold development-only data that never enters the
repository. Tests load fixtures through a helper rather than inline strings.
