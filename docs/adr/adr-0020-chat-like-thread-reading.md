# ADR-0020: Chat-like reading with real thread branches

## Status

Accepted on 2026-11-28. This decision implements R46.

## Context

A flat chat view hides the structure of a technical mailing list, while a
strict tree view is slower to scan than a modern chat client. The maintainer
defined the target as "a metà tra Slack e Zulip": channels and triage on the
left, topics ordered by last activity in the centre and a branch-aware
conversation on the right. Long messages contain nested citations and patch
diffs, so a daily reading tool must keep those blocks manageable.

## Decision

The GUI presents catalogue lists as channels beside cross-channel views for
own threads, unread mail and awaiting reply. The centre pane shows topics with
patch badges, unread counts and triage state. The right pane keeps reply
branches visible and reads like chat. Deeper citation levels fold by default,
diff blocks render in monospace with clear colour, and selected text can be
quoted into the composer. Sending requires Ctrl+Enter and shows To and Cc
before the action. User-visible text comes from Fluent resources so both
front-ends share vocabulary.

## Consequences

The interface is a thin presentation layer over engine streams and holds no
parsing or threading rules. A reader can scan a busy list quickly without
losing the relationship between parallel patch reviews. The composer respects
mailing list etiquette and avoids an accidental half-written public message.
Because the pattern is defined once, implementation proceeds without repeated
confirmation loops. The GUI remains read-only until the outbound slice lands.
