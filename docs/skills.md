# Skills index

Working conventions live in `.agents/skills` as plain Markdown files with
`name` and `description` front matter. They are agent-agnostic, as required
by R29, and are loaded before work in the area they describe. Updating a
skill is part of the change that updates the convention.

| Skill | Load before |
| :--- | :--- |
| `track-committer-directives` | Any directive, decision, preference or course change stated by the maintainer |
| `writing-documentation` | Writing or editing documentation, ADRs, README or agent instructions |
| `litzy-workflow` | Any work in the workspace, including tests and commits |
| `litzy-clean-code` | Writing or reviewing a Dart source file |
| `litzy-solid-review` | Designing a class or reviewing a change before a pull request |
| `litzy-data-separation` | Adding data or deciding where a kind of data belongs |
| `litzy-multiplatform` | User interface or packaging work across the five targets |
| `litzy-l10n` | User-visible text, Fluent resources or the l10n package |

The skill files are part of the documentation and follow the pure-prose
style of R28. They are deliberately short: they state a binding procedure
and point back to the requirement or ADR that owns the decision.
