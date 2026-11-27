# ADR-0011: Typed plugins and a local summarizer

## Status

Accepted on 2026-11-28. This decision implements R19 and R21.

## Context

Newsletters, feeds and mailing lists are the same problem of asynchronous
content that should not land in a personal mailbox. The maintainer also
wants a brief local summarizer and a future inbound SMTP plugin, while
keeping the shipped perimeter free of infrastructure.

## Decision

A versioned, typed extension surface allows plugins to provide sources,
filters and agents. Mode C adapters and the RSS source are ordinary plugins
behind that surface, as is the local summarizer. A plugin cannot bypass the
storage policy or the trust chain. The summarizer runs only on the user's
machine, adapts to available hardware, supports several local models and
produces brief output. The removed Mode A may return only as a plugin after
a new decision.

## Consequences

New sources can be added without changing front-ends, and all ingestion
shares one trust chain. Sandboxing and strict interface boundaries are
required so a plugin cannot read secrets or write outside its slot. Local
models are downloaded on demand and never bundled, which keeps the
repository and the application small.
