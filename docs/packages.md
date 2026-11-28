# Packages

The workspace uses unprefixed package names. Each package has one reason to
change, and dependencies point inward: front-ends depend on the protocol,
and the protocol depends on nothing but the Dart core libraries.

| Package | Responsibility |
| :--- | :--- |
| `protocol` | Pure Dart engine contract, immutable values and reactive streams |
| `engine` | Embedded isolate, ingestion, storage, threading and outbound work |
| `core` | RFC 5322 parsing, thread algorithms and domain value types |
| `security` | Keychain and OAuth ports for credentials entered in the app |
| `cli` | Terminal client over the same engine contract |

`l10n` for Fluent resources and `app` for the Flutter GUI are planned slices,
not yet present in the workspace. `engine` replaced the earlier `server`
package, as recorded in ADR-0002. There is no wire protocol or version
handshake, as recorded in ADR-0016.
There is no PostgreSQL adapter, no MinIO adapter and no inbound SMTP
listener in the shipped tree. `data/` sits outside the packages and holds
the catalogue, rulesets and fixtures. Every Dart source file carries the
copyright notice required by R12.
