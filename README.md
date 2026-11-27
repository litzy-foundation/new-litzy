# Litzy

Litzy is a local-first application for reading, triaging and answering
mailing lists, newsletters and feeds. Its defining property is that list
traffic never enters the personal mailbox. A user can open a list from a
local catalogue and read real threads without an email account, a server
or any infrastructure.

The engine runs inside the client process on a separate Dart isolate. It
stores messages, threads, triage state and raw content in one local SQLite
database. A Flutter GUI and a terminal CLI are thin front-ends over the same
typed protocol and the same data. There is no JSON-over-WebSocket boundary
between them: messages cross the isolate boundary as typed LMLP messages
through `SendPort` and `ReceivePort`.

Public technical lists are reachable directly through NNTP and public-inbox
mirrors, which are grouped under Mode C. Authenticated IMAP and SMTP remain
optional, for users who want to vacuum their own mailbox or reply from their
own address. When IMAP is used, Litzy never deletes mail by default: ingested
messages are moved to a dedicated folder or marked as read and archived. A
real `EXPUNGE` is available only as an explicit per-list opt-in, guarded by
the same two-phase commit and checksum verification that has always protected
the ingestion path.

## Design commitments

All decisions are recorded in `docs/requirements.md` and in the ADRs under
`docs/adr/`. The short version is that everything stays on the user's
machine. Configuration and fixtures are declarative YAML under `data/`,
runtime state lives in SQLite, credentials are kept in the operating system
keychain, and no plaintext secret is ever versioned. Nothing is sent to a
service operated by the project.

Contributions follow the rules in `CONTRIBUTING.md`. Every change reaches
`main` through a pull request, and automated agents never add themselves or
their tools as co-authors of a commit.

## Repository layout

| Path | Purpose |
| :--- | :--- |
| `packages/protocol` | Typed LMLP messages and the in-process transport |
| `packages/engine` | Ingestion, threading, SQLite storage and outbound work on a dedicated isolate |
| `packages/core` | Parsing, threading algorithms and domain value types |
| `packages/l10n` | User-visible strings |
| `packages/app` | Flutter GUI for desktop and mobile |
| `packages/cli` | Terminal client over the same engine |
| `data` | Versioned YAML catalogue, rulesets and fixtures |
| `docs` | Requirements, decisions, roadmap and problem register |
| `.agents/skills` | Agent-agnostic working skills |

## Getting started

Toolchains are pinned with mise. Run `dart pub get` and `dart run melos
bootstrap` from the repository root, then `dart run melos run analyze` and
`dart run melos run test`. Detailed commands are in `docs/development.md`.

## Documentation

Start from `docs/requirements.md` for the permanent directives,
`docs/architecture.md` for the shape of the system, `docs/lmlp-protocol.md`
for the typed bus and `docs/roadmap.md` for the current work.
