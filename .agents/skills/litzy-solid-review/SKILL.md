---
name: litzy-solid-review
description: REQUIRED before committing code or after writing a new class. Applies the SOLID and pattern checklist from engineering-standards.md and declares what was not verified.
---

# Litzy SOLID review

Apply the checklist in `docs/engineering-standards.md` to the modified code
and answer each question explicitly. Does the new class have a single reason
to change, or does it mix two domains such as parsing and input output? Would
a growing conditional chain be better as a sealed type with an exhaustive
switch? Can the dependency be replaced by a fake without hacks, or does it
need a port in the protocol package? Is the exposed API minimal? Does any
dependency point from the engine to a front-end, which is forbidden?

Check that failures are deterministic result values, that new data is
classified as declarative YAML, SQLite state or a secret, and that public
members have doc comments. Verify that analysis is clean, formatting is
clean and targeted tests are green. End the review by declaring what was
not verified, so a claim of completeness is never implied by silence.
