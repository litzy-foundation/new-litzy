# ADR-0021: Credential-free reading in the terminal

## Status

Accepted on 2026-11-28. This decision implements R45 and refines R13 and R24.

## Context

The engine already reads public lists through NNTP and public-inbox, and the
versioned catalogue names `git@vger.kernel.org`, but a daily reader still has
to supply a catalogue path and reason about message identifiers. The maintainer
asked to read that list through the CLI and the GUI with tests that require no
credentials. Requiring a password, an email account or a platform keychain for
public data would contradict R41, while putting catalogue defaults in Dart
would contradict R2.

## Decision

The engine resolves a default catalogue and source from versioned YAML under
`data/catalog`. The `sync` verb accepts explicit overrides but can be sent with
both paths omitted, so the terminal can refresh the Git list from public data
without a credential prompt. The CLI adds `channels` to list persisted
channels, `list` to summarise topics in one channel or across channels, and
`show` to reconstruct one thread with its parent links. These commands send
typed requests through the existing in-process engine contract and print
structured results. They never touch IMAP, SMTP or the keychain.

The resolver finds the nearest workspace root from the current directory, so
the source checkout works without configuration. Packaging places the same
YAML beside the installed client. Acceptance tests drive the real binary, the
real engine isolate and the real SQLite profile against local NNTP and
public-inbox fixtures that serve a recorded Atom feed, a gzipped mbox and an
NNTP conversation. The GUI reuses the same verbs in S11 rather than introducing
a second reading path.

## Consequences

A user can follow the Git list immediately after opening a profile, while an
explicit catalogue still supports another mirror or a test fixture. The engine
remains the only owner of catalogue resolution and trust checks, so the CLI and
GUI stay thin front-ends. Because the read path has no credential dependency,
its tests remain deterministic and the GUI can be built on the same verbs
without waiting for native keychain adapters.
