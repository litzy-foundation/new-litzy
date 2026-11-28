---
name: litzy-workflow
description: REQUIRED for any work in the Litzy monorepo. Covers toolchain, TDD, targeted tests, Conventional Commits, PR-only flow and the ban on agent co-authors.
---

# Litzy workflow

Read `docs/requirements.md` and `AGENTS.md` at the start of a session. If a
task changes architecture or adds a directive, write the documentation
first, then the code. Establish the baseline with `dart run melos run
analyze` and `dart run melos run test` before touching a package.

Use mise for toolchains and invoke melos through `dart run`. Work on a topic
branch and reach `main` only through a pull request, as required by R31.
Push the branch as `pr/<number>-<slug>` and let the maintainer merge with a
merge commit. Never commit on `main`, never force push and never add an
agent co-author trailer, as required by R30.

Algorithm, ingestion and purge work follows red, green, refactor. Run the
targeted test command while iterating and the full suite before the pull
request is merged. Analysis at zero issues, clean formatting and green
tests are merge conditions, not goals. Commit messages follow Conventional
Commits and changes are atomic. Package names have no prefix and
`pubspec.lock` is committed.

The agent also runs acceptance against every binary it builds or changes,
including the compiled GUI client, as required by R50 and ADR-0023. Widget and
engine-backed tests do not close a binary slice. A target that cannot be
exercised locally is recorded as unverified in the roadmap and the problem
register.
