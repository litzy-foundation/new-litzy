# ADR-0024: Standalone SQL resources

## Status

Accepted on 2026-11-28. This decision implements R51 and refines R47 and
ADR-0004.

## Context

R47 already required the SQLite schema to live in a separate `.sql` file, and
the rebuilt engine adopted `packages/engine/schema.sql`. The maintainer
restated the rule more broadly: "sql va in file sql autonomo , non nel codice".
The broader wording covers statements and reusable fragments as well as the
schema, so a single schema file alone does not settle the boundary.

SQL written as Dart strings is hard to review with database tools, easy to
duplicate and impossible to validate independently of the client code. Code
needs a stable way to select a statement and bind values, while the database
language stays in files that can be inspected and changed on their own.

## Decision

Every SQL statement, schema definition, pragma and reusable fragment lives in
a standalone `.sql` resource. Dart code holds only resource keys, named
parameters and the loader that reads a resource. No Dart string contains SQL
text. The engine loads schema and statements by key at startup or before a
query, and a test rejects SQL keywords embedded in Dart source. Dynamic query
shapes use named fragments from `.sql` resources rather than assembled string
literals.

## Consequences

Database changes are reviewed as data changes next to the code that selects
them. Loading by key adds a small indirection but gives every statement a
single source of truth. The guard test turns the convention into a merge
condition, so a regression fails analysis or tests rather than review alone.
The audit in S14 found statements in the local database and in two engine
tests; all now load from `packages/engine/sql`. The SQL part of P15 is closed,
while the wider literal question Q8 stays open.
