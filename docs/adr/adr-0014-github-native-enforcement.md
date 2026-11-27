# ADR-0014: GitHub-native enforcement of the pull request flow

## Status

Accepted on 2026-11-28. This decision implements R38 and supersedes the
hook-based enforcement in ADR-0001.

## Context

The rebuild initially versioned a `pre-receive` hook and installed it in a
local bare mirror. The authoritative remote is a public repository on GitHub,
where a custom pre-receive hook cannot be installed. The maintainer stated
that such a hook will never be used and asked for a GitHub-based alternative.
A policy that exists only on a local mirror would give a false sense of
protection while the real remote accepted writes that the policy forbids.

## Decision

Enforcement lives on GitHub. Branch protection on `main` requires a pull
request, applies to administrators, and blocks force pushes and deletion of
the branch. A GitHub Actions workflow named `pr-guard` runs on every pull
request and publishes a required status check with the same name. The check
requires the base to be `main`, the head branch to match
`pr/<number>-<slug>` with the pull request number, exactly one commit in the
pull request, a Conventional Commit subject, and no `Co-Authored-By` trailer
naming an agent, a model, a harness or an automation account.

No hook is versioned and no bare-mirror hook is installed. The local bare
repository remains an offline mirror without server-side policy. The
two-parent merge commit whose subject names the pull request remains the
historical proof that a change was accepted through review.

## Consequences

The enforced rules now apply at the authoritative remote, so a local mirror
can be lost or replaced without weakening the workflow. A check is only as
good as the workflow that defines it, so changes to `pr-guard` need review
like any other code. The check inspects pull request metadata and the single
commit message; it does not replace human review of requirements, design and
tests. A future move to GitHub rulesets can refine who may create branches,
but the branch names and commit shape are already checked on every pull
request.
