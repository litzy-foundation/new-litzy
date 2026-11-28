# AGENTS.md — permanent directives

This file is binding for every agent working in this repository. The
authoritative source is `docs/requirements.md`, which must be read at the
start of every session. In case of contradiction, the requirements win.

## Working rules that apply to every session

An agent works entirely on the local machine. It does not push, does not
create remote branches and does not open remote pull requests unless the
maintainer explicitly asks for that action in the current session. No local
data is removed as a side effect of work.

Every change reaches `main` through a pull request, including documentation,
configuration and data. The `main` branch is read-only and the authoritative
remote is `litzy-foundation/new-litzy`, created from zero with the GitHub
CLI. An agent never commits directly to `main` and never pushes arbitrary
branches. It works on a topic branch, pushes it to the remote as
`pr/<number>-<slug>`, and the maintainer merges it
through a two-parent merge commit whose subject names the pull request.
GitHub branch protection and the required `pr-guard` status check enforce
this and reject agent co-author trailers; no server-side hook is used. The
empty root commit of a new repository is the only direct commit on `main`,
and it carries no content. The full model is in `docs/repository-security.md`.

An agent never adds itself, its model, its harness or its tools as a
co-author. No commit created by an agent carries a `Co-Authored-By` trailer
for an agent or automation account. Only real human contributors are
credited. This rule is permanent.

Documentation is written before or together with code. Every directive
stated by the maintainer is crystallized into `docs/requirements.md` and
summarized here in the same session. Architectural choices land as ADRs with
Context, Decision and Consequences. Nothing exists only in a conversation.

Documentation is English prose without emoji or decorative markers. Every
source file carries the notice `Copyright (c) 2026 Alessio Attilio and the
litzy contributors` verbatim. Secrets enter the app through OAuth or a secure
credential form and live in the operating system keychain, never in a
versioned file or a `.env` file.

## Permanent directives

1. Multiplatform (R1): Linux, macOS, Windows, Android and iOS from one
   codebase, with an adaptive user interface. The web is out of scope for
   now.
2. Data separation (R2): declarative configuration and fixtures in `data/`,
   runtime state in SQLite, secrets in environment or keychain.
3. Documentation-first (R3): document everything the maintainer says; a
   feature without documentation is not done.
4. Agent-agnostic skills (R4): load the relevant skill from
   `.agents/skills` before work in its area and update skills with the
   conventions they describe.
5. Dart quality (R5 and R6): idiomatic, immutable, sound Dart with explicit
   error types and SOLID boundaries.
6. Self-questioning (R7): ask the uncomfortable questions before
   implementing and keep open questions in the requirements file.
7. Continuous improvement (R8): close every slice by asking whether it can
   be done better and keep the suite green.
8. In-app secure configuration (R37, superseding the `.env` flow in R9): no
   `.env` file and no credential in a versioned file; OAuth and secure
   credential entry are managed by the app and tokens live in the OS keychain.
9. Provider agnosticism (R10): any RFC-compliant IMAP or SMTP provider works
   without special cases.
10. English documentation (R11) and pure prose (R28).
11. Copyright (R12) on every source file.
12. Dual front-end (R13): GUI and CLI are thin clients over the same engine.
13. Local-first embedded client (R14): the engine runs in a Dart isolate
    inside the client process, and SQLite is the only active store.
14. Mailbox separation (R15): list mail never enters the personal mailbox.
    Purge is opt-in; the default keeps mail out of harm's way and real
    `EXPUNGE` requires an explicit per-list decision plus two-phase commit
    and SHA-256 verification.
15. Root-cause engineering (R16): docs, tests and implementation land
    together with tested failure paths.
16. Everything in-app (R17): subscribe, receive, read, triage, reply and
    unsubscribe from Litzy.
17. Security (R18): encryption at rest, OS keychain for credentials, no
    telemetry and no mTLS or token between client and engine because they
    share a process.
18. Plugins and ecosystem (R19 and R22): sources, filters and local agents
    share one governance surface.
19. Paid cloud (R20) is parked at zero cost and is not implemented.
20. Local LLM (R21): local-only, brief, hardware-adaptive and sandboxed.
21. Problem register: every raised problem stays in
    `docs/milestone-issues.md` until it has evidence of closure.
22. Zero infrastructure (R23): no PostgreSQL, no MinIO, no inbound SMTP
    listener, and no service operated by the project.
23. Ingestion sources (R24): Mode B IMAP vacuum, Mode C NNTP and
    public-inbox with a local YAML catalogue, plus Maildir and mbox import.
24. Threading (R25): SQLite recursive queries with FTS5; the earlier
    materialized-path restriction is superseded.
25. Simplified outbound (R26): authenticated SMTP, sendmail or msmtp pipe,
    opt-in DKIM and patch or mbox export.
26. End-to-end acceptance (R27): tests drive the real binary, engine and
    database.
27. PR-only (R31) and no agent co-authors (R30), as stated above. A pull
   request carries exactly one commit, and an agent writes a brief body that
   states the purpose and scope of the slice in a few sentences (R36).
28. Typed in-process bus (R32): LMLP messages cross the UI and engine
    isolates through `SendPort` and `ReceivePort`, never as JSON.
29. Engine package (R33): the engine lives in `packages/engine`.
30. Local blobs (R34): compressed SQLite blobs or a local content-addressed
    folder, with no object store.
31. OS keychain secrets (R35 and R37): `flutter_secure_storage` and libsecret
    hold OAuth tokens and credentials entered in the app.
32. GitHub-native enforcement (R38): no pre-receive hook; branch protection
    and the required `pr-guard` status check enforce the pull request flow.
33. Mode B transport (R39): the IMAP client uses IMAPS 993 with TLS by default,
    reads the password from the keychain through `CredentialVault` and speaks
    RFC LOGIN. Plain sockets are limited to loopback fixtures. The typed Mode B
    verb lands before its CLI command, which waits for a platform `SecretStore`.
34. Pure local contract (R40): `protocol` is Dart interfaces, immutable values
    and streams only, with no wire protocol, serialisation or remote framing.
    The engine is a local isolate behind `LmlpEngine`.
35. Public lists first (R41): NNTP and public-inbox replace the permanently
    removed inbound SMTP listener. The Git list is readable without an account.
36. Filesystem blobs (R42): SQLite holds metadata and FTS5; raw compressed
    `.eml` files live in a content-addressed local folder through `BlobStore`.
37. Opt-in purge (R43): IMAP defaults to move or mark as seen; physical
    `EXPUNGE` needs an explicit per-list decision plus the verification gate.
38. SQLite concurrency (R44): every open sets WAL and a five second busy
    timeout before schema access, with no daemon and no server process.
39. Credential-free dogfooding (R45): the next vertical slice reads
    `git@vger.kernel.org` in CLI and GUI using local fixtures and public data.
40. Chat-like reading (R46): channels, topic feed and branch-aware thread pane,
    with quote folding, diff rendering, selection quoting and Ctrl+Enter send.
41. Clean code (R47): one public class per file, keys instead of literal
    values, Fluent text, YAML data and separate `.sql` schema files.
42. Import and export (R48): explicit transfer plus declarative automatic
    rules, never bypassing the verification gate.
43. Discoverability (R49): one accurate public description and a small set of
    truthful tags for the local-first mailing list reader.
44. Agent-tested binaries (R50): the agent runs a real acceptance test on every
    binary it builds or changes, including the compiled GUI client. Widget and
    engine-backed tests alone do not close a binary slice.
45. SQL resources (R51): SQL lives only in standalone `.sql` files loaded by
    key, never embedded in Dart source.
46. Named control characters (R52): control escapes never appear in Dart
    source; `TextTokens` and a validation function provide their equivalent.
47. Automatic access (R53): the user enters only an email address; discovery
    is provider agnostic, TLS is mandatory, and credentials come from OAuth or
    a secure form into the OS keychain with no plaintext or avoidable
    vulnerabilities.
48. App style and baseline (R54): one declarative style across all targets,
    plus the identity, setup, settings, states and secure lifecycle that make
    Litzy a real application.

## Fixed operational rules

Toolchains come from mise and melos is a root dev dependency. Package names
carry no prefix. `dart analyze` at zero, clean formatting and green tests
are merge conditions. TDD is mandatory for parsing, threading, ingestion and
purge. Targeted tests run during iteration and the full suite runs in
continuous integration. Conventional Commits and atomic changes are the
norm. IMAP `EXPUNGE` never happens without the two-phase commit and the
checksum gate. The current plan is in `docs/roadmap.md`.
