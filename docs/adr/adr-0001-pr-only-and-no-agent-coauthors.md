# ADR-0001: Pull requests for every change, and no agent co-authors

## Status

Accepted on 2026-11-28. This decision implements R30 and R31.

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
pull request branch. The remote is a local bare repository created from
zero, and topic branches reach it as `pr/<number>-<slug>`. A server-side
hook rejects direct writes to `main`, arbitrary branch names, force updates
and any commit whose trailer names an agent, a model, a harness or an
automation account as co-author. The only direct commit on `main` is an
empty root commit. Human contributors may be credited only with real names
and addresses.

## Consequences

The merge history is a durable proof of the workflow, and no agent
authorship can enter the rebuilt repository even by accident. The local
remote keeps the whole process on disk, and it can be replaced by a hosted
remote later without rewriting history. The cost is one extra merge commit
per change and the need to maintain the hook, which is versioned beside the
rule it enforces.
