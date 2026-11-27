# Packages

The workspace uses unprefixed package names. Each package has one reason to
change, and dependencies point inward: front-ends depend on the protocol,
and the protocol depends on nothing but the Dart core libraries.

| Package | Responsibility |
| :--- | :--- |
| `protocol` | Typed LMLP message union, in-process transport and version handshake |
| `engine` | Embedded isolate, ingestion, storage, threading and outbound work |
| `core` | RFC 5322 parsing, thread algorithms and domain value types |
| `l10n` | Fluent resources for user-visible strings |
| `app` | Flutter GUI for desktop and mobile |
| `cli` | Terminal client over the same protocol |

`engine` replaced the earlier `server` package, as recorded in ADR-0002.
There is no PostgreSQL adapter, no MinIO adapter and no inbound SMTP
listener in the shipped tree. `data/` sits outside the packages and holds
the catalogue, rulesets and fixtures. Every Dart source file carries the
copyright notice required by R12.
