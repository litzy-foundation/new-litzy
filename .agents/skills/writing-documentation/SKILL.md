---
name: writing-documentation
description: REQUIRED when writing or editing any Litzy documentation, including docs, ADRs, README, AGENTS.md, CONTRIBUTING.md and skills. Enforces pure English prose with no emoji or decorative markers.
---

# Writing documentation

All Litzy documentation is English prose, as required by R11 and R28. A
reader who has never seen the project must understand a document without
asking anyone. Explain ideas in complete sentences and use lists only for
genuinely enumerable items such as file layouts and step sequences.

Never use emoji, including status symbols in place of words. Write that a
slice is done, in progress or open. Never use decorative dividers, banners
of punctuation or ASCII art. Structure comes from headings and paragraph
order. A table is acceptable for parallel facts, not for narration.

Documentation comes before or together with the code it describes, as
required by R3. Every directive is recorded in `requirements.md`, every
architectural choice in an ADR, every slice in the roadmap and every problem
in the problem register. One fact belongs in one place; cross-reference
rather than duplicate it, because a duplicated fact will rot.

Before committing documentation, check that there is no emoji, that every
heading is followed by prose, that statuses are spelled out and that quoted
directives are preserved verbatim in the requirements record.
