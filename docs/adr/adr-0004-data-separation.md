# ADR-0004: Data separated from code

## Status

Accepted on 2026-11-28. This decision implements R2 and R9.

## Context

The maintainer requires that declarative data stay out of Dart source and
that no secret be versioned. A local YAML source catalogue is needed for
Mode C, along with rulesets and fixtures. Runtime state changes constantly
and does not belong in a versioned file.

## Decision

Declarative configuration, the list catalogue, rulesets and fixtures live
as YAML under `data/`, outside the packages. Runtime data such as messages,
threads, cursors and triage state lives in the local SQLite database.
Credentials are entered in the application through OAuth or a secure
credential form and are kept in the operating system keychain, as decided
in R37. No `.env` file is part of the supported configuration flow and no
credential is versioned. A missing required field in a data file is an
explicit startup error.

Triage state consists of two booleans per message: whether the message has
been read and whether the user starred it. Both live in the `messages` table
so an existing profile gains them through a migration. The engine exposes
one verb to change a flag and one to read both back, and the front-ends never
write SQLite directly. Draft replies also live in SQLite because they are
mutable runtime state, not declarative configuration.

## Consequences

Catalogue changes are reviewable in pull requests without touching code.
Tests can use named fixtures instead of inline strings. Secrets never enter
the repository. A small amount of validation code is needed at startup to
check the YAML before it reaches the engine.
