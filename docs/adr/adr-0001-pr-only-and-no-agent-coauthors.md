# ADR-0001: Pull requests for every change, and no agent co-authors

## Status

Accepted on 2026-11-28. This decision implements R30 and R31. The hook-based
enforcement described below was superseded on the same day by R38 and
ADR-0014, which use GitHub-native checks instead.

## Context

The previous history recorded every commit with a `Co-Authored-By` trailer
for an automation account. The maintainer stated as a permanent rule that
the agent must not put itself in the co-authors, and confirmed that work
proceeds only with pull requests by default, including the initial commits
of the rebuild. The repository also has to stay entirely on the local
machine until publishing is explicitly authorised.

## Decision

Every change reaches `main` through a pull request. The `main` branch is
read-only and accepts only a two-parent merge commit whose subject names a
pull request branch. Topic branches reach the remote as
`pr/<number>-<slug>`. The original design used a server-side hook in a local
bare mirror to reject direct writes to `main`, arbitrary branch names, force
updates and agent co-author trailers. That mechanism is no longer used,
because the authoritative remote is a public GitHub repository; R38 and
ADR-0014 define the GitHub-based replacement. The only direct commit on
`main` is an empty root commit. Human contributors may be credited only with
real names and addresses.

## Consequences

The merge history is a durable proof of the workflow, and no agent
authorship cannot enter the rebuilt repository. The authoritative remote is
hosted on GitHub, and the history can be mirrored locally without rewriting
it. The cost is one extra merge commit per change and the need to maintain
the GitHub checks described in ADR-0014.
