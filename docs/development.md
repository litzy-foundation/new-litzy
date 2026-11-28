# Development guide

## Prerequisites

Toolchains are pinned with mise in the root `mise.toml`. Melos is a root dev
dependency and is invoked with `dart run melos`, never as a global tool.

```bash
dart pub get
dart run melos bootstrap
```

There is no local infrastructure to start. The engine uses SQLite, raw
content stays in the local database or in a local folder, and external
protocols are represented by fixture servers in tests. Any earlier compose
file for PostgreSQL, MinIO or other services is not part of this repository.

## Commands

| Command | Effect |
| :--- | :--- |
| `dart run melos bootstrap` | Resolve dependencies in every workspace package |
| `dart run melos run analyze` | Analyze all packages, zero issues required |
| `dart run melos run test` | Run the full suite |
| `dart run melos run test:core` | Run only the tests of `core` |
| `dart run melos run test:protocol` | Run only the tests of `protocol` |
| `dart run melos run test:engine` | Run only the tests of `engine` |
| `dart run melos run test:binary` | Build and launch the CLI and Linux GUI binaries |
| `dart run melos run build:gui-linux` | Build the Linux GUI binary used by acceptance |
| `dart run melos run format` | Format all Dart sources |

## Test discipline

Parsing, threading, ingestion and purge work follows red, green, refactor.
The targeted command runs while iterating and the full suite runs before a
pull request is merged. Acceptance tests start the real binary, engine and
database as described in ADR-0013. Test databases are created in temporary
directories, never in the package directory and never in a user's profile.
No test deletes local user data. Binary acceptance lives in `binary_test`
directories so the normal Dart and Flutter suites do not launch a binary before
it has been built. SQL statements live in standalone `.sql` resources under
`packages/engine/sql`, and a guard reads its detection patterns from
`data/quality/sql_guard.yaml`.

## Code standards

The root `analysis_options.yaml` owns every lint rule. Sources are
immutable by default, failures are deterministic result values rather than
exceptions across boundaries, and every public declaration has a doc
comment. Section banners, stubs and dead code are forbidden. Each source
file carries the copyright notice required by R12.

## Version control

Every change reaches `main` through a pull request as required by R31. Work
on a local topic branch, push it as `pr/<number>-<slug>`, open the pull
request and let the maintainer merge with a merge commit. No agent adds a
co-author trailer, as required by R30. Commit messages follow Conventional
Commits, and changes are atomic. The complete security model is in
`repository-security.md`.

## Namespace convention

Package names have no prefix: `protocol`, `engine`, `core`, `l10n`, `app`
and `cli`. Renaming a package means updating the root workspace, each
`resolution: workspace` entry, the path dependencies and every
`package:<name>/...` import.
