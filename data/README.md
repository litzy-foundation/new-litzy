# Data

This directory holds declarative data only, as required by R2 and ADR-0004.
Nothing here contains logic or secrets. Runtime state belongs in the local
SQLite database and credentials belong in the environment or the operating
system keychain.

## Layout

The `catalog` directory holds the YAML list catalogue for Mode C. Each entry
names a list, its protocol, its list identifier and the endpoints that can
serve it. The `default.yaml` file names the catalogue and source used when a
front-end omits those flags. The `rulesets` directory holds classification
rules, including the newsletter defaults. The `fixtures` directory holds named
fixtures used by tests. The `quality` directory holds the detection patterns
read by the SQL resource guard, so the guard itself stays free of statement
text. A `local` directory may be created for development-only data and is
git-ignored; it never enters the repository.

## Validation

A missing required field is an explicit startup error rather than a silent
default. Catalogue changes are reviewable in pull requests and do not
require a code change. Tests load fixtures by name through a helper instead
of embedding message data in Dart source.
