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

## R9 — Environment-driven configuration, superseded by R37

The original rule kept credentials out of source and versioned files, and
supplied configuration through `LITZY_*` environment variables loaded from a
git-ignored root `.env`, with `.env.example` documenting the variables.
The maintainer has since decided that the application, not an environment
file, manages credentials. This wording is preserved as history and is
superseded by R37 for every secret and for the whole configuration flow.

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

## R37 — Configuration and credentials are managed in the app through OAuth

The maintainer stated that a `.env` file would not be used for management
and that the app should manage everything through OAuth access and other
secure mechanisms of that kind. Credentials are entered and renewed inside
Litzy, using the OAuth flow of the provider where the provider supports it.
Tokens and passwords are stored in the operating system keychain as decided
in R35, and no `.env` file is part of the repository or of the supported
configuration flow. A provider without OAuth uses its secure credential
entry in the app, still kept in the keychain. Continuous integration may
inject non-secret settings as environment variables, but it never reads a
`.env` file and never stores a credential in a versioned file.

This decision supersedes the `.env` part of R9. It does not authorise any
remote service operated by the project, and it leaves R18 unchanged: no
telemetry, encryption at rest and no token between client and engine.

## R38 — GitHub-native enforcement replaces server-side hooks

The maintainer stated that a pre-receive hook will never be used, because a
public repository on GitHub does not offer that hook, and asked for a
GitHub-based alternative. Enforcement therefore lives entirely on GitHub.
Branch protection on `main` requires a pull request, applies to
administrators, and blocks force pushes and branch deletion. A required
status check named `pr-guard` comes from a GitHub Actions workflow on every
pull request. It verifies that the base is `main`, that the head branch is
named `pr/<number>-<slug>` with the pull request number, that the branch
carries exactly one commit, that its subject follows Conventional Commits,
and that no `Co-Authored-By` trailer names an agent, a model, a harness or an
automation account. A pull request that fails any of these checks cannot be
merged.

No versioned hook and no installed bare-mirror hook remain in the project.
The local bare repository is still an offline mirror, but it has no server-side
policy. This decision supersedes only the hook-based enforcement described in
R31 and ADR-0001; the pull request rule itself is unchanged. The two-parent
merge commit whose subject names the pull request remains the historical
evidence that every change came through a pull request.

## R39 — Mode B transport, authentication and command surface

For the real IMAP client the maintainer chose: "Password from keychain — Read
the password through CredentialVault and use RFC LOGIN. OAuth XOAUTH2 can be
added when provider adapters exist." The front-end reads the password from
the operating system keychain and passes it only through the typed in-process
bus to the engine. No password is written to SQLite, a versioned file, a log
or a `.env` file. XOAUTH2 is deferred until provider adapters exist.

The maintainer chose: "IMAPS 993, TLS required — Use SecureSocket by default;
a local test fixture can opt into plain sockets." Every connection to a
non-loopback host uses `SecureSocket` on port 993. Plain sockets are accepted
only for a loopback test host and are rejected for any remote address.

The maintainer chose: "Client plus typed Mode B verb — Add IMAP ingestion and
mailbox snapshot behind typed verbs, so purge and audit can use the real
client end to end." The RFC client sits behind `MailboxPort`, and the engine
owns the connection, the fetch, the verified persistence and the stored
mailbox policy. The front-end never speaks IMAP itself.

The maintainer chose: "Defer CLI command — Land the RFC client and typed Mode
B verb now, tested through the real engine isolate with a fake keychain
value. Add the CLI command when a platform SecretStore adapter exists." No
password flag, environment variable or interactive prompt is added to the CLI
in this slice. The decision is recorded in ADR-0015.

## R40 — Pure in-process Dart contract

The maintainer stated: "Taglia il wire protocol LMLP e InboundSmtpListener
(Mode A)" and "Trasforma protocol in un contratto puramente in-process
(interfacce Dart + Stream reattivi tra un background Isolate e la UI/CLI)".
The package named `protocol` remains the shared contract, but it contains
only Dart interfaces, immutable values and reactive streams. There is no
serialisation format, no remote procedure call layer, no WebSocket framing,
no protocol version handshake and no wire vocabulary. The engine is exposed
as an asynchronous `LmlpEngine` interface implemented on a dedicated isolate;
`SendPort` and `ReceivePort` are implementation details of that local hop and
not a protocol a front-end can send over a network. This supersedes the wire
framing language retained in R32 and `docs/lmlp-protocol.md`, while preserving
the typed in-process boundary itself. The decision is in ADR-0016.

## R41 — Public lists first, no inbound listener

The maintainer stated: "Sostituisci Mode A con un ingestor NNTP /
Public-Inbox" and "in pratica elimina tutta la parte infra/server nostra, solo
client". Mode A, the inbound SMTP listener, is permanently removed and cannot
return as a plugin without a new explicit decision. This closes Q6. The first
reading experience comes from NNTP or public-inbox mirrors such as
`nntp.lore.kernel.org` and `lore.kernel.org`, so `git@vger.kernel.org` can be
read without an email account, a domain or credentials. IMAP remains an
optional Mode B source for people who want their own mailbox. The decision is
in ADR-0018.

## R42 — Raw messages live on the filesystem

The maintainer stated: "Non salvare i blob .eml dentro il file SQLite". SQLite
keeps metadata, triage state, cursors, thread relations and the FTS5 index.
Raw messages are compressed on disk in a content-addressed folder shaped like
`blobs/ab/cd/<sha256>.eml.gz`, reached through the existing `BlobStore` port.
The compressed SQLite blob backend from R34 is superseded and is not the
default for any new profile. This keeps WAL checkpoints, vacuum and the FTS5
cache free of large message bodies. Existing profiles are migrated rather
than losing content. The decision is in ADR-0017.

## R43 — Purge stays opt-in on a local client

The maintainer stated: "Rendi l'EXPUNGE su IMAP opt-in, non il comportamento
predefinito". A local client cannot assume a server backup, so the default
IMAP action moves a message to a dedicated archive folder or marks it as
seen. Physical `EXPUNGE` requires an explicit per-list decision and still
passes the two-phase commit and SHA-256 gate of R15. This reinforces R15 and
does not weaken it.

## R44 — SQLite concurrency between front-ends

The maintainer stated: "Gestisci subito la concorrenza SQLite tra CLI
(litzy) e GUI (litzy-gui)". Every database open sets `journal_mode=WAL` and
`busy_timeout=5000` before schema access. A busy database must produce a
deterministic error rather than an unhandled process failure. A shared
write lock is added only if the two pragmas prove insufficient in an
acceptance test. No daemon or server process is introduced. The decision is
in ADR-0019.

## R45 — Credential-free dogfooding of the Git list

The maintainer stated: "proviamo quindi a leggere i mailing list di git.git
(git@vger.kernel.org), sia cli che gui, devi fare tu i test che non richiedono
credenziali". The next vertical slice reads that public list through the CLI
and the GUI using public data only. Tests use local fixtures and recorded
public messages, never an account, password or OAuth token. Reading is
separated from sending, so the slice does not depend on SMTP or on a platform
keychain adapter. The decision is tracked in the roadmap.

## R46 — Slack-like reading, Zulip-like thread depth

The maintainer defined the interface as "a metà tra Slack e Zulip": a left
sidebar of catalogue channels plus the cross-channel views for own threads,
unread mail and awaiting reply; a centre feed of topics ordered by last
activity with patch badges, unread counts and triage state; and a right pane
where a conversation reads like chat while preserving reply branches. Quote
folding collapses deeper citation levels by default, diffs render in
monospace with clear colour, selection can be quoted into the composer, and
sending uses Ctrl+Enter with a visible To and Cc preview rather than a bare
Enter. The maintainer added "conferme a non finire poi": the interface must
be defined once and then implemented, without repeated confirmation loops.
The decision is in ADR-0020 and its first read-only implementation is recorded
in ADR-0022.

## R47 — Clean local code conventions

The maintainer stated: "se la patch è valida, è valida e basta come principio"
and "1 file -> 1 classe (1 funzionalità, pulito)". A valid, focused patch is
accepted on its merits without ceremony beyond the permanent pull request
rules. One source file defines one public class with one reason to change.
The maintainer also stated: "no stringhe hardcoded di ogni tipo, tutte in
file esterni", "db in file .sql a parte", "no valori, solo chiavi, no cose
come \n \t \0 nel codice, usa cose fatte bene , ste cose mi sanno ti
zozzimma, tutto pulitissimo, tutto in yml". Code refers to keys rather than
literal values; user-visible text lives in Fluent resources, declarative
values in YAML and the schema in separate `.sql` files. Newline, tab and null
characters are never written as raw literals in source when a named
representation is possible. These conventions update the clean-code,
localisation and data-separation skills.

## R48 — Import, export and automatic transfer

The maintainer stated: "aggiungiamo la possibilità di import/export,
autoimport/autoexport". Litzy offers explicit import and export of profile
data and supports declarative automatic transfer rules. The first transfer
slice uses mbox and Maildir for import and mbox for export, because both
formats already exist in the local import path and need no remote service.
Automatic rules are versioned YAML under `data/rulesets` and run when a sync
completes; they write to a declared local directory and never perform a
destructive mailbox action without the existing verification gate. This
closes Q10 and is tracked in S12.

## R49 — Discoverability of the project

The maintainer stated: "definisci la descrizione giusta ed anche i tag giusti
per farmi trovare, voglio indicizzarmi, voglio fare un sacco di like e
utilizzatori". The project needs an accurate public description and a small
set of discoverability tags that describe a local-first mailing list reader
for technical lists. The description and the topics are defined in
`data/metadata/discoverability.yaml` and mirrored in the README. They are
then applied to the GitHub repository description and topics, which closes
Q11 and is tracked in S13. Claims must match implemented behaviour; a
planned feature is never advertised as present.

## Open questions

| # | Question | Status |
| :-- | :--- | :--- |
| Q1 | Should the Flutter GUI also target the web? The maintainer's phrase was desktop and mobile of every kind, which excludes the web. | Open, needs an explicit decision |
| Q2 | iOS builds need macOS tooling. Should CI use a macOS runner or should builds stay manual? | Open |
| Q3 | Should client-side rulesets be available offline? | Open |
| Q4 | Which SPDX license applies to the contributors named in the copyright notice? | Open |
| Q5 | Should the GUI and CLI share the engine in-process or over local IPC? | Closed by R32 and refined by R40: one local Dart isolate, no wire protocol |
| Q6 | Can the former inbound SMTP listener return as a plugin? | Closed by R41: permanently removed until a new maintainer decision |
| Q7 | Should cloud archiving ever be enabled, and who would operate it? | Parked by R20 |
| Q8 | Which literals must be moved out of source besides user-visible text, especially protocol delimiters and control characters? | Open, needs an explicit choice under R47 |
| Q9 | Should the Flutter GUI package be created now, or should the first credential-free slice prove the CLI against real Git list data? | Closed by the maintainer's explicit request for both: CLI first in S10, GUI next in S11, as recorded in R45 |
| Q10 | Which formats and triggers do import, export, autoimport and autoexport use in the first slice? | Closed by R48: mbox and Maildir import, mbox export, YAML rules triggered after sync |
| Q11 | Where are the public description and discoverability tags published? | Closed by R49: versioned YAML, README and GitHub repository metadata in S13 |
| Q12 | Is WAL with a five second busy timeout enough, or is a shared write lock needed from the first two-front-end test? | Closed by S9: two real processes write to one profile with WAL and a five second busy timeout, so no shared lock is added |
| Q13 | Should the thread builder and quote or diff analyzer be restored from the preserved backup or reimplemented against the current engine contract? | Closed: restore and adapt the preserved algorithms in S14, because their tests cover hostile reference chains and real patch bodies |

Decisions recorded in this cycle close the questions about front-end order,
transfer formats, publication place, algorithm provenance and SQLite
contention. Q8 stays open because its answer requires a tested code slice
rather than a naming choice.
