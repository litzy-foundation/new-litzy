# Engineering standards

These standards implement R5 and R6. They are enforced by analysis, review
and the skill files under `.agents/skills`.

## Language

Dart is used with sound null safety and a strict analyzer. Prefer final
classes, const constructors and immutable fields. Use exhaustive switches
over sealed unions instead of chains of type checks. Avoid `dynamic`,
unused members and swallowed errors. Recoverable failures are represented
by deterministic result types; exceptions are reserved for broken
invariants.

## Structure

Each package has one reason to change. Dependencies point from front-ends
to the protocol and from the protocol to nothing but the Dart core. The
engine depends on the domain and storage ports, never on a front-end.
Interfaces are small and expressed in terms the caller already owns. A new
concrete dependency between two packages is a design error unless it goes
through a port in `protocol`.

## SOLID review checklist

A change is reviewed against the following questions. Does the new class
have a single reason to change? Would a growing conditional chain be better
as a sealed type and an exhaustive switch? Can a dependency be replaced by
a fake without hacks, or does it need a port? Is the exposed API minimal?
Does any dependency point the wrong way between front-end and engine? Are
failures deterministic? Is new data classified as YAML, SQLite or secret?
Do public members have doc comments? Are analysis, formatting and targeted
tests clean?

## Comments

Only doc comments and rare explanatory inline comments are allowed. Section
banners, aligned rules of punctuation and all-caps headers are forbidden in
source files. A file that seems to need sections should be split. Comments
are English and complete sentences, as required by R11.

## Tests

Algorithm work follows red, green, refactor. Failure paths are tested, not
hoped for. Acceptance tests use the real binary, engine and database.
Anything that touches user data uses a temporary directory.
