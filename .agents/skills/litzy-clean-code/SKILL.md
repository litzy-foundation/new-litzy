---
name: litzy-clean-code
description: REQUIRED when writing or reviewing any Litzy Dart source file. Enforces doc comments only, no banner comments, no stubs or dead code, and root-cause quality.
---

# Litzy clean code

The file is the structure. Comments decorate declarations, never the page.
Section banners, aligned rules of punctuation, ASCII art and all-caps
headers are forbidden in every case. A section expressed by a comment is a
request for two files.

The only comments allowed are doc comments on public declarations, a
library-level doc comment explaining the role of the file and the driving
requirement, and rare inline comments that explain a why which code cannot
express. Comments are English complete sentences. Every public symbol has a
doc comment a newcomer understands.

Committed code contains no stub, no `UnimplementedError`, no `TODO`, no
commented-out code and no unused import. A feature that is not ready ships
nothing and is tracked in the roadmap or the problem register. Prefer final
classes, const constructors and immutable values. Order a file by cohesion,
keep one concept per file and avoid dumping grounds.

One source file defines one public class with one reason to change. Code refers
to keys rather than literal values. Declarative values live in YAML, all SQL
lives in standalone `.sql` resources loaded by key, and user-visible text lives
in Fluent resources.
Newline, tab and null characters are expressed through named representations
rather than raw literals when a named form is available. A valid focused patch
is accepted on its merits without ceremony beyond the permanent pull request
rules.

Before committing, format the source, run analysis at zero issues, check the
diff for forbidden markers and verify that failure paths are tested.
