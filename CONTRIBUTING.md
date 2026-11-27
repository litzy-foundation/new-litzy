# Contributing to Litzy

This file is binding for every contributor, including automated agents. The
permanent requirements live in `docs/requirements.md`; when this file and the
requirements disagree, the requirements win.

## Everything stays local

Work is performed on the contributor's own machine. The project does not
depend on a hosted service, and this repository does not push changes to a
remote automatically. Publishing to a remote is a separate, explicit action
that requires a decision by the maintainer. Agents never push, never create
remote branches and never open remote pull requests unless the maintainer
explicitly asks for that action in the current session.

Local data is never removed as a side effect of development. A rebuild of
the repository keeps a complete local copy of the previous state before any
destructive step. Runtime user data is never deleted to make a test pass.

## Every change goes through a pull request

Nothing lands directly on `main`. Every change, including documentation,
configuration, data files and code, is made on a topic branch and reaches
`main` through a pull request. The `main` branch is read-only: it accepts
only a two-parent merge commit whose subject names the pull request. An
agent must not commit to `main` under any circumstance, including a
bootstrap commit, an emergency fix or a change that appears trivial. The
only commit created directly on `main` is the empty root commit that makes a
new repository addressable; it contains no content.

The authoritative remote is `litzy-foundation/new-litzy`, created from zero
with the GitHub CLI. It has a local bare mirror for offline work. A
contributor pushes a finished topic branch to the remote as
`pr/<number>-<slug>` and opens a pull request. After review the maintainer
merges it into `main` with a merge commit. GitHub branch protection rejects
direct writes to `main`, force pushes and deletions. The required `pr-guard`
status check runs on every pull request and rejects a wrong base, a wrong
branch name, more than one commit, a non-conventional subject or an agent
co-author trailer. No server-side hook is used, as required by R38. The rules
and the commands are in `docs/repository-security.md`.

That merge history is the evidence of the workflow and is preserved. Review
happens before the merge, and it covers the requirements, the docs, the
tests and the implementation together.

## Agents are never co-authors

An automated agent must never add itself, its model, its harness or any of
its tools to the commit trailers. In particular, no commit may contain a
`Co-Authored-By` trailer naming an agent or an automation account. A commit
is authored by the human who made or directed the work. If no human other
than the maintainer contributed, the commit has a single author and no
co-author trailer. Human contributors are credited only with their real name
and address. Agents may mention the work in the commit body when it helps a
reader, but they never claim authorship.

This rule is permanent and applies retroactively to all future work. The
history created before this rule was written is preserved only as a local
backup and is not the history of the rebuilt repository.

## Branches and commits

Branch names are `feat/<slice>-<scope>`, `fix/<slice>-<scope>` or
`docs/<scope>`. Commit messages follow Conventional Commits, for example
`feat(engine): add typed isolate transport` or `docs: record PR-only rule`.
A pull request carries exactly one commit, as required by R36. That commit
is atomic: its documentation, tests and implementation are one change, and
no second commit is pushed to fix a review comment. Amend the single commit
and force push the pull request branch instead.

When an agent opens a pull request, it writes a brief body in the style of
the foundation pull request: a few sentences stating what the change
establishes, what it records and what it does not include. It does not write
a long narrative and it does not claim human authorship. The maintainer may
expand the body during review. The pull request template carries this rule.

## Before opening a pull request

Documentation comes first or together with the code, as required by R3.
Any new directive or decision is recorded in `docs/requirements.md` and in
an ADR before it is implemented. No `.env` file is used for configuration or
credential management, as required by R37: the app manages OAuth and secure
credential entry and stores tokens in the operating system keychain.
Algorithm and ingestion work follows the red, green, refactor cycle. The
analyzer must be clean and the formatter must report no changes. Targeted
tests are run while iterating; the full suite runs before the pull request
is merged.

## Review checklist

A review confirms that the change is documented, that the relevant skill in
`.agents/skills` was followed, that failure paths are tested, that no secret
appears in a versioned file, that the diff contains no agent co-author
trailer and that the change reached `main` through a merge from a topic
branch.
