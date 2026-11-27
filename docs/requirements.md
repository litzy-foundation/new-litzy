# Permanent requirements of Litzy

This file is the ultimate source of project requirements. Every statement
made by the maintainer that expresses a directive, a decision, a preference
or a change of course is recorded here in the same session. No agent may
weaken or delete an existing requirement; a change of mind is recorded as a
new explicit decision that supersedes the old wording, and both entries
point at each other. `AGENTS.md` is an operative summary of this file.

The repository was rebuilt from zero on 2026-11-28. The previous working
tree and history are preserved as a local copy outside the repository. The
requirements below carry forward the earlier directives and incorporate the
decisions taken for the rebuild.

## R1 — Every desktop and mobile platform

Litzy App targets every desktop and mobile platform: Linux, macOS, Windows,
Android and iOS. One codebase serves all of them, with an adaptive interface
that becomes a master-detail layout on desktop and a stack on mobile. The
web is not included at present. Details are in `multiplatform.md`.

## R2 — Data separated from code

Data never lives inside Dart source. Declarative configuration, the source
catalogue, rulesets and test fixtures are versioned YAML under `data/`.
Runtime data such as messages, threads, triage state and cursors lives in
the local SQLite database. Credentials live in the environment or the
operating system keychain. The decision is recorded in ADR-0004.

## R3 — Documentation-first

The maintainer asked permanently to document everything they say and to
remember it forever. Every directive, decision or feature is written into
this file or an ADR before or together with the implementation. Nothing is
done until it is documented.

## R4 — Agent-agnostic skills

Working conventions live in `.agents/skills` as plain Markdown with front
matter, valid for every agent. The relevant skill is loaded before work in
its area. Skills are project files and are updated in the same change as the
conventions they encode. The index is in `skills.md`.

## R5 — Dart best practices

Code is idiomatic and defensive: sound null safety, immutable value types,
exhaustive handling of sealed types, no unjustified `dynamic` and a strict
analyzer. The standards are in `engineering-standards.md`.

## R6 — SOLID and design patterns

Components respect SOLID and use the appropriate pattern in the appropriate
place, including ports and adapters, repositories, strategies and sum types.
The mapping onto the packages is in `engineering-standards.md`.

## R7 — Self-questioning

Before implementing, the awkward questions are asked and answered: scale,
failure safety, alternatives and cost. Open questions stay in the open
questions section of this file and close only with a recorded decision.

## R8 — Continuous improvement

Every slice ends with a review that asks whether it can be done better.
Refactoring is encouraged while the suite stays green.

## R9 — Environment-driven configuration

No credential appears in source, tests or versioned files. Configuration
arrives from `LITZY_*` environment variables, optionally loaded from a
git-ignored root `.env`, and `.env.example` documents every variable with a
placeholder. Non-secret defaults such as local ports are allowed.

## R10 — Email provider agnosticism

Every component that speaks IMAP or SMTP works with any RFC-compliant
provider. No provider-specific default, header quirk or path is hard-coded.
An exception requires an ADR and a port or adapter boundary.

## R11 — English documentation

All documentation, ADRs, skills and agent instructions are written in
English. Source comments are English as well.

## R12 — Copyright

Every source file carries the notice `Copyright (c) 2026 Alessio Attilio and
the litzy contributors` verbatim. The root `LICENSE` carries the same
notice. The SPDX license choice is an open question.

## R13 — Dual front-end

Litzy is usable as a Flutter GUI and as a terminal CLI. Both are thin
front-ends over the same embedded engine, the same protocol and the same
database. A feature reachable from one is reachable from the other when the
input and output make sense. The decision is in ADR-0010.

## R14 — 100 percent local-first embedded client

No server infrastructure is required. The engine runs inside the client
process on a separate Dart isolate, and the database is a single local
SQLite file. All workers, ingestion, threading and outbound operations are
embedded. There is no server the project operates and no network hop between
the front-end and the engine. The decision is in ADR-0002.

## R15 — Mailbox separation, with opt-in purge

Mailing-list mail must never appear in the user's regular mailbox. The
earlier wording required an immediate `EXPUNGE` after a verified commit.
That wording is superseded by this requirement, because automatically
deleting thousands of messages from a personal account on first sync is an
unacceptable risk.

The safe default keeps the original mail intact. An ingested message is
moved to a dedicated IMAP folder such as `Litzy/Ingested`, or marked with
`\Seen` and removed from the inbox, according to the user's choice. Real
`EXPUNGE` is an explicit opt-in that is enabled per list only after the user
trusts the flow. Even then it happens only after verified persistence, behind
the two-phase commit and SHA-256 verification of the existing pipeline.
Uncertain messages are quarantined and never silently deleted. The `audit`
verb verifies that no residual list mail remains in the inbox under the
currently selected policy. Mode C never touches a personal mailbox because
it reads public sources directly. The decision is in ADR-0008.

## R16 — Root-cause, production-ready engineering

Work is done at the root cause rather than patched on top. Failures are
explicit and deterministic, every failure path is tested, and persistence
is durable from the first slice. Documentation, tests and implementation
land together.

## R17 — Everything in-app

The user subscribes from Litzy, authenticates with their own email at any
RFC-compliant provider, and completes subscribe, receive, read, triage,
reply and unsubscribe inside the application.

## R18 — Maximum security with no leaks

Local data is encrypted at rest, secret buffers are handled with care and
nothing is telemetried. Because the client and the engine share a process,
there is no network link to protect: mTLS and tokens between them are
removed. Security effort goes into protecting IMAP and SMTP passwords on the
user's disk through the operating system keychain, and into the encryption
of the local database. The decision is in ADR-0007 and ADR-0012.

## R19 — Plugins, RSS and newsletters

A typed plugin system handles sources, filters and agents. Newsletters,
feeds and lists share one destination and one governance surface. Content
extracted from a mailbox leaves that mailbox, as required by R15.

## R20 — Paid cloud archiving, parked

Cloud archiving and a paid plan remain a future option. They are frozen at
zero cost: no hosted service is operated now, and pricing is versioned data
under `data/` if it is ever enabled. This requirement does not authorise any
infrastructure work.

## R21 — Local language model agent

A local-only agent produces brief thread summaries. It adapts to available
hardware, supports multiple models and runs as a sandboxed plugin. Content
never leaves the machine.

## R22 — The ecosystem

The long-term ambition is one ecosystem around mailing lists, feeds and the
various kinds of asynchronous junk: several sources, one governance surface,
optional intelligence and typed extensions.

## R23 — Zero-infrastructure perimeter

The local-first pivot is the product, not a compromise. PostgreSQL and MinIO
adapters are not shipped. The engine package is named `packages/engine`,
which makes its in-process role explicit. Mode A, the inbound SMTP listener,
is removed: it requires a domain, MX records and an always-on server, which
contradicts the zero-infrastructure requirement. It may return as a future
plugin only after a new decision. The free perimeter is the local machine;
any remote publishing is an explicit human action. The decision is in
ADR-0002.

## R24 — Ingestion sources and Mode C

Mail reaches Litzy only from sources that run on the user's machine. They
are:

- Mode B, IMAP vacuum of the user's own mailbox, with the opt-in purge
  policy of R15.
- Mode C, direct reading from NNTP servers such as `nntp.lore.kernel.org`
  and from public-inbox mirrors through Atom feeds and `.mbox.gz`
  downloads. A local YAML catalogue under `data/catalog/` lets a user pick
  `git@vger.kernel.org` or a kernel list and read threads without an email
  account.
- Local Maildir and mbox import for users who already synchronise mail with
  mbsync, isync or offlineimap.

The maintainer's words for Mode C are that it offers a magical experience
without even asking for an email account, and that IMAP and SMTP stay
optional, only for people who want to reply or follow private lists. The
decision is in ADR-0009.

## R25 — Threading with SQLite recursion and full-text search

The earlier design stored threads through a fixed-width materialized path
and explicitly avoided recursion. That restriction is superseded by this
requirement. The current choice is SQLite with Drift, `WITH RECURSIVE`
queries for deep thread trees and FTS5 for search. SQLite handles deep trees
in milliseconds without an external dependency. The old materialized-path
entry is kept here as history: it was replaced because the recursive engine
is simpler and the dependency cost is zero. The decision is in ADR-0005.

## R26 — Simplified outbound

Authenticated SMTP to the user's provider is the main path. A sendmail or
msmtp pipe transport reuses the local `git send-email` setup. DKIM is
strictly opt-in for own-domain users. The thread view exports a series as
patch files or one mbox.

## R27 — End-to-end acceptance

Acceptance tests open the real application with the real binary, the real
engine and the real database and perform the flows. In-process fakes test
algorithmic cores but do not by themselves constitute acceptance.

## R28 — Pure prose documentation

Documentation is clean English prose with no emoji, no decorative markers
and no status symbols in place of words. The style guide is in
`.agents/skills/writing-documentation`.

## R29 — Agent-agnostic skills

General skills live in `.agents/skills` with plain front matter and are
valid for every agent, not only one vendor's tooling.

## R30 — Agents are never co-authors

The maintainer stated that the agent must not put itself in the co-authors,
as a permanent rule. An agent never adds itself, its model, its harness or
any of its tools to a commit trailer. No `Co-Authored-By` trailer naming an
agent or automation account is allowed. Only real human contributors are
credited, with their real name and address. This rule applies to every
commit in the rebuilt repository, including bootstrap and documentation
commits. The decision is in ADR-0001.

## R31 — Pull requests by default for everything

The maintainer stated that work proceeds only through pull requests by
default, and confirmed that the rule covers the initial commits of the
rebuild. Every change, including docs, data and configuration, lands on
`main` through a pull request. No agent commits directly to `main`. Locally
a pull request is represented by a topic branch merged with a merge commit.
The empty root commit that makes a new repository addressable carries no
content. The decision is in ADR-0001.

## R32 — LMLP as a typed in-process bus

The protocol package is kept, and JSON serialisation over WebSocket is
removed. An `InProcessLmlpTransport` passes typed messages between the UI
isolate and the engine isolate through `SendPort` and `ReceivePort`. This is
what allows one engine and one protocol to serve both the terminal client
and the Flutter application without duplicating logic. The decision is in
ADR-0003.

## R33 — The engine package

`packages/server` is renamed to `packages/engine`. The name states that the
component is an embedded engine running on a Dart isolate separate from the
UI, not a server. The decision is in ADR-0002.

## R34 — Local blob storage

MinIO and any object store are replaced by local storage. Raw `.eml` content
is kept either in a compressed SQLite blob table using Zstd or in a local
content-addressed `sha256/` folder. For messages below roughly 100 KB,
SQLite is often faster than the filesystem and gives an atomic backup in a
single database file. The decision is in ADR-0006.

## R35 — Secrets in the operating system keychain

The earlier M5 idea of mTLS or tokens between front-end and engine is
replaced by operating system keychain storage using `flutter_secure_storage`
on mobile and libsecret or the equivalent on desktop. With no network
between client and engine, security protects IMAP and SMTP passwords on the
user's disk. The decision is in ADR-0007.

## R36 — One commit per pull request, and a brief body from an agent

The maintainer stated that the standard for a pull request is always one
commit, and then showed the body of the foundation pull request as the style
they like for an agent: short, concrete and limited to what the change
establishes, what it records and what it does not include. A topic branch
therefore carries a single commit with its documentation and tests together,
and an agent opens the pull request with a brief body in that style. The
body states the purpose of the slice and its scope in a few sentences; it
does not claim human authorship or turn into a long narrative. The human
maintainer may expand the body during review. The rule is recorded in the
pull request template under `.github`, in `CONTRIBUTING.md` and in
`AGENTS.md`.

## Open questions

| # | Question | Status |
| :-- | :--- | :--- |
| Q1 | Should the Flutter GUI also target the web? The maintainer's phrase was desktop and mobile of every kind, which excludes the web. | Open, needs an explicit decision |
| Q2 | iOS builds need macOS tooling. Should CI use a macOS runner or should builds stay manual? | Open |
| Q3 | Should client-side rulesets be available offline? | Open |
| Q4 | Which SPDX license applies to the contributors named in the copyright notice? | Open |
| Q5 | Should the GUI and CLI share the engine in-process or over local IPC? | Closed by R32: in-process typed LMLP |
| Q6 | Can the former inbound SMTP listener return as a plugin? | Open, requires a new ADR after R23 |
| Q7 | Should cloud archiving ever be enabled, and who would operate it? | Parked by R20 |
