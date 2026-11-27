---
name: track-committer-directives
description: REQUIRED whenever the maintainer states a directive, decision, preference or course change. Crystallizes it into requirements, AGENTS.md, ADRs, roadmap and the problem register before or with any code.
---

# Track committer directives

The maintainer asked permanently to document everything they say and to
remember it forever, as recorded in R3. This skill is the operational
procedure and applies to every statement that expresses a directive, a
decision between alternatives, a preference or a change of course. Ordinary
task instructions do not need a permanent record, but a statement in doubt
is treated as a directive.

## Procedure

Recognize the directive and record it in the same session, before or with
the code. The home of a directive is `docs/requirements.md`, as a numbered
requirement in the maintainer's own terms. Quote the original wording when
it carries intent. Never delete or weaken an existing requirement: a change
of mind supersedes it with a new explicit decision, and both entries point
at each other.

Summarize the directive in `AGENTS.md` so every session inherits it. When it
settles an architectural alternative, write an ADR with Context, Decision
and Consequences. When it creates work, add the slice to `docs/roadmap.md`.
When it raises a problem, add the problem to `docs/milestone-issues.md` and
keep it there until it has closure evidence.

At the end of a session in which the maintainer spoke, verify that every
directive is somewhere in the permanent record. Nothing may live only in a
conversation.
