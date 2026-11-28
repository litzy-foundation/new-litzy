# ADR-0023: Agent-tested binaries

## Status

Accepted on 2026-11-28. This decision implements R50 and refines R27 and
ADR-0013.

## Context

R27 requires acceptance tests that open the real application with the real
binary, engine and database. ADR-0013 applies that rule to every slice. The
read-only GUI slice added an engine-backed widget test that starts the real
isolate and SQLite profile, but it did not build or launch the compiled GUI
client. The maintainer then stated: "anche il client binary va testato da te ;
i binary vanno testati da te".

An engine-backed widget test proves that the client code and engine agree on
typed requests and rendering. It does not prove that the shipped binary can be
built, started and given a real profile. A CLI binary without a process-level
run has the same gap. A slice cannot be called done while the agent has not
exercised a binary it produced.

## Decision

The agent builds and launches every binary it produces or changes as part of
the slice acceptance. For the GUI this means compiling a desktop binary with
the pinned Flutter toolchain and running it against a recorded public fixture
and a temporary SQLite profile. For the CLI it means invoking the shipped
binary as a process. The harness locates the binary through an injected path,
never through a fixed developer path, and keeps all runtime state in temporary
directories.

A target that this machine cannot build or run is recorded as unverified in
the roadmap and the problem register. No report claims that a binary was
tested on a platform where it was not launched. The full suite and the binary
acceptance both have to pass before the slice is offered for merge.

## Consequences

Binary acceptance becomes a merge condition alongside formatting, analysis and
unit tests. The harness needs a build step before the test step and must clean
up processes and temporary profiles after each run. CI has to build the same
binary that acceptance launches. Slices that cannot exercise a target say so
explicitly instead of treating source-level green tests as proof of packaged
behaviour. P20 is closed for Linux: the compiled GUI and CLI binaries were
launched against real SQLite profiles on 2026-11-28. The other targets were
not exercised and remain recorded as unverified rather than covered.
